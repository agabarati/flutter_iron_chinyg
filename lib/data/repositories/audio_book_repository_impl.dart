import 'package:dartz/dartz.dart';
import 'package:flutter_iron_chinyg/data/models/audio_book_part_model.dart';
import 'package:flutter_iron_chinyg/domain/entities/audio_book_part_preview.dart';
import '../../domain/repositories/audio_book_repository.dart';
import '../../domain/entities/audio_book.dart';
import '../../domain/entities/audio_book_preview.dart';
import '../../domain/entities/audio_book_part.dart';
import '../../core/errors/failures.dart';
import '../datasources/audio_book_remote_datasource.dart';

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
      // Пытаемся получить через новый эндпоинт /audiobook/{id}
      final data = await remoteDataSource.getFullAudioBook(id);
      final audiobook = data['audiobook'] as Map<String, dynamic>;
      final partsJson = data['audioparts'] as List;

      final parts = partsJson.map((partMap) {
        final folder = audiobook['folder'] as String;
        final fileName = (partMap['audiofile'] as String).split('/').last;
        final audioUrl = '${_mediaBaseUrl}audio/$folder/$fileName';
        final duration = _parseDuration(partMap['length'] as String);
        final dialect = partMap['dialect'] == 'IRN'
            ? Dialect.iron
            : Dialect.digor;
        return AudioBookPart(
          id: partMap['id'] as int,
          bookId: partMap['book_id'] as int,
          title: partMap['title'] as String?,
          text: partMap['text'] as String?,
          reader: partMap['reader'] as String,
          audioUrl: audioUrl,
          duration: duration,
          order: partMap['order'] as int? ?? 0,
          dialect: dialect,
          coverUrl: '',
        );
      }).toList();

      return Right(
        AudioBook(
          id: audiobook['id'] as int,
          title: audiobook['title'] as String,
          author: audiobook['author'] as String,
          description: audiobook['description'] as String?,
          reader: audiobook['reader'] as String,
          coverUrl: '$_mediaBaseUrl${audiobook['cover']}',
          order: audiobook['order_field'] as int? ?? 0,
          parts: parts,
        ),
      );
    } catch (e) {
      // Fallback на старый метод
      try {
        final bookModels = await remoteDataSource.getBooks();
        final bookModel = bookModels.firstWhere((model) => model.id == id);
        final partModels = await remoteDataSource.getBookPartsWithText(id);
        final parts = partModels
            .map((part) => _createAudioBookPart(part, bookModel.folder))
            .toList();
        return Right(
          AudioBook(
            id: bookModel.id,
            title: bookModel.title,
            author: bookModel.author,
            description: bookModel.description,
            reader: bookModel.reader,
            coverUrl: '$_mediaBaseUrl${bookModel.cover}',
            order: bookModel.order,
            parts: parts,
          ),
        );
      } catch (e2) {
        return Left(
          ServerFailure(message: 'Ошибка загрузки деталей книги: $e2'),
        );
      }
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
  Future<Either<Failure, List<AudioBookPartPreview>>> getAudioBookParts(
    int bookId,
  ) {
    // TODO: implement getAudioBookParts
    throw UnimplementedError();
  }

  // Внутри класса AudioBookRepositoryImpl

  /// Создаёт AudioBookPart из модели и папки книги
  AudioBookPart _createAudioBookPart(AudioBookPartModel model, String folder) {
    final fileName = model.audiofile.split('/').last;
    final audioUrl = '${_mediaBaseUrl}audio/$folder/$fileName';
    final duration = _parseDuration(model.length);
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
      dialect: dialect,
      coverUrl: '',
    );
  }
}
