// lib/domain/entities/playback_progress.dart
import 'package:equatable/equatable.dart';

/// Модель прогресса прослушивания части
class PlaybackProgress extends Equatable {
  final int partId; // ID части
  final int bookId; // ID книги (для удобства)
  final Duration position; // Текущая позиция
  final Duration duration; // Общая длительность
  final DateTime lastUpdated; // Когда было последнее обновление

  const PlaybackProgress({
    required this.partId,
    required this.bookId,
    required this.position,
    required this.duration,
    required this.lastUpdated,
  });

  /// Процент прослушивания (0.0 - 1.0)
  double get progressPercentage {
    if (duration.inSeconds == 0) return 0.0;
    return position.inSeconds / duration.inSeconds;
  }

  /// Считается ли часть прослушанной (более 90%)
  bool get isCompleted => progressPercentage >= 0.9;

  @override
  List<Object?> get props => [partId, bookId, position, duration, lastUpdated];
}
