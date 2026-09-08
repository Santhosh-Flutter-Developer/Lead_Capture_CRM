import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/views/views.dart';

class DealStatusEdit extends StatefulWidget {
  final String uid;
  const DealStatusEdit({super.key, required this.uid});

  @override
  State<DealStatusEdit> createState() => _DealStatusEditState();
}

class _DealStatusEditState extends State<DealStatusEdit> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _colorController = TextEditingController();
  Color _selectedColor = const Color(0xFF64748B);

  late Future _future;
  DealStatusModel? _dealStatusModel;
  bool _isFinal = false;

  @override
  void initState() {
    _future = _init();
    super.initState();
  }

  Future<void> _init() async {
    _dealStatusModel = await DealStatusService.getDealStatus(uid: widget.uid);
    _nameController.text = _dealStatusModel?.name ?? '';
    _descriptionController.text = _dealStatusModel?.description ?? '';
    _selectedColor = Color(_dealStatusModel?.color ?? 0);
    _isFinal = _dealStatusModel?.isFinal ?? false;
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _colorController.dispose();
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
        backgroundColor: AppColors.grey50,
        body: FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const WaitingLoading();
            } else if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                ),
              );
            } else {
              return Column(
                children: [
                  FormWidgets.buildHeader(
                    context: context,
                    title: "Update Deal Status",
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 500),
                        child: Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.7,
                            child: Card(
                              color: AppColors.white,
                              elevation: 7,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: AppColors.grey200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                  vertical: 24.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Status Information",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                    ),
                                    const SizedBox(height: 10),
                                    Divider(
                                      color: AppColors.grey300,
                                      thickness: 1,
                                    ),
                                    const SizedBox(height: 20),
                                    LayoutBuilder(
                                      builder: (context, constraints) =>
                                          _buildFormFields(constraints),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
        bottomNavigationBar: FormWidgets.buildBottomBar(
          context: context,
          onSubmit: _submitForm,
          isEdit: true,
        ),
      ),
    );
  }

  Widget _buildFormFields(BoxConstraints constraints) {
    // final double currentWidth = constraints.maxWidth;
    // const double minWidth = 300.0;
    // const double horizontalSpacing = 20.0;

    // final bool twoCols = currentWidth >= (minWidth * 2 + horizontalSpacing);
    // final double fieldWidth =
    //     twoCols ? (currentWidth - horizontalSpacing) / 2 : currentWidth;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormFields(
            label: 'Status Name',
            controller: _nameController,
            hintText: 'Enter Status name',
            isRequired: true,
            valid: (input) => input == null || input.isEmpty
                ? 'Status Name is required'
                : null,
          ),
          const SizedBox(height: 20),
          FormFields(
            label: 'Description',
            controller: _descriptionController,
            hintText: 'Enter description (optional)',
            maxLines: 4,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: 20),
          FormFields(
            label: 'Color',
            controller: _colorController,
            fillColor: Color(_selectedColor.toARGB32()),
            onTap: () async {
              Color? selectedColor = await pickColor(context, _selectedColor);
              if (selectedColor != null) {
                _selectedColor = selectedColor;
                setState(() {});
              }
            },
            readOnly: true,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Checkbox(
                value: _isFinal,
                onChanged: (value) {
                  setState(() {
                    _isFinal = value ?? false;
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Mark as Final Status',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Deals with Final status will be locked and cannot be modified or moved.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);

        String? duplicateError =
            await DealStatusService.checkDealStatusExists(
          name: _nameController.text.trim(),
          excludeUid: widget.uid,
        );

        if (duplicateError != null) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          FlushBar.show(context, duplicateError, isSuccess: false);
          return;
        }

        DealStatusModel dealStatusModel = DealStatusModel(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          color: _selectedColor.toARGB32(),
          orderNumber: _dealStatusModel?.orderNumber ?? 0,
          isFinal: _isFinal,
          createdBy: await Spdb.getUser(),
        );

        await DealStatusService.editDealStatus(
          uid: widget.uid,
          dealStatus: dealStatusModel,
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);

        FlushBar.show(context, 'Status updated successfully', isSuccess: true);
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
