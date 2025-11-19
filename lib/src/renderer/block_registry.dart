import '../parsing/markdown_block.dart';
import '../render_objects/base/render_markdown_block.dart';
import '../render_objects/render_blockquote.dart';
import '../render_objects/render_code_block.dart';
import '../render_objects/render_header.dart';
import '../render_objects/render_latex.dart';
import '../render_objects/render_list.dart';
import '../render_objects/render_paragraph.dart';
import '../render_objects/render_table.dart';
import '../render_objects/render_thematic_break.dart';
import '../theme/markdown_theme.dart';

/// Factory for creating RenderObjects from MarkdownBlocks.
class BlockRegistry {
  /// Creates a RenderObject for the given block.
  static RenderMarkdownBlock createRenderObject({
    required MarkdownBlock block,
    required MarkdownTheme theme,
    void Function(String url)? onLinkTapped,
    void Function(int index, bool checked)? onCheckboxTapped,
  }) {
    switch (block.type) {
      case MarkdownBlockType.paragraph:
        return RenderMarkdownParagraph(
          block: block,
          theme: theme,
          onLinkTapped: onLinkTapped,
          onCheckboxTapped: onCheckboxTapped,
        );
      case MarkdownBlockType.header:
        return RenderMarkdownHeader(
          block: block,
          theme: theme,
          onLinkTapped: onLinkTapped,
          onCheckboxTapped: onCheckboxTapped,
        );
      case MarkdownBlockType.codeBlock:
        return RenderMarkdownCodeBlock(
          block: block,
          theme: theme,
          onLinkTapped: onLinkTapped,
          onCheckboxTapped: onCheckboxTapped,
        );
      case MarkdownBlockType.blockquote:
        return RenderMarkdownBlockquote(
          block: block,
          theme: theme,
          onLinkTapped: onLinkTapped,
          onCheckboxTapped: onCheckboxTapped,
        );
      case MarkdownBlockType.orderedList:
      case MarkdownBlockType.unorderedList:
        return RenderMarkdownList(
          block: block,
          theme: theme,
          onLinkTapped: onLinkTapped,
          onCheckboxTapped: onCheckboxTapped,
        );
      case MarkdownBlockType.table:
        return RenderMarkdownTable(
          block: block,
          theme: theme,
          onLinkTapped: onLinkTapped,
          onCheckboxTapped: onCheckboxTapped,
        );
      case MarkdownBlockType.thematicBreak:
        return RenderMarkdownThematicBreak(
          block: block,
          theme: theme,
          onLinkTapped: onLinkTapped,
          onCheckboxTapped: onCheckboxTapped,
        );
      case MarkdownBlockType.latex:
        return RenderMarkdownLatex(
          block: block,
          theme: theme,
          onLinkTapped: onLinkTapped,
          onCheckboxTapped: onCheckboxTapped,
        );
      case MarkdownBlockType.html:
        // Render HTML as paragraph for now
        return RenderMarkdownParagraph(
          block: block,
          theme: theme,
          onLinkTapped: onLinkTapped,
          onCheckboxTapped: onCheckboxTapped,
        );
    }
  }

  /// Updates an existing RenderObject with new block data.
  static void updateRenderObject({
    required RenderMarkdownBlock renderObject,
    required MarkdownBlock block,
    required MarkdownTheme theme,
    void Function(String url)? onLinkTapped,
    void Function(int index, bool checked)? onCheckboxTapped,
  }) {
    renderObject
      ..block = block
      ..theme = theme
      ..onLinkTapped = onLinkTapped
      ..onCheckboxTapped = onCheckboxTapped;
  }
}
