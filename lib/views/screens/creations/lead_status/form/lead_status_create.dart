import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/services/services.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import '/views/views.dart';

class LeadStatusCreate extends StatefulWidget {
  const LeadStatusCreate({super.key});

  @override
  State<LeadStatusCreate> createState() => _LeadStatusCreateState();
}

class _LeadStatusCreateState extends State<LeadStatusCreate> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  Color _selectedColor = const Color(0xFF64748B);
  bool _isFinal = false;
  bool _showFinalWarning = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
        body: Column(
          children: [
            FormWidgets.buildHeader(
              context: context,
              title: "Create Lead Status",
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
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
                                style: Theme.of(context).textTheme.titleMedium!
                                    .copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Divider(color: Theme.of(context).colorScheme.outlineVariant, thickness: 1),
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
        ),
        bottomNavigationBar: FormWidgets.buildBottomBar(
          context: context,
          onSubmit: _submitForm,
          isEdit: false,
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
                onChanged: (val) async {
                  if (val == true) {
                    bool exists = await LeadStatusService.hasFinalStatus();
                    if (exists) {
                      setState(() {
                        _showFinalWarning = true;
                        _isFinal = false;
                      });
                      return;
                    }
                  }

                  setState(() {
                    _isFinal = val ?? false;
                    _showFinalWarning = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Final Lead Status',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          if (_showFinalWarning) ...[
            const SizedBox(height: 4),
            Text(
              'Final status is already assigned',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);

        String? duplicateError =
            await LeadStatusService.checkLeadStatusExists(
          name: _nameController.text.trim(),
        );

        if (duplicateError != null) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          FlushBar.show(context, duplicateError, isSuccess: false);
          return;
        }

        LeadStatusModel leadStatusModel = LeadStatusModel(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          color: _selectedColor.toARGB32(),
          orderNumber: 0,
          isFinal: _isFinal,
          createdBy: await Spdb.getUser(),
        );

        await LeadStatusService.createLeadStatus(leadStatus: leadStatusModel);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, {
          "status": true,
          "name": leadStatusModel.name,
        });

        FlushBar.show(context, 'Status created successfully', isSuccess: true);
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
