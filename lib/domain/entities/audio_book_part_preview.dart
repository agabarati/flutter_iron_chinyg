// lib/domain/entities/audio_book_part_preview.dart
import 'package:equatable/equatable.dart';
import 'package:flutter_iron_chinyg/domain/entities/audio_book_part.dart';

class AudioBookPartPreview extends Equatable {
  final int id;
  final int bookId;
  final String? title;
  final String reader;
  final String audioUrl;
  final Duration duration;
  final int order;
  final Dialect dialect;

  const AudioBookPartPreview({
    required this.id,
    required this.bookId,
    this.title,
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
    reader,
    audioUrl,
    duration,
    order,
    dialect,
  ];
}
