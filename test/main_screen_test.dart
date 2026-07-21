import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leadcapture/views/screens/main/src/main_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'userType': 'admin',
      'uid': 'test_admin_id',
    });
  });

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: MainScreen(isAdmin: true),
    );
  }

  testWidgets('MainScreen initializes and shows splash or error', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    
    // It should initially show a Splash or loading state, or immediately an error if Spdb fails.
    // We just want to ensure it doesn't crash on render.
    expect(find.byType(MainScreen), findsOneWidget);
  });
}
