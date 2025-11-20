import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// A mixin that provides text selection capabilities for RenderBox objects
/// that render text using TextPainter.
mixin SelectableTextMixin on RenderBox {
  /// The text painter used for rendering.
  TextPainter? get selectableTextPainter;

  /// The offset at which text is painted.
  Offset get textPaintOffset => Offset.zero;

  /// The selection registrar from the parent SelectionArea.
  SelectionRegistrar? _registrar;
  SelectionRegistrar? get registrar => _registrar;
  set registrar(SelectionRegistrar? value) {
    if (_registrar == value) return;
    if (_selectable != null) {
      _registrar?.remove(_selectable!);
    }
    _registrar = value;
    if (value != null && _selectable != null) {
      value.add(_selectable!);
    }
  }

  _SelectableFragment? _selectable;

  /// Whether selection is enabled for this render object.
  bool _selectionEnabled = true;
  bool get selectionEnabled => _selectionEnabled;
  set selectionEnabled(bool value) {
    if (_selectionEnabled == value) return;
    _selectionEnabled = value;
    if (!value && _selectable != null) {
      _registrar?.remove(_selectable!);
      _selectable = null;
    } else if (value && _registrar != null) {
      _initSelectable();
    }
  }

  /// Initializes the selectable fragment after layout.
  void initSelectableIfNeeded() {
    if (!_selectionEnabled || _registrar == null) return;

    if (_selectable == null) {
      _initSelectable();
    } else {
      _selectable!._didChangePainter();
    }
  }

  void _initSelectable() {
    final painter = selectableTextPainter;
    if (painter == null) return;

    _selectable = _SelectableFragment(
      paragraph: this,
    );
    _registrar!.add(_selectable!);
  }

  /// Disposes of selection resources.
  void disposeSelectable() {
    if (_selectable != null) {
      _registrar?.remove(_selectable!);
      _selectable = null;
    }
  }

  /// Paints the selection highlight.
  void paintSelection(PaintingContext context, Offset offset) {
    final selection = _selectable?._textSelectionStart;
    final selectionEnd = _selectable?._textSelectionEnd;

    if (selection == null || selectionEnd == null) return;

    final painter = selectableTextPainter;
    if (painter == null) return;

    const selectionColor = Color(0x663399FF);
    final boxes = painter.getBoxesForSelection(
      TextSelection(
        baseOffset: selection.offset,
        extentOffset: selectionEnd.offset,
      ),
    );

    for (final box in boxes) {
      context.canvas.drawRect(
        box.toRect().shift(offset + textPaintOffset),
        Paint()..color = selectionColor,
      );
    }
  }

  /// Gets the plain text content for this render object.
  String get selectableText {
    final painter = selectableTextPainter;
    if (painter == null) return '';
    return painter.plainText;
  }
}

/// A selectable fragment that represents the text content of a render object.
class _SelectableFragment implements Selectable {
  _SelectableFragment({
    required this.paragraph,
  });

  final SelectableTextMixin paragraph;

  TextPosition? _textSelectionStart;
  TextPosition? _textSelectionEnd;

  final List<VoidCallback> _listeners = [];
  SelectionGeometry _value = const SelectionGeometry(
    status: SelectionStatus.none,
    hasContent: false,
  );

  void _didChangePainter() {
    _updateValue();
    _notifyListeners();
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void _updateValue() {
    final painter = paragraph.selectableTextPainter;
    if (painter == null) {
      _value = const SelectionGeometry(
        status: SelectionStatus.none,
        hasContent: false,
      );
      return;
    }

    if (_textSelectionStart == null || _textSelectionEnd == null) {
      _value = SelectionGeometry(
        status: SelectionStatus.none,
        hasContent: painter.plainText.isNotEmpty,
      );
      return;
    }

    final startOffset = _getOffsetForPosition(_textSelectionStart!);
    final endOffset = _getOffsetForPosition(_textSelectionEnd!);

    final isCollapsed =
        _textSelectionStart!.offset == _textSelectionEnd!.offset;

    _value = SelectionGeometry(
      status:
          isCollapsed ? SelectionStatus.collapsed : SelectionStatus.uncollapsed,
      hasContent: painter.plainText.isNotEmpty,
      startSelectionPoint: SelectionPoint(
        localPosition: startOffset,
        lineHeight: painter.preferredLineHeight,
        handleType: TextSelectionHandleType.left,
      ),
      endSelectionPoint: SelectionPoint(
        localPosition: endOffset,
        lineHeight: painter.preferredLineHeight,
        handleType: TextSelectionHandleType.right,
      ),
    );
  }

  @override
  SelectionGeometry get value => _value;

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  Offset _getOffsetForPosition(TextPosition position) {
    final painter = paragraph.selectableTextPainter;
    if (painter == null) return Offset.zero;
    // Return local position (relative to this render object)
    return painter.getOffsetForCaret(position, Rect.zero) +
        paragraph.textPaintOffset;
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    final painter = paragraph.selectableTextPainter;
    if (painter == null) return SelectionResult.none;

    late final SelectionResult result;

    switch (event.type) {
      case SelectionEventType.startEdgeUpdate:
      case SelectionEventType.endEdgeUpdate:
        final edgeEvent = event as SelectionEdgeUpdateEvent;
        result = _handleEdgeUpdate(edgeEvent);
      case SelectionEventType.clear:
        result = _handleClear();
      case SelectionEventType.selectAll:
        result = _handleSelectAll();
      case SelectionEventType.selectWord:
        final wordEvent = event as SelectWordSelectionEvent;
        result = _handleSelectWord(wordEvent.globalPosition);
      case SelectionEventType.selectParagraph:
        result = _handleSelectParagraph();
      case SelectionEventType.granularlyExtendSelection:
        final extendEvent = event as GranularlyExtendSelectionEvent;
        result = _handleGranularlyExtendSelection(
          extendEvent.forward,
          extendEvent.isEnd,
          extendEvent.granularity,
        );
      case SelectionEventType.directionallyExtendSelection:
        final extendEvent = event as DirectionallyExtendSelectionEvent;
        result = _handleDirectionallyExtendSelection(
          extendEvent.dx,
          extendEvent.isEnd,
          extendEvent.direction,
        );
    }

    if (result != SelectionResult.none) {
      paragraph.markNeedsPaint();
      _updateValue();
      _notifyListeners();
    }

    return result;
  }

  SelectionResult _handleEdgeUpdate(SelectionEdgeUpdateEvent event) {
    final painter = paragraph.selectableTextPainter;
    if (painter == null) return SelectionResult.none;

    // Convert global position to local position relative to this render object
    final transform = paragraph.getTransformTo(null);
    final invertedTransform = Matrix4.tryInvert(transform);
    if (invertedTransform == null) return SelectionResult.none;

    final localPosition =
        MatrixUtils.transformPoint(invertedTransform, event.globalPosition) -
            paragraph.textPaintOffset;

    // Check if position is within this block's bounds
    final isAbove = localPosition.dy < 0;
    final isBelow = localPosition.dy > paragraph.size.height;

    final isStartEdge = event.type == SelectionEventType.startEdgeUpdate;
    final textLength = painter.plainText.length;

    if (isAbove) {
      // Position is above this block
      if (isStartEdge) {
        // Start edge is above - this block should select from beginning
        _textSelectionStart = const TextPosition(offset: 0);
        // If end is not set, default to selecting nothing
        _textSelectionEnd ??= const TextPosition(offset: 0);
      } else {
        // End edge is above - nothing to select in this block
        _textSelectionEnd = const TextPosition(offset: 0);
        _textSelectionStart ??= const TextPosition(offset: 0);
      }
      return SelectionResult.previous;
    } else if (isBelow) {
      // Position is below this block
      if (isStartEdge) {
        // Start edge is below - nothing to select
        _textSelectionStart = TextPosition(offset: textLength);
        _textSelectionEnd ??= TextPosition(offset: textLength);
      } else {
        // End edge is below - select entire block from start
        _textSelectionEnd = TextPosition(offset: textLength);
        // If start is not set, default to beginning
        _textSelectionStart ??= const TextPosition(offset: 0);
      }
      return SelectionResult.next;
    } else {
      // Position is within this block
      final clampedPosition = _clampOffset(localPosition);
      final textPosition = painter.getPositionForOffset(clampedPosition);

      if (isStartEdge) {
        _textSelectionStart = textPosition;
        // For blocks where start is set within, end should default to end of block
        // if dragging down, or beginning if dragging up
        _textSelectionEnd ??= TextPosition(offset: textLength);
      } else {
        _textSelectionEnd = textPosition;
        // For blocks where end is set within, start should default to beginning
        _textSelectionStart ??= const TextPosition(offset: 0);
      }
      return SelectionResult.end;
    }
  }

  Offset _clampOffset(Offset offset) {
    return Offset(
      offset.dx.clamp(0, paragraph.size.width),
      offset.dy.clamp(0, paragraph.size.height),
    );
  }

  SelectionResult _handleClear() {
    _textSelectionStart = null;
    _textSelectionEnd = null;
    return SelectionResult.none;
  }

  SelectionResult _handleSelectAll() {
    final painter = paragraph.selectableTextPainter;
    if (painter == null) return SelectionResult.none;

    _textSelectionStart = const TextPosition(offset: 0);
    _textSelectionEnd = TextPosition(offset: painter.plainText.length);
    return SelectionResult.none;
  }

  SelectionResult _handleSelectWord(Offset globalPosition) {
    final painter = paragraph.selectableTextPainter;
    if (painter == null) return SelectionResult.none;

    // Convert global position to local position
    final transform = paragraph.getTransformTo(null);
    final invertedTransform = Matrix4.tryInvert(transform);
    if (invertedTransform == null) return SelectionResult.none;

    final localPosition =
        MatrixUtils.transformPoint(invertedTransform, globalPosition) -
            paragraph.textPaintOffset;
    final position = painter.getPositionForOffset(localPosition);
    final word = painter.getWordBoundary(position);

    _textSelectionStart = TextPosition(offset: word.start);
    _textSelectionEnd = TextPosition(offset: word.end);

    return SelectionResult.end;
  }

  SelectionResult _handleSelectParagraph() {
    final painter = paragraph.selectableTextPainter;
    if (painter == null) return SelectionResult.none;

    // Select all text in this paragraph
    _textSelectionStart = const TextPosition(offset: 0);
    _textSelectionEnd = TextPosition(offset: painter.plainText.length);

    return SelectionResult.end;
  }

  SelectionResult _handleGranularlyExtendSelection(
    bool forward,
    bool isEnd,
    TextGranularity granularity,
  ) {
    final painter = paragraph.selectableTextPainter;
    if (painter == null) return SelectionResult.none;

    final targetPosition = isEnd ? _textSelectionEnd : _textSelectionStart;
    if (targetPosition == null) return SelectionResult.none;

    TextPosition newPosition;

    switch (granularity) {
      case TextGranularity.character:
        final newOffset = forward
            ? math.min(targetPosition.offset + 1, painter.plainText.length)
            : math.max(targetPosition.offset - 1, 0);
        newPosition = TextPosition(offset: newOffset);
      case TextGranularity.word:
        final wordBoundary = painter.getWordBoundary(targetPosition);
        newPosition = forward
            ? TextPosition(offset: wordBoundary.end)
            : TextPosition(offset: wordBoundary.start);
      case TextGranularity.line:
        final lineMetrics = painter.computeLineMetrics();
        final currentOffset =
            painter.getOffsetForCaret(targetPosition, Rect.zero);
        var currentLine = 0;
        for (var i = 0; i < lineMetrics.length; i++) {
          if (currentOffset.dy <= lineMetrics[i].baseline) {
            currentLine = i;
            break;
          }
        }
        if (forward && currentLine < lineMetrics.length - 1) {
          final nextLineY = lineMetrics[currentLine + 1].baseline -
              lineMetrics[currentLine + 1].ascent;
          newPosition =
              painter.getPositionForOffset(Offset(currentOffset.dx, nextLineY));
        } else if (!forward && currentLine > 0) {
          final prevLineY = lineMetrics[currentLine - 1].baseline -
              lineMetrics[currentLine - 1].ascent;
          newPosition =
              painter.getPositionForOffset(Offset(currentOffset.dx, prevLineY));
        } else {
          newPosition = targetPosition;
        }
      case TextGranularity.paragraph:
      case TextGranularity.document:
        newPosition = forward
            ? TextPosition(offset: painter.plainText.length)
            : const TextPosition(offset: 0);
    }

    if (isEnd) {
      _textSelectionEnd = newPosition;
    } else {
      _textSelectionStart = newPosition;
    }

    return SelectionResult.end;
  }

  SelectionResult _handleDirectionallyExtendSelection(
    double dx,
    bool isEnd,
    SelectionExtendDirection direction,
  ) {
    final painter = paragraph.selectableTextPainter;
    if (painter == null) return SelectionResult.none;

    final targetPosition = isEnd ? _textSelectionEnd : _textSelectionStart;
    if (targetPosition == null) return SelectionResult.none;

    final currentOffset = painter.getOffsetForCaret(targetPosition, Rect.zero);

    TextPosition newPosition;

    switch (direction) {
      case SelectionExtendDirection.previousLine:
        final newY = currentOffset.dy - painter.preferredLineHeight;
        if (newY < 0) return SelectionResult.previous;
        newPosition = painter.getPositionForOffset(Offset(dx, newY));
      case SelectionExtendDirection.nextLine:
        final newY = currentOffset.dy + painter.preferredLineHeight;
        if (newY > paragraph.size.height) return SelectionResult.next;
        newPosition = painter.getPositionForOffset(Offset(dx, newY));
      case SelectionExtendDirection.forward:
        final newOffset =
            math.min(targetPosition.offset + 1, painter.plainText.length);
        newPosition = TextPosition(offset: newOffset);
      case SelectionExtendDirection.backward:
        final newOffset = math.max(targetPosition.offset - 1, 0);
        newPosition = TextPosition(offset: newOffset);
    }

    if (isEnd) {
      _textSelectionEnd = newPosition;
    } else {
      _textSelectionStart = newPosition;
    }

    return SelectionResult.end;
  }

  @override
  SelectedContent? getSelectedContent() {
    if (_textSelectionStart == null || _textSelectionEnd == null) return null;

    final painter = paragraph.selectableTextPainter;
    if (painter == null) return null;

    final start = _textSelectionStart!.offset;
    final end = _textSelectionEnd!.offset;

    if (start == end) return null;

    final text = painter.plainText;
    final selectedText = text.substring(
      math.min(start, end),
      math.max(start, end),
    );

    return SelectedContent(plainText: selectedText);
  }

  @override
  Matrix4 getTransformTo(RenderObject? ancestor) {
    return paragraph.getTransformTo(ancestor);
  }

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {
    // Handle layers are managed by the SelectionArea
  }

  @override
  Size get size => paragraph.size;

  @override
  List<Rect> get boundingBoxes => <Rect>[Offset.zero & size];

  @override
  void dispose() {
    _listeners.clear();
  }

  @override
  SelectedContentRange? getSelection() {
    if (_textSelectionStart == null || _textSelectionEnd == null) {
      return null;
    }
    return SelectedContentRange(
      startOffset: _textSelectionStart!.offset,
      endOffset: _textSelectionEnd!.offset,
    );
  }

  @override
  int get contentLength {
    final painter = paragraph.selectableTextPainter;
    if (painter == null) return 0;
    return painter.plainText.length;
  }
}
