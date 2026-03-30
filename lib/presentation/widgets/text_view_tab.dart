// lib/presentation/widgets/text_view_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../../domain/entities/audio_book_part.dart';
import '../providers/providers.dart';

class TextViewTab extends ConsumerStatefulWidget {
  final AudioBookPart part;

  const TextViewTab({super.key, required this.part});

  @override
  ConsumerState<TextViewTab> createState() => _TextViewTabState();
}

class _TextViewTabState extends ConsumerState<TextViewTab> {
  final Map<String, String> _translationCache = {};
  String? _cachedCss;

  /// Загружает CSS с сервера
  Future<String> _getCssStyles() async {
    if (_cachedCss != null) return _cachedCss!;

    try {
      final response = await http.Client().get(
        Uri.parse('https://audiobooks.ironapps.ru/static/css/base.css'),
      );
      if (response.statusCode == 200) {
        _cachedCss = response.body;
        return _cachedCss!;
      }
    } catch (e) {
      print('Ошибка загрузки CSS: $e');
    }

    // Если CSS не загрузился, возвращаем базовые стили
    return '''
      body {
        padding: 16px;
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        font-size: 16px;
        line-height: 1.5;
      }
      .trn { color: #2e7d32; }
      .com { color: #666; font-style: italic; }
      .ref { color: #8B4513; font-weight: 500; }
    ''';
  }

  void _showTranslationDialog(String initialWord) async {
    final TextEditingController wordController = TextEditingController(
      text: initialWord,
    );

    final dialogState = ValueNotifier<({bool isLoading, String result})>((
      isLoading: true,
      result: '',
    ));

    _loadTranslation(initialWord, dialogState);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ValueListenableBuilder(
          valueListenable: dialogState,
          builder: (context, state, _) {
            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              content: SizedBox(
                width: double.maxFinite,
                height: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: wordController,
                              decoration: InputDecoration(
                                hintText: 'Введите слово для перевода',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: state.isLoading
                                ? null
                                : () async {
                                    final searchWord = wordController.text
                                        .trim();
                                    if (searchWord.isEmpty) return;
                                    await _loadTranslation(
                                      searchWord,
                                      dialogState,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: state.isLoading
                                  ? Colors.grey
                                  : Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Агурын'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: state.isLoading
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text('Загрузка перевода...'),
                                ],
                              ),
                            )
                          : state.result.isEmpty
                          ? const Center(child: Text('Перевод не найден'))
                          : FutureBuilder<String>(
                              future: _getCssStyles(),
                              builder: (context, cssSnapshot) {
                                if (!cssSnapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                return WebViewWidget(
                                  controller: WebViewController()
                                    ..loadHtmlString('''
                                          <!DOCTYPE html>
                                          <html>
                                          <head>
                                            <meta charset="UTF-8">
                                            <meta name="viewport" content="width=device-width, initial-scale=1.0">
                                            <style>
                                              body {
                                                padding: 16px;
                                                margin: 0;
                                                font-size: 16px;
                                                line-height: 1.5;
                                              }
                                              ${cssSnapshot.data}
                                            </style>
                                          </head>
                                          <body>
                                            ${state.result}
                                          </body>
                                          </html>
                                          ''')
                                    ..setJavaScriptMode(
                                      JavaScriptMode.unrestricted,
                                    )
                                    ..setBackgroundColor(Colors.transparent),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Закрыть'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadTranslation(
    String word,
    ValueNotifier<({bool isLoading, String result})> dialogState,
  ) async {
    dialogState.value = (isLoading: true, result: '');

    try {
      if (_translationCache.containsKey(word)) {
        dialogState.value = (
          isLoading: false,
          result: _translationCache[word]!,
        );
        return;
      }

      final html = await ref.read(
        translateWordProvider(
          TranslationParams(word: word, dialect: widget.part.dialect),
        ).future,
      );

      _translationCache[word] = html;
      dialogState.value = (isLoading: false, result: html);
    } catch (e) {
      dialogState.value = (isLoading: false, result: 'Ошибка: ${e.toString()}');
    }
  }

  void _onWordTap(String word) {
    _showTranslationDialog(word);
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
        if (word.length >= 2) {
          spans.add(
            TextSpan(
              text: word,
              style: const TextStyle(
                color: Colors.black,
                decoration: TextDecoration.none,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _onWordTap(word),
            ),
          );
        } else {
          spans.add(TextSpan(text: word));
        }
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

    if (text.isEmpty) {
      return const Center(child: Text('Текст отсутствует'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText.rich(
        _buildTextWithSpans(text),
        style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black),
      ),
    );
  }
}
