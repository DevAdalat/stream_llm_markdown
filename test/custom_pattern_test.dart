import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_markdown_renderer/stream_markdown_renderer.dart';

class RenderTestBox extends RenderBox {
  @override
  void performLayout() {
    size = const Size(100, 50);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.drawRect(offset & size, Paint()..color = Colors.red);
  }
}

void main() {
  testWidgets('Custom pattern rendering', (tester) async {
    final controller = StreamController<String>();

    final pattern = MarkdownPattern(
      pattern: RegExp(r'^custom$'),
      createRenderObject: (block, theme) => RenderTestBox(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamMarkdownRenderer(
            markdownStream: controller.stream,
            customPatterns: [pattern],
          ),
        ),
      ),
    );

    controller.add('\uEB1Ecustom\uEB1E');
    await tester.pumpAndSettle();

    final rendererFinder = find.byType(StreamMarkdownRenderer);
    final renderer = tester.renderObject(rendererFinder);

    bool foundCustom = false;
    void visit(RenderObject object) {
      if (object is RenderTestBox) {
        foundCustom = true;
      }
      object.visitChildren(visit);
    }

    renderer.visitChildren(visit);

    expect(foundCustom, isTrue);

    await controller.close();
  });
}
