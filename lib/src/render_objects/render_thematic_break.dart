import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../theme/markdown_theme.dart';
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

  static const _defaultHeight = 24.0;

  @override
  double computeIntrinsicHeight(double width) => _defaultHeight;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final hrTheme = theme.horizontalRuleTheme;

    final thickness = hrTheme?.thickness ?? 1.0;
    final indent = hrTheme?.indent ?? 0.0;
    final endIndent = hrTheme?.endIndent ?? 0.0;
    final color = hrTheme?.color ??
        theme.textStyle?.color?.withValues(alpha: 0.2) ??
        const Color(0xFFE5E7EB);
    final style = hrTheme?.style ?? HorizontalRuleStyle.solid;

    final lineY = offset.dy + (_defaultHeight - thickness) / 2;
    final lineWidth = size.width - indent - endIndent;

    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    switch (style) {
      case HorizontalRuleStyle.solid:
        canvas.drawRect(
          Rect.fromLTWH(offset.dx + indent, lineY, lineWidth, thickness),
          Paint()..color = color,
        );
      case HorizontalRuleStyle.dashed:
        _drawDashedLine(canvas, offset.dx + indent, lineY, lineWidth, paint);
      case HorizontalRuleStyle.dotted:
        _drawDottedLine(
          canvas,
          offset.dx + indent,
          lineY,
          lineWidth,
          paint,
          thickness,
        );
    }
  }

  void _drawDashedLine(
    ui.Canvas canvas,
    double x,
    double y,
    double width,
    Paint paint,
  ) {
    const dashWidth = 8.0;
    const dashSpace = 4.0;
    var currentX = x;

    while (currentX < x + width) {
      final dashEnd = (currentX + dashWidth).clamp(x, x + width);
      canvas.drawLine(
        Offset(currentX, y),
        Offset(dashEnd, y),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  void _drawDottedLine(
    ui.Canvas canvas,
    double x,
    double y,
    double width,
    Paint paint,
    double thickness,
  ) {
    final dotRadius = thickness;
    const dotSpace = 6.0;
    var currentX = x + dotRadius;

    while (currentX < x + width) {
      canvas.drawCircle(
        Offset(currentX, y),
        dotRadius,
        Paint()..color = paint.color,
      );
      currentX += dotRadius * 2 + dotSpace;
    }
  }
}
