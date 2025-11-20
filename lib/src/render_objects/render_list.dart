import 'package:flutter/rendering.dart';

import '../parsing/markdown_block.dart';
import '../text/inline_span_builder.dart';
import '../theme/markdown_theme.dart';
import 'base/render_markdown_block.dart';

/// Renders an ordered or unordered list.
class RenderMarkdownList extends RenderMarkdownBlock {
  /// Creates a new render list.
  RenderMarkdownList({
    required super.block,
    required super.theme,
    super.onLinkTapped,
    super.onCheckboxTapped,
  });

  final List<TextPainter> _itemPainters = [];
  final _spanBuilder = const InlineSpanBuilder();
  final List<Rect> _checkboxRects = [];
  final List<_NestedListInfo> _nestedLists = [];

  ListTheme get _listTheme => theme.listTheme ?? const ListTheme();

  bool get _isOrdered => block.type == MarkdownBlockType.orderedList;

  List<Map<String, dynamic>> get _items =>
      (block.metadata['items'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>() ??
      [];

  int get _start => (block.metadata['start'] as int?) ?? 1;

  @override
  void invalidateCache() {
    for (final painter in _itemPainters) {
      painter.dispose();
    }
    _itemPainters.clear();
    _checkboxRects.clear();
    _disposeNestedLists();
    super.invalidateCache();
  }

  void _disposeNestedLists() {
    for (final nested in _nestedLists) {
      for (final painter in nested.painters) {
        painter.dispose();
      }
    }
    _nestedLists.clear();
  }

  void _buildItemPainters(double maxWidth) {
    if (_itemPainters.isNotEmpty) return;

    final indentWidth = _listTheme.indentWidth ?? 24;
    final availableWidth = maxWidth - indentWidth;
    final baseStyle = theme.textStyle ?? const TextStyle(fontSize: 16);

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final content = item['content'] as String? ?? '';
      final span = _spanBuilder.build(
        content,
        baseStyle,
        theme,
        onLinkTapped: onLinkTapped,
      );

      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: availableWidth);

      _itemPainters.add(painter);

      // Build nested list painters if children exist
      final children = item['children'] as List<dynamic>?;
      if (children != null && children.isNotEmpty) {
        final nestedItems = children.cast<Map<String, dynamic>>();
        final nestedPainters = <TextPainter>[];
        final nestedAvailableWidth = availableWidth - indentWidth;

        for (final nestedItem in nestedItems) {
          final nestedContent = nestedItem['content'] as String? ?? '';
          final nestedSpan = _spanBuilder.build(
            nestedContent,
            baseStyle,
            theme,
            onLinkTapped: onLinkTapped,
          );

          final nestedPainter = TextPainter(
            text: nestedSpan,
            textDirection: TextDirection.ltr,
          )..layout(
              maxWidth: nestedAvailableWidth > 0 ? nestedAvailableWidth : 0,
            );

          nestedPainters.add(nestedPainter);
        }

        // Determine if nested list is ordered by checking if any item looks ordered
        const isNestedOrdered =
            false; // Nested lists inherit unordered by default

        _nestedLists.add(
          _NestedListInfo(
            itemIndex: i,
            items: nestedItems,
            isOrdered: isNestedOrdered,
            painters: nestedPainters,
          ),
        );
      }
    }
  }

  @override
  double computeIntrinsicHeight(double width) {
    _buildItemPainters(width);

    final itemSpacing = _listTheme.itemSpacing ?? 4;
    var height = 0.0;

    for (var i = 0; i < _itemPainters.length; i++) {
      height += _itemPainters[i].height;

      // Add height for nested list if present
      final nestedList =
          _nestedLists.where((n) => n.itemIndex == i).firstOrNull;
      if (nestedList != null) {
        for (var j = 0; j < nestedList.painters.length; j++) {
          height += itemSpacing;
          height += nestedList.painters[j].height;
        }
      }

      if (i < _itemPainters.length - 1) {
        height += itemSpacing;
      }
    }

    return height;
  }

  @override
  void performLayout() {
    for (final painter in _itemPainters) {
      painter.dispose();
    }
    _itemPainters.clear();
    _checkboxRects.clear();
    _disposeNestedLists();

    final height = computeIntrinsicHeight(constraints.maxWidth);
    size = Size(constraints.maxWidth, height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final indentWidth = _listTheme.indentWidth ?? 24;
    final itemSpacing = _listTheme.itemSpacing ?? 4;
    final bulletColor = _listTheme.bulletColor ?? const Color(0xFF6B7280);

    _buildItemPainters(constraints.maxWidth);
    _checkboxRects.clear();

    var currentY = offset.dy;

    for (var i = 0; i < _itemPainters.length; i++) {
      final item = _items[i];
      final painter = _itemPainters[i];
      final isChecked = item['checked'] as bool?;

      // Calculate vertical center for bullet/number
      final bulletY = currentY + painter.height / 2;

      if (isChecked != null) {
        // Task list item - draw checkbox
        const checkboxSize = 16.0;
        final checkboxX = offset.dx + (indentWidth - checkboxSize) / 2;
        final checkboxY = bulletY - checkboxSize / 2;
        final checkboxRect =
            Rect.fromLTWH(checkboxX, checkboxY, checkboxSize, checkboxSize);
        _checkboxRects.add(checkboxRect);

        final checkboxColor = isChecked
            ? (_listTheme.checkboxCheckedColor ?? const Color(0xFF2563EB))
            : (_listTheme.checkboxUncheckedColor ?? const Color(0xFF6B7280));

        // Draw checkbox
        canvas.drawRRect(
          RRect.fromRectAndRadius(checkboxRect, const Radius.circular(3)),
          Paint()
            ..color = checkboxColor
            ..style = isChecked ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );

        // Draw checkmark if checked
        if (isChecked) {
          final path = Path()
            ..moveTo(checkboxX + 3, bulletY)
            ..lineTo(checkboxX + 6, bulletY + 3)
            ..lineTo(checkboxX + 12, bulletY - 4);

          canvas.drawPath(
            path,
            Paint()
              ..color = const Color(0xFFFFFFFF)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round,
          );
        }
      } else if (_isOrdered) {
        // Ordered list - draw number
        final number = '${_start + i}.';
        final numberPainter = TextPainter(
          text: TextSpan(
            text: number,
            style: TextStyle(
              fontSize: 16,
              color: bulletColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        numberPainter.paint(
          canvas,
          Offset(
            offset.dx + indentWidth - numberPainter.width - 8,
            bulletY - numberPainter.height / 2,
          ),
        );
        numberPainter.dispose();
      } else {
        // Unordered list - draw bullet
        canvas.drawCircle(
          Offset(offset.dx + indentWidth / 2, bulletY),
          3,
          Paint()..color = bulletColor,
        );
      }

      // Draw item text
      painter.paint(canvas, Offset(offset.dx + indentWidth, currentY));

      currentY += painter.height;

      // Draw nested list if present
      final nestedList =
          _nestedLists.where((n) => n.itemIndex == i).firstOrNull;
      if (nestedList != null) {
        final nestedIndentWidth = indentWidth * 2;

        for (var j = 0; j < nestedList.painters.length; j++) {
          currentY += itemSpacing;

          final nestedItem = nestedList.items[j];
          final nestedPainter = nestedList.painters[j];
          final nestedBulletY = currentY + nestedPainter.height / 2;
          final nestedIsChecked = nestedItem['checked'] as bool?;

          if (nestedIsChecked != null) {
            // Nested task list item - draw checkbox
            const checkboxSize = 16.0;
            final checkboxX = offset.dx +
                nestedIndentWidth -
                indentWidth +
                (indentWidth - checkboxSize) / 2;
            final checkboxY = nestedBulletY - checkboxSize / 2;
            final checkboxRect =
                Rect.fromLTWH(checkboxX, checkboxY, checkboxSize, checkboxSize);

            final checkboxColor = nestedIsChecked
                ? (_listTheme.checkboxCheckedColor ?? const Color(0xFF2563EB))
                : (_listTheme.checkboxUncheckedColor ??
                    const Color(0xFF6B7280));

            canvas.drawRRect(
              RRect.fromRectAndRadius(checkboxRect, const Radius.circular(3)),
              Paint()
                ..color = checkboxColor
                ..style =
                    nestedIsChecked ? PaintingStyle.fill : PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );

            if (nestedIsChecked) {
              final path = Path()
                ..moveTo(checkboxX + 3, nestedBulletY)
                ..lineTo(checkboxX + 6, nestedBulletY + 3)
                ..lineTo(checkboxX + 12, nestedBulletY - 4);

              canvas.drawPath(
                path,
                Paint()
                  ..color = const Color(0xFFFFFFFF)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round,
              );
            }
          } else if (nestedList.isOrdered) {
            // Nested ordered list - draw number
            final number = '${j + 1}.';
            final numberPainter = TextPainter(
              text: TextSpan(
                text: number,
                style: TextStyle(
                  fontSize: 16,
                  color: bulletColor,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();

            numberPainter.paint(
              canvas,
              Offset(
                offset.dx + nestedIndentWidth - numberPainter.width - 8,
                nestedBulletY - numberPainter.height / 2,
              ),
            );
            numberPainter.dispose();
          } else {
            // Nested unordered list - draw smaller bullet
            canvas.drawCircle(
              Offset(
                offset.dx + nestedIndentWidth - indentWidth / 2,
                nestedBulletY,
              ),
              2.5,
              Paint()..color = bulletColor,
            );
          }

          // Draw nested item text
          nestedPainter.paint(
            canvas,
            Offset(offset.dx + nestedIndentWidth, currentY),
          );
          currentY += nestedPainter.height;
        }
      }

      currentY += itemSpacing;
    }
  }

  @override
  int getCheckboxAtPosition(Offset position) {
    for (var i = 0; i < _checkboxRects.length; i++) {
      if (_checkboxRects[i].contains(position)) {
        return i;
      }
    }
    return -1;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      final checkboxIndex = getCheckboxAtPosition(event.localPosition);
      if (checkboxIndex >= 0 && onCheckboxTapped != null) {
        final item = _items[checkboxIndex];
        final isChecked = item['checked'] as bool? ?? false;
        onCheckboxTapped!(checkboxIndex, !isChecked);
      }
    }
  }

  @override
  Offset? getCursorOffset() {
    if (_itemPainters.isEmpty) return null;
    
    // Get the last item painter
    final lastPainter = _itemPainters.last;
    
    // Get the position at the end of the last item's text
    final endPosition = TextPosition(offset: lastPainter.plainText.length);
    final endOffset = lastPainter.getOffsetForCaret(endPosition, Rect.zero);
    
    // Calculate Y position - sum of all previous items
    var yOffset = 0.0;
    final itemSpacing = _listTheme.itemSpacing ?? 8;
    for (var i = 0; i < _itemPainters.length - 1; i++) {
      yOffset += _itemPainters[i].height + itemSpacing;
    }
    
    // Add left indent and bullet/number width
    final leftIndent = _listTheme.indentWidth ?? 16.0;
    final bulletWidth = _listTheme.bulletSize ?? 6.0;
    final xOffset = leftIndent + bulletWidth + 8 + endOffset.dx;
    
    return Offset(xOffset, yOffset + endOffset.dy);
  }
}

/// Information about a nested list for rendering.
class _NestedListInfo {
  _NestedListInfo({
    required this.itemIndex,
    required this.items,
    required this.isOrdered,
    required this.painters,
  });

  final int itemIndex;
  final List<Map<String, dynamic>> items;
  final bool isOrdered;
  final List<TextPainter> painters;
}
