// lib/domain/usecases/get_audio_books.dart
import 'package:dartz/dartz.dart';
import '../repositories/audio_book_repository.dart';
import '../entities/audio_book.dart';
import '../../core/errors/failures.dart';

class GetAudioBooks {
  final AudioBookRepository repository;

  GetAudioBooks({required this.repository});

  Future<Either<Failure, List<AudioBook>>> call() {
    return repository.getAudioBooks();
  }
}
