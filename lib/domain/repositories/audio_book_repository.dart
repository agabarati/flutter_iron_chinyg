// lib/domain/repositories/audio_book_repository.dart
import 'package:dartz/dartz.dart';
import '../entities/audio_book_preview.dart';
import '../entities/audio_book.dart';
import '../../core/errors/failures.dart';

abstract class AudioBookRepository {
  /// 🖼️ Получить список книг для главного экрана (БЕЗ загрузки частей)
  /// Быстрый метод, использует только данные из /audio/
  Future<Either<Failure, List<AudioBookPreview>>> getAudioBookPreviews();

  /// 📚 Получить полную информацию о книге с частями (для экрана плеера)
  /// Загружает данные из /parts_with_text/{bookId}
  Future<Either<Failure, AudioBook>> getAudioBookDetails(int bookId);

  /// ⚠️ Устаревшие методы (оставлены для обратной совместимости)
  @Deprecated('Используйте getAudioBookPreviews() для списка')
  Future<Either<Failure, List<AudioBook>>> getAudioBooks();

  @Deprecated('Используйте getAudioBookDetails() для деталей')
  Future<Either<Failure, AudioBook>> getAudioBookById(int id);
}
