import 'package:flutter/rendering.dart';

import 'base/render_markdown_block.dart';

/// Renders a thematic break (horizontal rule).
class RenderMarkdownThematicBreak extends RenderMarkdownBlock {
  /// Creates a new render thematic break.
  RenderMarkdownThematicBreak({
    required super.block,
    required super.theme,
    super.onLinkTapped,
    super.onCheckboxTapped,
  });

  static const _height = 24.0;
  static const _lineHeight = 1.0;

  @override
  double computeIntrinsicHeight(double width) => _height;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    
    final lineY = offset.dy + (_height - _lineHeight) / 2;
    final lineColor = theme.textStyle?.color?.withValues(alpha: 0.2) ?? 
        const Color(0xFFE5E7EB);

    canvas.drawRect(
      Rect.fromLTWH(offset.dx, lineY, size.width, _lineHeight),
      Paint()..color = lineColor,
    );
  }
}
