import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import '/app/app.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/services/services.dart';
import 'company_location_settings.dart';

class SettingsColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color background = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color surface = Colors.white;
}

class Settings extends StatelessWidget {
  final bool showAppbar;
  final Function(bool)? onThemeChanged;

  const Settings({super.key, this.showAppbar = true, this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SettingsBloc()..add(LoadSettingsEvent())),
      ],
      child: SettingsListing(
        showAppbar: showAppbar,
        onThemeChanged: onThemeChanged,
      ),
    );
  }
}

class SettingsListing extends StatefulWidget {
  final bool showAppbar;
  final Function(bool)? onThemeChanged;

  const SettingsListing({
    super.key,
    this.showAppbar = true,
    this.onThemeChanged,
  });

  @override
  State<SettingsListing> createState() => _SettingsListingState();
}

class _SettingsListingState extends State<SettingsListing> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.showAppbar
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              centerTitle: false,
              leading: Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Back(color: Theme.of(context).colorScheme.onSurface),
              ),
              title: Text(
                "Preferences",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: Theme.of(context).dividerColor,
                  height: 1,
                ),
              ),
            )
          : null,
      body: BlocConsumer<SettingsBloc, SettingsState>(
        listener: (context, state) {},
        builder: (context, state) {
          if (state is SettingsLoading) {
            return const Center(child: WaitingLoading());
          }
          if (state is SettingsLoaded) {
            final settings = state.settings;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildSectionHeader("Notifications", Iconsax.notification),
                    const SizedBox(height: 12),
                    _buildSettingsCard([
                      _buildSwitchTile(
                        icon: Iconsax.sms,
                        iconColor: Colors.blueAccent,
                        title: "Email Notifications",
                        subtitle: "Receive daily summaries via email",
                        value: settings.emailNotification,
                        onChanged: (val) => context.read<SettingsBloc>().add(
                          UpdateSettingsEvent("emailNotification", val),
                        ),
                      ),
                      _buildSwitchTile(
                        icon: Iconsax.notification,
                        iconColor: Colors.orangeAccent,
                        title: "Push Notifications",
                        subtitle: "Instant alerts on your device",
                        value: settings.pushNotification,
                        onChanged: (val) => context.read<SettingsBloc>().add(
                          UpdateSettingsEvent("pushNotification", val),
                        ),
                      ),
                      // _buildSwitchTile(
                      //   icon: Iconsax.wallet,
                      //   iconColor: Colors.green,
                      //   title: "Payroll",
                      //   subtitle: "Show payroll related modules",
                      //   value: settings.payrollEnabled,
                      //   onChanged: (val) async {
                      //     context.read<SettingsBloc>().add(
                      //       UpdateSettingsEvent("payrollEnabled", val),
                      //     );
                      //     await Spdb.savePayrollSettings(val);
                      //   },
                      // ),
                      _buildSwitchTile(
                        icon: Iconsax.message,
                        iconColor: Colors.greenAccent,
                        title: "In-App Alerts",
                        subtitle: "Banners and indicators within the app",
                        value: settings.inAppNotification,
                        onChanged: (val) => context.read<SettingsBloc>().add(
                          UpdateSettingsEvent("inAppNotification", val),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: PanelSettingsNotifier.hidePanel,
                        builder: (context, hidePanel, _) {
                          return _buildSwitchTile(
                            icon: hidePanel
                                ? Iconsax.lamp_slash
                                : Iconsax.lamp_on,
                            iconColor: Colors.purple,
                            title: "Hide Chat Panel",
                            subtitle: "Enable to hide the side panel",
                            value: hidePanel,
                            onChanged: (val) async {
                              await Spdb.savePanelSettings(val);
                            },
                          );
                        },
                      ),
                    ], context),
                    const SizedBox(height: 32),
                    _buildSectionHeader("App Appearance", Iconsax.brush),
                    const SizedBox(height: 12),
                    _buildSettingsCard([
                      _buildSwitchTile(
                        icon: isDark ? Iconsax.moon : Iconsax.sun_1,
                        iconColor: const Color(0xFF34495E),
                        title: "Dark Theme",
                        subtitle: "Reduce eye strain in low light",
                        value: isDark,
                        onChanged: (value) => themeProvider.setDarkMode(value),
                        isInDevelop: false,
                      ),
                      // _buildInteractiveTile(
                      //   icon: Iconsax.global,
                      //   iconColor: Colors.indigoAccent,
                      //   title: "Language",
                      //   trailing: _buildDropdown(
                      //     value: settings.language,
                      //     options: ["English", "Hindi", "Tamil", "Telugu"],
                      //     onChanged: (val) => context.read<SettingsBloc>().add(
                      //       UpdateSettingsEvent("language", val),
                      //     ),
                      //   ),
                      // ),
                      // _buildInteractiveTile(
                      //   icon: Iconsax.music_dashboard,
                      //   iconColor: Colors.deepOrangeAccent,
                      //   title: "Dashboard Layout",
                      //   trailing: _buildDropdown(
                      //     value: settings.dashboardLayout,
                      //     options: ["Default", "Compact", "Analytics"],
                      //     onChanged: (val) => context.read<SettingsBloc>().add(
                      //       UpdateSettingsEvent("dashboardLayout", val),
                      //     ),
                      //   ),
                      // ),
                    ], context),
                    const SizedBox(height: 32),
                    _buildSectionHeader("System & Data", Iconsax.status),
                    const SizedBox(height: 12),
                    _buildSettingsCard([
                      _buildInteractiveTile(
                        icon: Iconsax.mobile_programming,
                        iconColor: Colors.purpleAccent,
                        title: "Application Name",
                        trailing: SizedBox(
                          width: 140,
                          child: TextField(
                            onChanged: (val) => context
                                .read<SettingsBloc>()
                                .add(UpdateSettingsEvent("appName", val)),
                            controller:
                                TextEditingController(text: settings.appName)
                                  ..selection = TextSelection.fromPosition(
                                    TextPosition(
                                      offset: settings.appName.length,
                                    ),
                                  ),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: SettingsColors.primary,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: "Enter Name",
                              hintStyle: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: SettingsColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildSwitchTile(
                        icon: Iconsax.cloud_notif,
                        iconColor: Colors.cyan,
                        title: "Cloud Auto-Backup",
                        subtitle: "Secure your data automatically",
                        value: settings.autoBackup,
                        onChanged: (val) => context.read<SettingsBloc>().add(
                          UpdateSettingsEvent("autoBackup", val),
                        ),
                      ),
                      _buildInteractiveTile(
                        icon: Iconsax.trash,
                        iconColor: Colors.redAccent,
                        title: "Trash Manager",
                        onTap: () =>
                            Navigate.route(context, const TrashScreen()),
                        trailing: const Icon(
                          Iconsax.arrow_right_3,
                          size: 16,
                          color: SettingsColors.border,
                        ),
                      ),
                    ], context),
                    const SizedBox(height: 40),
                    _buildFooter(),
                  ],
                ),
              ),
            );
          }
          if (state is SettingsError) {
            return ErrorDisplay(error: state.message);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(List<Widget> children, [BuildContext? ctx]) {
    final effectiveCtx = ctx ?? context;
    final cardColor = Theme.of(effectiveCtx).colorScheme.surface;
    final borderColor = Theme.of(effectiveCtx).dividerColor;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          bool isLast = entry.key == children.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast)
                Container(
                  margin: const EdgeInsets.only(left: 64),
                  color: borderColor,
                  height: 1,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isInDevelop = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildIconContainer(icon, iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!isInDevelop)
            MorphSwitch(value: value, onChanged: onChanged)
          else
            Text(
              "In Development",
              style: TextStyle(
                fontSize: 10,
                color: SettingsColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildIconContainer(icon, iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildIconContainer(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  // Widget _buildDropdown({
  //   required String value,
  //   required List<String> options,
  //   required ValueChanged<String?> onChanged,
  // }) {
  //   final validValue = options.contains(value) ? value : options.first;
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //     decoration: BoxDecoration(
  //       color: SettingsColors.background,
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: SettingsColors.border),
  //     ),
  //     child: DropdownButtonHideUnderline(
  //       child: DropdownButton<String>(
  //         value: validValue,
  //         icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: SettingsColors.textSecondary),
  //         isDense: true,
  //         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SettingsColors.textPrimary),
  //         items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
  //         onChanged: onChanged,
  //       ),
  //     ),
  //   );
  // }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          const Text(
            "Syncing with Cloud Vault",
            style: TextStyle(
              fontSize: 11,
              color: SettingsColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Workspace Version ${VersionService.version?.version ?? 'N/A'} (LTS)",
            style: TextStyle(fontSize: 10, color: SettingsColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class MorphSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const MorphSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.decelerate,
        width: 48,
        height: 26,
        decoration: BoxDecoration(
          color: value
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(3),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.decelerate,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
