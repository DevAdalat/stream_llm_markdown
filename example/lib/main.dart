import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:stream_markdown_renderer/stream_markdown_renderer.dart';

void main() {
  runApp(const MyApp());
}

class DemoPage extends StatefulWidget {
  final bool isDarkMode;

  final VoidCallback onToggleTheme;
  const DemoPage({
    required this.isDarkMode,
    required this.onToggleTheme,
    super.key,
  });

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _DemoPageState extends State<DemoPage> {
  StreamController<String>? _controller;
  final ScrollController _scrollController = ScrollController();
  bool _isStreaming = false;

  @override
  Widget build(BuildContext context) {
    log('Building DemoPage');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stream Markdown Demo'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isStreaming ? null : _startStream,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_isStreaming ? 'Streaming...' : 'Start Stream'),
                ),
                const SizedBox(width: 16),
                if (_isStreaming)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SelectionArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: _controller != null
                    ? StreamMarkdownRenderer(
                        markdownStream: _controller!.stream,
                        showCursor: false,
                        // characterDelay: const Duration(
                        //   milliseconds: 15,
                        // ), // Character-by-character animation
                        scrollController: _scrollController,
                        autoScrollToBottom: true,
                        theme: widget.isDarkMode
                            ? MarkdownTheme.dark()
                            : MarkdownTheme.light(),
                        onLinkTapped: (url) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Link tapped: $url')),
                          );
                        },
                        onCheckboxTapped: (index, checked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Checkbox $index ${checked ? 'checked' : 'unchecked'}',
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          'Press "Start Stream" to begin',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.close();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _simulateAiStream(StreamController<String> controller) async {
    const markdown = '''
# Welcome to Stream Markdown Renderer

This is a **high-performance** streaming Markdown renderer built with custom RenderObjects for *maximum efficiency*.

## Features

### Text Formatting

You can use **bold**, *italic*, ~~strikethrough~~, and `inline code`.

### Code Blocks

Here's a Dart code example:

```dart
void main() {
  final greeting = 'Hello, World!';
  print(greeting);
  
  // Calculate factorial
  int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
  }
  
  print('5! = \${factorial(5)}');
}
```

And some Python:

```python
def fibonacci(n):
    """Generate Fibonacci sequence."""
    if n <= 0:
        return []
    elif n == 1:
        return [0]
    
    sequence = [0, 1]
    while len(sequence) < n:
        sequence.append(sequence[-1] + sequence[-2])
    return sequence

# Print first 10 Fibonacci numbers
print(fibonacci(10))
```

### Lists

#### Unordered List
- First item
- Second item with **bold**
- Third item with `code`
- Fourth item

#### Ordered List
1. Step one
2. Step two
3. Step three

#### Task List
- [x] Implement parser
- [x] Build render objects
- [x] Add syntax highlighting
- [ ] Write documentation
- [ ] Publish to pub.dev

#### Nested Lists
- Main item one
  - Nested item A
  - Nested item B
  - Nested item C
- Main item two
  - Nested item D
  - Nested item E
- Main item three

### Blockquotes

> This is a blockquote with some **important** information.
> 
> It can span multiple lines.

> **Note:** Blockquotes now support nested content:
> 
> - Point one
> - Point two
> - Point three
> 
> You can include lists, code, and more!

### Tables

| Feature | Status | Priority |
|:--------|:------:|--------:|
| Parsing | Done | High |
| Rendering | Done | High |
| Themes | Done | Medium |
| Testing | Pending | Low |

### Links

Check out [Flutter](https://flutter.dev) for more information.

You can also use autolinks: <https://dart.dev>

### Math (LaTeX)

Inline math: \$E = mc^2\$

Block math:

\$\$
\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}
\$\$

---

## Performance

This renderer is designed for **extreme performance**:

- Sub-millisecond layout times
- Intelligent diffing for minimal repaints
- Cached text layout
- Zero widget tree overhead

Perfect for AI chat applications! 🚀
''';

    var buffer = '';

    // Simulate streaming with realistic chunk sizes and delays
    // Split into words and whitespace to simulate token-based streaming
    final RegExp tokenRegex = RegExp(r'[^\s]+|\s+');
    final matches = tokenRegex.allMatches(markdown);

    for (final match in matches) {
      if (controller.isClosed) break;

      final token = match.group(0)!;
      buffer += token;
      controller.add(buffer);

      // Variable delay to simulate realistic streaming
      final isNewline = token.contains('\n');
      final isSpace = token.trim().isEmpty;

      final delay = isNewline ? 50 : (isSpace ? 10 : 30);
      await Future<void>.delayed(Duration(milliseconds: delay));

      // Scroll to bottom after rendering
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    if (!controller.isClosed) {
      setState(() {
        _isStreaming = false;
      });
    }
  }

  void _startStream() {
    _controller?.close();
    _controller = StreamController<String>();
    setState(() {
      _isStreaming = true;
    });

    _simulateAiStream(_controller!);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    log('Building MaterialApp');
    return MaterialApp(
      title: 'Stream Markdown Renderer Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _themeMode,
      home: DemoPage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }
}
