// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('Stream Markdown Renderer smoke test', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app starts with "Start Stream" button.
    expect(find.text('Start Stream'), findsOneWidget);
    expect(find.text('Stream Markdown Demo'), findsOneWidget);

    // Tap the 'Start Stream' button and trigger a frame.
    await tester.tap(find.text('Start Stream'));
    await tester.pump();

    // Verify that streaming has started (button text changes).
    expect(find.text('Streaming...'), findsOneWidget);

    // Pump for enough time to let the stream complete (or at least process some chunks)
    // The simulation runs for a few seconds.
    await tester.pump(const Duration(seconds: 5));

    // Pump one more time to ensure everything is settled
    await tester.pumpAndSettle();
  });
}
