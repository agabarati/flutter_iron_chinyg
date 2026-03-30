// lib/data/repositories/playback_repository_impl.dart
import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/playback_repository.dart';
import '../../domain/entities/playback_progress.dart';
import '../../core/errors/failures.dart';

class PlaybackRepositoryImpl implements PlaybackRepository {
  final SharedPreferences prefs;
  static const String _keyPrefix = 'playback_';

  PlaybackRepositoryImpl({required this.prefs});

  @override
  Future<Either<Failure, void>> saveProgress(PlaybackProgress progress) async {
    try {
      final key = '${_keyPrefix}${progress.partId}';
      final data = {
        'partId': progress.partId,
        'bookId': progress.bookId,
        'position': progress.position.inSeconds,
        'duration': progress.duration.inSeconds,
        'lastUpdated': progress.lastUpdated.toIso8601String(),
      };
      await prefs.setString(key, json.encode(data));
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(message: 'Ошибка сохранения прогресса: $e'));
    }
  }

  @override
  Future<Either<Failure, PlaybackProgress?>> getProgress(int partId) async {
    try {
      final key = '${_keyPrefix}$partId';
      final dataString = prefs.getString(key);

      if (dataString == null) {
        return const Right(null);
      }

      final data = json.decode(dataString) as Map<String, dynamic>;
      final progress = PlaybackProgress(
        partId: data['partId'] as int,
        bookId: data['bookId'] as int,
        position: Duration(seconds: data['position'] as int),
        duration: Duration(seconds: data['duration'] as int),
        lastUpdated: DateTime.parse(data['lastUpdated'] as String),
      );

      return Right(progress);
    } catch (e) {
      return Left(StorageFailure(message: 'Ошибка получения прогресса: $e'));
    }
  }

  @override
  Future<Either<Failure, List<PlaybackProgress>>> getBookProgress(
    int bookId,
  ) async {
    try {
      final allKeys = prefs.getKeys();
      final bookKeys = allKeys.where((key) => key.startsWith(_keyPrefix));

      final List<PlaybackProgress> progresses = [];

      for (final key in bookKeys) {
        final dataString = prefs.getString(key);
        if (dataString != null) {
          final data = json.decode(dataString) as Map<String, dynamic>;
          if (data['bookId'] == bookId) {
            progresses.add(
              PlaybackProgress(
                partId: data['partId'] as int,
                bookId: data['bookId'] as int,
                position: Duration(seconds: data['position'] as int),
                duration: Duration(seconds: data['duration'] as int),
                lastUpdated: DateTime.parse(data['lastUpdated'] as String),
              ),
            );
          }
        }
      }

      return Right(progresses);
    } catch (e) {
      return Left(StorageFailure(message: 'Ошибка получения прогрессов: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearProgress(int partId) async {
    try {
      final key = '${_keyPrefix}$partId';
      await prefs.remove(key);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(message: 'Ошибка очистки прогресса: $e'));
    }
  }
}
