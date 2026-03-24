// lib/presentation/widgets/text_view_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../domain/entities/audio_book_part.dart';
import '../providers/providers.dart';

class TextViewTab extends ConsumerStatefulWidget {
  final AudioBookPart part;

  const TextViewTab({super.key, required this.part});

  @override
  ConsumerState<TextViewTab> createState() => _TextViewTabState();
}

class _TextViewTabState extends ConsumerState<TextViewTab> {
  void _showTranslationDialog(String word, String htmlContent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(word),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(child: HtmlWidget(htmlContent)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _onWordTap(String word) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final html = await ref.read(
        translateWordProvider(
          TranslationParams(word: word, dialect: widget.part.dialect),
        ).future,
      );

      if (context.mounted) Navigator.pop(context);
      if (context.mounted) _showTranslationDialog(word, html);
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось перевести слово "$word"'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  TextSpan _buildTextWithSpans(String text) {
    final spans = <TextSpan>[];
    final wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);
    final separatorPattern = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

    int pos = 0;
    while (pos < text.length) {
      final wordMatch = wordPattern.matchAsPrefix(text, pos);
      if (wordMatch != null) {
        final word = wordMatch.group(0)!;
        spans.add(
          TextSpan(
            text: word,
            style: const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _onWordTap(word),
          ),
        );
        pos += word.length;
      }

      final sepMatch = separatorPattern.matchAsPrefix(text, pos);
      if (sepMatch != null) {
        spans.add(TextSpan(text: sepMatch.group(0)!));
        pos += sepMatch.group(0)!.length;
      }
    }

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.part.text ?? 'Текст отсутствует';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText.rich(
        _buildTextWithSpans(text),
        style: const TextStyle(fontSize: 16, height: 1.5),
      ),
    );
  }
}
