// lib/data/repositories/audio_book_repository_impl.dart
import 'package:dartz/dartz.dart';

import '../../domain/repositories/audio_book_repository.dart';
import '../../domain/entities/audio_book.dart';
import '../../domain/entities/audio_book_preview.dart';
import '../../domain/entities/audio_book_part.dart';
import '../../core/errors/failures.dart';
import '../datasources/audio_book_remote_datasource.dart';
import '../models/audio_book_model.dart';
import '../models/audio_book_part_model.dart';

/// Реализация репозитория аудиокниг
class AudioBookRepositoryImpl implements AudioBookRepository {
  final AudioBookRemoteDataSource remoteDataSource;

  // Базовый URL для медиа-файлов
  static const String _mediaBaseUrl = 'https://audiobooks.ironapps.ru/media/';

  AudioBookRepositoryImpl({required this.remoteDataSource});

  // ⚡ БЫСТРЫЙ МЕТОД для главного экрана - только превью книг, БЕЗ загрузки частей
  @override
  Future<Either<Failure, List<AudioBookPreview>>> getAudioBookPreviews() async {
    try {
      // 1. Получаем только список книг (без частей)
      final bookModels = await remoteDataSource.getBooks();

      if (bookModels.isEmpty) {
        return const Right([]);
      }

      // 2. Преобразуем в Preview (только данные из JSON)
      final previews = bookModels
          .where((model) => model.published)
          .map(
            (model) => AudioBookPreview(
              id: model.id,
              title: model.title,
              author: model.author,
              description: model.description,
              reader: model.reader,
              coverUrl: '$_mediaBaseUrl${model.cover}',
              order: model.order,
            ),
          )
          .toList();

      // 3. Сортируем по порядку
      previews.sort((a, b) => a.order.compareTo(b.order));

      return Right(previews);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (e) {
      return Left(ServerFailure(message: 'Неизвестная ошибка: $e'));
    }
  }

  // 📚 ПОЛНЫЙ МЕТОД для экрана плеера - загружает книгу со всеми частями
  @override
  Future<Either<Failure, AudioBook>> getAudioBookDetails(int id) async {
    try {
      // 1. Получаем информацию о книге
      final bookModels = await remoteDataSource.getBooks();

      final bookModel = bookModels.firstWhere(
        (model) => model.id == id && model.published,
        orElse: () => throw ServerFailure(message: 'Книга с ID $id не найдена'),
      );

      // 2. Загружаем части ТОЛЬКО для этой книги
      final partModels = await remoteDataSource.getBookPartsWithText(id);

      // 3. Преобразуем части
      final parts = partModels
          .where((part) => part.published)
          .map((part) => _createAudioBookPart(part, bookModel.folder))
          .toList();

      // 4. Создаем полную книгу
      final book = AudioBook(
        id: bookModel.id,
        title: bookModel.title,
        author: bookModel.author,
        description: bookModel.description,
        reader: bookModel.reader,
        coverUrl: '$_mediaBaseUrl${bookModel.cover}',
        order: bookModel.order,
        parts: parts,
      );

      return Right(book);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (e) {
      return Left(ServerFailure(message: 'Ошибка загрузки деталей книги: $e'));
    }
  }

  // 🎯 Вспомогательный метод для создания части книги
  AudioBookPart _createAudioBookPart(AudioBookPartModel model, String folder) {
    // Извлекаем имя файла из полного пути
    // audiofile приходит как "audio/37_kokaev_t_arvganan/07_gabueva_sabyr_sagas.mp3"
    final fileName = model.audiofile.split('/').last;

    // Формируем правильный URL: media/audio/папка_книги/имя_файла
    final audioUrl = '${_mediaBaseUrl}audio/$folder/$fileName';

    // Парсим длительность из формата "ММ:СС" в Duration
    final duration = _parseDuration(model.length);

    // Определяем диалект (IRN -> iron, DIG -> digor)
    final dialect = model.dialect == 'IRN' ? Dialect.iron : Dialect.digor;

    return AudioBookPart(
      id: model.id,
      bookId: model.bookId,
      title: model.title,
      text: model.text,
      reader: model.reader,
      audioUrl: audioUrl,
      duration: duration,
      order: model.order,
      dialect: dialect, // Добавляем диалект
    );
  }

  // ⏱ Парсинг длительности
  Duration _parseDuration(String length) {
    try {
      final parts = length.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return Duration(minutes: minutes, seconds: seconds);
      }
    } catch (e) {
      print('⚠️ Ошибка парсинга длительности "$length": $e');
    }
    return Duration.zero;
  }

  // ⚠️ Deprecated - оставляем для обратной совместимости, но не используем
  @override
  @Deprecated(
    'Используйте getAudioBookPreviews() для списка и getAudioBookDetails() для деталей',
  )
  Future<Either<Failure, List<AudioBook>>> getAudioBooks() async {
    // Этот метод больше не нужен, но оставляем заглушку
    return Left(ServerFailure(message: 'Метод устарел'));
  }

  @override
  @Deprecated('Используйте getAudioBookDetails() вместо getAudioBookById()')
  Future<Either<Failure, AudioBook>> getAudioBookById(int id) async {
    return Left(ServerFailure(message: 'Метод устарел'));
  }
}
