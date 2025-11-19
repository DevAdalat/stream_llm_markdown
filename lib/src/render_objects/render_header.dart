import 'package:flutter/rendering.dart';

import '../text/inline_span_builder.dart';
import '../theme/markdown_theme.dart';
import 'base/render_markdown_block.dart';

/// Renders a header block (H1-H6).
class RenderMarkdownHeader extends RenderMarkdownBlock {
  /// Creates a new render header.
  RenderMarkdownHeader({
    required super.block,
    required super.theme,
    super.onLinkTapped,
    super.onCheckboxTapped,
  });

  TextPainter? _textPainter;
  final _spanBuilder = const InlineSpanBuilder();

  int get _level => (block.metadata['level'] as int?) ?? 1;

  @override
  void invalidateCache() {
    _textPainter?.dispose();
    _textPainter = null;
    super.invalidateCache();
  }

  TextPainter _getTextPainter(double maxWidth) {
    if (_textPainter != null) return _textPainter!;

    final headerTheme = theme.headerTheme ?? const HeaderTheme();
    final baseStyle = headerTheme.getStyleForLevel(_level);
    
    final span = _spanBuilder.build(
      block.content,
      baseStyle,
      theme,
      onLinkTapped: onLinkTapped,
    );

    _textPainter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    return _textPainter!;
  }

  @override
  double computeIntrinsicHeight(double width) {
    final painter = _getTextPainter(width);
    return painter.height;
  }

  @override
  void performLayout() {
    _textPainter?.dispose();
    _textPainter = null;
    
    final painter = _getTextPainter(constraints.maxWidth);
    size = Size(constraints.maxWidth, painter.height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final painter = _getTextPainter(constraints.maxWidth);
    painter.paint(context.canvas, offset);
  }
}
