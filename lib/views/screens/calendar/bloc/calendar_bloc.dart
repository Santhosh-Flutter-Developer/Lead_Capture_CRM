import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
part 'calendar_event.dart';
part 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarCalendar, CalendarState> {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<EventModel> allEvents = [];
  List<TaskModel> allTasks = [];
  List<LeadModel> allLeads = [];
  List<DealModel> allDeals = [];

  CalendarBloc() : super(CalendarLoading()) {
    on<StreamCalendar>(_streamCalendar);
  }

  Future<void> _streamCalendar(
    StreamCalendar event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());

    final cid = await Spdb.getCid();

    await LeadService.backfillLeadActivitiesToCalendar();

    final eventsStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.events.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => EventModel.fromMap(d.id, d.data()))
              .toList(),
        );

    final tasksStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.tasks.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => TaskModel.fromMap(d.id, d.data()))
              .toList(),
        );

    final leadsStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leads.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => LeadModel.fromMap(d.id, d.data()))
              .toList(),
        );

    final dealsStream = firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.deals.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => DealModel.fromMap(d.id, d.data()))
              .toList(),
        );

    await emit.forEach(
      Rx.combineLatest4<
        List<EventModel>,
        List<TaskModel>,
        List<LeadModel>,
        List<DealModel>,
        Map<String, dynamic>
      >(
        eventsStream,
        tasksStream,
        leadsStream,
        dealsStream,
        (events, tasks, leads, deals) => {'events': events, 'tasks': tasks, 'leads': leads, 'deals': deals},
      ),
      onData: (data) {
        return CalendarLoaded(
          data['events'] as List<EventModel>,
          data['tasks'] as List<TaskModel>,
          data['leads'] as List<LeadModel>,
          data['deals'] as List<DealModel>,
        );
      },
      onError: (error, stackTrace) {
        return CalendarError("Failed to load calendar: $error");
      },
    );
  }
}
