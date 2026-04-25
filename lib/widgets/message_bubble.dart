import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../core/app_locale.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
    this.reasoning,
    this.imagePaths = const [],
  });

  final String role;
  final String content;
  final String timestamp;
  final bool isStreaming;
  final String? reasoning;
  final List<String> imagePaths;

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Container(
            margin: const EdgeInsets.only(bottom: 22, left: 52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              color: isDark ? const Color(0xFF343436) : const Color(0xFFE6E7EB),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final path in imagePaths) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(path),
                      width: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (content.isNotEmpty) const SizedBox(height: 10),
                ],
                if (content.isNotEmpty)
                  Text(
                    content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.35,
                      color: isDark ? Colors.white : const Color(0xFF17181B),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final reasoningText = reasoning?.trim() ?? '';
    final hasReasoning = reasoningText.isNotEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 26),
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ThoughtBlock(
            text: hasReasoning ? reasoningText : null,
            isStreaming: isStreaming && !hasReasoning,
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: content.isEmpty ? (isStreaming ? '' : '(empty)') : content,
            selectable: true,
            extensionSet:
                md.ExtensionSet(md.ExtensionSet.gitHubFlavored.blockSyntaxes, [
                  _TexSyntax(display: true),
                  _TexSyntax(display: false),
                  ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                ]),
            builders: {'math': _MathBuilder()},
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    color: isDark ? Colors.white : const Color(0xFF17181B),
                  ),
                  listBullet: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.45,
                    color: isDark ? Colors.white : const Color(0xFF17181B),
                  ),
                  codeblockPadding: const EdgeInsets.all(12),
                  codeblockDecoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E20)
                        : const Color(0xFFEDEFF3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
          ),
          if (isStreaming && content.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark
                      ? const Color(0xFFB7B8BE)
                      : const Color(0xFF6F737C),
                ),
              ),
            ),
          if (!isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _CopyAction(content: content),
              ),
            ),
        ],
      ),
    );
  }
}

class _TexSyntax extends md.InlineSyntax {
  _TexSyntax({required this.display})
    : super(display ? r'\$\$((?:.|\n)+?)\$\$' : r'\$([^\$\n]+?)\$');

  final bool display;

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('math', match[1]!.trim());
    element.attributes['display'] = display.toString();
    parser.addNode(element);
    return true;
  }
}

class _MathBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final expression = element.textContent.trim();
    final isDisplay = element.attributes['display'] == 'true';
    final style =
        preferredStyle?.copyWith(fontSize: 17) ?? const TextStyle(fontSize: 17);
    final math = Math.tex(
      expression,
      mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
      textStyle: style,
      onErrorFallback: (_) => Text(expression, style: preferredStyle),
    );
    if (!isDisplay) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: math,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: math,
    );
  }
}

class _CopyAction extends StatefulWidget {
  const _CopyAction({required this.content});

  final String content;

  @override
  State<_CopyAction> createState() => _CopyActionState();
}

class _CopyActionState extends State<_CopyAction> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: _copied
          ? appText(context, zh: '已复制', en: 'Copied')
          : appText(context, zh: '复制', en: 'Copy'),
      child: IconButton(
        onPressed: _copy,
        icon: Icon(
          _copied ? Icons.check_rounded : Icons.copy_rounded,
          size: 22,
          color: _copied
              ? const Color(0xFF6EA981)
              : (isDark ? const Color(0xFF8D8F96) : const Color(0xFF7B7F88)),
        ),
      ),
    );
  }
}

class _ThoughtBlock extends StatelessWidget {
  const _ThoughtBlock({required this.text, required this.isStreaming});

  final String? text;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isStreaming
                  ? appText(context, zh: '思考中...', en: 'Thinking...')
                  : appText(context, zh: '思考', en: 'Thought'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDark
                    ? const Color(0xFF9EA0A8)
                    : const Color(0xFF777B84),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? const Color(0xFF9EA0A8) : const Color(0xFF777B84),
            ),
          ],
        ),
        if (content != null && content.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 2,
                height: 96,
                color: isDark
                    ? const Color(0xFF4B4C52)
                    : const Color(0xFFD6D8DE),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: isDark
                        ? const Color(0xFFB6B7BD)
                        : const Color(0xFF70747D),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
