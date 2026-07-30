import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import '/constants/constants.dart';
import '/views/views.dart';

class ClientProfile extends StatefulWidget {
  final ClientModel client;
  final bool isCompany;

  const ClientProfile({
    super.key,
    required this.client,
    required this.isCompany,
  });

  @override
  State<ClientProfile> createState() => _ClientProfileState();
}

class _ClientProfileState extends State<ClientProfile> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: Scaffold(
        appBar: FormWidgets.buildHeader(
          context: context,
          title: "Client Details",
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  // _buildHeader(context),
                  // const SizedBox(height: 24),
                  _buildHeaderCard(context),
                  const SizedBox(height: 24),
                  _buildContactInfo(context),
                  const SizedBox(height: 20),
                  _buildCompanyInfo(context),
                  // const SizedBox(height: 24),
                  // _buildInvoicesExpandable(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildHeader(BuildContext context) {
  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: CachedNetworkImage(
                  imageUrl:
                      widget.client.profilePictureUrl != null &&
                          widget.client.profilePictureUrl!.isNotEmpty
                      ? widget.client.profilePictureUrl!
                      : AppStrings.emptyProfilePhotoUrl,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    highlightColor: Theme.of(context).colorScheme.surface,
                    child: Container(color: Theme.of(context).colorScheme.surface),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                  height: 45,
                  width: 45,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.client.clientName!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.client.companyName!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 20,
                      runSpacing: 6,
                      children: [
                        _iconText(context, Icons.email, widget.client.email!),
                        _iconText(
                          context,
                          Icons.phone,
                          widget.client.mobileNumber!,
                        ),
                        _iconText(
                          context,
                          Icons.language,
                          widget.client.officialWebsite ?? "No website",
                        ),
                        _iconText(
                          context,
                          Icons.location_on,
                          "${widget.client.city?.name ?? '-'}, ${widget.client.state?.name ?? '-'}",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // const SizedBox(height: 24),
          // Row(
          //   children: [
          //     _statCard(
          //       context,
          //       Icons.folder_open_outlined,
          //       "Projects",
          //       "8",
          //       const Color(0xFF1E88E5),
          //     ),
          //     _statCard(
          //       context,
          //       Icons.attach_money,
          //       "Earnings",
          //       "\$24,000",
          //       const Color(0xFF43A047),
          //     ),
          //     _statCard(
          //       context,
          //       Icons.receipt_long_outlined,
          //       "Due Invoices",
          //       "2",
          //       const Color(0xFFE53935),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }

  Widget _iconText(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
      ],
    );
  }

  // Widget _statCard(
  Widget _buildContactInfo(BuildContext context) {
    final items = [
      {
        "label": "Client Name",
        "value": "${widget.client.salutation} ${widget.client.clientName}",
      },
      {"label": "Email", "value": widget.client.email},
      {"label": "Mobile", "value": widget.client.mobileNumber},
      {"label": "Gender", "value": widget.client.gender},
      {
        "label": "Login Allowed",
        "value": widget.client.loginAllowed == true ? "Yes" : "No",
      },
    ];

    return expandableSection(
      context: context,
      title: "Contact Details",
      icon: Icons.person_outline,
      initiallyExpanded: widget.isCompany ? false : true,
      child: _infoGrid(context, items),
    );
  }

  Widget _buildCompanyInfo(BuildContext context) {
    final items = [
      {"label": "Company Name", "value": widget.client.companyName},
      {"label": "Website", "value": widget.client.officialWebsite},
      {"label": "GST/VAT No", "value": widget.client.gstVatNumber},
      {"label": "Office Phone", "value": widget.client.officePhoneNo},
      {"label": "Address", "value": widget.client.companyAddress},
    ];

    return expandableSection(
      context: context,
      title: "Company Details",
      icon: Icons.apartment_outlined,
      initiallyExpanded: widget.isCompany,
      child: _infoGrid(context, items),
    );
  }

  Widget expandableSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    return Container(
      decoration: _cardDecoration(),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        initiallyExpanded: initiallyExpanded,
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        children: [child],
      ),
    );
  }

  Widget _infoGrid(BuildContext context, List<Map<String, dynamic>> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800
            ? 3
            : constraints.maxWidth > 500
            ? 2
            : 1;

        return Wrap(
          spacing: 20,
          runSpacing: 12,
          children: items.map((item) {
            return SizedBox(
              width: constraints.maxWidth / crossAxisCount - 24,
              child: _infoTile(
                context,
                item["label"].toString(),
                item["value"]?.toString() ?? "-",
              ),
            );
          }).toList(),
        );
      },
    );
  }


  // Widget _buildInvoicesExpandable(BuildContext context) {
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "completed":
      case "paid":
        return AppColors.success;
      case "pending":
      case "in progress":
        return AppColors.orange;
      case "overdue":
        return AppColors.danger;
      default:
        return AppColors.grey;
    }
  }

  // Widget _invoiceTile(
  //   BuildContext context,
  //   String title,
  //   String status,
  //   Color color,
  // ) {
  //   return ListTile(
  //     contentPadding: EdgeInsets.zero,
  //     leading: const Icon(Icons.receipt_outlined, color: AppColors.black54),
  //     title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
  //     trailing: Text(
  //       status,
  //       style: Theme.of(context).textTheme.bodyMedium?.copyWith(
  //         color: color,
  //         fontWeight: FontWeight.w600,
  //       ),
  //     ),
  //   );
  // }

  Widget _listTile(
    BuildContext context,
    String title,
    // String status,
    // Color color,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.circle,
        // color: color,
        size: 14,
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      // trailing: Text(
      //   status,
      //   style: Theme.of(context).textTheme.bodySmall?.copyWith(
      //     color: color,
      //     fontWeight: FontWeight.w600,
      //   ),
      // ),
    );
  }

  Widget _infoTile(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value.isEmpty ? "-" : value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // Widget _sectionHeader(BuildContext context, String title, IconData icon) {
  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

