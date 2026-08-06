import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/theme/theme.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import 'dart:async';

class DealKanbanListing extends StatefulWidget {
  final List<DealModel> dealList;
  const DealKanbanListing({super.key, required this.dealList});

  @override
  State<DealKanbanListing> createState() => _DealKanbanListingState();
}

class _DealKanbanListingState extends State<DealKanbanListing> {
  late Future _future;
  late Map<DealStatusModel, List<DealModel>> _dealList;

  DealModel? _draggedDeal;
  DealStatusModel? _draggedFromList;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _future = _initializeBoard();
  }

  @override
  void didUpdateWidget(covariant DealKanbanListing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dealList != widget.dealList) {
      _future = _initializeBoard();
      setState(() {});
    }
  }

  Future<void> _initializeBoard() async {
    _dealList = await DealService.getDealByGroup(dealList: widget.dealList);
  }

  void _handleDragStarted(DealModel task, DealStatusModel fromList) {
    setState(() {
      _draggedDeal = task;
      _draggedFromList = fromList;
    });
  }

  void _handleDragEnd(DraggableDetails details) {
    if (!details.wasAccepted &&
        _draggedDeal != null &&
        _draggedFromList != null) {
      setState(() {
        if (!_dealList[_draggedFromList]!.any(
          (t) => t.uid == _draggedDeal!.uid,
        )) {
          _dealList[_draggedFromList]!.add(_draggedDeal!);
        }
      });
    }
    setState(() {
      _draggedDeal = null;
      _draggedFromList = null;
    });
  }

  void _startEdgeScrolling(DragUpdateDetails details) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scrollThreshold = 100.0; // Distance from edge to trigger scroll
    double scrollSpeed = 15.0; // How fast to scroll

    _scrollTimer?.cancel();

    _scrollTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (details.globalPosition.dx < scrollThreshold) {
        // Scroll Left
        if (_scrollController.offset > 0) {
          _scrollController.animateTo(
            _scrollController.offset - scrollSpeed,
            duration: const Duration(milliseconds: 20),
            curve: Curves.linear,
          );
        }
      } else if (details.globalPosition.dx > screenWidth - scrollThreshold) {
        // Scroll Right
        if (_scrollController.offset <
            _scrollController.position.maxScrollExtent) {
          _scrollController.animateTo(
            _scrollController.offset + scrollSpeed,
            duration: const Duration(milliseconds: 20),
            curve: Curves.linear,
          );
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const WaitingLoading();
        } else if (snapshot.hasError) {
          return ErrorDisplay(error: snapshot.error.toString());
        } else {
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12.0),
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _dealList.entries.map((entry) {
                  return _buildKanbanColumn(entry.key, entry.value);
                }).toList(),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildKanbanColumn(DealStatusModel list, List<DealModel> deals) {
    return DragTarget<DealModel>(
      onWillAcceptWithDetails: (details) {
        // Prevent dragging locked deals
        if (details.data.isLocked) {
          return false;
        }
        return details.data.uid != null;
      },
      onAcceptWithDetails: (details) async {
        final deal = details.data;

        if (_draggedFromList == list) return;

        final originalDeal = deal.copyWith();

        _dealList[_draggedFromList!] = List.from(_dealList[_draggedFromList]!)
          ..removeWhere((t) => t.uid == deal.uid);

        _dealList[list] = List.from(_dealList[list]!)..add(deal);

        setState(() {});

        try {
          await DealService.updateDealStatus(
            uid: deal.uid!,
            dealStatus: list.uid!,
          );
        } catch (e) {
          _dealList[_draggedFromList!] = List.from(_dealList[_draggedFromList]!)
            ..add(originalDeal);
          _dealList[list] = List.from(_dealList[list]!)
            ..removeWhere((l) => l.uid == deal.uid);

          setState(() {});

          FlushBar.show(context, e.toString(), isSuccess: false);
        }
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;
        double totalValue = deals.fold(
          0.0,
          (sum, item) => sum + item.dealValue,
        );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 260,
          height: MediaQuery.of(context).size.height * 0.78,
          margin: const EdgeInsets.only(right: 12.0),
          decoration: BoxDecoration(
            color: isHovering
                ? Color(list.color).withValues(alpha: 0.1)
                : Color(list.color).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: isHovering ? AppColors.blue : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildKanbanColumnHeader(list, deals.length, totalValue),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 10,
                  ),
                  itemCount: deals.length,
                  itemBuilder: (context, index) {
                    return _buildKanbanCard(deals[index], list);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanColumnHeader(
    DealStatusModel list,
    int count,
    double totalValue,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Color(list.color),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  list.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Theme.of(context).colorScheme.surface,
          child: Text(
            _currencyFormat.format(totalValue),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKanbanCard(DealModel task, DealStatusModel list) {
    // Draggable card for unconverted deals
    final isLocked = task.isLocked;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: isLocked
          ? _buildLockedCard(task, list)
          : Draggable<DealModel>(
              data: task,
              onDragStarted: () => _handleDragStarted(task, list),
              onDragUpdate: (details) {
                _startEdgeScrolling(details);
              },
              onDragEnd: (details) {
                _scrollTimer?.cancel();
                _handleDragEnd(details);
              },
              feedback: Material(
                elevation: 8.0,
                borderRadius: BorderRadius.circular(12.0),
                color: Colors.transparent,
                child: Transform.rotate(
                  angle: 0.05,
                  child: Container(
                    width: 244,
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: _buildCardContent(task),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.2,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              child: InkWell(
                onTap: () {
                  if (kIsDesktop) {
                    GeneralDialog.showRTLSheet(context, DealsViewPage(deal: task));
                  } else {
                    Sheet.showSheet(context, widget: DealsViewPage(deal: task));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.shadow.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12.0),
                  child: _buildCardContent(task),
                ),
              ),
            ),
    );
  }

  Widget _buildLockedCard(DealModel task, DealStatusModel list) {
    return InkWell(
      onTap: () {
        if (kIsDesktop) {
          GeneralDialog.showRTLSheet(context, DealsViewPage(deal: task));
        } else {
          Sheet.showSheet(context, widget: DealsViewPage(deal: task));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12.0),
        child: Stack(
          children: [
            Opacity(
              opacity: 0.7,
              child: _buildCardContent(task),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                Icons.lock,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(DealModel deal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// HEADER ROW (Avatar + Name + Value)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                deal.dealName.isNotEmpty ? deal.dealName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),

            /// Name + Email + Company
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deal.dealName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                  if (deal.dealEmail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      deal.dealEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  if (deal.companyName?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      deal.companyName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],

                  if (deal.clientName?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            deal.clientName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            /// Deal Value
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _currencyFormat.format(deal.dealValue),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        /// STATUS & SOURCE
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _chip(
              CacheService.dealStatusByUid(deal.dealStatus ?? '')?.name ?? '',
              AppColors.blue,
            ),
          ],
        ),

        const SizedBox(height: 12),

        /// FOOTER META
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM').format(deal.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  deal.createdBy.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
