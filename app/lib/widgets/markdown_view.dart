import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import 'ui.dart';

/// Renders an AI answer written in Markdown (GitHub flavour): headings, bold/italic, inline code,
/// lists, quotes, links, code blocks with a copy button, and tables that scroll sideways.
/// Built on the `markdown` parser so it follows Lumi's look instead of a package's theme.
class MarkdownView extends StatefulWidget {
  const MarkdownView({super.key, required this.data, this.trailing});

  final String data;

  /// Shown right after the last word (the blinking caret while an answer streams in).
  final Widget? trailing;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  String? _parsedFor;
  List<md.Node> _nodes = const [];

  List<md.Node> _parse(String data) {
    if (_parsedFor != data) {
      _parsedFor = data;
      _nodes = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored, encodeHtml: false)
          .parseLines(data.replaceAll('\r\n', '\n').split('\n'));
    }
    return _nodes;
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _parse(widget.data);
    final builder = _Builder(context, trailing: widget.trailing);
    final blocks = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      final isLast = i == nodes.length - 1;
      blocks.add(builder.block(nodes[i], last: isLast));
    }
    if (widget.trailing != null && !builder.trailingPlaced) blocks.add(widget.trailing!);

    // Start-aligned so a short answer gives a snug bubble; code blocks and tables still take the full width.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          blocks[i],
        ],
      ],
    );
  }
}

class _Builder {
  _Builder(this.context, {this.trailing});

  final BuildContext context;
  final Widget? trailing;
  var trailingPlaced = false;

  static const _base = TextStyle(fontSize: 15, height: 1.55, color: AppColors.text);

  Widget block(md.Node node, {bool last = false}) {
    if (node is md.Text) return _paragraph([node], _base, last: last);
    if (node is! md.Element) return const SizedBox.shrink();
    final children = node.children ?? const <md.Node>[];

    switch (node.tag) {
      case 'p':
        return _paragraph(children, _base, last: last);
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final size = switch (node.tag) { 'h1' => 22.0, 'h2' => 19.0, 'h3' => 17.0, _ => 15.5 };
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _paragraph(children, AppText.heading(size).copyWith(height: 1.3), last: last),
        );
      case 'ul' || 'ol':
        return _list(node, ordered: node.tag == 'ol', last: last);
      case 'pre':
        final code = children.whereType<md.Element>().firstOrNull;
        final language = (code?.attributes['class'] ?? '').replaceFirst('language-', '');
        return _CodeBlock(code: (code?.textContent ?? node.textContent).trimRight(), language: language);
      case 'blockquote':
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.lamp, width: 3))),
          child: _blocks(children, style: _base.copyWith(color: AppColors.muted)),
        );
      case 'table':
        return _table(node);
      case 'hr':
        return const Divider(height: 8, color: AppColors.border);
      default:
        return _paragraph(children, _base, last: last);
    }
  }

  Widget _blocks(List<md.Node> nodes, {TextStyle style = _base}) {
    // A list item or quote may hold plain inline nodes or full paragraphs.
    final hasBlocks = nodes.any((n) => n is md.Element && _isBlock(n.tag));
    if (!hasBlocks) return _paragraph(nodes, style);
    final widgets = <Widget>[];
    final inline = <md.Node>[];
    void flush() {
      if (inline.isNotEmpty) widgets.add(_paragraph(List.of(inline), style));
      inline.clear();
    }

    for (final n in nodes) {
      if (n is md.Element && _isBlock(n.tag)) {
        flush();
        widgets.add(block(n));
      } else {
        inline.add(n);
      }
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widgets.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          widgets[i],
        ],
      ],
    );
  }

  static bool _isBlock(String tag) =>
      const {'p', 'ul', 'ol', 'pre', 'blockquote', 'table', 'hr', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}.contains(tag);

  Widget _paragraph(List<md.Node> nodes, TextStyle style, {bool last = false}) {
    final spans = _inline(nodes, style);
    if (last && trailing != null && !trailingPlaced) {
      trailingPlaced = true;
      spans.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: trailing!));
    }
    return Text.rich(TextSpan(children: spans), style: style);
  }

  List<InlineSpan> _inline(List<md.Node> nodes, TextStyle style) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is md.Text) {
        spans.add(TextSpan(text: _unescape(node.text), style: style));
        continue;
      }
      if (node is! md.Element) continue;
      final children = node.children ?? const <md.Node>[];
      switch (node.tag) {
        case 'strong' || 'b':
          spans.addAll(_inline(children, style.copyWith(fontWeight: FontWeight.w700)));
        case 'em' || 'i':
          spans.addAll(_inline(children, style.copyWith(fontStyle: FontStyle.italic)));
        case 'del':
          spans.addAll(_inline(children, style.copyWith(decoration: TextDecoration.lineThrough)));
        case 'code':
          spans.add(
            TextSpan(
              text: _unescape(node.textContent),
              style: AppText.mono(13.5, color: const Color(0xFFE6F5C4)).copyWith(
                backgroundColor: const Color(0xFF242A20),
              ),
            ),
          );
        case 'a':
          spans.addAll(
            _inline(children, style.copyWith(color: AppColors.accent, decoration: TextDecoration.underline)),
          );
        case 'br':
          spans.add(const TextSpan(text: '\n'));
        case 'input':
          final checked = node.attributes['checked'] != null;
          spans.add(TextSpan(text: checked ? '☑ ' : '☐ ', style: style));
        default:
          spans.addAll(_inline(children, style));
      }
    }
    return spans;
  }

  Widget _list(md.Element list, {required bool ordered, bool last = false}) {
    final items = (list.children ?? const <md.Node>[]).whereType<md.Element>().where((e) => e.tag == 'li').toList();
    final start = int.tryParse(list.attributes['start'] ?? '') ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: ordered ? 26 : 18,
                  child: Text(
                    ordered ? '${start + i}.' : '•',
                    style: _base.copyWith(color: ordered ? AppColors.muted : AppColors.accent),
                  ),
                ),
                Expanded(child: _blocks(items[i].children ?? const [])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _table(md.Element table) {
    final rows = <(bool, List<md.Element>)>[];
    for (final section in (table.children ?? const <md.Node>[]).whereType<md.Element>()) {
      final header = section.tag == 'thead';
      for (final tr in (section.children ?? const <md.Node>[]).whereType<md.Element>()) {
        rows.add((header, (tr.children ?? const <md.Node>[]).whereType<md.Element>().toList()));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final columns = rows.map((r) => r.$2.length).reduce((a, b) => a > b ? a : b);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: AppColors.border, borderRadius: BorderRadius.circular(12)),
          children: [
            for (final (header, cells) in rows)
              TableRow(
                decoration: BoxDecoration(color: header ? AppColors.surfaceHigh : AppColors.bg),
                children: [
                  for (var c = 0; c < columns; c++)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: c < cells.length
                            ? Text.rich(
                                TextSpan(
                                  children: _inline(
                                    cells[c].children ?? const [],
                                    _base.copyWith(
                                      fontSize: 14,
                                      height: 1.4,
                                      fontWeight: header ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _unescape(String text) => text
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

/// A code block: language label, copy button, and code that scrolls sideways instead of wrapping.
class _CodeBlock extends StatefulWidget {
  const _CodeBlock({required this.code, required this.language});

  final String code;
  final String language;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  var _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.language.isEmpty ? 'code' : widget.language,
                    style: AppText.mono(12, color: AppColors.muted),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: _copied ? AppColors.accent : AppColors.muted,
                    minimumSize: const Size(44, 40),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _copy,
                  icon: AnimatedSwitcher(
                    duration: Motion.of(context, const Duration(milliseconds: 180)),
                    child: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      key: ValueKey(_copied),
                      size: 16,
                    ),
                  ),
                  label: Text(_copied ? l.copied : l.copyCode),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Text(widget.code, style: AppText.mono(13, color: const Color(0xFFD7DCE3)).copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}
