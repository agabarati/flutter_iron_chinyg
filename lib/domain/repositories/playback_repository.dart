// lib/domain/repositories/playback_repository.dart
import 'package:dartz/dartz.dart';
import '../entities/playback_progress.dart';
import '../../core/errors/failures.dart';

/// Репозиторий для хранения прогресса прослушивания
abstract class PlaybackRepository {
  /// Сохранить прогресс для части
  Future<Either<Failure, void>> saveProgress(PlaybackProgress progress);

  /// Получить прогресс для конкретной части
  Future<Either<Failure, PlaybackProgress?>> getProgress(int partId);

  /// Получить все прогрессы для книги
  Future<Either<Failure, List<PlaybackProgress>>> getBookProgress(int bookId);

  /// Очистить прогресс для части (если нужно)
  Future<Either<Failure, void>> clearProgress(int partId);
}
