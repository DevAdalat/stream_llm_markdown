import 'package:flutter/rendering.dart';

import '../parsing/markdown_block.dart';
import '../text/inline_span_builder.dart';
import '../theme/markdown_theme.dart';
import 'base/render_markdown_block.dart';

/// Renders a table.
class RenderMarkdownTable extends RenderMarkdownBlock {
  /// Creates a new render table.
  RenderMarkdownTable({
    required super.block,
    required super.theme,
    super.onLinkTapped,
    super.onCheckboxTapped,
  });

  final List<List<TextPainter>> _cellPainters = [];
  final _spanBuilder = const InlineSpanBuilder();
  List<double> _columnWidths = [];
  List<double> _rowHeights = [];

  TableTheme get _tableTheme => theme.tableTheme ?? const TableTheme();
  
  List<List<String>> get _rows {
    final rows = block.metadata['rows'] as List<dynamic>?;
    if (rows == null) return [];
    return rows.map((r) => (r as List<dynamic>).cast<String>()).toList();
  }
  
  List<TableAlignment> get _alignments {
    final alignments = block.metadata['alignments'] as List<dynamic>?;
    if (alignments == null) return [];
    return alignments.map((a) {
      switch (a as String) {
        case 'center':
          return TableAlignment.center;
        case 'right':
          return TableAlignment.right;
        default:
          return TableAlignment.left;
      }
    }).toList();
  }

  @override
  void invalidateCache() {
    for (final row in _cellPainters) {
      for (final painter in row) {
        painter.dispose();
      }
    }
    _cellPainters.clear();
    _columnWidths = [];
    _rowHeights = [];
    super.invalidateCache();
  }

  void _buildCellPainters(double maxWidth) {
    if (_cellPainters.isNotEmpty) return;

    final rows = _rows;
    if (rows.isEmpty) return;

    final cellPadding = _tableTheme.cellPadding ?? 
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    
    // First, create all painters to measure
    final numColumns = rows.isNotEmpty ? rows[0].length : 0;
    _columnWidths = List.filled(numColumns, 0);
    _rowHeights = [];

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final rowPainters = <TextPainter>[];
      var rowHeight = 0.0;

      for (var colIndex = 0; colIndex < row.length; colIndex++) {
        final isHeader = rowIndex == 0;
        final cellStyle = isHeader
            ? (_tableTheme.headerTextStyle ?? const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ))
            : (_tableTheme.cellTextStyle ?? const TextStyle(fontSize: 14));

        final span = _spanBuilder.build(
          row[colIndex],
          cellStyle,
          theme,
          onLinkTapped: onLinkTapped,
        );

        final painter = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
          textAlign: _getTextAlign(colIndex),
        )..layout();

        rowPainters.add(painter);

        // Update column width
        final cellWidth = painter.width + cellPadding.horizontal;
        if (cellWidth > _columnWidths[colIndex]) {
          _columnWidths[colIndex] = cellWidth;
        }

        // Update row height
        final cellHeight = painter.height + cellPadding.vertical;
        if (cellHeight > rowHeight) {
          rowHeight = cellHeight;
        }
      }

      _cellPainters.add(rowPainters);
      _rowHeights.add(rowHeight);
    }

    // Adjust column widths to fit available space
    final totalWidth = _columnWidths.fold<double>(0, (sum, w) => sum + w);
    if (totalWidth > maxWidth && numColumns > 0) {
      final scale = maxWidth / totalWidth;
      _columnWidths = _columnWidths.map((w) => w * scale).toList();
    }

    // Re-layout painters with final widths
    for (var rowIndex = 0; rowIndex < _cellPainters.length; rowIndex++) {
      for (var colIndex = 0; colIndex < _cellPainters[rowIndex].length; colIndex++) {
        final painter = _cellPainters[rowIndex][colIndex];
        final cellPaddingHorizontal = cellPadding.horizontal;
        painter.layout(maxWidth: _columnWidths[colIndex] - cellPaddingHorizontal);
      }
    }
  }

  TextAlign _getTextAlign(int columnIndex) {
    if (columnIndex >= _alignments.length) return TextAlign.left;
    switch (_alignments[columnIndex]) {
      case TableAlignment.center:
        return TextAlign.center;
      case TableAlignment.right:
        return TextAlign.right;
      case TableAlignment.left:
        return TextAlign.left;
    }
  }

  @override
  double computeIntrinsicHeight(double width) {
    _buildCellPainters(width);
    
    final borderWidth = _tableTheme.borderWidth ?? 1;
    return _rowHeights.fold<double>(0, (sum, h) => sum + h) + 
           borderWidth * (_rowHeights.length + 1);
  }

  @override
  void performLayout() {
    for (final row in _cellPainters) {
      for (final painter in row) {
        painter.dispose();
      }
    }
    _cellPainters.clear();
    _columnWidths = [];
    _rowHeights = [];
    
    final height = computeIntrinsicHeight(constraints.maxWidth);
    size = Size(constraints.maxWidth, height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    _buildCellPainters(constraints.maxWidth);

    final borderWidth = _tableTheme.borderWidth ?? 1;
    final borderColor = _tableTheme.borderColor ?? const Color(0xFFE5E7EB);
    final headerBgColor = _tableTheme.headerBackgroundColor ?? const Color(0xFFF9FAFB);
    final cellBgColor = _tableTheme.cellBackgroundColor;
    final cellPadding = _tableTheme.cellPadding ?? 
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    var currentY = offset.dy;

    for (var rowIndex = 0; rowIndex < _cellPainters.length; rowIndex++) {
      final isHeader = rowIndex == 0;
      final rowHeight = _rowHeights[rowIndex];
      var currentX = offset.dx;

      // Draw row background
      final rowRect = Rect.fromLTWH(
        offset.dx,
        currentY,
        _columnWidths.fold<double>(0, (sum, w) => sum + w),
        rowHeight,
      );

      if (isHeader) {
        canvas.drawRect(rowRect, Paint()..color = headerBgColor);
      } else if (cellBgColor != null) {
        canvas.drawRect(rowRect, Paint()..color = cellBgColor);
      }

      // Draw cells
      for (var colIndex = 0; colIndex < _cellPainters[rowIndex].length; colIndex++) {
        final painter = _cellPainters[rowIndex][colIndex];
        final cellWidth = _columnWidths[colIndex];

        // Draw cell border
        final cellRect = Rect.fromLTWH(currentX, currentY, cellWidth, rowHeight);
        canvas.drawRect(
          cellRect,
          Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth,
        );

        // Calculate text position based on alignment
        double textX;
        switch (_getTextAlign(colIndex)) {
          case TextAlign.center:
            textX = currentX + (cellWidth - painter.width) / 2;
            break;
          case TextAlign.right:
            textX = currentX + cellWidth - painter.width - cellPadding.right;
            break;
          default:
            textX = currentX + cellPadding.left;
        }

        final textY = currentY + (rowHeight - painter.height) / 2;
        painter.paint(canvas, Offset(textX, textY));

        currentX += cellWidth;
      }

      currentY += rowHeight;
    }
  }
}
