import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

/// Menu item configuration with role-based access control
class MenuItem {
  final String id;
  final String title;
  final IconData icon;
  final String? route;
  final List<MenuItem>? children;
  final bool isAdminOnly;
  final List<String> requiredPermissions;
  final bool isDivider;
  final bool isStatic;

  MenuItem({
    required this.id,
    required this.title,
    required this.icon,
    this.route,
    this.children,
    this.isAdminOnly = false,
    this.requiredPermissions = const [],
    this.isDivider = false,
    this.isStatic = false,
  });

  /// Check if menu item is accessible based on user role and permissions
  Future<bool> isAccessible({
    required bool isAdmin,
    required List<String> userPermissions,
  }) async {
    if (isStatic) return true;
    if (isDivider) return true;
    if (isAdminOnly && !isAdmin) return false;

    if (requiredPermissions.isNotEmpty) {
      final hasPermission = requiredPermissions.any(
        (permission) => userPermissions.contains(permission),
      );
      if (!hasPermission && !isAdmin) return false;
    }

    return true;
  }
}

/// Service for managing menu configurations and access control
class MenuService {
  /// Get all menu items for the application
  static List<MenuItem> getAllMenuItems() {
    return [
      // Main Navigation
      MenuItem(
        id: 'dashboard',
        title: 'Dashboard',
        icon: Iconsax.home_2,
        route: '/dashboard',
      ),
      // MenuItem(
      //   id: 'feed',
      //   title: 'Feed',
      //   icon: Iconsax.activity,
      //   route: '/feed',
      // ),

      // // Chats
      // MenuItem(
      //   id: 'chats',
      //   title: 'Chats',
      //   icon: Iconsax.message,
      //   route: '/chats',
      //   requiredPermissions: ['Chats'],
      // ),

      // CRM Section
      MenuItem(
        id: 'crm',
        title: 'CRM',
        icon: Iconsax.graph,
        children: [
          MenuItem(
            id: 'lead_category',
            title: 'Lead Category',
            icon: Iconsax.category,
            route: '/lead-category',
            requiredPermissions: ['Lead Category'],
          ),
          MenuItem(
            id: 'lead_source',
            title: 'Lead Source',
            icon: Iconsax.share,
            route: '/lead-source',
            requiredPermissions: ['Lead Source'],
          ),
          MenuItem(
            id: 'lead_priority',
            title: 'Lead Priority',
            icon: Iconsax.flag,
            route: '/lead-priority',
            requiredPermissions: ['Lead Priority'],
          ),
          MenuItem(
            id: 'lead_status',
            title: 'Lead Status',
            icon: Iconsax.link_circle,
            route: '/lead-status',
            requiredPermissions: ['Lead Status'],
          ),
          MenuItem(
            id: 'deal_status',
            title: 'Deal Status',
            icon: Iconsax.activity,
            route: '/deal-status',
            requiredPermissions: ['Deal Status'],
          ),
          MenuItem(
            id: 'leads',
            title: 'Leads',
            icon: Iconsax.graph,
            route: '/leads',
            requiredPermissions: ['Leads'],
          ),
          MenuItem(
            id: 'deals',
            title: 'Deals',
            icon: Iconsax.lock,
            route: '/deals',
            requiredPermissions: ['Deals'],
          ),
          MenuItem(
            id: 'clients',
            title: 'Clients',
            icon: Iconsax.people,
            children: [
              MenuItem(
                id: 'client_company',
                title: 'Company',
                icon: Iconsax.building,
                route: '/client-company',
                requiredPermissions: ['Company'],
              ),
              MenuItem(
                id: 'client_contact',
                title: 'Contact',
                icon: Iconsax.user,
                route: '/client-contact',
                requiredPermissions: ['Contact'],
              ),
            ],
          ),
        ],
      ),

      // Calendar
      MenuItem(
        id: 'calendar',
        title: 'Calendar',
        icon: Iconsax.calendar_1,
        route: '/calendar',
        requiredPermissions: ['Calendar'],
      ),

      // Tasks
      // MenuItem(
      //   id: 'tasks',
      //   title: 'Tasks',
      //   icon: Iconsax.check,
      //   route: '/tasks',
      //   requiredPermissions: ['Tasks'],
      // ),

      // Customer Tickets
      // MenuItem(
      //   id: 'tickets',
      //   title: 'Tickets',
      //   icon: Iconsax.ticket,
      //   route: '/tickets',
      //   requiredPermissions: ['Tickets'],
      // ),

      // Settings
      MenuItem(
        id: 'settings',
        title: 'Settings',
        icon: Iconsax.setting_2,
        route: '/settings',
      ),

      // Admin Only Section
      MenuItem(
        id: 'admin_section',
        title: 'Admin',
        icon: Iconsax.shield,
        isAdminOnly: true,
        children: [
          MenuItem(
            id: 'login_logs',
            title: 'Login Logs',
            icon: Iconsax.login,
            route: '/login-logs',
            requiredPermissions: ['Login Logs'],
          ),
          MenuItem(
            id: 'activity_logs',
            title: 'Activity Logs',
            icon: Iconsax.activity,
            route: '/activity-logs',
            requiredPermissions: ['Activity Logs'],
          ),
        ],
      ),

      // Downloads
      MenuItem(
        id: 'downloads',
        title: 'Downloads',
        icon: Iconsax.document_download,
        route: '/downloads',
        requiredPermissions: ['Downloads'],
      ),

      // Developer Area
      MenuItem(
        id: 'developer_area',
        title: 'Developer Area',
        icon: Iconsax.code,
        route: '/developer-area',
        requiredPermissions: ['Developer Area'],
      ),

      // Static items (always visible)
      MenuItem(
        id: 'app_version',
        title: 'App Version',
        icon: Iconsax.info_circle,
        isStatic: true,
      ),
    ];
  }

  /// Filter menu items based on user role and permissions (handles nested children recursively)
  static Future<List<MenuItem>> filterMenuItems({
    required bool isAdmin,
    required List<String> userPermissions,
  }) async {
    final allItems = getAllMenuItems();
    final filteredItems = <MenuItem>[];

    Future<List<MenuItem>> filterChildren(List<MenuItem> children) async {
      final filtered = <MenuItem>[];
      for (final child in children) {
        final childAccessible = await child.isAccessible(
          isAdmin: isAdmin,
          userPermissions: userPermissions,
        );

        if (child.children != null) {
          final grandChildren = await filterChildren(child.children!);
          if (grandChildren.isNotEmpty) {
            filtered.add(
              MenuItem(
                id: child.id,
                title: child.title,
                icon: child.icon,
                route: child.route,
                children: grandChildren,
                isAdminOnly: child.isAdminOnly,
                requiredPermissions: child.requiredPermissions,
                isDivider: child.isDivider,
                isStatic: child.isStatic,
              ),
            );
          }
        } else if (childAccessible) {
          filtered.add(child);
        }
      }
      return filtered;
    }

    for (final item in allItems) {
      final accessible = await item.isAccessible(
        isAdmin: isAdmin,
        userPermissions: userPermissions,
      );

      if (item.children != null) {
        final filteredChildren = await filterChildren(item.children!);
        if (filteredChildren.isNotEmpty) {
          filteredItems.add(
            MenuItem(
              id: item.id,
              title: item.title,
              icon: item.icon,
              route: item.route,
              children: filteredChildren,
              isAdminOnly: item.isAdminOnly,
              requiredPermissions: item.requiredPermissions,
              isDivider: item.isDivider,
              isStatic: item.isStatic,
            ),
          );
        }
      } else if (accessible) {
        filteredItems.add(item);
      }
    }

    return filteredItems;
  }

  /// Get all available permissions
  static List<String> getAllPermissions() {
    return [
      'Chats',
      'Lead Category',
      'Lead Source',
      'Lead Priority',
      'Lead Status',
      'Deal Status',
      'Leads',
      'Deals',
      'Company',
      'Contact',
      'Calendar',
      'Tasks',
      'Tickets',
      'Downloads',
      'Developer Area',
      'Login Logs',
      'Activity Logs',
    ];
  }
}
