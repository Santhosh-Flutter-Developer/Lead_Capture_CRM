import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import '/services/others/src/menu_service.dart';
import '/utils/utils.dart';
import '/views/views.dart';

class DesktopColors {
  static const Color primary = AppColors.primary;
  static const Color sidebarBackground = Color(0xFF1E293B);
  static const Color selectionTile = Color(0xFF334155);
  static const Color lightText = Color(0xFFF1F5F9);
  static const Color lightTextSecondary = Color(0xFF94A3B8);
  static const Color white = AppColors.white;
  static const Color transparent = AppColors.transparent;
  static const Color hover = Color(0x1AFFFFFF);
}

class SidebarIconTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? selectedColor;
  final Color? hoverColor;
  final Color? iconColor;

  const SidebarIconTile({
    super.key,
    required this.icon,
    required this.title,
    required this.isSelected,
    this.onTap,
    this.selectedColor,
    this.hoverColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: hoverColor ?? Colors.white.withValues(alpha: 0.1),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color:
                iconColor ??
                (isSelected
                    ? DesktopColors.primary
                    : DesktopColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}

class DesktopSidebar extends StatefulWidget {
  final bool isCollapsed;
  final ValueChanged<bool> onCollapseChanged;
  final String selectedMenu;
  final ValueChanged<String> onMenuSelected;
  final bool isAdmin;
  final String? companyLogo;

  const DesktopSidebar({
    super.key,
    required this.isCollapsed,
    required this.onCollapseChanged,
    required this.selectedMenu,
    required this.onMenuSelected,
    required this.isAdmin,
    this.companyLogo,
  });

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  int expandedIndex = -1;
  late Future _future;
  List<Map<String, dynamic>> _menus = [];
  final ScrollController _scrollController = ScrollController();

  static const double _expandedWidth = 240.0;
  static const double _collapsedWidth = 72.0;

  @override
  void initState() {
    super.initState();
    _future = _updateExpandedIndex();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DesktopSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMenu != widget.selectedMenu) {
      _updateExpandedIndex();
    }
  }

  Future<void> _updateExpandedIndex() async {
    _menus = await _getMenus();
    for (int i = 0; i < _menus.length; i++) {
      if (_menus[i].containsKey('children')) {
        final children = _menus[i]['children'] as List;
        if (children.any(
          (c) =>
              (c is String && c == widget.selectedMenu) ||
              (c is Map && c['title'] == widget.selectedMenu),
        )) {
          setState(() {
            expandedIndex = i;
          });
          return;
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getMenus() async {
    final settings = await SettingsService().fetchSettings();
    final bool payrollEnabled = settings.payrollEnabled;
    final userPermissions = await MenuService.getUserPermissions();

    // Get filtered menu items using MenuService
    final menuItems = await MenuService.filterMenuItems(
      isAdmin: widget.isAdmin,
      payrollEnabled: payrollEnabled,
      userPermissions: userPermissions,
    );

    // Convert MenuItem to Map format for existing UI
    List<Map<String, dynamic>> menus = [];

    for (final item in menuItems) {
      if (item.isStatic) {
        menus.add({
          'icon': item.icon,
          'title': 'App Version : ${AppPackageInfo.version}',
          'onTap': false,
        });
        continue;
      }

      if (item.children != null && item.children!.isNotEmpty) {
        // Handle expandable menu
        final children = <dynamic>[];
        for (final child in item.children!) {
          if (child.children != null && child.children!.isNotEmpty) {
            // Handle nested expandable menu
            final nestedChildren = child.children!.map((c) => c.title).toList();
            children.add({'title': child.title, 'children': nestedChildren});
          } else {
            children.add(child.title);
          }
        }

        // Add trailing widget for Chats
        Widget? trailing;
        if (item.id == 'chats') {
          trailing = ValueListenableBuilder<int>(
            valueListenable: ChatService.unviewedCount(),
            builder: (context, count, _) {
              if (count == 0 || widget.isCollapsed) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: DesktopColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$count",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall!.copyWith(color: DesktopColors.white),
                ),
              );
            },
          );
        }

        menus.add({
          'icon': item.icon,
          'title': item.title,
          'children': children,
          if (trailing != null) 'trailing': trailing,
        });
      } else {
        // Handle simple menu item
        menus.add({'icon': item.icon, 'title': item.title});
      }
    }

    return menus;
  }

  @override
  Widget build(BuildContext context) {
    final double sidebarWidth = widget.isCollapsed
        ? _collapsedWidth
        : _expandedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: DesktopColors.sidebarBackground,
        border: Border(
          right: BorderSide(
            color: DesktopColors.lightTextSecondary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildLogo(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 12.0,
              ),
              child: FutureBuilder(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error loading menus",
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.red),
                      ),
                    );
                  }
                  return Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView(
                      controller: _scrollController,
                      children: _menus.asMap().entries.map((entry) {
                        int index = entry.key;
                        var menu = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: menu.containsKey('children')
                              ? buildExpandableMenu(
                                  icon: menu['icon'] as IconData,
                                  title: menu['title'] as String,
                                  expanded: expandedIndex == index,
                                  onToggle: () {
                                    // setState(() {
                                    setState(() {
                                      expandedIndex = expandedIndex == index
                                          ? -1
                                          : index;
                                    });

                                    // if (widget.isCollapsed) {
                                    //   widget.onCollapseChanged(false);
                                    // }
                                    // });
                                  },
                                  children: menu['children'] as List<dynamic>,
                                )
                              : buildMenuItem(
                                  menu['icon'] as IconData,
                                  menu['title'] as String,
                                  menu['trailing'],
                                  onTap: menu.containsKey('onTap')
                                      ? menu['onTap'] as bool
                                      : true,
                                ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ),
          _buildCollapseButton(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    final String? networkLogo = widget.companyLogo;

    return Column(
      children: [
        SizedBox(
          height: 70,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: widget.isCollapsed
                  ? const Icon(Iconsax.buildings, size: 28, color: Colors.white)
                  : InkWell(
                      onTap: () =>
                          Navigate.routeReplace(context, RouteScreen()),
                      child: (networkLogo != null && networkLogo.isNotEmpty)
                          ? Image.network(
                              networkLogo,
                              height: 36,
                              fit: BoxFit.contain,
                              frameBuilder:
                                  (
                                    context,
                                    child,
                                    frame,
                                    wasSynchronouslyLoaded,
                                  ) {
                                    return wasSynchronouslyLoaded
                                        ? child
                                        : AnimatedOpacity(
                                            opacity: frame == null ? 0 : 1,
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                            curve: Curves.easeOut,
                                            child: child,
                                          );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildDefaultLogoAsset(),
                            )
                          : _buildDefaultLogoAsset(),
                    ),
            ),
          ),
        ),
        Divider(
          color: DesktopColors.lightTextSecondary.withValues(alpha: 0.1),
          height: 1,
          indent: widget.isCollapsed ? 0 : 16,
          endIndent: widget.isCollapsed ? 0 : 16,
        ),
      ],
    );
  }

  Widget _buildDefaultLogoAsset() {
    return Image.asset(
      ImageAssets.logoTransparent,
      height: 36,
      color: DesktopColors.white,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Iconsax.buildings, size: 30, color: DesktopColors.white),
    );
  }

  Widget _buildCollapseButton() {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12.0,
        top: 8.0,
        left: 8.0,
        right: 8.0,
      ),
      child: IconButton(
        icon: Icon(
          widget.isCollapsed ? Iconsax.arrow_right_3 : Iconsax.arrow_left_2,
          color: DesktopColors.lightTextSecondary,
          size: 20,
        ),
        onPressed: () {
          final newValue = !widget.isCollapsed;

          if (newValue) {
            setState(() => expandedIndex = -1);
          }

          widget.onCollapseChanged(newValue);
        },
        tooltip: widget.isCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
      ),
    );
  }

  Widget buildMenuItem(
    IconData icon,
    String title,
    Widget? trailing, {
    bool onTap = true,
  }) {
    final bool isSelected = widget.selectedMenu == title;

    if (widget.isCollapsed) {
      return SidebarIconTile(
        icon: icon,
        title: title,
        isSelected: isSelected,
        onTap: onTap
            ? () {
                widget.onMenuSelected(title);
                setState(() => expandedIndex = -1);
              }
            : null,
        selectedColor: DesktopColors.selectionTile,
        hoverColor: DesktopColors.hover,
        iconColor: isSelected
            ? DesktopColors.primary
            : DesktopColors.lightTextSecondary,
      );
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.comfortable,
      minTileHeight: 20,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      leading: Icon(icon, size: 20),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: isSelected
              ? DesktopColors.primary
              : DesktopColors.lightTextSecondary.withValues(alpha: 0.7),
        ),
      ),
      trailing: trailing,
      onTap: onTap
          ? () {
              widget.onMenuSelected(title);
              setState(() => expandedIndex = -1);
            }
          : null,
      selected: isSelected,
      selectedColor: DesktopColors.primary,
      selectedTileColor: DesktopColors.selectionTile,
      iconColor: isSelected
          ? DesktopColors.primary
          : DesktopColors.lightTextSecondary,
      textColor: isSelected
          ? DesktopColors.primary
          : DesktopColors.lightTextSecondary,
      hoverColor: DesktopColors.hover,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      horizontalTitleGap: 8,
    );
  }

  Widget buildExpandableMenu({
    required IconData icon,
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required List<dynamic> children,
  }) {
    final bool isChildSelected = children.any(
      (c) =>
          (c is String && c == widget.selectedMenu) ||
          (c is Map && c['title'] == widget.selectedMenu),
    );
    final bool isActive = expanded || isChildSelected;

    if (widget.isCollapsed) {
      return SidebarIconTile(
        icon: icon,
        title: title,
        isSelected: isActive,
        onTap: onToggle,
        selectedColor: DesktopColors.selectionTile,
        hoverColor: DesktopColors.hover,
        iconColor: isActive
            ? DesktopColors.primary
            : DesktopColors.lightTextSecondary,
      );
    }

    final Color textColor = isActive
        ? DesktopColors.primary
        : DesktopColors.lightTextSecondary;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: DesktopColors.transparent,
        expansionTileTheme: ExpansionTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: DesktopColors.transparent,
          collapsedBackgroundColor: DesktopColors.transparent,
          iconColor: textColor,
          textColor: textColor,
          tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        ),
      ),
      child: ExpansionTile(
        dense: true,
        leading: Icon(
          icon,
          size: title == 'Clients' ? 10 : 20,
          color: DesktopColors.lightTextSecondary,
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: DesktopColors.lightTextSecondary.withValues(alpha: 0.7),
          ),
        ),
        trailing: Icon(
          expanded ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
          size: 16,
          color: DesktopColors.lightTextSecondary,
        ),
        onExpansionChanged: (_) => onToggle(),
        initiallyExpanded: expanded,
        childrenPadding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
        children: children.map((child) {
          if (child is String) return _buildChildMenuItem(child);
          if (child is Map && child.containsKey('title')) {
            return buildExpandableMenu(
              icon: Icons.circle,
              title: child['title'],
              expanded: child['title'] == widget.selectedMenu,
              onToggle: () {},
              children: child['children'] as List<dynamic>,
            );
          }
          return const SizedBox.shrink();
        }).toList(),
      ),
    );
  }

  Widget _buildChildMenuItem(String title) {
    if (widget.isCollapsed) return const SizedBox.shrink();

    final bool isSelected = widget.selectedMenu == title;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      child: ListTile(
        dense: true,
        minTileHeight: 36,
        contentPadding: const EdgeInsets.only(left: 20),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: isSelected
                ? DesktopColors.primary
                : DesktopColors.lightTextSecondary.withValues(alpha: 0.7),
          ),
        ),
        leading: Icon(
          Icons.circle,
          size: 6,
          color: isSelected
              ? DesktopColors.primary
              : DesktopColors.lightTextSecondary.withValues(alpha: 0.7),
        ),
        onTap: () {
          widget.onMenuSelected(title);
          setState(() => expandedIndex = -1);
        },
        selected: isSelected,
        selectedColor: DesktopColors.primary,
        selectedTileColor: DesktopColors.selectionTile,
        textColor: DesktopColors.lightTextSecondary,
        hoverColor: DesktopColors.hover,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        horizontalTitleGap: 0,
      ),
    );
  }
}
