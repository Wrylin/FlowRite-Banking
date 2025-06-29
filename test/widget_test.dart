// This is a basic Flutter widget test for the FlowRite Banking app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowrite_banking/main.dart';

void main() {
  testWidgets('App loads and shows welcome page', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait for any async operations to complete
    await tester.pumpAndSettle();

    // Verify that our app loads successfully
    expect(find.byType(MaterialApp), findsOneWidget);

    // You can add more specific tests here based on what's in your WelcomePage
    // For example, if WelcomePage has specific text or widgets:
    // expect(find.text('Welcome'), findsOneWidget);
    // expect(find.text('FlowRite'), findsOneWidget);
  });

  testWidgets('App has correct title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait for any async operations to complete
    await tester.pumpAndSettle();

    // Verify the app title is set correctly
    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.title, equals('FlowRite'));
  });
}
