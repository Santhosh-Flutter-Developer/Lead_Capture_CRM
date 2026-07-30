import 'package:flutter/material.dart';
import '/services/services.dart';
import '/models/models.dart';
import '/views/views.dart';

class DesignationCreate extends StatefulWidget {
  const DesignationCreate({super.key});

  @override
  State<DesignationCreate> createState() => _DesignationCreateState();
}

class _DesignationCreateState extends State<DesignationCreate> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
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
              title: "Create Designation",
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 500),
                  child: Card(
                    color: Theme.of(context).cardTheme.color,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 20.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Designation Information",
                            style: Theme.of(context).textTheme.titleMedium!
                                .copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.primary,
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
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    const double minColumnWidth = 220.0;

    final bool canShowGrid =
        currentWidth >= (minColumnWidth * 3 + horizontalSpacing * (3 - 1));

    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (3 - 1)) / 3
        : currentWidth;

    return Form(
      key: _formKey,
      child: Wrap(
        spacing: horizontalSpacing,
        runSpacing: verticalSpacing,
        children: [
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Designation Name',
              controller: _nameController,
              hintText: 'Enter designation name',
              isRequired: true,
              valid: (input) => input == null || input.isEmpty
                  ? 'Designation Name is required'
                  : null,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Description',
              controller: _descriptionController,
              hintText: 'Enter description (optional)',
              maxLines: 3,
              keyboardType: TextInputType.multiline,
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

        String? duplicateError = await DesignationService.checkDesignationExists(
          name: _nameController.text.trim(),
        );

        if (duplicateError != null) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          FlushBar.show(
            context,
            duplicateError,
            isSuccess: false,
          );
          return;
        }

        DesignationModel designationModel = DesignationModel(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          createdBy: await Spdb.getUser(),
        );

        await DesignationService.createDesignation(
          designation: designationModel,
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);

        FlushBar.show(
          context,
          'Designation created successfully',
          isSuccess: true,
        );
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
