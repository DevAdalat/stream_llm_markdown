/// A high-performance streaming Markdown renderer for Flutter.
///
/// This package provides a StreamMarkdownRenderer widget that renders
/// streaming Markdown content using custom RenderObjects for maximum
/// performance. It's designed specifically for AI chat applications where
/// content is streamed character by character.
///
/// ## Features
///
/// - 100% RenderObject-based rendering for maximum performance
/// - Streaming-aware incremental parsing with intelligent diffing
/// - Full GitHub-Flavored Markdown support
/// - Built-in syntax highlighting for 15+ languages
/// - Customizable themes
///
/// ## Usage
///
/// ```dart
/// import 'package:stream_markdown_renderer/stream_markdown_renderer.dart';
///
/// StreamMarkdownRenderer(
///   markdownStream: myStream,
///   theme: MarkdownTheme.dark(),
///   onLinkTapped: (url) => launchUrl(Uri.parse(url)),
/// )
/// ```
library;

export 'src/parsing/markdown_block.dart'
    show ListItem, MarkdownBlock, MarkdownBlockType, TableAlignment, TableCell;
export 'src/renderer/stream_markdown_renderer.dart' show StreamMarkdownRenderer;
export 'src/theme/markdown_theme.dart';
