// lib/presentation/widgets/text_view_tab.dart
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
  AudioPlayerService? _service;

  // Кэш для WebView контроллеров по частям
  final Map<int, WebViewController> _webViewControllers = {};

  // Флаг, нужно ли сохранять состояние
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    final service = await AudioPlayerService.forBook(
      widget.book.id,
      widget.book.parts,
    );

    if (mounted) {
      setState(() {
        _service = service;
        _currentIndex = service.currentIndex;
        _currentText = _getCurrentText(service);
      });

      // Предзагружаем первую часть
      _preloadPartContent(_currentIndex);

      service.statusStream.listen((status) {
        if (mounted) {
          final newIndex = service.currentIndex;
          if (newIndex != _currentIndex) {
            setState(() {
              _currentIndex = newIndex;
              _currentText = _getCurrentText(service);
            });
            // Загружаем новую часть
            _loadPartContent(_currentIndex);
          }
        }
      });
    }
  }

  // Предзагрузка содержимого части
  Future<void> _preloadPartContent(int index) async {
    if (index < 0 || index >= widget.book.parts.length) return;
    if (_webViewControllers.containsKey(index)) return;

    final part = widget.book.parts[index];
    final text = part.text ?? '';
    if (text.isEmpty) return;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent);

    await controller.loadHtmlString(_buildHtmlContent(text));
    _webViewControllers[index] = controller;
  }

  // Загрузка содержимого части
  Future<void> _loadPartContent(int index) async {
    if (index < 0 || index >= widget.book.parts.length) return;

    // Если уже есть в кэше, просто показываем
    if (_webViewControllers.containsKey(index)) return;

    final part = widget.book.parts[index];
    final text = part.text ?? '';
    if (text.isEmpty) return;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent);

    await controller.loadHtmlString(_buildHtmlContent(text));
    _webViewControllers[index] = controller;
  }

  String _getCurrentText(AudioPlayerService service) {
    final parts = widget.book.parts;
    final currentIndex = service.currentIndex;
    if (currentIndex >= 0 && currentIndex < parts.length) {
      return parts[currentIndex].text ?? '';
    }
    return '';
  }

  String _buildHtmlContent(String text) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes">
        <style>
          body {
            padding: 16px;
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            font-size: 16px;
            line-height: 1.5;
            background-color: #ffffff;
          }
          .word {
            font-size: 28px;
            font-weight: bold;
            color: #2c3e50;
            margin-bottom: 16px;
            padding-bottom: 8px;
            border-bottom: 2px solid #eee;
          }
          .trn {
            color: #2e7d32 !important;
            font-weight: 500;
          }
          .com {
            color: #666666 !important;
            font-style: italic !important;
          }
          .ref {
            color: #8B4513 !important;
            font-weight: 500;
          }
          .ex {
            list-style-type: none;
            margin-left: 20px;
            padding: 4px 0;
          }
          .ex li {
            color: #1a1a1a;
            margin-bottom: 4px;
            font-style: italic;
          }
          .m1 {
            margin-top: 12px;
            margin-bottom: 4px;
          }
          .m2 {
            margin-left: 16px;
            margin-top: 4px;
            margin-bottom: 4px;
          }
          .m3 {
            margin-left: 32px;
            margin-top: 4px;
            margin-bottom: 4px;
          }
          i, em {
            font-style: italic;
          }
          b, strong {
            font-weight: bold;
          }
          ul {
            margin: 0;
            padding-left: 20px;
          }
          li {
            margin-bottom: 4px;
          }
        </style>
      </head>
      <body>
        ${text.replaceAll('\n', '<br>')}
      </body>
      </html>
    ''';
  }

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
    if (_service == null) return;

    final currentPart = _service!.currentPart;
    if (currentPart == null) return;

    final TextEditingController wordController = TextEditingController(
      text: initialWord,
    );

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
    super.build(context); // Для AutomaticKeepAliveClientMixin

    if (_service == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final parts = widget.book.parts;
    final currentPart = _currentIndex >= 0 && _currentIndex < parts.length
        ? parts[_currentIndex]
        : null;
    final text = currentPart?.text ?? '';

    if (text.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.text_fields, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Выберите часть для отображения текста'),
          ],
        ),
      );
    }

    // Используем кэшированный WebViewController или создаем новый
    final controller = _webViewControllers[_currentIndex];
    if (controller != null) {
      return WebViewWidget(controller: controller);
    }

    // Если нет в кэше, создаем и загружаем
    return FutureBuilder(
      future: _loadPartContent(_currentIndex),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final newController = _webViewControllers[_currentIndex];
        if (newController != null) {
          return WebViewWidget(controller: newController);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
