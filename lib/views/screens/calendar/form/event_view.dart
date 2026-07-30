import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/theme/theme.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class EventViewPage extends StatelessWidget {
  final EventModel event;

  const EventViewPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return EventView(event: event);
  }
}

class EventView extends StatefulWidget {
  final EventModel event;
  const EventView({super.key, required this.event});

  @override
  State<EventView> createState() => _EventViewState();
}

class _EventViewState extends State<EventView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        // backgroundColor: AppColors.grey50,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Event Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pop(context);
              if (kIsDesktop) {
                GeneralDialog.showRTLSheet(
                  context,
                  EventEdit(uid: widget.event.uid ?? ''),
                );
              } else {
                Sheet.showSheet(
                  context,
                  widget: EventEdit(uid: widget.event.uid ?? ''),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailCard(
              context,
              'Event Name',
              widget.event.eventName,
              Iconsax.calendar,
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              context,
              'Description',
              widget.event.eventDescription.isNotEmpty
                  ? widget.event.eventDescription
                  : 'No description',
              Iconsax.document_text,
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              context,
              'Start Time',
              widget.event.eventDateTime.formatDateTime,
              Iconsax.clock,
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              context,
              'End Time',
              widget.event.eventEndDateTime.formatDateTime,
              Iconsax.clock,
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              context,
              'Repeat Type',
              widget.event.eventRepeatType.name.capitalizeFirst,
              Iconsax.repeat,
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              context,
              'Status',
              widget.event.completed ? 'Completed' : 'Pending',
              widget.event.completed ? Iconsax.tick_circle : Iconsax.timer,
              valueColor: widget.event.completed
                  ? AppColors.success
                  : AppColors.warning,
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              context,
              'Created By',
              widget.event.createdBy.name,
              Iconsax.user,
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              context,
              'Created At',
              widget.event.createdAt.formatDateTime,
              Iconsax.calendar_tick,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
