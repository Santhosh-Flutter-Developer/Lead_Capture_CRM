import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/theme/theme.dart';

/// Time tracking tab of the task view.
///
/// Time is the sum of the real work sessions (`taskTimeLogs`): a session opens
/// when the task is started/resumed and closes when it is put on hold or
/// completed. So:
///  * Running            -> the clock ticks every second.
///  * On Hold            -> the clock is paused (hold time is not counted).
///  * Completed          -> the clock is stopped for good.
class TaskTimeTrackingPanel extends StatefulWidget {
  final Stream<List<TaskTimeLogModel>>? logsStream;
  final TaskStatus status;
  final DateTime? startedTime;
  final DateTime? completedTime;

  const TaskTimeTrackingPanel({
    super.key,
    required this.logsStream,
    required this.status,
    required this.startedTime,
    required this.completedTime,
  });

  @override
  State<TaskTimeTrackingPanel> createState() => _TaskTimeTrackingPanelState();
}

class _Session {
  final DateTime start;
  final DateTime end;
  final bool live;
  final String userId;
  const _Session(this.start, this.end, this.live, this.userId);
  Duration get duration => end.difference(start);
}

class _TaskTimeTrackingPanelState extends State<TaskTimeTrackingPanel> {
  static const int _collapsedSessions = 5;

  Timer? _ticker;
  DateTime _now = DateTime.now();
  // When the task stopped running during this screen's lifetime. Only used to
  // close a session whose end time hasn't reached us from the server yet.
  DateTime? _pausedAt;
  bool _showAllSessions = false;

  bool get _running =>
      widget.status == TaskStatus.started ||
      widget.status == TaskStatus.inProgress;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant TaskTimeTrackingPanel old) {
    super.didUpdateWidget(old);
    final wasRunning =
        old.status == TaskStatus.started ||
        old.status == TaskStatus.inProgress;
    if (wasRunning && !_running) _pausedAt = DateTime.now();
    if (_running) _pausedAt = null;
    _syncTicker();
  }

  void _syncTicker() {
    if (_running) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
      _now = DateTime.now();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------

  List<_Session> _buildSessions(List<TaskTimeLogModel> logs) {
    DateTime openEnd(DateTime start) {
      if (_running) return _now;
      // Not running but the session is still open => it ended when the task
      // was completed / paused; never keep counting.
      return widget.completedTime ?? _pausedAt ?? start;
    }

    _Session make(DateTime start, DateTime? end, String uid) {
      final isLive = end == null && _running;
      var e = end ?? openEnd(start);
      if (e.isBefore(start)) e = start;
      return _Session(start, e, isLive, uid);
    }

    if (logs.isEmpty) {
      // Older tasks that have no logs: fall back to started/completed times.
      final s = widget.startedTime;
      if (s == null) return const [];
      return [make(s, widget.completedTime, '')];
    }
    final sorted = [...logs]..sort((a, b) => a.startTime.compareTo(b.startTime));
    return [for (final l in sorted) make(l.startTime, l.endTime, l.userId)];
  }

  /// Splits sessions at midnight so every day gets its own share.
  Map<DateTime, Duration> _byDay(List<_Session> sessions) {
    final out = <DateTime, Duration>{};
    for (final s in sessions) {
      var cur = s.start;
      while (cur.isBefore(s.end)) {
        final day = DateTime(cur.year, cur.month, cur.day);
        final next = DateTime(cur.year, cur.month, cur.day + 1);
        final segEnd = s.end.isBefore(next) ? s.end : next;
        out[day] = (out[day] ?? Duration.zero) + segEnd.difference(cur);
        cur = segEnd;
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 338:05:09 (hours are not wrapped at 24, like a stopwatch)
  static String _clock(Duration d) =>
      '${d.inHours}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';

  static String _short(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${_two(d.inMinutes % 60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${_two(d.inSeconds % 60)}s';
    return '${d.inSeconds}s';
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final stream = widget.logsStream;
    if (stream == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: WaitingLoading(),
      );
    }
    return StreamBuilder<List<TaskTimeLogModel>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: WaitingLoading(),
          );
        }
        final sessions = _buildSessions(snap.data ?? const []);
        if (sessions.isEmpty) return _empty(context);

        final active = sessions.fold<Duration>(
          Duration.zero,
          (sum, s) => sum + s.duration,
        );
        final first = sessions.first.start;
        final lastEnd = sessions.last.end;
        final wallEnd = widget.completedTime ?? (_running ? _now : lastEnd);
        var paused = wallEnd.difference(first) - active;
        if (paused.isNegative) paused = Duration.zero;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(context, active, first),
            const SizedBox(height: 16),
            _statTiles(context, first, sessions.length, paused),
            const SizedBox(height: 28),
            _label(context, 'WORK SESSIONS'),
            const SizedBox(height: 12),
            _sessionList(context, sessions),
            const SizedBox(height: 28),
            _label(context, 'DAILY BREAKDOWN'),
            const SizedBox(height: 12),
            _dailyBreakdown(context, sessions),
          ],
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Iconsax.timer_start, size: 40, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'Task has not been started yet.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Time is tracked once the task is started.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w900,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: 1.5,
    ),
  );

  Widget _hero(BuildContext context, Duration active, DateTime first) {
    final Color color;
    final IconData icon;
    final String badge;
    final String note;
    switch (widget.status) {
      case TaskStatus.completed:
        color = AppColors.success;
        icon = Iconsax.tick_circle;
        badge = 'COMPLETED';
        note = widget.completedTime == null
            ? 'Timer stopped'
            : 'Timer stopped - completed ${widget.completedTime!.listingDateTime}';
        break;
      case TaskStatus.onHold:
        color = AppColors.warning;
        icon = Iconsax.pause_circle;
        badge = 'PAUSED';
        note = 'Timer is paused while the task is on hold';
        break;
      default:
        color = AppColors.primary;
        icon = Iconsax.timer_1;
        badge = 'TRACKING';
        note = 'Timer is running';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ACTIVE TIME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _badge(badge, color),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _clock(active),
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    final running = _running;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (running) ...[
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _now.second.isEven ? 1 : 0.25,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTiles(
    BuildContext context,
    DateTime first,
    int count,
    Duration paused,
  ) {
    final tiles = <Widget>[
      _tile(context, Iconsax.play, 'First started', first.listingDateTime),
      _tile(
        context,
        Iconsax.tick_circle,
        'Completed',
        widget.completedTime?.listingDateTime ?? '--',
      ),
      _tile(context, Iconsax.layer, 'Work sessions', '$count'),
      _tile(context, Iconsax.pause, 'Time on hold', _short(paused)),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 760 ? 4 : 2;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionList(BuildContext context, List<_Session> sessions) {
    final scheme = Theme.of(context).colorScheme;
    // Newest first, numbered by the order they happened.
    final numbered = [
      for (var i = 0; i < sessions.length; i++) (i + 1, sessions[i]),
    ].reversed.toList();
    final visible = _showAllSessions
        ? numbered
        : numbered.take(_collapsedSessions).toList();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            _sessionRow(context, visible[i].$1, visible[i].$2),
          ],
          if (numbered.length > _collapsedSessions) ...[
            Divider(height: 1, color: scheme.outlineVariant),
            TextButton(
              onPressed: () =>
                  setState(() => _showAllSessions = !_showAllSessions),
              child: Text(
                _showAllSessions
                    ? 'Show less'
                    : 'Show all ${numbered.length} sessions',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sessionRow(BuildContext context, int n, _Session s) {
    final scheme = Theme.of(context).colorScheme;
    final who = s.userId.isEmpty
        ? null
        : CacheService.getUserByUid(s.userId)?.name;
    final endText = s.live ? 'Running' : s.end.listingDateTime;
    final color = s.live ? AppColors.primary : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(
              '$n',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.start.listingDateTime}  \u2192  $endText',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (who != null && who.isNotEmpty)
                  Text(
                    who,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _short(s.duration),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: s.live ? AppColors.primary : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyBreakdown(BuildContext context, List<_Session> sessions) {
    final scheme = Theme.of(context).colorScheme;
    final byDay = _byDay(sessions);
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final shown = days.take(7).toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    var maxSecs = 1;
    for (final d in shown) {
      if (byDay[d]!.inSeconds > maxSecs) maxSecs = byDay[d]!.inSeconds;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (final d in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      d.formatDateMonth,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: byDay[d]!.inSeconds / maxSecs,
                        minHeight: 10,
                        backgroundColor: scheme.primary.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(scheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 64,
                    child: Text(
                      _short(byDay[d]!),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (days.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Showing the last ${shown.length} of ${days.length} days',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}