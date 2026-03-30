// lib/data/models/audio_book_part_model.dart
import 'package:equatable/equatable.dart';

/// DTO для части аудиокниги (трека).
/// Строго соответствует JSON из /parts_with_text/{bookId}
class AudioBookPartModel extends Equatable {
  final int id;
  final int bookId;
  final String? title;
  final String? text;
  final String reader;
  final String audiofile;
  final String length;
  final String dialect;
  final int order;
  final bool published;
  final int listened;
  final int listenedIos;
  final String cover;

  const AudioBookPartModel({
    required this.id,
    required this.bookId,
    this.title,
    this.text,
    required this.reader,
    required this.audiofile,
    required this.length,
    required this.dialect,
    required this.order,
    required this.published,
    required this.listened,
    required this.listenedIos,
    required this.cover,
  });

  /// Фабричный метод для создания модели из JSON
  factory AudioBookPartModel.fromJson(Map<String, dynamic> json) {
    return AudioBookPartModel(
      id: json['id'] as int,
      bookId: json['book_id'] as int,
      title: json['title'] as String?,
      text: json['text'] as String?,
      reader: json['reader'] as String,
      audiofile: json['audiofile'] as String,
      length: json['length'] as String,
      dialect:
          json['dialect'] as String, // Просто сохраняем строку "IRN" или "DGR"
      order: json['order'] as int? ?? 0,
      published: json['published'] as bool? ?? true,
      listened: json['listened'] as int? ?? 0,
      listenedIos: json['listened_ios'] as int? ?? 0,
      cover: '',
    );
  }

  /// Альтернативный фабричный метод для создания из JSON эндпоинта /parts/{bookId}
  /// (на случай, если нам понадобится получать части без текста)
  factory AudioBookPartModel.fromPartsJson(Map<String, dynamic> json) {
    return AudioBookPartModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      bookId: int.tryParse(json['book_id']?.toString() ?? '0') ?? 0,
      title: json['part_title'] as String?,
      text: json['part_text'] as String?,
      reader: json['part_reader'] as String? ?? json['reader'] as String? ?? '',
      audiofile: json['audiofile'] as String,
      length: json['length'] as String,
      dialect: json['dialect'] as String? ?? 'IRN',
      order: 0,
      published: true,
      listened: int.tryParse(json['listened']?.toString() ?? '0') ?? 0,
      listenedIos: 0,
      cover: '',
    );
  }

  /// Вспомогательный геттер для получения текста (для единообразия)
  String? get contentText => text;

  @override
  List<Object?> get props => [
    id,
    bookId,
    title,
    text,
    reader,
    audiofile,
    length,
    dialect,
    order,
    published,
    listened,
    listenedIos,
  ];
}
