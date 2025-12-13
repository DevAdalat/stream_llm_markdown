import 'package:flutter/rendering.dart';
import 'base/render_markdown_block.dart';
import '../parsing/markdown_block.dart';
import '../theme/markdown_theme.dart';

/// A wrapper for custom RenderObjects in the markdown stream.
class RenderCustomMarkdownBlock extends RenderMarkdownBlock
    with RenderObjectWithChildMixin<RenderBox> {
  RenderCustomMarkdownBlock({
    required RenderBox child,
    required MarkdownBlock block,
    required MarkdownTheme theme,
  }) : super(block: block, theme: theme) {
    this.child = child;
  }

  @override
  double computeIntrinsicHeight(double width) {
    if (child == null) return 0;
    return child!.getMinIntrinsicHeight(width);
  }

  @override
  Size computeSize(BoxConstraints constraints) {
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
      return child!.size;
    }
    return Size(constraints.maxWidth, 0);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child != null) {
      return child!.hitTest(result, position: position);
    }
    return false;
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (child != null) visitor(child!);
  }
}
