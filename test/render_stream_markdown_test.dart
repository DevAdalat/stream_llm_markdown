import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_markdown_renderer/stream_markdown_renderer.dart';

void main() {
  testWidgets(
      'StreamMarkdownRenderer layouts children and sets parent data correctly',
      (tester) async {
    final controller = StreamController<String>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamMarkdownRenderer(
            markdownStream: controller.stream,
            selectionEnabled: true,
          ),
        ),
      ),
    );

    // Stream some content
    controller.add('# Header\n\nParagraph text.');
    await tester.pumpAndSettle();

    // Find the RenderStreamMarkdown
    final renderObject =
        tester.renderObject(find.byType(StreamMarkdownRenderer));
    expect(renderObject, isA<RenderBox>());

    // We need to access children to check parent data.
    // Since RenderStreamMarkdown doesn't expose children publicly, we can use visitChildren.
    final children = <RenderBox>[];
    (renderObject as RenderBox).visitChildren((child) {
      children.add(child as RenderBox);
    });

    expect(children.length, greaterThan(0));

    // Check ParentData
    double currentY = 0;
    for (final child in children) {
      expect(child.parentData, isA<BoxParentData>());
      final parentData = child.parentData as BoxParentData;

      // Verify offset is set (and increasing)
      expect(parentData.offset.dy, equals(currentY));

      currentY += child.size.height + 16.0; // 16 is default block spacing
    }

    await controller.close();
  });
}
