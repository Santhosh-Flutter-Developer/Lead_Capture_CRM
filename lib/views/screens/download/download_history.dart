import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/models/src/download_model.dart';
import 'package:leadcapture/utils/src/open_file.dart';
import 'package:leadcapture/utils/src/platform.dart';
import 'package:leadcapture/views/screens/download/bloc/download_bloc.dart';
import 'package:leadcapture/views/screens/download/bloc/download_event.dart';
import 'package:leadcapture/views/screens/download/bloc/download_state.dart';
import 'package:leadcapture/views/ui/src/back.dart';
import 'package:leadcapture/views/ui/src/loading.dart';

// DownloadHistoryColors removed in favor of Theme.of(context)

class DownloadHistory extends StatefulWidget {
  final bool showAppbar;

  const DownloadHistory({super.key, required this.showAppbar});

  @override
  State<DownloadHistory> createState() => _DownloadHistoryState();
}

class _DownloadHistoryState extends State<DownloadHistory> {
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
    context.read<DownloadHistoryBloc>().add(StreamDownloadHistory());
  }

  Map<String, List<DownloadHistoryModel>> _groupByDay(
    List<DownloadHistoryModel> items,
  ) {
    final Map<String, List<DownloadHistoryModel>> map = {};
    final now = DateTime.now();
    for (final item in items) {
      final dt = item.downloadedAt;
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
      create: (_) => DownloadHistoryBloc()..add(StreamDownloadHistory()),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: widget.showAppbar
            ? AppBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
                leading: Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Back(color: Theme.of(context).colorScheme.onSurface),
                ),
                title: Text(
                  "Download History",
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
        body: BlocBuilder<DownloadHistoryBloc, DownloadHistoryState>(
          builder: (context, state) {
            if (state is DownloadHistoryLoading) {
              return const Center(child: WaitingLoading());
            }
            if (state is DownloadHistoryError) {
              return Center(child: Text(state.message));
            }
            if (state is DownloadHistoryLoaded) {
              final filteredList = state.items.where((it) {
                if (_search.isEmpty) return true;
                return it.fileName.toLowerCase().contains(_search) ||
                    it.url.toLowerCase().contains(_search);
              }).toList();

              if (filteredList.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => _refresh(context),
                  child: ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.2,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download_for_offline,
                              size: 80,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "No Downloads Found",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Text(
                                "You haven't downloaded any files yet.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            // const SizedBox(height: 24),
                            // ElevatedButton.icon(
                            //   onPressed: () => _refresh(context),
                            //   icon: const Icon(Icons.refresh, size: 18),
                            //   label: const Text("Refresh"),
                            //   style: ElevatedButton.styleFrom(
                            //     backgroundColor: DownloadHistoryColors.primary,
                            //     shape: RoundedRectangleBorder(
                            //       borderRadius: BorderRadius.circular(12),
                            //     ),
                            //     padding: const EdgeInsets.symmetric(
                            //       horizontal: 20,
                            //       vertical: 12,
                            //     ),
                            //     textStyle: const TextStyle(
                            //       fontWeight: FontWeight.w600,
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final grouped = _groupByDay(filteredList);

              return RefreshIndicator(
                onRefresh: () => _refresh(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    if (kIsDesktop)
                      Row(
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
        Container(
          color: Theme.of(context).colorScheme.outlineVariant,
          height: 1,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                hintText: 'Filter by filename or URL...',
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

  Widget _buildSection(String label, List<DownloadHistoryModel> items) {
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
        ...items.map((item) => _buildDownloadCard(item)),
      ],
    );
  }

  Widget _buildDownloadCard(DownloadHistoryModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status icon with circle background
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isSuccess
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.2),
              ),
              child: Icon(
                item.isSuccess ? Icons.check_circle : Icons.error,
                color: item.isSuccess ? Colors.green : Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.url,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _timeAgo(item.downloadedAt),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (item.isSuccess)
              IconButton(
                icon: Icon(
                  Icons.open_in_new,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => openfile(item.filePath, context),
              ),
          ],
        ),
      ),
    );
  }
}
