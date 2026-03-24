// lib/presentation/providers/providers.dart
import 'package:http/http.dart' as http;
import 'package:riverpod/riverpod.dart';

import '../../data/datasources/audio_book_remote_datasource.dart';
import '../../data/datasources/translation_remote_datasource.dart';
import '../../data/repositories/audio_book_repository_impl.dart';
import '../../data/repositories/translation_repository_impl.dart';
import '../../domain/repositories/audio_book_repository.dart';
import '../../domain/repositories/translation_repository.dart';
import '../../domain/entities/audio_book_preview.dart';
import '../../domain/entities/audio_book.dart';
import '../../domain/entities/audio_book_part.dart';

// HTTP клиент
final httpClientProvider = Provider<http.Client>((ref) => http.Client());

// Remote Data Source (аудио)
final audioBookRemoteDataSourceProvider = Provider<AudioBookRemoteDataSource>((
  ref,
) {
  return AudioBookRemoteDataSource(client: ref.watch(httpClientProvider));
});

// Репозиторий (аудио)
final audioBookRepositoryProvider = Provider<AudioBookRepository>((ref) {
  return AudioBookRepositoryImpl(
    remoteDataSource: ref.watch(audioBookRemoteDataSourceProvider),
  );
});

// Превью книг (главный экран)
final audioBookPreviewsProvider = FutureProvider<List<AudioBookPreview>>((
  ref,
) async {
  final repository = ref.watch(audioBookRepositoryProvider);
  final result = await repository.getAudioBookPreviews();
  return result.fold((failure) => throw failure, (data) => data);
});

// Детали книги (плеер)
final audioBookDetailsProvider = FutureProvider.family<AudioBook, int>((
  ref,
  bookId,
) async {
  final repository = ref.watch(audioBookRepositoryProvider);
  final result = await repository.getAudioBookDetails(bookId);
  return result.fold((failure) => throw failure, (data) => data);
});

// Перевод
final translationRemoteDataSourceProvider =
    Provider<TranslationRemoteDataSource>((ref) {
      return TranslationRemoteDataSource(client: ref.watch(httpClientProvider));
    });

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return TranslationRepositoryImpl(
    remoteDataSource: ref.watch(translationRemoteDataSourceProvider),
  );
});

class TranslationParams {
  final String word;
  final Dialect dialect;
  const TranslationParams({required this.word, required this.dialect});
}

final translateWordProvider = FutureProvider.family<String, TranslationParams>((
  ref,
  params,
) async {
  final repo = ref.watch(translationRepositoryProvider);
  final result = await repo.translateWord(params.word, params.dialect);
  return result.fold((failure) => throw failure, (html) => html);
});
