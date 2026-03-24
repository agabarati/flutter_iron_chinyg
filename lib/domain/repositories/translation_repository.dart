// lib/domain/repositories/translation_repository.dart
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/audio_book_part.dart';

abstract class TranslationRepository {
  Future<Either<Failure, String>> translateWord(String word, Dialect dialect);
}
