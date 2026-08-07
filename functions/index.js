/* eslint-disable linebreak-style */
/* eslint-disable padded-blocks */
/* eslint linebreak-style: ["error", "windows"] */
/* eslint-disable indent, max-len, space-in-parens, no-multi-spaces, key-spacing, object-curly-spacing, comma-dangle */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const nodemailer = require("nodemailer");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

admin.initializeApp();

const FIREBASE_API_KEY = "AIzaSyD1-qmYt3fwlA-TlHmxHOhd_DL3lmj5TF0";

exports.sendEmail = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
        const { smtp_host, smtp_user, smtp_pass, from, from_name, to, subject, message } = req.body;

        if (!smtp_user || !smtp_pass || !to || !subject || !message) {
            return res.status(400).json({ success: false, error: "Missing required fields" });
        }

        const transporter = nodemailer.createTransport({
            host: smtp_host || "smtp.gmail.com",
            port: 465,
            secure: true,
            auth: { user: smtp_user, pass: smtp_pass },
        });

        await transporter.sendMail({
            from: `"${from_name || "Lead Capture"}" <${from || smtp_user}>`,
            to: to,
            replyTo: from || smtp_user,
            subject: subject,
            html: message,
        });

        return res.status(200).json({ success: true, message: "Email sent successfully" });
    } catch (error) {
        console.error("sendEmail error:", error);
        return res.status(500).json({ success: false, error: error.message });
    }
});

exports.verifyAuth = functions.https.onRequest(async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ success: false, error: "Missing email or password" });
        }

        // Call Firebase Authentication REST API to verify credentials
        const response = await axios.post(
            `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
            {
                email,
                password,
                returnSecureToken: true
            }
        );

        return res.status(200).json({ success: true, data: response.data });

    } catch (error) {
        let errorMessage = "Authentication failed";

        if (error.response && error.response.data && error.response.data.error && error.response.data.error.message) {
            errorMessage = error.response.data.error.message;
        }

        return res.status(400).json({
            success: false,
            error: errorMessage
        });
    }
});

exports.updateUserPassword = functions.https.onRequest(async (req, res) => {
    try {
        const { email, newPassword } = req.body;

        if (!email || !newPassword) {
            return res.status(400).json({ success: false, error: "Missing email or password" });
        }

        const user = await admin.auth().getUserByEmail(email);
        await admin.auth().updateUser(user.uid, { password: newPassword });

        res.json({ success: true, message: `Password updated for ${email}` });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
});

exports.deleteUserByEmail = functions.https.onRequest(async (req, res) => {
    try {
        const { email } = req.body;

        if (!email) {
            return res.status(400).json({ success: false, error: "Missing email" });
        }

        const user = await admin.auth().getUserByEmail(email);
        await admin.auth().deleteUser(user.uid);

        res.json({ success: true, message: `User with email ${email} deleted` });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
});

exports.removeoldNotifications = onSchedule(
    {
        schedule: "every 24 hours",
        timeZone: "Asia/Kolkata",
    },
    async (event) => {
        const db = getFirestore();
        const now = Timestamp.now();
        const cutoff = new Date(now.toDate().getTime() - 7 * 24 * 60 * 60 * 1000);

        console.log(`Cleaning notifications older than: ${cutoff.toISOString()}`);

        try {
            const usersSnapshot = await db.collection("users").get();
            let totalDeleted = 0;

            for (const userDoc of usersSnapshot.docs) {
                const notificationsRef = userDoc.ref.collection("notifications");
                const oldRecordsSnapshot = await notificationsRef
                    .where("timestamp", "<", cutoff)
                    .get();

                if (!oldRecordsSnapshot.empty) {
                    const batch = db.batch();
                    oldRecordsSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
                    await batch.commit();
                    totalDeleted += oldRecordsSnapshot.size;
                }
            }

            console.log(`Total old notifications deleted: ${totalDeleted}`);
            return null;
        } catch (error) {
            console.error("Error cleaning notifications:", error);
            return null;
        }
    }
);

exports.reminderScheduler = onSchedule("every 1 minutes", async () => {
    const db = getFirestore();
    const now = Timestamp.now();

    const snapshot = await db
        .collection("reminders")
        .where("isSent", "==", false)
        .where("scheduledAt", "<=", now)
        .get();

    for (const doc of snapshot.docs) {
        const reminder = doc.data();
        const notif = reminder.notification;

        try {
            // Send FCM
            if (notif.toFcms && notif.toFcms.length > 0) {
                await getMessaging().sendEachForMulticast({
                    tokens: notif.toFcms,
                    notification: {
                        title: notif.title,
                        body: notif.body,
                    },
                    data: notif.payload,
                });
            }

            // Save notification to sub-collection. Uses the reminder's own
            // doc id so re-processing the same reminder (e.g. scheduler
            // overlap) overwrites instead of duplicating the notification.
            await db
                .collection("users")
                .doc(notif.collectionId)
                .collection("notifications")
                .doc(doc.id)
                .set({
                    title: notif.title,
                    body: notif.body,
                    toFcms: notif.toFcms,
                    toUids: notif.toUids,
                    senderId: notif.senderId,
                    type: notif.type,
                    payload: notif.payload,
                    createdAt: Date.now(),
                });

            // Mark reminder sent
            await doc.ref.update({ isSent: true });
        } catch (error) {
            console.error(`Error sending reminder ${doc.id}:`, error);
            await doc.ref.update({
                lastError: error.message || String(error),
                lastErrorAt: Date.now(),
            });
        }
    }
});