# Stream Markdown Renderer

A high-performance streaming Markdown renderer for Flutter, designed specifically for AI chat applications. Built entirely with custom RenderObjects for maximum efficiency and smooth "typing" animations.

## Features

- **100% RenderObject-Based**: No widget tree bloat - entire document rendered with custom RenderObjects
- **Streaming Support**: Incremental parsing with intelligent diffing for smooth AI-style streaming
- **Full GFM Support**: Headers, bold, italic, strikethrough, code blocks, tables, task lists, and more
- **Syntax Highlighting**: Built-in support for 15+ programming languages
- **High Performance**: Sub-millisecond layout times even with 500+ blocks
- **Customizable Themes**: Full control over colors, fonts, and spacing
- **Production Ready**: Error-resilient, never crashes on malformed Markdown

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  stream_markdown_renderer: ^1.0.0
```

## Usage

### Basic Usage

```dart
import 'package:stream_markdown_renderer/stream_markdown_renderer.dart';

class MyWidget extends StatelessWidget {
  final Stream<String> markdownStream;

  const MyWidget({required this.markdownStream, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamMarkdownRenderer(
      markdownStream: markdownStream,
      onLinkTapped: (url) => launchUrl(Uri.parse(url)),
    );
  }
}
```

### Custom Theme

```dart
StreamMarkdownRenderer(
  markdownStream: stream,
  theme: MarkdownTheme(
    textStyle: const TextStyle(fontSize: 16),
    codeTheme: CodeBlockTheme(
      backgroundColor: Colors.grey[900]!,
      textStyle: const TextStyle(
        fontFamily: 'Fira Code',
        fontSize: 14,
      ),
    ),
    headerTheme: HeaderTheme(
      h1Style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
);
```

### Simulating AI Streaming

```dart
Stream<String> simulateAiStream() async* {
  const response = '''
# Hello World

This is a **streaming** markdown renderer.
''';
void main() {
  for (var i = 0; i < response.length; i++) {
    yield response.substring(0, i + 1);
    await Future.delayed(const Duration(milliseconds: 20));
  }
}
```

### Custom Widgets via Patterns

You can inject custom Flutter widgets into the markdown stream by defining patterns. Use the special Unicode delimiter `\uEB1E` (or `󠄞`) to wrap content that should be rendered as a custom block.

```dart
StreamMarkdownRenderer(
  markdownStream: myStream,
  customPatterns: [
    MarkdownPattern(
      // Match the content inside the delimiters
      pattern: RegExp(r'^custom$'), 
      createRenderObject: (block, theme) {
        // Return a RenderBox for your custom widget
        // Note: You must provide a RenderBox, not a Widget.
        return RenderCustomBox();
      },
    ),
  ],
)
```

Then stream the content wrapped in the delimiter:

```dart
// Stream content with delimiters
controller.add('Here is a custom widget: \uEB1Ecustom\uEB1E');
```

## Supported Markdown Features

- **Headers**: H1-H6
- **Emphasis**: Bold, italic, strikethrough
- **Code**: Inline code and fenced code blocks with syntax highlighting
- **Lists**: Ordered, unordered, and task lists with checkboxes
- **Blockquotes**: Including nested blockquotes
- **Tables**: With column alignment support
- **Links**: Clickable links with tap callbacks
- **Images**: Image placeholders (tap to open)
- **Horizontal Rules**: Thematic breaks
- **LaTeX**: Inline and block math expressions (placeholder rendering)
- **HTML**: Safe subset support (`<br>`, `<del>`, etc.)

## Supported Languages for Syntax Highlighting

- Dart
- JavaScript/TypeScript
- Python
- Java
- C/C++
- Rust
- Go
- Swift
- Kotlin
- Ruby
- PHP
- SQL
- JSON
- YAML
- Bash/Shell

## Performance

The renderer achieves exceptional performance through:

1. **Stable Block IDs**: Each Markdown block has a deterministic ID for efficient diffing
2. **Incremental Updates**: Only modified blocks trigger relayout/repaint
3. **Cached Text Layout**: `ui.Paragraph` objects are cached with constraints
4. **Zero Allocations**: No unnecessary object allocations after warm-up

## API Reference

### StreamMarkdownRenderer

The main widget for rendering streaming Markdown.

```dart
StreamMarkdownRenderer({
  required Stream<String> markdownStream,
  MarkdownTheme? theme,
  void Function(String url)? onLinkTapped,
  void Function(int index, bool checked)? onCheckboxTapped,
  Key? key,
});
```

### MarkdownTheme

Customizable theme for the renderer.

```dart
MarkdownTheme({
  TextStyle? textStyle,
  Color? linkColor,
  HeaderTheme? headerTheme,
  CodeBlockTheme? codeTheme,
  BlockquoteTheme? blockquoteTheme,
  TableTheme? tableTheme,
  double? blockSpacing,
});
```

## License

MIT License - see [LICENSE](LICENSE) for details.
