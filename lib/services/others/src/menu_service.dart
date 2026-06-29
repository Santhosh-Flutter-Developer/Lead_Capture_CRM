import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/constants/src/enum.dart';
import '/services/services.dart';

/// Menu item configuration with role-based access control
class MenuItem {
  final String id;
  final String title;
  final IconData icon;
  final String? route;
  final List<MenuItem>? children;
  final bool isAdminOnly;
  final bool requiresPayroll;
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
    this.requiresPayroll = false,
    this.requiredPermissions = const [],
    this.isDivider = false,
    this.isStatic = false,
  });

  /// Check if menu item is accessible based on user role and permissions
  Future<bool> isAccessible({
    required bool isAdmin,
    required bool payrollEnabled,
    required List<String> userPermissions,
  }) async {
    if (isStatic) return true;
    if (isDivider) return true;
    if (isAdminOnly && !isAdmin) return false;
    if (requiresPayroll && !payrollEnabled) return false;

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
      MenuItem(
        id: 'feed',
        title: 'Feed',
        icon: Iconsax.activity,
        route: '/feed',
      ),

      // Creation Section
      MenuItem(
        id: 'creation',
        title: 'Creation',
        icon: Iconsax.element_plus,
        children: [
          MenuItem(
            id: 'role',
            title: 'Role',
            icon: Iconsax.user_square,
            route: '/role',
            requiredPermissions: ['Role'],
          ),
          MenuItem(
            id: 'designation',
            title: 'Designation',
            icon: Iconsax.tick_circle,
            route: '/designation',
            requiredPermissions: ['Designation'],
          ),
          MenuItem(
            id: 'department',
            title: 'Department',
            icon: Iconsax.building,
            route: '/department',
            requiredPermissions: ['Department'],
          ),
          MenuItem(
            id: 'sub_department',
            title: 'Sub Department',
            icon: Iconsax.building_3,
            route: '/sub-department',
            requiredPermissions: ['Sub Department'],
          ),

          // MenuItem(
          //   id: 'employee_status',
          //   title: 'Employee Status',
          //   icon: Iconsax.tag,
          //   route: '/employee-status',
          //   requiredPermissions: ['Employee Status'],
          // ),
          MenuItem(
            id: 'employees',
            title: 'Employees',
            icon: Iconsax.security_user,
            route: '/employees',
            requiredPermissions: ['Employees'],
          ),
        ],
      ),

      // Chats
      MenuItem(
        id: 'chats',
        title: 'Chats',
        icon: Iconsax.message,
        route: '/chats',
        requiredPermissions: ['Chats'],
      ),

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

      // Companies
      // MenuItem(
      //   id: 'companies',
      //   title: 'Companies',
      //   icon: Iconsax.building,
      //   route: '/companies',
      //   requiredPermissions: ['Company'],
      // ),

      // Calendar
      MenuItem(
        id: 'calendar',
        title: 'Calendar',
        icon: Iconsax.calendar_1,
        route: '/calendar',
        requiredPermissions: ['Calendar'],
      ),

      // Projects
      MenuItem(
        id: 'projects',
        title: 'Projects',
        icon: Iconsax.airdrop,
        route: '/projects',
        requiredPermissions: ['Projects'],
      ),

      // Tasks
      MenuItem(
        id: 'tasks',
        title: 'Tasks',
        icon: Iconsax.check,
        route: '/tasks',
        requiredPermissions: ['Tasks'],
      ),
      // Customer Tickets
      MenuItem(
        id: 'tickets',
        title: 'Tickets',
        icon: Iconsax.ticket,
        route: '/tickets',
        requiredPermissions: ['Tickets'],
      ),

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
            isAdminOnly: true,
          ),
          MenuItem(
            id: 'activity_logs',
            title: 'Activity Logs',
            icon: Iconsax.activity,
            route: '/activity-logs',
            isAdminOnly: true,
          ),
          // MenuItem(
          //   id: 'backup',
          //   title: 'Backup',
          //   icon: Iconsax.cloud,
          //   route: '/backup',
          //   isAdminOnly: true,
          // ),
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

  /// Filter menu items based on user role and permissions
  static Future<List<MenuItem>> filterMenuItems({
    required bool isAdmin,
    required bool payrollEnabled,
    required List<String> userPermissions,
  }) async {
    final allItems = getAllMenuItems();
    final filteredItems = <MenuItem>[];

    for (final item in allItems) {
      final accessible = await item.isAccessible(
        isAdmin: isAdmin,
        payrollEnabled: payrollEnabled,
        userPermissions: userPermissions,
      );

      if (!accessible) continue;

      if (item.children != null) {
        // Filter children
        final filteredChildren = <MenuItem>[];
        for (final child in item.children!) {
          final childAccessible = await child.isAccessible(
            isAdmin: isAdmin,
            payrollEnabled: payrollEnabled,
            userPermissions: userPermissions,
          );
          if (childAccessible) {
            filteredChildren.add(child);
          }
        }

        // Only add parent if it has accessible children
        if (filteredChildren.isNotEmpty) {
          filteredItems.add(
            MenuItem(
              id: item.id,
              title: item.title,
              icon: item.icon,
              route: item.route,
              children: filteredChildren,
              isAdminOnly: item.isAdminOnly,
              requiresPayroll: item.requiresPayroll,
              requiredPermissions: item.requiredPermissions,
              isDivider: item.isDivider,
              isStatic: item.isStatic,
            ),
          );
        }
      } else {
        filteredItems.add(item);
      }
    }

    return filteredItems;
  }

  /// Get user permissions from role
  static Future<List<String>> getUserPermissions() async {
    final user = await Spdb.getUser();

    if (user.userType == UserType.admin) {
      // Admin has all permissions
      return getAllPermissions();
    }

    // Get employee role
    final employee = await EmployeeService.getEmployee(uid: user.uid);
    if (employee?.role == null) return [];

    final role = await RoleService.getRole(uid: employee!.role);

    // Extract permission names from role permissions
    return role.permissions.map((p) => p.page).toList();
  }

  /// Get all available permissions
  static List<String> getAllPermissions() {
    return [
      'Role',
      'Designation',
      'Department',
      'Sub Department',
      'Employee Status',
      'Employees',
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
      'Projects',
      'Tasks',
      'Tickets',
      'Downloads',
      'Developer Area',
    ];
  }
}
