// lib/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/providers.dart';
import '../widgets/loading_widget.dart';
import 'player_page.dart';
import '../../domain/entities/audio_book_preview.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final previewsAsync = ref.watch(audioBookPreviewsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ирон чиныг'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(audioBookPreviewsProvider);
            },
          ),
        ],
      ),
      body: previewsAsync.when(
        loading: () => const LoadingWidget(message: 'Загрузка списка книг...'),
        data: (previews) {
          if (previews.isEmpty) {
            return _buildEmptyState();
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(audioBookPreviewsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: previews.length,
              itemBuilder: (context, index) {
                final preview = previews[index];
                return _buildBookCard(preview);
              },
            ),
          );
        },
        error: (error, stackTrace) => _buildErrorState(),
      ),
    );
  }

  Widget _buildBookCard(AudioBookPreview book) {
    // Определяем форму слова "кæсы" или "кæсынц" в зависимости от количества чтецов
    final readerPrefix = _getReaderPrefix(book.reader);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToPlayer(context, book.id),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 130,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Обложка книги
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: book.coverUrl,
                    width: 80,
                    height: 106,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 80,
                      height: 106,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 80,
                      height: 106,
                      color: Colors.grey[300],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.book, size: 32, color: Colors.grey[600]),
                          const SizedBox(height: 4),
                          Text(
                            'нет\nобложки',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Информация о книге
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Название книги
                      Text(
                        book.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Автор
                      Text(
                        book.author,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Чтецы — два блока: слева метка, справа имена
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Левая часть: "Чиныг кæсы:" или "Чиныг кæсынц:"
                          Text(
                            readerPrefix,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Правая часть: имена чтецов
                          Expanded(
                            child: Text(
                              book.reader,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getReaderPrefix(String reader) {
    // Проверяем, есть ли несколько чтецов
    // Разделители: запятая, точка с запятой, " и ", " , ", " ; "
    if (reader.contains(',') ||
        reader.contains(';') ||
        reader.contains(' и ') ||
        reader.contains(',')) {
      return 'Чиныг кæсынц:';
    }
    return 'Чиныг кæсы:';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Нет доступных аудиокниг',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Проверьте подключение к интернету',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(audioBookPreviewsProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Бафæлварын ногæй'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 80, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Рæдыд!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.red[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Нæ фæцис бастæн интернетима',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(audioBookPreviewsProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Бафæлварын ногæй'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPlayer(BuildContext context, int bookId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlayerPage(bookId: bookId)),
    );
  }
}
