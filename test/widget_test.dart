// Basic Flutter widget test for Streame app
//
// This test verifies the app can initialize and render without errors.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streame/main.dart';

void main() {
  testWidgets('App smoke test - app initializes', (WidgetTester tester) async {
    // Build our app with ProviderScope wrapper and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: StreameApp(),
      ),
    );

    // Verify the app rendered (splash screen should be visible)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
