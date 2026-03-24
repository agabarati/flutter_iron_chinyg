// lib/domain/entities/audio_book_preview.dart
import 'package:equatable/equatable.dart';

/// Облегченная версия аудиокниги для отображения в списке
/// Содержит только данные из /audio/ эндпоинта
class AudioBookPreview extends Equatable {
  final int id;
  final String title;
  final String author;
  final String? description;
  final String reader;
  final String coverUrl;
  final int order;

  const AudioBookPreview({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    required this.reader,
    required this.coverUrl,
    required this.order,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    author,
    description,
    reader,
    coverUrl,
    order,
  ];
}
