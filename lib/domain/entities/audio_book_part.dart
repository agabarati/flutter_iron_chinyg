// lib/domain/entities/audio_book_part.dart
import 'package:equatable/equatable.dart';

enum Dialect {
  iron, // иронский (IRN)
  digor, // дигорский (DIG)
}

class AudioBookPart extends Equatable {
  final int id;
  final int bookId;
  final String? title;
  final String? text;
  final String reader;
  final String audioUrl;
  final Duration duration;
  final int order;
  final Dialect dialect;

  const AudioBookPart({
    required this.id,
    required this.bookId,
    this.title,
    this.text,
    required this.reader,
    required this.audioUrl,
    required this.duration,
    required this.order,
    required this.dialect,
  });

  @override
  List<Object?> get props => [
    id,
    bookId,
    title,
    text,
    reader,
    audioUrl,
    duration,
    order,
    dialect,
  ];
}
