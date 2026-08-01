// ─────────────────────────────────────────────────────────────────────────────
// firebase-messaging-sw.js  — NEW FILE  (place in /web folder)
//
// This service worker is required for Firebase Cloud Messaging background
// push notifications on web. It runs in the background even when the browser
// tab is closed.
//
// HOW TO GET YOUR VAPID KEY:
//   1. Go to Firebase Console → Project Settings
//   2. Click "Cloud Messaging" tab
//   3. Scroll to "Web Push certificates"
//   4. Click "Generate key pair" (or use existing)
//   5. Copy the Key Pair string and paste it into notification_service.dart
//      as kVapidKey
//
// This file uses the Firebase compat SDK (v9 compat) which works in SW context.
// ─────────────────────────────────────────────────────────────────────────────

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// ── Firebase config (matches firebase_options.dart web config) ────────────────
firebase.initializeApp({
  apiKey: 'AIzaSyCGyZe6crlOPMfMmXvYWiquBCQDfDBmmo8',
  authDomain: 'leadcapture-79a43.firebaseapp.com',
  projectId: 'leadcapture-79a43',
  storageBucket: 'leadcapture-79a43.firebasestorage.app',
  messagingSenderId: '204207195810',
  appId: '1:204207195810:web:4f329a51ecefce1f0339fb',
});

const messaging = firebase.messaging();

// ── Background message handler ────────────────────────────────────────────────
// This fires when a push message arrives while the app tab is in the background
// or the browser is closed. It shows a system notification.
messaging.onBackgroundMessage(function (payload) {
  console.log('[SW] Background message received:', payload);

  const notificationTitle =
    payload.notification?.title ||
    payload.data?.title ||
    'LeadcaptureCRM';

  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || 'New notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
    // Vibrate pattern for mobile browsers that support it
    vibrate: [200, 100, 200],
  };

  return self.registration.showNotification(
    notificationTitle,
    notificationOptions,
  );
});

// ── Notification click handler ────────────────────────────────────────────────
// Opens / focuses the app tab when the user taps the notification.
self.addEventListener('notificationclick', function (event) {
  event.notification.close();

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then(function (windowClients) {
        // If a tab is already open, focus it
        for (var i = 0; i < windowClients.length; i++) {
          var client = windowClients[i];
          if ('focus' in client) {
            return client.focus();
          }
        }
        // Otherwise open a new tab
        if (clients.openWindow) {
          return clients.openWindow('/');
        }
      })
  );
});
