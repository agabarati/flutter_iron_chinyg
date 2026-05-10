import 'package:flutter/material.dart';
import 'package:flutter_iron_chinyg/domain/entities/audio_book_part.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/audio_player_service.dart';
import '../../domain/entities/audio_book.dart';
import '../providers/providers.dart';

class TextViewTab extends ConsumerStatefulWidget {
  final AudioBook book;
  const TextViewTab({super.key, required this.book});

  @override
  ConsumerState<TextViewTab> createState() => _TextViewTabState();
}

class _TextViewTabState extends ConsumerState<TextViewTab>
    with AutomaticKeepAliveClientMixin {
  final Map<String, String> _translationCache = {};
  String? _cachedCss;
  int _currentIndex = -1;
  String _currentText = '';
  late final AudioPlayerService _service = AudioPlayerService.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentIndex = _service.currentIndex;
    _currentText = _getCurrentText();
    _service.statusStream.listen((_) {
      if (mounted) {
        final newIndex = _service.currentIndex;
        final newText = _getCurrentText();
        if (newIndex != _currentIndex || newText != _currentText) {
          setState(() {
            _currentIndex = newIndex;
            _currentText = newText;
          });
        }
      }
    });
  }

  String _getCurrentText() {
    final parts = widget.book.parts;
    final idx = _service.currentIndex;
    return (idx >= 0 && idx < parts.length) ? parts[idx].text ?? '' : '';
  }

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
    return '';
  }

  void _showTranslationDialog(String initialWord) async {
    final currentPart = _service.currentPart;
    if (currentPart == null) return;

    final wordController = TextEditingController(text: initialWord);
    final dialogState = ValueNotifier<({bool isLoading, String result})>((
      isLoading: true,
      result: '',
    ));

    _loadTranslation(initialWord, currentPart.dialect, dialogState);

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
                                      currentPart.dialect,
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
                          ? const Center(child: CircularProgressIndicator())
                          : state.result.isEmpty
                          ? const Center(child: Text('Тӕлмац не ссардӕуыд'))
                          : FutureBuilder<String>(
                              future: _getCssStyles(),
                              builder: (context, cssSnapshot) {
                                if (!cssSnapshot.hasData)
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                return WebViewWidget(
                                  controller: WebViewController()
                                    ..loadHtmlString('''
                                          <!DOCTYPE html>
                                          <html>
                                          <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
                                          <style>body{padding:16px;margin:0;font-size:16px;line-height:1.5;}${cssSnapshot.data}</style>
                                          </head>
                                          <body>${state.result}</body>
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
                  child: const Text('Сæхгæнын'),
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
    Dialect dialect,
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
          TranslationParams(word: word, dialect: dialect),
        ).future,
      );
      _translationCache[word] = html;
      dialogState.value = (isLoading: false, result: html);
    } catch (e) {
      dialogState.value = (isLoading: false, result: 'Рæдыд: ${e.toString()}');
    }
  }

  void _onWordTap(String word) => _showTranslationDialog(word);

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
                color: Color(0xFF333333), // тёмно-серый
                decoration: TextDecoration.none,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _onWordTap(word),
            ),
          );
        } else {
          spans.add(
            TextSpan(
              text: word,
              style: const TextStyle(color: Color(0xFF333333)),
            ),
          );
        }
        pos += word.length;
      }
      final sepMatch = separatorPattern.matchAsPrefix(text, pos);
      if (sepMatch != null) {
        spans.add(
          TextSpan(
            text: sepMatch.group(0)!,
            style: const TextStyle(color: Color(0xFF333333)),
          ),
        );
        pos += sepMatch.group(0)!.length;
      }
    }
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_currentText.isEmpty) {
      return const Center(child: Text('Выберите часть для отображения текста'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText.rich(
        _buildTextWithSpans(_currentText),
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: Color(0xFF333333),
        ), // базовый стиль для всего текста
      ),
    );
  }
}
