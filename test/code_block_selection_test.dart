import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_markdown_renderer/stream_markdown_renderer.dart';

void main() {
  testWidgets('Selection inside code block during streaming does not crash',
      (tester) async {
    final controller = StreamController<String>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            child: StreamMarkdownRenderer(
              markdownStream: controller.stream,
              selectionEnabled: true,
            ),
          ),
        ),
      ),
    );

    // Start streaming a code block
    controller.add('```dart\n');
    await tester.pump();

    controller.add('```dart\nvoid main() {\n');
    await tester.pump();

    // Find the renderer
    final rendererFinder = find.byType(StreamMarkdownRenderer);
    expect(rendererFinder, findsOneWidget);

    // Start a drag gesture on the renderer (center)
    final gesture = await tester.startGesture(tester.getCenter(rendererFinder));
    await tester.pump();

    // Stream more content while dragging
    controller.add('```dart\nvoid main() {\n  print("Hello");\n');
    await tester.pump(); // This triggers invalidateCache and layout

    // Move the gesture (update selection)
    // This triggers dispatchSelectionEvent -> paintSelection -> selectableTextPainter
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();

    controller.add('```dart\nvoid main() {\n  print("Hello");\n}\n```');
    await tester.pump();

    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();

    await gesture.up();
    await tester.pump();

    await controller.close();
  });
}
