// lib/presentation/providers/providers.dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter_iron_chinyg/data/repositories/playback_repository_impl.dart';
import 'package:flutter_iron_chinyg/domain/entities/playback_progress.dart';
import 'package:flutter_iron_chinyg/domain/repositories/playback_repository.dart';
import 'package:flutter_iron_chinyg/services/audio_player_service.dart';
import 'package:flutter_iron_chinyg/services/audio_service_factory.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:riverpod/riverpod.dart';
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

// 💾 SharedPreferences
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});

// 📊 Playback Repository
final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) {
    throw Exception('SharedPreferences не инициализированы');
  }
  return PlaybackRepositoryImpl(prefs: prefs);
});

// 🎯 Провайдер для прогресса книги
final bookProgressProvider = FutureProvider.family<List<PlaybackProgress>, int>(
  (ref, bookId) async {
    final repository = ref.watch(playbackRepositoryProvider);
    final result = await repository.getBookProgress(bookId);

    return result.fold((failure) => throw failure, (progresses) => progresses);
  },
);

// 🎵 Audio Service провайдер
final audioServiceProvider = FutureProvider<AudioPlayerService>((ref) async {
  // Инициализируем just_audio_background
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ironapp.ironaudiobooks.channel.audio',
    androidNotificationChannelName: 'Аудиоплеер',
    androidNotificationOngoing: true,
  );

  // Запускаем сервис
  return await AudioService.init(
    builder: getAudioPlayerService,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ironapp.ironaudiobooks.channel.audio',
      androidNotificationChannelName: 'Аудиоплеер',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
});

// Синглтон сервиса
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  return AudioPlayerService.instance;
});

// Поток состояния плеера с начальным значением
final playbackStatusProvider = StreamProvider<PlaybackStatus>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.statusStream;
});
