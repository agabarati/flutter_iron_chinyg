import 'package:dartz/dartz.dart';
import 'package:flutter_iron_chinyg/domain/entities/audio_book_part_preview.dart';
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
  static const String _mediaBaseUrl = 'https://audiobooks.ironapps.ru/media/';

  AudioBookRepositoryImpl({required this.remoteDataSource});

  // ==================== БЫСТРЫЙ МЕТОД ДЛЯ СПИСКА КНИГ ====================
  @override
  Future<Either<Failure, List<AudioBookPreview>>> getAudioBookPreviews() async {
    try {
      final bookModels = await remoteDataSource.getBooks();
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
      // previews.sort((a, b) => a.order.compareTo(b.order));
      return Right(previews);
    } catch (e) {
      return Left(ServerFailure(message: 'Ошибка загрузки списка книг: $e'));
    }
  }

  // ==================== ОПТИМИЗИРОВАННЫЙ МЕТОД ДЛЯ ЭКРАНА ПЛЕЕРА ====================
  @override
  Future<Either<Failure, AudioBook>> getAudioBookDetails(int id) async {
    try {
      // 1. Получаем полные данные одним запросом
      final data = await remoteDataSource.getFullAudioBook(id);

      // 2. Парсим данные о книге
      final audiobook = data['audiobook'] as Map<String, dynamic>;
      final partsJson = data['audioparts'] as List;

      // 3. Преобразуем каждую часть в бизнес-сущность
      final List<AudioBookPart> parts = partsJson.map((partMap) {
        return _createAudioBookPartFromJson(
          partMap,
          audiobook['folder'] as String,
        );
      }).toList();

      // 4. Формируем готовую бизнес-сущность
      final book = AudioBook(
        id: audiobook['id'] as int,
        title: audiobook['title'] as String,
        author: audiobook['author'] as String,
        description: audiobook['description'] as String?,
        reader: audiobook['reader'] as String,
        coverUrl: '$_mediaBaseUrl${audiobook['cover']}',
        order: audiobook['order_field'] as int? ?? 0,
        parts: parts,
      );

      return Right(book);
    } catch (e) {
      return Left(ServerFailure(message: 'Ошибка загрузки деталей книги: $e'));
    }
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

  /// Создаёт AudioBookPart из JSON-объекта, полученного от эндпоинта /audiobook/{id}
  AudioBookPart _createAudioBookPartFromJson(
    Map<String, dynamic> json,
    String folder,
  ) {
    final audiofile = json['audiofile'] as String;
    final fileName = audiofile.split('/').last;
    final audioUrl = '${_mediaBaseUrl}audio/$folder/$fileName';
    final duration = _parseDuration(json['length'] as String);
    final dialect = json['dialect'] == 'IRN' ? Dialect.iron : Dialect.digor;

    return AudioBookPart(
      id: json['id'] as int,
      bookId: json['book_id'] as int,
      title: json['title'] as String?,
      text: json['text'] as String?,
      reader: json['reader'] as String,
      audioUrl: audioUrl,
      duration: duration,
      order: json['order'] as int? ?? 0,
      dialect: dialect,
      coverUrl: '',
    );
  }

  /// Парсит строку длительности "ММ:СС" в Duration
  Duration _parseDuration(String length) {
    try {
      final parts = length.split(':');
      if (parts.length == 2) {
        return Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
        );
      }
    } catch (e) {
      print('Ошибка парсинга длительности "$length": $e');
    }
    return Duration.zero;
  }

  // ==================== УСТАРЕВШИЕ МЕТОДЫ (ОСТАВЛЕНЫ ДЛЯ СОВМЕСТИМОСТИ) ====================

  @override
  Future<Either<Failure, List<AudioBook>>> getAudioBooks() async {
    // Устаревший метод – перенаправляем на getAudioBookDetails для каждой книги
    final previewsResult = await getAudioBookPreviews();
    return previewsResult.fold((failure) => Left(failure), (previews) async {
      final List<AudioBook> books = [];
      for (final preview in previews) {
        final bookResult = await getAudioBookDetails(preview.id);
        bookResult.fold((failure) => null, (book) => books.add(book));
      }
      return Right(books);
    });
  }

  @override
  Future<Either<Failure, AudioBook>> getAudioBookById(int id) async {
    return getAudioBookDetails(id);
  }

  // Остальные методы, если требуются (getBookPartsLight, getFullPart и т.д.), можно не реализовывать или оставить заглушки.
  // Но для соблюдения контракта интерфейса добавляем их:

  @override
  Future<Either<Failure, List<AudioBookPart>>> getBookPartsLight(
    int bookId,
  ) async {
    // Не используется в текущей логике, но заглушка обязательна
    return Left(
      ServerFailure(message: 'Метод getBookPartsLight не реализован'),
    );
  }

  @override
  Future<Either<Failure, AudioBookPart>> getFullPart(int partId) async {
    // Не используется в текущей логике
    return Left(ServerFailure(message: 'Метод getFullPart не реализован'));
  }

  @override
  Future<Either<Failure, List<AudioBookPartPreview>>> getAudioBookParts(
    int bookId,
  ) {
    // TODO: implement getAudioBookParts
    throw UnimplementedError();
  }
}
