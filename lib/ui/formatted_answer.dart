import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Виджет для форматированного отображения ответа модели:
/// - Обычный текст с инлайн-кодом (`код`) и базовым форматированием
/// - Блоки кода (```lang ... ```) в стиле темной IDE (VS Code / JetBrains):
///   - Контрастная плашка с рамкой
///   - Бейдж языка программирования
///   - Кнопка моментального копирования сниппета в буфер обмена
///   - Моноширинный шрифт и синтаксическая подсветка ключевых слов
///   - Горизонтальный скролл без некрасивых разрывов строк
class FormattedAnswerView extends StatelessWidget {
  const FormattedAnswerView({
    super.key,
    required this.text,
    required this.baseColor,
    required this.fontSize,
    this.isBold = false,
  });

  final String text;
  final Color baseColor;
  final double fontSize;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildBlock(context, blocks[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildBlock(BuildContext context, AnswerBlock block) {
    if (block.isCode) {
      return _CodeSnippetBlock(
        code: block.content,
        language: block.language,
        baseFontSize: fontSize,
      );
    }

    return _RichTextBlock(
      content: block.content,
      baseColor: baseColor,
      fontSize: fontSize,
      isBold: isBold,
    );
  }

  @visibleForTesting
  static List<AnswerBlock> parseBlocksForTesting(String input) => _parseBlocks(input);

  static List<AnswerBlock> _parseBlocks(String input) {
    final blocks = <AnswerBlock>[];
    final lines = input.split('\n');

    bool inCode = false;
    String codeLang = '';
    final currentLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        if (inCode) {
          // Завершение блока кода
          blocks.add(AnswerBlock(
            isCode: true,
            language: codeLang.isEmpty ? 'CODE' : codeLang.toUpperCase(),
            content: currentLines.join('\n'),
          ));
          currentLines.clear();
          inCode = false;
          codeLang = '';
        } else {
          // Начало блока кода
          if (currentLines.isNotEmpty) {
            final text = currentLines.join('\n').trim();
            if (text.isNotEmpty) {
              blocks.add(AnswerBlock(isCode: false, content: text));
            }
            currentLines.clear();
          }
          inCode = true;
          codeLang = trimmed.substring(3).trim();
        }
      } else {
        currentLines.add(line);
      }
    }

    if (currentLines.isNotEmpty) {
      final text = currentLines.join('\n');
      if (inCode) {
        blocks.add(AnswerBlock(
          isCode: true,
          language: codeLang.isEmpty ? 'CODE' : codeLang.toUpperCase(),
          content: text,
        ));
      } else if (text.trim().isNotEmpty) {
        blocks.add(AnswerBlock(isCode: false, content: text.trim()));
      }
    }

    return blocks;
  }
}

class AnswerBlock {
  const AnswerBlock({
    required this.isCode,
    required this.content,
    this.language = '',
  });

  final bool isCode;
  final String content;
  final String language;
}

/// Виджет для рендеринга блока кода в стиле IDE с подсветкой и копированием
class _CodeSnippetBlock extends StatefulWidget {
  const _CodeSnippetBlock({
    required this.code,
    required this.language,
    required this.baseFontSize,
  });

  final String code;
  final String language;
  final double baseFontSize;

  @override
  State<_CodeSnippetBlock> createState() => _CodeSnippetBlockState();
}

class _CodeSnippetBlockState extends State<_CodeSnippetBlock> {
  bool _copied = false;

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final codeFontSize = (widget.baseFontSize * 0.95).clamp(11.0, 16.0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14171C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Шапка редактора: бейдж языка + кнопка Copy
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFF1B1F26),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Palette.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.language.isEmpty ? 'CODE' : widget.language,
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Palette.sec,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _copy,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check : Icons.copy_rounded,
                          size: 12,
                          color: _copied ? Palette.green : Palette.sec,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Copied' : 'Copy',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _copied ? Palette.green : Palette.sec,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Тело кода с подсветкой синтаксиса и горизонтальным скроллом
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SelectableText.rich(
              _SyntaxHighlighter.highlight(widget.code, widget.language),
              style: TextStyle(
                fontFamily: 'Menlo',
                fontFamilyFallback: const ['Monaco', 'Courier New', 'monospace'],
                fontSize: codeFontSize,
                height: 1.45,
                color: const Color(0xFFD4D7DC),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Виджет для обычного текста с поддержкой инлайн-кода (`код`) и жирного текста (**текст**)
class _RichTextBlock extends StatelessWidget {
  const _RichTextBlock({
    required this.content,
    required this.baseColor,
    required this.fontSize,
    required this.isBold,
  });

  final String content;
  final Color baseColor;
  final double fontSize;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final spans = _parseInlineSpans(content);

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          color: baseColor,
          fontSize: fontSize,
          height: 1.45,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
        ),
        children: spans,
      ),
    );
  }

  List<InlineSpan> _parseInlineSpans(String text) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(`[^`]+`|\*\*[^*]+\*\*)');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      final matched = match.group(0)!;
      if (matched.startsWith('`') && matched.endsWith('`') && matched.length >= 2) {
        final codeText = matched.substring(1, matched.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF22262E),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Palette.border),
            ),
            child: Text(
              codeText,
              style: TextStyle(
                fontFamily: 'Menlo',
                fontFamilyFallback: const ['Monaco', 'monospace'],
                fontSize: (fontSize * 0.9).clamp(10.0, 15.0),
                color: Palette.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ));
      } else if (matched.startsWith('**') && matched.endsWith('**') && matched.length >= 4) {
        final boldContent = matched.substring(2, matched.length - 2);
        spans.add(TextSpan(
          text: boldContent,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return spans;
  }
}

/// Легковесный синтаксический анализатор ключевых слов, типов, строк и комментариев в стиле темной темы IDE
class _SyntaxHighlighter {
  static const _keywordColor = Color(0xFFC678DD); // Фиолетово-розовый (def, class, return, if, func)
  static const _typeColor = Color(0xFFE5C07B);    // Теплый янтарный (int, str, List, bool, class names)
  static const _stringColor = Color(0xFF98C379);  // Зеленый (строки)
  static const _numberColor = Color(0xFFD19A66);  // Оранжевый (числа)
  static const _commentColor = Color(0xFF7F848E); // Приглушенный серый (комментарии)
  static const _builtinColor = Color(0xFF56B6C2); // Бирюзовый (self, this, true, false, null)

  static final _keywords = {
    'def', 'class', 'return', 'if', 'elif', 'else', 'for', 'while', 'in', 'is', 'not',
    'and', 'or', 'import', 'from', 'as', 'try', 'except', 'finally', 'raise', 'with',
    'async', 'await', 'lambda', 'yield', 'pass', 'break', 'continue', 'global',
    // Dart / JS / TS / C++ / Go
    'function', 'const', 'let', 'var', 'final', 'late', 'required', 'switch', 'case',
    'default', 'new', 'throw', 'catch', 'typeof', 'instanceof', 'interface', 'implements',
    'extends', 'override', 'static', 'enum', 'struct', 'fn', 'pub', 'mut', 'impl', 'trait',
    'select', 'where', 'join', 'group', 'by', 'order', 'having', 'insert', 'update',
  };

  static final _builtins = {
    'true', 'false', 'null', 'none', 'nil', 'self', 'this', 'super', 'undefined',
  };

  static final _types = {
    'int', 'float', 'str', 'bool', 'list', 'dict', 'set', 'tuple', 'any', 'void',
    'string', 'number', 'boolean', 'double', 'num', 'object', 'map', 'future', 'stream',
    'widget', 'buildcontext', 'statefulwidget', 'statelesswidget',
  };

  static TextSpan highlight(String code, String language) {
    final lines = code.split('\n');
    final lineSpans = <TextSpan>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      lineSpans.add(_highlightLine(line));
      if (i < lines.length - 1) {
        lineSpans.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(children: lineSpans);
  }

  static TextSpan _highlightLine(String line) {
    final spans = <TextSpan>[];

    // Проверка комментариев (# или //)
    final commentIdx = _findCommentIndex(line);
    String codePart = line;
    String commentPart = '';

    if (commentIdx != -1) {
      codePart = line.substring(0, commentIdx);
      commentPart = line.substring(commentIdx);
    }

    // Токенизация кодовой части (строки, идентификаторы, числа, операторы)
    final tokenRegex = RegExp(r'''("""[\s\S]*?"""|''' r"'''[\s\S]*?'''" r'''|"[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*'|\b\d+(?:\.\d+)?\b|\b[A-Za-z_][A-Za-z0-9_]*\b|[^\sA-Za-z0-9_]+|\s+)''');

    for (final match in tokenRegex.allMatches(codePart)) {
      final token = match.group(0)!;
      final lower = token.toLowerCase();

      if ((token.startsWith('"') && token.endsWith('"')) ||
          (token.startsWith("'") && token.endsWith("'"))) {
        spans.add(TextSpan(text: token, style: const TextStyle(color: _stringColor)));
      } else if (RegExp(r'^\d+(\.\d+)?$').hasMatch(token)) {
        spans.add(TextSpan(text: token, style: const TextStyle(color: _numberColor)));
      } else if (_keywords.contains(lower)) {
        spans.add(TextSpan(text: token, style: const TextStyle(color: _keywordColor, fontWeight: FontWeight.w600)));
      } else if (_builtins.contains(lower)) {
        spans.add(TextSpan(text: token, style: const TextStyle(color: _builtinColor)));
      } else if (_types.contains(lower) || (token.isNotEmpty && token[0] == token[0].toUpperCase() && token[0] != token[0].toLowerCase())) {
        spans.add(TextSpan(text: token, style: const TextStyle(color: _typeColor)));
      } else {
        spans.add(TextSpan(text: token));
      }
    }

    if (commentPart.isNotEmpty) {
      spans.add(TextSpan(
        text: commentPart,
        style: const TextStyle(color: _commentColor, fontStyle: FontStyle.italic),
      ));
    }

    return TextSpan(children: spans);
  }

  static int _findCommentIndex(String line) {
    bool inSingleQuote = false;
    bool inDoubleQuote = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"' && !inSingleQuote) {
        if (i == 0 || line[i - 1] != '\\') inDoubleQuote = !inDoubleQuote;
      } else if (char == "'" && !inDoubleQuote) {
        if (i == 0 || line[i - 1] != '\\') inSingleQuote = !inSingleQuote;
      } else if (!inSingleQuote && !inDoubleQuote) {
        if (char == '#') return i;
        if (char == '/' && i + 1 < line.length && line[i + 1] == '/') return i;
      }
    }
    return -1;
  }
}
