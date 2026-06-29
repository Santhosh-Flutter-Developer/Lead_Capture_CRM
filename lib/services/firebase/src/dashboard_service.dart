import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:leadcapture/models/src/attendance_model.dart';
import 'package:leadcapture/services/firebase/src/attendance_service.dart';
import 'package:leadcapture/services/firebase/src/salary_service.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTimeRange _resolveDateRange(String filter, DateTimeRange? customRange) {
    final now = DateTime.now();

    switch (filter) {
      case "Today":
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: now,
        );

      case "This Week":
        final start = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: start, end: now);

      case "This Month":
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);

      case "Custom Date":
        if (customRange != null) {
          return customRange;
        } else {
          debugPrint("Custom date range is null, defaulting to today");
          return DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: now,
          );
        }

      default:
        return DateTimeRange(start: DateTime(2000), end: now);
    }
  }

  Future<DashboardModel> fetchDashboardData({
    required bool isAdmin,
    required String userId,
    required String filter,
    DateTimeRange? range,
  }) async {
    try {
      final cid = await Spdb.getCid();
      if (cid == null) throw "CollectionId cannot be null";

      final dateRange = _resolveDateRange(filter, range);

      final totalLeads = await _fetchTotalLeads(cid, dateRange);
      final convertedLeads = await _fetchConvertedLeads(cid, dateRange);
      final ongoingDeals = await _fetchOngoingDeals(cid, dateRange);
      final pendingTasks = await _fetchPendingTasks(cid, dateRange);
      final activeEmployees = await _fetchActiveEmployees(cid, dateRange);
      final assignedTasks = await _fetchAssignedTasks(cid, userId, dateRange);
      final pendingFollowUps = await _fetchPendingFollowUps(cid, dateRange);
      final leadsAssigned = await _fetchLeadsAssigned(cid, userId, dateRange);
      final totalTickets = await _fetchTotalTickets(cid, dateRange);
      final pendingTickets = await _fetchPendingTickets(cid, dateRange);
      final assignedTickets = await _fetchAssignedTickets(
        cid,
        userId,
        dateRange,
      );

      final recentActivities = await RecentActivityService()
          .getRecentActivities();

      final notifications = await _fetchNotifications(cid, userId);
      final upcomingTasks = await _fetchUpcomingTasks(cid);

      final allLeads = await LeadService.getAllLeads();
      final allDeals = await DealService.getAllDeals();
      final allTasks = await TaskService.getAllTasks();
      final allTickets = await TicketService.getAllTickets();
      List<HolidayModel> holidays = [];

      final attendanceStats = await AttendanceService.getAttendanceStats(
        userUid: userId,
        fromDate: dateRange.start,
        toDate: dateRange.end,
        holidays: holidays,
      );

      final salary = await SalaryLedgerService.getSalarySummary(
        userUid: userId,
        fromDate: dateRange.start,
        toDate: dateRange.end,
      );
      return DashboardModel(
        totalLeads: totalLeads,
        convertedLeads: convertedLeads,
        ongoingDeals: ongoingDeals,
        pendingTasks: pendingTasks,
        activeEmployees: activeEmployees,
        assignedTasks: assignedTasks,
        pendingFollowUps: pendingFollowUps,
        leadsAssigned: leadsAssigned,
        totalTickets: totalTickets,
        pendingTickets: pendingTickets,
        assignedTickets: assignedTickets,
        recentActivities: recentActivities,
        notifications: notifications,
        upcomingTasks: upcomingTasks,
        allLeads: allLeads,
        allDeals: allDeals,
        allTasks: allTasks,
        allTickets: allTickets,
        attendanceStats: attendanceStats,
        salary: salary,
      );
    } catch (e, st) {
      debugPrint("Error fetching dashboard: $e\n$st");
      throw 'Error fetching dashboard: $e';
    }
  }

  Future<int> _fetchTotalLeads(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leads.name)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchConvertedLeads(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leads.name)
        .where("leadsConversion", isEqualTo: true)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchOngoingDeals(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.deals.name)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchPendingTasks(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.tasks.name)
        .where("completed", isEqualTo: false)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchActiveEmployees(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.employees.name)
        .where("isActive", isEqualTo: true)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchAssignedTasks(
    String cid,
    String userId,
    DateTimeRange range,
  ) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.tasks.name)
        .where("assignees", arrayContains: userId)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchLeadsAssigned(
    String cid,
    String userId,
    DateTimeRange range,
  ) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leads.name)
        .where("assignedTo", isEqualTo: userId)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchPendingFollowUps(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leads.name)
        .where("allowFollowUp", isEqualTo: true)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchTotalTickets(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.customerTickets.name)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchPendingTickets(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.customerTickets.name)
        .where("status", isEqualTo: TicketStatus.open.name)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchAssignedTickets(
    String cid,
    String userId,
    DateTimeRange range,
  ) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.customerTickets.name)
        .where("assignTo", arrayContains: userId)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  // Future<List<String>> _fetchPersonalActivities(String userId) async {
  //   final snap = await _firestore
  //       .collection("personalActivities")
  //       .where("userId", isEqualTo: userId)
  //       .orderBy("createdAt", descending: true)
  //       .limit(5)
  //       .get();
  //   return snap.docs.map((d) => d.data()['activity'].toString()).toList();
  // }

  Future<List<NotificationModel>> _fetchNotifications(
    String cid,
    String userId,
  ) async {
    try {
      final snap = await _firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.notifications.name)
          .where("toUids", arrayContains: userId)
          .get();

      final notifications = snap.docs
          .map((d) => NotificationModel.fromMap(d.id, d.data()))
          .toList();

      notifications.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

      return notifications.take(5).toList();
    } catch (e, st) {
      debugPrint("Error fetching notifications: $e\n$st");
      throw 'Error fetching notifications: $e';
    }
  }

  Future<List<UpcomingDeadlineItemModel>> _fetchUpcomingTasks(
    String cid,
  ) async {
    try {
      final now = DateTime.now();
      final start = now.millisecondsSinceEpoch;
      final end = now.add(const Duration(days: 1)).millisecondsSinceEpoch;

      final tasksSnap = await FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.tasks.name)
          .where("deadline", isGreaterThan: start)
          .where("deadline", isLessThanOrEqualTo: end)
          .get();

      final eventsSnap = await FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.events.name)
          .where("eventDateTime", isGreaterThan: start)
          .where("eventDateTime", isLessThanOrEqualTo: end)
          .get();

      final ticketsSnap = await FirebaseFirestore.instance
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .where("deadline", isGreaterThan: start)
          .where("deadline", isLessThanOrEqualTo: end)
          .get();

      final upcoming = <UpcomingDeadlineItemModel>[];

      for (final d in tasksSnap.docs) {
        final task = TaskModel.fromMap(d.id, d.data());
        if (task.deadline == null || task.completed) continue;

        upcoming.add(
          UpcomingDeadlineItemModel(
            id: d.id,
            title: task.taskName,
            scheduledAt: task.deadline!,
            source: 'task',
          ),
        );
      }

      for (final d in eventsSnap.docs) {
        final event = EventModel.fromMap(d.id, d.data());
        if (event.completed) continue;
        upcoming.add(
          UpcomingDeadlineItemModel(
            id: d.id,
            title: event.eventName,
            scheduledAt: event.eventDateTime,
            source: 'event',
          ),
        );
      }

      for (final d in ticketsSnap.docs) {
        final ticket = CustomerTicketModel.fromMap(d.id, d.data());
        if (ticket.deadline == null || ticket.status == TicketStatus.closed) continue;
        upcoming.add(
          UpcomingDeadlineItemModel(
            id: d.id,
            title: ticket.ticketTitle,
            scheduledAt: ticket.deadline!,
            source: 'ticket',
          ),
        );
      }

      upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

      return upcoming.take(5).toList();
    } catch (e, st) {
      debugPrint("Error fetching upcoming tasks: $e\n$st");
      return [];
    }
  }
}
