import 'package:flutter/rendering.dart';

import '../text/inline_span_builder.dart';
import '../theme/markdown_theme.dart';
import 'base/render_markdown_block.dart';

/// Renders a blockquote.
class RenderMarkdownBlockquote extends RenderMarkdownBlock {
  /// Creates a new render blockquote.
  RenderMarkdownBlockquote({
    required super.block,
    required super.theme,
    super.onLinkTapped,
    super.onCheckboxTapped,
  });

  TextPainter? _textPainter;
  final _spanBuilder = const InlineSpanBuilder();

  BlockquoteTheme get _blockquoteTheme =>
      theme.blockquoteTheme ?? const BlockquoteTheme();

  @override
  void invalidateCache() {
    _textPainter?.dispose();
    _textPainter = null;
    super.invalidateCache();
  }

  @override
  void dispose() {
    _textPainter?.dispose();
    _textPainter = null;
    super.dispose();
  }

  TextPainter _getTextPainter(double maxWidth) {
    if (_textPainter != null) return _textPainter!;

    final padding = _blockquoteTheme.padding ??
        const EdgeInsets.fromLTRB(16, 12, 12, 12);
    final borderWidth = _blockquoteTheme.borderWidth ?? 4;
    final availableWidth = maxWidth - padding.horizontal - borderWidth;

    final baseStyle = _blockquoteTheme.textStyle ??
        TextStyle(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: theme.textStyle?.color ?? const Color(0xFF4B5563),
        );

    final span = _spanBuilder.build(
      block.content,
      baseStyle,
      theme,
      onLinkTapped: onLinkTapped,
    );

    _textPainter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: availableWidth > 0 ? availableWidth : 0);

    return _textPainter!;
  }

  @override
  double computeIntrinsicHeight(double width) {
    final painter = _getTextPainter(width);
    final padding = _blockquoteTheme.padding ??
        const EdgeInsets.fromLTRB(16, 12, 12, 12);
    return painter.height + padding.vertical;
  }

  @override
  void performLayout() {
    _textPainter?.dispose();
    _textPainter = null;

    final height = computeIntrinsicHeight(constraints.maxWidth);
    size = Size(constraints.maxWidth, height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final padding = _blockquoteTheme.padding ??
        const EdgeInsets.fromLTRB(16, 12, 12, 12);
    final borderWidth = _blockquoteTheme.borderWidth ?? 4;
    final borderColor =
        _blockquoteTheme.borderColor ?? const Color(0xFFD1D5DB);
    final backgroundColor = _blockquoteTheme.backgroundColor;

    // Draw background if specified
    if (backgroundColor != null) {
      final rect = offset & size;
      canvas.drawRect(rect, Paint()..color = backgroundColor);
    }

    // Draw left border
    final borderRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      borderWidth,
      size.height,
    );
    canvas.drawRect(borderRect, Paint()..color = borderColor);

    // Draw text
    final painter = _getTextPainter(constraints.maxWidth);
    final textOffset =
        offset + Offset(borderWidth + padding.left, padding.top);
    painter.paint(canvas, textOffset);
  }
}
