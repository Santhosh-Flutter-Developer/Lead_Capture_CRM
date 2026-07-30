import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/utils/src/platform.dart';
import '/models/models.dart';
import '/views/views.dart';
import 'bloc/login_log_bloc.dart';

// LoginLogColors removed in favor of Theme.of(context)

class LoginLogsListing extends StatefulWidget {
  final bool showAppbar;

  const LoginLogsListing({super.key, required this.showAppbar});

  @override
  State<LoginLogsListing> createState() => _LoginLogsListingState();
}

class _LoginLogsListingState extends State<LoginLogsListing> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh(BuildContext context) async {
    context.read<LoginLogsBloc>().add(StreamLoginLogs());
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Map<String, List<LoginLogsModel>> _groupByDay(List<LoginLogsModel> items) {
    final Map<String, List<LoginLogsModel>> map = {};
    final now = DateTime.now();
    for (final item in items) {
      final dt = item.loginTime;
      final difference = DateTime(
        dt.year,
        dt.month,
        dt.day,
      ).difference(DateTime(now.year, now.month, now.day)).inDays;

      String label;
      if (difference == 0) {
        label = 'Today';
      } else if (difference == -1) {
        label = 'Yesterday';
      } else {
        label = DateFormat('dd MMM yyyy').format(dt);
      }
      map.putIfAbsent(label, () => []).add(item);
    }
    return map;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginLogsBloc()..add(StreamLoginLogs()),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: widget.showAppbar
            ? AppBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Back(color: Theme.of(context).colorScheme.onSurface),
                ),
                centerTitle: false,
                title: Text(
                  "Access Logs",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(70),
                  child: _buildHeaderSearch(),
                ),
              )
            : null,
        body: BlocBuilder<LoginLogsBloc, LoginLogsState>(
          builder: (context, state) {
            if (state is LoginLogsLoading) {
              return const Center(child: WaitingLoading());
            }
            if (state is LoginLogsError) {
              return ErrorDisplay(error: state.message);
            }
            if (state is LoginLogsLoaded) {
              final filteredList = state.loginLog.where((it) {
                if (_search.isEmpty) return true;
                final device = it.loginAlert.device.toLowerCase();
                final ip = it.loginAlert.ipAddress.toLowerCase();
                final location = it.loginAlert.location.toLowerCase();
                final name = it.user.name.toLowerCase();
                return device.contains(_search) ||
                    ip.contains(_search) ||
                    location.contains(_search) ||
                    name.contains(_search);
              }).toList();

              if (filteredList.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => _refresh(context),
                  child: ListView(
                    children: const [
                      SizedBox(height: 100),
                      NoData(text: "No login records found for this query"),
                    ],
                  ),
                );
              }

              final grouped = _groupByDay(filteredList);

              return RefreshIndicator(
                onRefresh: () => _refresh(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (kIsDesktop)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: "Refresh",
                              icon: const Icon(Iconsax.refresh),
                              iconSize: 18,
                              onPressed: () => _refresh(context),
                            ),
                          ],
                        ),
                      ),

                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          children: grouped.entries.map((entry) {
                            return _buildSection(entry.key, entry.value);
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildHeaderSearch() {
    return Column(
      children: [
        Container(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Iconsax.search_normal,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                hintText: 'Filter by user, device, or IP address...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String label, List<LoginLogsModel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...items.map((item) => _buildLoginCard(item)),
      ],
    );
  }

  Widget _buildLoginCard(LoginLogsModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UserAvatar(userData: item.user, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.user.name.isNotEmpty
                            ? item.user.name
                            : 'Unknown User',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        item.user.desc ?? 'Active Session',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _timeAgo(item.loginTime),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getDeviceIcon(item.loginAlert.device),
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.loginAlert.device,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(Iconsax.global, item.loginAlert.ipAddress),
                      const SizedBox(height: 4),
                      _buildInfoRow(Iconsax.location, item.loginAlert.location),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getDeviceIcon(String device) {
    final d = device.toLowerCase();
    if (d.contains('iphone') || d.contains('android') || d.contains('mobile')) {
      return Iconsax.mobile;
    }
    if (d.contains('mac') || d.contains('windows') || d.contains('linux')) {
      return Iconsax.monitor;
    }
    return Iconsax.device_message;
  }
}
