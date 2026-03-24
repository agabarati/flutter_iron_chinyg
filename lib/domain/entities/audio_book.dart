// lib/domain/entities/audio_book.dart
import 'package:equatable/equatable.dart';
import 'audio_book_part.dart';

/// Бизнес-сущность, представляющая полную аудиокнигу с её частями.
class AudioBook extends Equatable {
  final int id;
  final String title;
  final String author;
  final String? description;
  final String reader;
  final String coverUrl;
  final int order;
  final List<AudioBookPart> parts; // Список частей

  const AudioBook({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    required this.reader,
    required this.coverUrl,
    required this.order,
    required this.parts,
  });

  AudioBook copyWith({List<AudioBookPart>? parts}) {
    return AudioBook(
      id: id,
      title: title,
      author: author,
      description: description,
      reader: reader,
      coverUrl: coverUrl,
      order: order,
      parts: parts ?? this.parts,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    author,
    description,
    reader,
    coverUrl,
    order,
    parts,
  ];
}
