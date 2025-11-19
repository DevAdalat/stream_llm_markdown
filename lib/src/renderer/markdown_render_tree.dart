import '../parsing/markdown_block.dart';
import '../render_objects/base/render_markdown_block.dart';
import '../theme/markdown_theme.dart';
import 'block_registry.dart';

/// Manages a tree of RenderMarkdownBlocks with intelligent diffing.
class MarkdownRenderTree {
  /// Creates a new render tree.
  MarkdownRenderTree({
    required this.theme,
    this.onLinkTapped,
    this.onCheckboxTapped,
  });

  /// The theme for rendering.
  MarkdownTheme theme;

  /// Callback when a link is tapped.
  void Function(String url)? onLinkTapped;

  /// Callback when a checkbox is tapped.
  void Function(int index, bool checked)? onCheckboxTapped;

  /// Current list of render objects.
  final List<RenderMarkdownBlock> _renderObjects = [];

  /// Map of block IDs to render objects for quick lookup.
  final Map<String, RenderMarkdownBlock> _blockMap = {};

  /// Previous block list for diffing.
  List<MarkdownBlock> _previousBlocks = [];

  /// Gets the current render objects.
  List<RenderMarkdownBlock> get renderObjects => List.unmodifiable(_renderObjects);

  /// Updates the tree with new blocks, performing intelligent diffing.
  /// 
  /// Returns true if the tree was modified.
  bool update(List<MarkdownBlock> newBlocks) {
    if (_areBlocksEqual(newBlocks, _previousBlocks)) {
      return false;
    }

    final newRenderObjects = <RenderMarkdownBlock>[];
    final newBlockMap = <String, RenderMarkdownBlock>{};

    for (final block in newBlocks) {
      final existingRenderObject = _blockMap[block.id];
      
      if (existingRenderObject != null) {
        // Update existing render object
        BlockRegistry.updateRenderObject(
          renderObject: existingRenderObject,
          block: block,
          theme: theme,
          onLinkTapped: onLinkTapped,
          onCheckboxTapped: onCheckboxTapped,
        );
        newRenderObjects.add(existingRenderObject);
        newBlockMap[block.id] = existingRenderObject;
      } else {
        // Create new render object
        final renderObject = BlockRegistry.createRenderObject(
          block: block,
          theme: theme,
          onLinkTapped: onLinkTapped,
          onCheckboxTapped: onCheckboxTapped,
        );
        newRenderObjects.add(renderObject);
        newBlockMap[block.id] = renderObject;
      }
    }

    // Dispose of removed render objects
    for (final entry in _blockMap.entries) {
      if (!newBlockMap.containsKey(entry.key)) {
        entry.value.dispose();
      }
    }

    _renderObjects
      ..clear()
      ..addAll(newRenderObjects);
    
    _blockMap
      ..clear()
      ..addAll(newBlockMap);
    
    _previousBlocks = List.of(newBlocks);

    return true;
  }

  /// Updates the theme for all render objects.
  void updateTheme(MarkdownTheme newTheme) {
    if (theme == newTheme) return;
    
    theme = newTheme;
    for (final renderObject in _renderObjects) {
      renderObject.theme = newTheme;
    }
  }

  /// Updates callbacks for all render objects.
  void updateCallbacks({
    void Function(String url)? onLinkTapped,
    void Function(int index, bool checked)? onCheckboxTapped,
  }) {
    this.onLinkTapped = onLinkTapped;
    this.onCheckboxTapped = onCheckboxTapped;
    
    for (final renderObject in _renderObjects) {
      renderObject
        ..onLinkTapped = onLinkTapped
        ..onCheckboxTapped = onCheckboxTapped;
    }
  }

  /// Disposes all render objects.
  void dispose() {
    for (final renderObject in _renderObjects) {
      renderObject.dispose();
    }
    _renderObjects.clear();
    _blockMap.clear();
    _previousBlocks = [];
  }

  bool _areBlocksEqual(List<MarkdownBlock> a, List<MarkdownBlock> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
