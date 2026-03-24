// lib/data/models/audio_book_model.dart (чистая версия)
import 'package:equatable/equatable.dart';

class AudioBookModel extends Equatable {
  final int id;
  final String title;
  final String author;
  final String? description;
  final String reader;
  final String folder;
  final String cover;
  final int order;
  final bool published;
  // Поля loaded, removed, updated и другие нам пока не нужны

  const AudioBookModel({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    required this.reader,
    required this.folder,
    required this.cover,
    required this.order,
    required this.published,
  });

  factory AudioBookModel.fromJson(Map<String, dynamic> json) {
    return AudioBookModel(
      id: json['id'] as int,
      title: json['title'] as String,
      author: json['author'] as String,
      description: json['description'] as String?,
      reader: json['reader'] as String,
      folder: json['folder'] as String,
      cover: json['cover'] as String,
      order: json['order'] as int? ?? 0,
      published: json['published'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    author,
    description,
    reader,
    folder,
    cover,
    order,
    published,
  ];
}
