// lib/presentation/providers/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/datasources/audio_book_remote_datasource.dart';
import '../../data/datasources/translation_remote_datasource.dart';
import '../../data/repositories/audio_book_repository_impl.dart';
import '../../data/repositories/translation_repository_impl.dart';
import '../../domain/repositories/audio_book_repository.dart';
import '../../domain/repositories/translation_repository.dart';
import '../../domain/entities/audio_book_preview.dart';
import '../../domain/entities/audio_book.dart';
import '../../domain/entities/audio_book_part.dart';

// 🌐 HTTP клиент
final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

// 📡 Remote Data Source
final audioBookRemoteDataSourceProvider = Provider<AudioBookRemoteDataSource>((
  ref,
) {
  return AudioBookRemoteDataSource(client: ref.watch(httpClientProvider));
});

// 📦 Репозиторий
final audioBookRepositoryProvider = Provider<AudioBookRepository>((ref) {
  return AudioBookRepositoryImpl(
    remoteDataSource: ref.watch(audioBookRemoteDataSourceProvider),
  );
});

// 🖼️ Провайдер для списка книг (превью)
final audioBookPreviewsProvider = FutureProvider<List<AudioBookPreview>>((
  ref,
) async {
  final repository = ref.watch(audioBookRepositoryProvider);
  final result = await repository.getAudioBookPreviews();

  return result.fold((failure) => throw failure, (previews) => previews);
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
