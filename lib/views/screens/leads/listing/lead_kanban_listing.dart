import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '/theme/theme.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/utils/utils.dart';

class LeadKanbanListing extends StatefulWidget {
  final List<LeadModel> leadList;
  final VoidCallback? onLeadDeleted;
  const LeadKanbanListing({
    super.key,
    required this.leadList,
    this.onLeadDeleted,
  });

  @override
  State<LeadKanbanListing> createState() => _LeadKanbanListingState();
}

class _LeadKanbanListingState extends State<LeadKanbanListing> {
  late Future _future;
  late Map<LeadStatusModel, List<LeadModel>> _leadList;

  LeadModel? _draggedLead;
  LeadStatusModel? _draggedFromList;

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
  void didUpdateWidget(covariant LeadKanbanListing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leadList != widget.leadList) {
      _future = _initializeBoard();
      setState(() {});
    }
  }

  Future<void> _initializeBoard() async {
    _leadList = await LeadService.getLeadByGroup(leadList: widget.leadList);
  }

  void _handleDragStarted(LeadModel task, LeadStatusModel fromList) {
    setState(() {
      _draggedLead = task;
      _draggedFromList = fromList;
    });
  }

  void _handleDragEnd(DraggableDetails details) {
    if (!details.wasAccepted &&
        _draggedLead != null &&
        _draggedFromList != null) {
      setState(() {
        if (!_leadList[_draggedFromList]!.any(
          (t) => t.uid == _draggedLead!.uid,
        )) {
          _leadList[_draggedFromList]!.add(_draggedLead!);
        }
      });
    }
    setState(() {
      _draggedLead = null;
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
                children: _leadList.entries.map((entry) {
                  return _buildKanbanColumn(entry.key, entry.value);
                }).toList(),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildKanbanColumn(LeadStatusModel list, List<LeadModel> leads) {
    return DragTarget<LeadModel>(
      onWillAcceptWithDetails: (details) {
        return details.data.uid != null && details.data.leadsConverted != true;
      },
      onAcceptWithDetails: (details) async {
        final lead = details.data;

        if (_draggedFromList == list) return;

        final originalLead = lead.copyWith();

        _leadList[_draggedFromList!] = List.from(_leadList[_draggedFromList]!)
          ..removeWhere((t) => t.uid == lead.uid);

        _leadList[list] = List.from(_leadList[list]!)..add(lead);

        setState(() {});

        try {
          if (list.isFinal) {
            final result = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => const ConfirmDialog(
                title: 'Convert Lead',
                content:
                    'Are you sure you want to convert this lead to a deal?',
              ),
            );

            if (result != true) {
              _leadList[_draggedFromList!] = List.from(
                _leadList[_draggedFromList]!,
              )..add(originalLead);

              _leadList[list] = List.from(_leadList[list]!)
                ..removeWhere((l) => l.uid == lead.uid);

              setState(() {});
              return;
            }
          }

          await LeadService.updateLeadStatus(
            uid: lead.uid!,
            leadStatus: list.uid!,
            leadsConverted: list.isFinal ? true : null,
          );

          if (list.isFinal) {
            await _convertLeadToDeal(context, lead);

            _leadList[list] = List.from(_leadList[list]!)
              ..removeWhere((l) => l.uid == lead.uid)
              ..add(lead.copyWith(leadsConverted: true));

            setState(() {});
          }
        } catch (e) {
          _leadList[_draggedFromList!] = List.from(_leadList[_draggedFromList]!)
            ..add(originalLead);
          _leadList[list] = List.from(_leadList[list]!)
            ..removeWhere((l) => l.uid == lead.uid);

          setState(() {});

          FlushBar.show(context, e.toString(), isSuccess: false);
        }
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;
        double totalValue = leads.fold(
          0.0,
          (sum, item) => sum + item.leadValue,
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
              color: isHovering
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildKanbanColumnHeader(list, leads.length, totalValue),
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
                  itemCount: leads.length,
                  itemBuilder: (context, index) {
                    return _buildKanbanCard(leads[index], list);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _convertLeadToDeal(BuildContext context, LeadModel lead) async {
    try {
      futureLoading(context);

      final leadDetails = await LeadService.getLead(uid: lead.uid ?? '');

      final dealData = {
        'dealName': leadDetails.leadName,
        'dealEmail': leadDetails.leadEmail,
        'companyName': leadDetails.companyName,
        'companyWebsite': leadDetails.companyWebsite,
        'companyCountry': leadDetails.companyCountry?.toMap(),
        'companyState': leadDetails.companyState?.toMap(),
        'companyCity': leadDetails.companyCity?.toMap(),
        'companyZipCode': leadDetails.companyZipCode,
        'companyMobile': leadDetails.companyMobile,
        'companyAddress': leadDetails.companyAddress,
        'clientName': leadDetails.clientName,
        'salutation': leadDetails.salutation,
        'clientEmail': leadDetails.clientEmail,
        'clientMobile': leadDetails.clientMobile,
        'clientGender': leadDetails.clientGender,
        'dealValue': leadDetails.leadValue,
        'notes': leadDetails.notes,
      };

      await LeadService.convertLeadToDeal(lead: leadDetails);

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Navigate.route(
        context,
        DealCreate(
          isFromLead: true,
          prefillDeal: DealModel.fromMap(lead.uid ?? '', dealData),
        ),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Widget _buildKanbanColumnHeader(
    LeadStatusModel list,
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
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => Sheet.showSheet(
                      context,
                      widget: quickLead(context, list),
                    ),
                    child: const Icon(
                      Iconsax.add_circle,
                      size: 18,
                      color: Colors.white,
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

  Widget quickLead(BuildContext context, LeadStatusModel status) {
    final GlobalKey<FormState> quickFormKey = GlobalKey<FormState>();
    final TextEditingController leadNameCtrl = TextEditingController();
    final TextEditingController leadValueCtrl = TextEditingController();

    final future = ClientService.getAllClients();
    ClientModel? selectedCompany;
    ClientModel? selectedContact;

    return StatefulBuilder(
      builder: (context, setSheetState) {
        return FutureBuilder<List<ClientModel>>(
          future: future,
          builder: (context, snapshot) {
            final allClients = snapshot.data ?? [];
            final companies = allClients
                .where(
                  (c) => c.isCompany && (c.companyName?.isNotEmpty ?? false),
                )
                .toList();
            final contacts = allClients
                .where(
                  (c) => !c.isCompany && (c.clientName?.isNotEmpty ?? false),
                )
                .toList();
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;

            return ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              child: Scaffold(
                backgroundColor: Theme.of(context).colorScheme.surface,
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: quickFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(
                                status.color,
                              ).withValues(alpha: 0.15),
                              child: Icon(
                                Iconsax.flash_1,
                                color: Color(status.color),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quick Lead',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    status.name,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
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

                        const Divider(height: 32),

                        /// Lead Name
                        Text(
                          'Lead Name',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        FormFields(
                          controller: leadNameCtrl,
                          hintText: 'Enter lead name',
                          isRequired: true,
                          valid: (v) => v == null || v.isEmpty
                              ? 'Lead name is required'
                              : null,
                        ),

                        const SizedBox(height: 20),

                        /// Lead Value
                        Text(
                          'Lead Value',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        FormFields(
                          controller: leadValueCtrl,
                          hintText: 'Enter amount',
                          keyboardType: TextInputType.number,
                        ),

                        const SizedBox(height: 20),

                        /// Company Name Dropdown
                        Text(
                          'Company Name',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        isLoading
                            ? const SizedBox(
                                height: 48,
                                child: Center(child: LinearProgressIndicator()),
                              )
                            : FormDropdownSearch(
                                initialItem: selectedCompany?.companyName ?? '',
                                items: companies
                                    .map((e) => e.companyName)
                                    .toList(),
                                onChanged: (value) {
                                  setSheetState(() {
                                    selectedCompany = companies
                                        .cast<ClientModel?>()
                                        .firstWhere(
                                          (c) => c?.companyName == value,
                                          orElse: () => null,
                                        );
                                  });
                                },
                              ),

                        const SizedBox(height: 20),

                        /// Contact Name Dropdown
                        Text(
                          'Contact Name',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        isLoading
                            ? const SizedBox(
                                height: 48,
                                child: Center(child: LinearProgressIndicator()),
                              )
                            : FormDropdownSearch(
                                initialItem: selectedContact?.clientName ?? '',
                                items: contacts
                                    .map((e) => e.clientName)
                                    .toList(),
                                onChanged: (value) {
                                  setSheetState(() {
                                    selectedContact = contacts
                                        .cast<ClientModel?>()
                                        .firstWhere(
                                          (c) => c?.clientName == value,
                                          orElse: () => null,
                                        );
                                  });
                                },
                              ),

                        const SizedBox(height: 28),

                        /// Create Button
                        Center(
                          child: SizedBox(
                            width: 200,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (!quickFormKey.currentState!.validate())
                                  return;

                                try {
                                  futureLoading(context);

                                  final lead = LeadModel.quick(
                                    leadName: leadNameCtrl.text.trim(),
                                    leadValue:
                                        double.tryParse(leadValueCtrl.text) ??
                                        0,
                                    leadStatus: status.uid!,
                                    createdBy: await Spdb.getUser(),
                                    workflow:
                                        await EmployeeService.getUserWorkflow(),
                                    // company fields
                                    companyName: selectedCompany?.companyName,
                                    companyWebsite:
                                        selectedCompany?.officialWebsite,
                                    companyMobile:
                                        selectedCompany?.officePhoneNo,
                                    companyCountry: selectedCompany?.country,
                                    companyState: selectedCompany?.state,
                                    companyCity: selectedCompany?.city,
                                    companyAddress:
                                        selectedCompany?.companyAddress,
                                    companyZipCode: selectedCompany?.postalCode,
                                    // contact fields
                                    clientId:
                                        selectedContact?.uid ??
                                        selectedCompany?.uid,
                                    clientName: selectedContact?.clientName,
                                    clientEmail: selectedContact?.email,
                                    clientMobile: selectedContact?.mobileNumber,
                                    clientGender: selectedContact?.gender,
                                    salutation: selectedContact?.salutation,
                                  );

                                  await LeadService.createLead(lead: lead);

                                  // pop loading dialog
                                  if (Navigator.canPop(context))
                                    Navigator.pop(context);
                                  // pop quick lead sheet
                                  if (Navigator.canPop(context))
                                    Navigator.pop(context);
                                  FlushBar.show(
                                    context,
                                    'Lead created successfully',
                                  );
                                } catch (e) {
                                  if (Navigator.canPop(context))
                                    Navigator.pop(context);
                                  FlushBar.show(
                                    context,
                                    e.toString(),
                                    isSuccess: false,
                                  );
                                }
                              },
                              icon: const Icon(Iconsax.add_circle, size: 18),
                              label: const Text(
                                'Create Lead',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                elevation: 2,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKanbanCard(LeadModel task, LeadStatusModel list) {
    if (task.leadsConverted == true) {
      // Converted leads are shown as static cards
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: InkWell(
          onTap: () async {
            final result = kIsDesktop
                ? await GeneralDialog.showRTLSheet(
                    context,
                    LeadsViewPage(lead: task),
                  )
                : await Sheet.showSheet(
                    context,
                    widget: LeadsViewPage(lead: task),
                  );
            if (result == 'deleted' && context.mounted) {
              widget.onLeadDeleted?.call();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
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
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCardContent(task, list),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.lock, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      'Converted to Deal',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Draggable card for unconverted leads
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Draggable<LeadModel>(
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
              child: _buildCardContent(task, list),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.2,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        child: InkWell(
          onTap: () async {
            final result = kIsDesktop
                ? await GeneralDialog.showRTLSheet(
                    context,
                    LeadsViewPage(lead: task),
                  )
                : await Sheet.showSheet(
                    context,
                    widget: LeadsViewPage(lead: task),
                  );
            if (result == 'deleted' && context.mounted) {
              widget.onLeadDeleted?.call();
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
            child: _buildCardContent(task, list),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(LeadModel lead, LeadStatusModel list) {
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
                lead.leadName.isNotEmpty ? lead.leadName[0].toUpperCase() : '?',
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
                    lead.leadName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                  if (lead.leadEmail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      lead.leadEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  if (lead.companyName?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      lead.companyName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.grey600,
                      ),
                    ),
                  ],

                  if (lead.clientName?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 10,
                          color: AppColors.grey600,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            lead.clientName!,
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

            /// Lead Value
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _currencyFormat.format(lead.leadValue),
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
              CacheService.leadStatusByUid(lead.leadStatus)?.name ?? '',
              AppColors.blue,
            ),
            _chip(lead.leadSource.name, AppColors.orange),
            // ElevatedButton(
            //   onPressed: () async {
            //   final originalLead = lead.copyWith();

            //     try {
            //       final result = await showDialog<bool>(
            //         context: context,
            //         builder: (context) => const ConfirmDialog(
            //           title: 'Convert Lead',
            //           content:
            //               'Are you sure you want to convert this lead to a deal?',
            //         ),
            //       );

            //       if (result == null || !result) {
            //         _leadList[_draggedFromList!] = List.from(_leadList[_draggedFromList]!,)..add(originalLead);
            //         _leadList[list] = List.from(_leadList[list]!)..removeWhere((l) => l.uid == lead.uid);

            //         setState(() {});
            //         return;
            //       }

            //       await LeadService.updateLeadStatus(
            //         uid: lead.uid!,leadStatus: list.uid!,
            //         leadsConverted: true,
            //       );

            //       // if (list.isFinal) {
            //         await _convertLeadToDeal(context, lead);
            //         _leadList[list] = List.from(_leadList[list]!)..removeWhere((l) => l.uid == lead.uid)..add(lead.copyWith(leadsConverted: true));
            //         setState(() {});
            //       // }
            //     } catch (e) {
            //       _leadList[_draggedFromList!] = List.from(
            //         _leadList[_draggedFromList]!,
            //       )..add(originalLead);
            //       _leadList[list] = List.from(_leadList[list]!)
            //         ..removeWhere((l) => l.uid == lead.uid);

            //       setState(() {});

            //       FlushBar.show(context, e.toString(), isSuccess: false);
            //     }
            //   },
            //   child: _chip("Make a Deal", AppColors.blueGrey),
            // ),
            // if (lead.leadStatus == 'Completed')
            // _chip('Won',const Color.fromARGB(255, 60, 255, 0),),
          ],
        ),

        const SizedBox(height: 12),

        /// FOOTER META
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: AppColors.grey600,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM').format(lead.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.grey600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 12,
                  color: AppColors.grey600,
                ),
                const SizedBox(width: 4),
                Text(
                  lead.createdBy.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.grey600,
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
