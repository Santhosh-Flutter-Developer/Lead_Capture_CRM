import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class EventCreate extends StatefulWidget {
  final DateTime? selectedDate;
  const EventCreate({super.key, this.selectedDate});

  @override
  State<EventCreate> createState() => _EventCreateState();
}

class _EventCreateState extends State<EventCreate> {
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _eventDescriptionController =
      TextEditingController();
  final TextEditingController _eventDateTimeController =
      TextEditingController();
  final TextEditingController _eventEndDateTimeController =
      TextEditingController();

  final List<String> _repeatTypes = EventRepeatType.values
      .map((e) => e.name.capitalizeFirst)
      .toList();
  String? _selectedRepeatType;

  DateTime? _selectedEventDateTime;
  DateTime? _selectedEndEventDateTime;


  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late Future _future;

  @override
  void initState() {
    _selectedEventDateTime = widget.selectedDate;
    _selectedEndEventDateTime = widget.selectedDate?.add(
      const Duration(hours: 1),
    );
    _eventDateTimeController.text =
        _selectedEventDateTime?.formatDateTime24Hrs ?? '';
    _eventEndDateTimeController.text =
        _selectedEndEventDateTime?.formatDateTime24Hrs ?? '';
    _future = _init();
    super.initState();
  }

  Future<void> _init() async {
    try {
      setState(() {});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _eventDescriptionController.dispose();
    _eventDateTimeController.dispose();
    _eventEndDateTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const WaitingLoading();
            } else if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              child: Center(
                child: Form(
                  key: _formKey,
                  child: Column(
                    // crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FormWidgets.buildHeader(
                        context: context,
                        title: "Create Event",
                      ),
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        title: "Event Details",
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              _buildFormFields(constraints, 4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: FormWidgets.buildBottomBar(
          context: context,
          onSubmit: _submitForm,
          isEdit: false,
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields(BoxConstraints constraints, int gridCounts) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    const double minColumnWidth = 220.0;

    final bool canShowGrid =
        currentWidth >=
        (minColumnWidth * gridCounts + horizontalSpacing * (gridCounts - 1));

    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (gridCounts - 1)) / gridCounts
        : currentWidth;

    return Wrap(
      spacing: horizontalSpacing,
      runSpacing: verticalSpacing,
      children: [
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Event Name',
            controller: _eventNameController,
            hintText: 'Enter Event Name',
            isRequired: true,
            valid: (input) => input == null || input.isEmpty
                ? 'Event Name is required'
                : null,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Event Description',
            controller: _eventDescriptionController,
            hintText: 'Enter Event Description',
            maxLines: 2,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            controller: _eventDateTimeController,
            readOnly: true,
            onTap: () async {
              var date = await datePicker(context);
              if (date != null) {
                var time = await pickTime(context, null);
                if (time != null) {
                  _eventDateTimeController.text =
                      '${date.formatDate} ${time.hour}:${time.minute}:00';
                  _selectedEventDateTime = date.copyWith(
                    hour: time.hour,
                    minute: time.minute,
                  );
                  setState(() {});
                }
              }
            },
            hintText: 'DD/MM/YYYY HH:MM:SS',
            suffixIcon: const Icon(Iconsax.calendar_1),
            label: 'Event Date & Time',
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            controller: _eventEndDateTimeController,
            readOnly: true,
            onTap: () async {
              var date = await datePicker(context);
              if (date != null) {
                var time = await pickTime(context, null);
                if (time != null) {
                  _eventEndDateTimeController.text =
                      '${date.formatDate} ${time.hour}:${time.minute}:00';
                  _selectedEndEventDateTime = date.copyWith(
                    hour: time.hour,
                    minute: time.minute,
                  );
                  setState(() {});
                }
              }
            },
            hintText: 'DD/MM/YYYY HH:MM:SS',
            suffixIcon: const Icon(Iconsax.calendar_1),
            label: 'Event End Date & Time',
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Repeat',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              CustomSearchableDropdown(
                items: _repeatTypes.map((e) => e).toList(),
                onChanged: (value) {
                  final rp = _repeatTypes.firstWhere(
                    (element) => element == value,
                  );
                  _selectedRepeatType = rp;
                },
                itemAsString: (s) => s,
              ),
            ],
          ),
        ),

      ],
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);

        EventModel eventModel = EventModel(
          eventName: _eventNameController.text.trim(),
          eventDateTime: _selectedEventDateTime ?? DateTime.now(),
          eventEndDateTime:
              _selectedEndEventDateTime ??
              DateTime.now().add(const Duration(hours: 1)),
          eventDescription: _eventDescriptionController.text.trim(),
          eventRepeatType: EventRepeatType.values.firstWhere(
            (e) =>
                e.name.capitalizeFirst ==
                (_selectedRepeatType ??
                    EventRepeatType.none.name.capitalizeFirst),
          ),
          eventAttendes: [],
          createdBy: await Spdb.getUser(),
        );

        await EventService.createEvent(event: eventModel);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);

        FlushBar.show(context, 'Event created successfully', isSuccess: true);
      } catch (e, st) {
        await ErrorService.recordError(e, st);
        debugPrint("${e.toString()}, ${st.toString()}");
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        FlushBar.show(
          context,
          e.toString(),
          isSuccess: false,
          error: e,
          stackTrace: st,
        );
      }
    }
  }
}
