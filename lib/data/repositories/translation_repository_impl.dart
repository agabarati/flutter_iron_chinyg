// lib/data/repositories/translation_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../domain/repositories/translation_repository.dart';
import '../../domain/entities/audio_book_part.dart';
import '../../core/errors/failures.dart';
import '../datasources/translation_remote_datasource.dart';

class TranslationRepositoryImpl implements TranslationRepository {
  final TranslationRemoteDataSource remoteDataSource;

  TranslationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, String>> translateWord(
    String word,
    Dialect dialect,
  ) async {
    try {
      final html = await remoteDataSource.translateWord(word, dialect);
      return Right(html);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (e) {
      return Left(ServerFailure(message: 'Ошибка перевода: $e'));
    }
  }
}
