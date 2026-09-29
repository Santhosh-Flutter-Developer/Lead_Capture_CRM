import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '/models/models.dart';
import '/views/views.dart';

/// Client / Company detail sheet.
///
/// Visual language matches the Leads & Deals detail views:
/// gradient avatar + value card, tinted quick actions, rounded info cards
/// with icon-chip data points.
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
  final ScrollController _scrollController = ScrollController();

  static const LinearGradient _brandGradient = LinearGradient(
    colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
  );
  static const Color _brandGlow = Color(0xFF4364F7);

  ClientModel get _c => widget.client;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ───────────────────────────── helpers ─────────────────────────────

  /// Blank / null / literal "null" values render as "-".
  String _v(String? value) {
    final t = value?.trim();
    return (t == null || t.isEmpty || t.toLowerCase() == 'null') ? '-' : t;
  }

  bool _has(String? value) => _v(value) != '-';

  String get _displayName {
    final person = _has(_c.clientName) ? _c.clientName!.trim() : '';
    final company = _has(_c.companyName) ? _c.companyName!.trim() : '';
    if (widget.isCompany) {
      return company.isNotEmpty
          ? company
          : (person.isNotEmpty ? person : 'Unnamed');
    }
    return person.isNotEmpty ? person : (company.isNotEmpty ? company : 'Unnamed');
  }

  String get _subtitle {
    if (!widget.isCompany) {
      return _has(_c.companyName) ? _c.companyName!.trim() : '';
    }
    final parts = <String>[
      if (_has(_c.city?.name)) _c.city!.name,
      if (_has(_c.state?.name)) _c.state!.name,
    ];
    return parts.join(', ');
  }

  String get _fullName {
    final parts = <String>[
      if (_has(_c.salutation)) _c.salutation!.trim(),
      if (_has(_c.clientName)) _c.clientName!.trim(),
    ];
    return parts.isEmpty ? '-' : parts.join(' ');
  }

  String get _phone =>
      _has(_c.mobileNumber) ? _c.mobileNumber!.trim() : (_has(_c.officePhoneNo) ? _c.officePhoneNo!.trim() : '');

  String get _imageUrl {
    final url = widget.isCompany
        ? (_has(_c.companyLogoUrl) ? _c.companyLogoUrl : _c.profilePictureUrl)
        : (_has(_c.profilePictureUrl) ? _c.profilePictureUrl : null);
    return (url ?? '').trim();
  }

  Future<void> _open(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        FlushBar.show(context, 'Could not open link', isSuccess: false);
      }
    } catch (_) {
      if (mounted) {
        FlushBar.show(context, 'Could not open link', isSuccess: false);
      }
    }
  }

  Uri? _websiteUri() {
    if (!_has(_c.officialWebsite)) return null;
    final raw = _c.officialWebsite!.trim();
    return Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
  }

  // ───────────────────────────── build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final contact = _infoSection("Contact Details", [
      _dataPoint(Iconsax.user, "Client Name", _fullName),
      _dataPoint(Iconsax.sms, "Email", _v(_c.email)),
      _dataPoint(Iconsax.call, "Mobile", _v(_c.mobileNumber)),
      _dataPoint(Iconsax.profile_2user, "Gender", _v(_c.gender)),
      _dataPoint(
        Iconsax.login,
        "Login Allowed",
        _c.loginAllowed == true ? "Yes" : "No",
      ),
    ]);

    final website = _has(_c.officialWebsite);
    final company = _infoSection("Company Details", [
      _dataPoint(Iconsax.buildings, "Company Name", _v(_c.companyName)),
      _dataPoint(
        Iconsax.global,
        "Website",
        _v(_c.officialWebsite),
        isLink: website,
        onTap: website && _websiteUri() != null
            ? () => _open(_websiteUri()!)
            : null,
      ),
      _dataPoint(Iconsax.personalcard, "GST/VAT No", _v(_c.gstVatNumber)),
      _dataPoint(Iconsax.call, "Office Phone", _v(_c.officePhoneNo)),
      _dataPoint(Iconsax.location, "Address", _v(_c.companyAddress)),
    ]);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: scheme.surface,
          elevation: 0,
          centerTitle: false,
          title: Text(
            "Client Details",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: scheme.onSurface,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: scheme.outlineVariant, height: 1),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                trackVisibility: true,
                radius: const Radius.circular(8),
                thickness: 8,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      // The section that matters most for this record goes first.
                      if (widget.isCompany) ...[
                        company,
                        const SizedBox(height: 16),
                        contact,
                      ] else ...[
                        contact,
                        const SizedBox(height: 16),
                        company,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────── header ─────────────────────────────

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(isMobile ? 60 : 80),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              _displayName,
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                            _badge(
                              widget.isCompany ? 'Company' : 'Contact',
                              scheme.primary,
                            ),
                            if (!_c.isActive) _badge('Inactive', scheme.error),
                          ],
                        ),
                        if (_subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (!isMobile) ...[
                          const SizedBox(height: 12),
                          _buildActionsRow(),
                        ],
                      ],
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 16),
                    _buildSinceCard(),
                  ],
                ],
              ),
              if (isMobile) ...[
                const SizedBox(height: 20),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildActionsRow()),
                    const SizedBox(width: 12),
                    _buildSinceCard(),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(double size) {
    final initial = _displayName.isNotEmpty && _displayName != 'Unnamed'
        ? _displayName[0].toUpperCase()
        : '?';

    Widget initialTile() => Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    final url = _imageUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _brandGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _brandGlow.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: url.isEmpty
          ? initialTile()
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => initialTile(),
                errorWidget: (_, __, ___) => initialTile(),
              ),
            ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSinceCard() {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: _brandGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isCompany ? "Company Since" : "Client Since",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                DateFormat('MMM dd, yyyy').format(_c.createdAt),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────── quick actions ─────────────────────────────

  Widget _buildActionsRow() {
    final phone = _phone;
    final email = _has(_c.email) ? _c.email!.trim() : '';
    final site = _websiteUri();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _quickAction(
          Iconsax.call,
          "Call",
          phone.isEmpty ? null : () => _open(Uri(scheme: 'tel', path: phone)),
          tooltip: phone.isEmpty ? "No contact number available" : "Call $phone",
        ),
        _quickAction(
          Iconsax.sms,
          "Email",
          email.isEmpty ? null : () => _open(Uri(scheme: 'mailto', path: email)),
          tooltip: email.isEmpty ? "No email available" : "Mail $email",
        ),
        _quickAction(
          Iconsax.global,
          "Website",
          site == null ? null : () => _open(site),
          tooltip: site == null ? "No website available" : site.toString(),
        ),
      ],
    );
  }

  Widget _quickAction(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    String? tooltip,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────── info cards ─────────────────────────────

  Widget _infoSection(String title, List<Widget> children) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 40.0;
              final cols = constraints.maxWidth > 820
                  ? 3
                  : constraints.maxWidth > 520
                  ? 2
                  : 1;
              final itemWidth =
                  (constraints.maxWidth - spacing * (cols - 1)) / cols;
              return Wrap(
                spacing: spacing,
                runSpacing: 24,
                children: children
                    .map((w) => SizedBox(width: itemWidth, child: w))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dataPoint(
    IconData icon,
    String label,
    String value, {
    bool isLink = false,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isLink ? scheme.primary : scheme.onSurface,
                  decoration: isLink ? TextDecoration.underline : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: content,
    );
  }
}