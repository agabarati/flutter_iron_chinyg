// lib/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/providers.dart';
import '../widgets/loading_widget.dart';
import 'player_page.dart'; // Добавляем импорт
import '../../domain/entities/audio_book_preview.dart';
import '../../core/errors/failures.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    // Используем провайдер для превью книг
    final previewsAsync = ref.watch(audioBookPreviewsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ирон чиныг'),
        actions: [
          // Кнопка обновления
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(audioBookPreviewsProvider);
            },
          ),
        ],
      ),
      body: previewsAsync.when(
        // Состояние загрузки
        loading: () => const LoadingWidget(message: 'Загрузка списка книг...'),

        // Данные загружены успешно
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

        // Ошибка загрузки
        error: (error, stackTrace) => _buildErrorState(error),
      ),
    );
  }

  // 🃏 Карточка книги
  Widget _buildBookCard(AudioBookPreview book) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToPlayer(context, book.id),
        borderRadius: BorderRadius.circular(12),
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
                  height: 100,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 80,
                    height: 100,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 80,
                    height: 100,
                    color: Colors.grey[300],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book, size: 40, color: Colors.grey[600]),
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
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Читает: ${book.reader}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Описание (если есть)
                    if (book.description != null &&
                        book.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        book.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Стрелка вправо
              Container(
                margin: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📭 Состояние "пустой список"
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
            label: const Text('Обновить'),
          ),
        ],
      ),
    );
  }

  // ❌ Состояние ошибки
  Widget _buildErrorState(Object error) {
    String errorMessage = 'Произошла неизвестная ошибка';

    if (error is Failure) {
      errorMessage = error.message;
    } else {
      errorMessage = error.toString();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(audioBookPreviewsProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить попытку'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 Навигация к экрану плеера
  void _navigateToPlayer(BuildContext context, int bookId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlayerPage(bookId: bookId)),
    );
  }
}
