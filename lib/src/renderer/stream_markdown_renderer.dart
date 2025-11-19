import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../parsing/incremental_markdown_parser.dart';
import '../parsing/markdown_block.dart';
import '../render_objects/base/render_markdown_block.dart';
import '../theme/markdown_theme.dart';
import 'block_registry.dart';

/// A widget that renders streaming Markdown content using custom RenderObjects.
///
/// This widget provides maximum performance by using a flat list of custom
/// RenderObjects instead of building a widget tree.
class StreamMarkdownRenderer extends LeafRenderObjectWidget {
  /// Creates a new stream markdown renderer.
  const StreamMarkdownRenderer({
    required this.markdownStream,
    this.theme,
    this.onLinkTapped,
    this.onCheckboxTapped,
    super.key,
  });

  /// The stream of Markdown content to render.
  ///
  /// Each emission should be the complete Markdown text so far
  /// (not just the new chunk).
  final Stream<String> markdownStream;

  /// The theme for rendering.
  final MarkdownTheme? theme;

  /// Callback when a link is tapped.
  final void Function(String url)? onLinkTapped;

  /// Callback when a checkbox is tapped.
  final void Function(int index, bool checked)? onCheckboxTapped;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderStreamMarkdown(
      markdownStream: markdownStream,
      theme: (theme ?? MarkdownTheme.light()).withDefaults(),
      onLinkTapped: onLinkTapped,
      onCheckboxTapped: onCheckboxTapped,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderStreamMarkdown renderObject,
  ) {
    renderObject
      ..markdownStream = markdownStream
      ..theme = (theme ?? MarkdownTheme.light()).withDefaults()
      ..onLinkTapped = onLinkTapped
      ..onCheckboxTapped = onCheckboxTapped;
  }
}

/// RenderObject for streaming Markdown content.
class RenderStreamMarkdown extends RenderBox {
  /// Creates a new render stream markdown.
  RenderStreamMarkdown({
    required Stream<String> markdownStream,
    required MarkdownTheme theme,
    void Function(String url)? onLinkTapped,
    void Function(int index, bool checked)? onCheckboxTapped,
  })  : _theme = theme,
        _onLinkTapped = onLinkTapped,
        _onCheckboxTapped = onCheckboxTapped {
    _subscribeToStream(markdownStream);
  }

  final _parser = IncrementalMarkdownParser();
  StreamSubscription<String>? _subscription;
  String _currentMarkdown = '';
  String _pendingMarkdown = '';
  List<MarkdownBlock> _currentBlocks = [];
  bool _updateScheduled = false;

  // Child render objects
  final List<RenderMarkdownBlock> _children = [];
  final Map<String, RenderMarkdownBlock> _childMap = {};

  /// The stream of Markdown content.
  Stream<String>? _markdownStream;
  Stream<String> get markdownStream => _markdownStream!;
  set markdownStream(Stream<String> value) {
    if (_markdownStream == value) return;
    _subscribeToStream(value);
  }

  /// The theme for rendering.
  MarkdownTheme get theme => _theme;
  MarkdownTheme _theme;
  set theme(MarkdownTheme value) {
    if (_theme == value) return;
    _theme = value;
    for (final child in _children) {
      child.theme = value;
    }
    markNeedsLayout();
  }

  /// Callback when a link is tapped.
  void Function(String url)? get onLinkTapped => _onLinkTapped;
  void Function(String url)? _onLinkTapped;
  set onLinkTapped(void Function(String url)? value) {
    if (_onLinkTapped == value) return;
    _onLinkTapped = value;
    for (final child in _children) {
      child.onLinkTapped = value;
    }
  }

  /// Callback when a checkbox is tapped.
  void Function(int index, bool checked)? get onCheckboxTapped =>
      _onCheckboxTapped;
  void Function(int index, bool checked)? _onCheckboxTapped;
  set onCheckboxTapped(void Function(int index, bool checked)? value) {
    if (_onCheckboxTapped == value) return;
    _onCheckboxTapped = value;
    for (final child in _children) {
      child.onCheckboxTapped = value;
    }
  }

  void _subscribeToStream(Stream<String> stream) {
    _subscription?.cancel();
    _markdownStream = stream;
    _currentMarkdown = '';
    _pendingMarkdown = '';
    _currentBlocks = [];
    _updateScheduled = false;

    // Clear existing children
    _clearChildren();

    _subscription = stream.listen(
      _onMarkdownReceived,
      onError: _onError,
      onDone: _onDone,
    );
  }

  void _clearChildren() {
    for (final child in _children) {
      dropChild(child);
      child.dispose();
    }
    _children.clear();
    _childMap.clear();
  }

  void _onMarkdownReceived(String markdown) {
    if (markdown == _currentMarkdown) return;

    _pendingMarkdown = markdown;
    
    // Throttle updates to once per frame
    if (!_updateScheduled) {
      _updateScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _updateScheduled = false;
        if (_pendingMarkdown != _currentMarkdown) {
          _currentMarkdown = _pendingMarkdown;
          _currentBlocks = _parser.parse(_currentMarkdown);
          _updateChildren();
        }
      });
    }
  }

  void _updateChildren() {
    final newChildren = <RenderMarkdownBlock>[];
    final newChildMap = <String, RenderMarkdownBlock>{};

    for (final block in _currentBlocks) {
      final existingChild = _childMap[block.id];

      if (existingChild != null) {
        // Update existing child
        BlockRegistry.updateRenderObject(
          renderObject: existingChild,
          block: block,
          theme: _theme,
          onLinkTapped: _onLinkTapped,
          onCheckboxTapped: _onCheckboxTapped,
        );
        newChildren.add(existingChild);
        newChildMap[block.id] = existingChild;
      } else {
        // Create new child
        final child = BlockRegistry.createRenderObject(
          block: block,
          theme: _theme,
          onLinkTapped: _onLinkTapped,
          onCheckboxTapped: _onCheckboxTapped,
        );
        adoptChild(child);
        newChildren.add(child);
        newChildMap[block.id] = child;
      }
    }

    // Dispose removed children
    for (final entry in _childMap.entries) {
      if (!newChildMap.containsKey(entry.key)) {
        dropChild(entry.value);
        entry.value.dispose();
      }
    }

    _children
      ..clear()
      ..addAll(newChildren);

    _childMap
      ..clear()
      ..addAll(newChildMap);

    markNeedsLayout();
  }

  void _onError(Object error, StackTrace stackTrace) {
    // Handle error gracefully - keep showing current content
  }

  void _onDone() {
    // Stream completed - ensure last block is not marked as partial
    if (_currentBlocks.isNotEmpty && _currentBlocks.last.isPartial) {
      final lastBlock = _currentBlocks.removeLast();
      _currentBlocks.add(lastBlock.copyWith(isPartial: false));
      _updateChildren();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _clearChildren();
    super.dispose();
  }

  @override
  void performLayout() {
    final blockSpacing = _theme.blockSpacing ?? 16;

    var totalHeight = 0.0;

    for (var i = 0; i < _children.length; i++) {
      final child = _children[i];

      // Layout each block with the full width
      child.layout(
        BoxConstraints(
          minWidth: 0,
          maxWidth: constraints.maxWidth,
        ),
        parentUsesSize: true,
      );

      totalHeight += child.size.height;

      if (i < _children.length - 1) {
        totalHeight += blockSpacing;
      }
    }

    size = Size(
      constraints.maxWidth,
      totalHeight > 0 ? totalHeight : 0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final blockSpacing = _theme.blockSpacing ?? 16;

    var currentY = offset.dy;

    for (var i = 0; i < _children.length; i++) {
      final child = _children[i];

      // Skip children that haven't been laid out yet
      if (!child.hasSize) continue;

      // Paint the block
      context.paintChild(child, Offset(offset.dx, currentY));

      currentY += child.size.height;

      if (i < _children.length - 1) {
        currentY += blockSpacing;
      }
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Safety check: don't hit test if we haven't been laid out yet
    if (!hasSize) return false;

    final blockSpacing = _theme.blockSpacing ?? 16;

    var currentY = 0.0;

    for (var i = 0; i < _children.length; i++) {
      final child = _children[i];
      
      // Skip children that haven't been laid out yet
      if (!child.hasSize) continue;
      
      final childOffset = Offset(0, currentY);
      final childRect = childOffset & child.size;

      if (childRect.contains(position)) {
        return result.addWithPaintOffset(
          offset: childOffset,
          position: position,
          hitTest: (BoxHitTestResult result, Offset transformed) {
            return child.hitTest(result, position: transformed);
          },
        );
      }

      currentY += child.size.height;

      if (i < _children.length - 1) {
        currentY += blockSpacing;
      }
    }

    return false;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    // Events are handled by child render objects
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final child in _children) {
      child.attach(owner);
    }
  }

  @override
  void detach() {
    for (final child in _children) {
      child.detach();
    }
    super.detach();
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    for (final child in _children) {
      visitor(child);
    }
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return _children.map((child) {
      return child.toDiagnosticsNode(name: 'child');
    }).toList();
  }
}
