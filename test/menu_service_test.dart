import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadcapture/services/others/src/menu_service.dart';

void main() {
  group('MenuService and MenuItem Tests', () {
    test('getAllMenuItems returns a non-empty list of items', () {
      final items = MenuService.getAllMenuItems();
      expect(items, isNotEmpty);
      expect(items.any((item) => item.id == 'dashboard'), isTrue);
      expect(items.any((item) => item.id == 'feed'), isTrue);
    });

    test('MenuItem isAccessible grants access if user is admin', () async {
      final item = MenuItem(
        id: 'admin_only',
        title: 'Admin Only',
        icon: null ?? const IconData(0),
        isAdminOnly: true,
      );

      final accessible = await item.isAccessible(
        isAdmin: true,
        payrollEnabled: false,
        userPermissions: [],
      );

      expect(accessible, isTrue);
    });

    test('MenuItem isAccessible denies access if user is not admin and item is isAdminOnly', () async {
      final item = MenuItem(
        id: 'admin_only',
        title: 'Admin Only',
        icon: null ?? const IconData(0),
        isAdminOnly: true,
      );

      final accessible = await item.isAccessible(
        isAdmin: false,
        payrollEnabled: false,
        userPermissions: [],
      );

      expect(accessible, isFalse);
    });

    test('MenuItem isAccessible respects requiredPermissions', () async {
      final item = MenuItem(
        id: 'role',
        title: 'Role',
        icon: null ?? const IconData(0),
        requiredPermissions: ['Role'],
      );

      final accessibleWithPerm = await item.isAccessible(
        isAdmin: false,
        payrollEnabled: false,
        userPermissions: ['Role', 'Other'],
      );
      expect(accessibleWithPerm, isTrue);

      final accessibleWithoutPerm = await item.isAccessible(
        isAdmin: false,
        payrollEnabled: false,
        userPermissions: ['Other'],
      );
      expect(accessibleWithoutPerm, isFalse);
    });
  });
}
