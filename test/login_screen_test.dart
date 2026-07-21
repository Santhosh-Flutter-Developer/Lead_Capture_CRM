import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadcapture/views/screens/auth/src/login.dart';

void main() {
  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: Scaffold(
        body: Login(),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI Rendering
  // ─────────────────────────────────────────────
  testWidgets('Login screen has Email and Password fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Email ID'), findsOneWidget);
    expect(find.text('Password'), findsWidgets);
    expect(find.text('Login'), findsWidgets);
  });

  testWidgets("Login screen shows 'Don't have account?' text",
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text("Don't have account?"), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });

  // ─────────────────────────────────────────────
  // Empty Submit Validation
  // ─────────────────────────────────────────────
  testWidgets('Login form shows validation errors on empty submit',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final loginButton = find.widgetWithText(ElevatedButton, 'Login').first;
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    // Email and Password errors should appear
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  // ─────────────────────────────────────────────
  // Email Field Validation
  // ─────────────────────────────────────────────
  testWidgets('Login form shows invalid email error for bad format',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Enter a badly-formatted email
    await tester.enterText(find.byType(TextFormField).first, 'notanemail');
    final loginButton = find.widgetWithText(ElevatedButton, 'Login').first;
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Invalid email address'), findsOneWidget);
  });

  testWidgets('Login form shows error for email with spaces',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).first, 'user @example.com');
    final loginButton = find.widgetWithText(ElevatedButton, 'Login').first;
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Email should not contain spaces'), findsOneWidget);
  });

  testWidgets('Login form accepts a valid email with no email error',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Enter a valid email — email error should NOT appear
    await tester.enterText(
        find.byType(TextFormField).first, 'user@example.com');
    final loginButton = find.widgetWithText(ElevatedButton, 'Login').first;
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Email is required'), findsNothing);
    expect(find.text('Invalid email address'), findsNothing);
    expect(find.text('Email should not contain spaces'), findsNothing);
    // Password error still expected since password is empty
    expect(find.text('Password is required'), findsOneWidget);
  });

  // ─────────────────────────────────────────────
  // Password Field Validation
  // ─────────────────────────────────────────────
  testWidgets('Login form shows password required error on empty password',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Enter valid email, leave password blank
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'user@example.com');
    // Leave password empty
    final loginButton = find.widgetWithText(ElevatedButton, 'Login').first;
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('Login form clears errors when both fields are valid',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'user@example.com');
    await tester.enterText(fields.at(1), 'SomePassword123');

    final loginButton = find.widgetWithText(ElevatedButton, 'Login').first;
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    // No field-level validation errors
    expect(find.text('Email is required'), findsNothing);
    expect(find.text('Invalid email address'), findsNothing);
    expect(find.text('Password is required'), findsNothing);
  });
}
