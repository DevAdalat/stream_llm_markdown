import 'package:flutter/rendering.dart';

import '../parsing/markdown_block.dart';
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

  final List<TextPainter> _painters = [];
  final _spanBuilder = const InlineSpanBuilder();

  BlockquoteTheme get _blockquoteTheme =>
      theme.blockquoteTheme ?? const BlockquoteTheme();

  @override
  void invalidateCache() {
    _disposePainters();
    super.invalidateCache();
  }

  void _disposePainters() {
    for (final painter in _painters) {
      painter.dispose();
    }
    _painters.clear();
  }

  @override
  void dispose() {
    _disposePainters();
    super.dispose();
  }

  bool get _hasChildren => block.children.isNotEmpty;

  void _buildPainters(double maxWidth) {
    if (_painters.isNotEmpty) return;

    final padding =
        _blockquoteTheme.padding ?? const EdgeInsets.fromLTRB(16, 12, 12, 12);
    final borderWidth = _blockquoteTheme.borderWidth ?? 4;
    final availableWidth = maxWidth - padding.horizontal - borderWidth;

    if (_hasChildren) {
      // Render each child block
      for (final childBlock in block.children) {
        final painter = _createPainterForBlock(childBlock, availableWidth);
        _painters.add(painter);
      }
    } else {
      // Render content directly
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

      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: availableWidth > 0 ? availableWidth : 0);

      _painters.add(painter);
    }
  }

  TextPainter _createPainterForBlock(
    MarkdownBlock childBlock,
    double availableWidth,
  ) {
    final baseStyle = _blockquoteTheme.textStyle ??
        TextStyle(
          fontSize: 16,
          color: theme.textStyle?.color ?? const Color(0xFF4B5563),
        );

    TextSpan span;

    switch (childBlock.type) {
      case MarkdownBlockType.paragraph:
        span = _spanBuilder.build(
          childBlock.content,
          baseStyle.copyWith(fontStyle: FontStyle.italic),
          theme,
          onLinkTapped: onLinkTapped,
        );

      case MarkdownBlockType.unorderedList:
      case MarkdownBlockType.orderedList:
        // Render list items with bullets/numbers
        final items = (childBlock.metadata['items'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final isOrdered = childBlock.type == MarkdownBlockType.orderedList;
        final start = (childBlock.metadata['start'] as int?) ?? 1;

        final children = <InlineSpan>[];
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          final content = item['content'] as String? ?? '';
          final prefix = isOrdered ? '${start + i}. ' : '• ';

          if (i > 0) {
            children.add(const TextSpan(text: '\n'));
          }

          children.add(
            TextSpan(
              text: prefix,
              style: baseStyle.copyWith(fontStyle: FontStyle.normal),
            ),
          );

          // Parse inline content
          final contentSpan = _spanBuilder.build(
            content,
            baseStyle.copyWith(fontStyle: FontStyle.normal),
            theme,
            onLinkTapped: onLinkTapped,
          );
          children.add(contentSpan);
        }

        span = TextSpan(children: children);

      case MarkdownBlockType.header:
        final level = (childBlock.metadata['level'] as int?) ?? 1;
        final headerStyle =
            theme.headerTheme?.getStyleForLevel(level) ?? baseStyle;
        span = _spanBuilder.build(
          childBlock.content,
          headerStyle,
          theme,
          onLinkTapped: onLinkTapped,
        );

      case MarkdownBlockType.codeBlock:
        final codeStyle = theme.codeTheme?.textStyle ??
            baseStyle.copyWith(fontFamily: 'monospace');
        span = TextSpan(text: childBlock.content, style: codeStyle);

      default:
        span = _spanBuilder.build(
          childBlock.content,
          baseStyle,
          theme,
          onLinkTapped: onLinkTapped,
        );
    }

    return TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: availableWidth > 0 ? availableWidth : 0);
  }

  @override
  double computeIntrinsicHeight(double width) {
    _buildPainters(width);

    final padding =
        _blockquoteTheme.padding ?? const EdgeInsets.fromLTRB(16, 12, 12, 12);
    final blockSpacing = theme.blockSpacing ?? 16.0;

    var height = padding.top;
    for (var i = 0; i < _painters.length; i++) {
      height += _painters[i].height;
      if (i < _painters.length - 1) {
        height += blockSpacing;
      }
    }
    height += padding.bottom;

    return height;
  }

  @override
  void performLayout() {
    _disposePainters();
    final height = computeIntrinsicHeight(constraints.maxWidth);
    size = Size(constraints.maxWidth, height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final padding =
        _blockquoteTheme.padding ?? const EdgeInsets.fromLTRB(16, 12, 12, 12);
    final borderWidth = _blockquoteTheme.borderWidth ?? 4;
    final borderColor = _blockquoteTheme.borderColor ?? const Color(0xFFD1D5DB);
    final backgroundColor = _blockquoteTheme.backgroundColor;
    final blockSpacing = theme.blockSpacing ?? 16.0;

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

    // Draw content
    _buildPainters(constraints.maxWidth);

    var currentY = offset.dy + padding.top;
    for (var i = 0; i < _painters.length; i++) {
      final painter = _painters[i];
      final textOffset =
          Offset(offset.dx + borderWidth + padding.left, currentY);
      painter.paint(canvas, textOffset);
      currentY += painter.height;
      if (i < _painters.length - 1) {
        currentY += blockSpacing;
      }
    }
  }
}
