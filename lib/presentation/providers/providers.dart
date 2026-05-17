// lib/presentation/providers/providers.dart
import 'dart:async';

import 'package:flutter_iron_chinyg/data/database/database_helper.dart';
import 'package:flutter_iron_chinyg/data/repositories/audio_book_cache_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/audio_book_remote_datasource.dart';
import '../../data/datasources/translation_remote_datasource.dart';
import '../../data/repositories/audio_book_repository_impl.dart';
import '../../data/repositories/translation_repository_impl.dart';
import '../../domain/repositories/audio_book_repository.dart';
import '../../domain/repositories/translation_repository.dart';
import '../../domain/entities/audio_book_preview.dart';
import '../../domain/entities/audio_book.dart';
import '../../domain/entities/audio_book_part.dart';

final httpClientProvider = Provider<http.Client>((ref) => http.Client());

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});

final audioBookCacheRepositoryProvider = Provider<AudioBookCacheRepository>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) throw Exception('SharedPreferences not initialized');
  return AudioBookCacheRepository(prefs: prefs);
});

final audioBookRemoteDataSourceProvider = Provider<AudioBookRemoteDataSource>((
  ref,
) {
  return AudioBookRemoteDataSource(client: ref.watch(httpClientProvider));
});

final audioBookRepositoryProvider = Provider<AudioBookRepository>((ref) {
  return AudioBookRepositoryImpl(
    remoteDataSource: ref.watch(audioBookRemoteDataSourceProvider),
  );
});

/// Провайдер списка книг с кэшированием (сначала БД, потом сеть)
final audioBookPreviewsProvider = FutureProvider<List<AudioBookPreview>>((
  ref,
) async {
  final cacheRepo = ref.watch(audioBookCacheRepositoryProvider);
  final remoteRepo = ref.watch(audioBookRepositoryProvider);

  final cached = await cacheRepo.loadBooks();

  if (cached != null && cached.isNotEmpty) {
    // Есть кэш – возвращаем его, а в фоне обновляем
    unawaited(
      remoteRepo.getAudioBookPreviews().then((result) {
        result.fold((failure) => null, (freshBooks) async {
          await cacheRepo.saveBooks(freshBooks);
        });
      }),
    );
    return cached;
  } else {
    // Кэша нет – ждём сеть
    final result = await remoteRepo.getAudioBookPreviews();
    return result.fold((failure) => throw failure, (books) {
      cacheRepo.saveBooks(books);
      return books;
    });
  }
});

// 📚 Провайдер для детальной информации о книге
final audioBookDetailsProvider = FutureProvider.family<AudioBook, int>((
  ref,
  bookId,
) async {
  final repository = ref.watch(audioBookRepositoryProvider);
  final result = await repository.getAudioBookDetails(bookId);

  return result.fold((failure) => throw failure, (book) => book);
});

// 🌐 Translation Data Source
final translationRemoteDataSourceProvider =
    Provider<TranslationRemoteDataSource>((ref) {
      return TranslationRemoteDataSource(client: ref.watch(httpClientProvider));
    });

// 📚 Translation Repository
final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return TranslationRepositoryImpl(
    remoteDataSource: ref.watch(translationRemoteDataSourceProvider),
  );
});

// 🈂️ Параметры для перевода
class TranslationParams {
  final String word;
  final Dialect dialect;

  const TranslationParams({required this.word, required this.dialect});
}

// 🈂️ Провайдер для перевода слова
final translateWordProvider = FutureProvider.family<String, TranslationParams>((
  ref,
  params,
) async {
  final repository = ref.watch(translationRepositoryProvider);
  final result = await repository.translateWord(params.word, params.dialect);

  return result.fold((failure) => throw failure, (html) => html);
});

// ⚠️ Устаревшие провайдеры (оставлены для обратной совместимости)
@Deprecated(
  'Используйте audioBookPreviewsProvider для списка и audioBookDetailsProvider для деталей',
)
final audioBooksProvider = FutureProvider<List<AudioBook>>((ref) async {
  final repository = ref.watch(audioBookRepositoryProvider);
  final result = await repository.getAudioBooks();

  return result.fold((failure) => throw failure, (books) => books);
});

final databaseHelperProvider = Provider<DatabaseHelper>(
  (ref) => DatabaseHelper(),
);

// Провайдер для избранного
// final favoriteBooksProvider = FutureProvider<List<AudioBookPreview>>((
//   ref,
// ) async {
//   final db = ref.watch(databaseHelperProvider);
//   return await db.getFavoriteBooks();
// });
