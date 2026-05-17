import 'package:equatable/equatable.dart';

class AudioBookPreview extends Equatable {
  final int id;
  final String title;
  final String author;
  final String? description;
  final String reader;
  final String coverUrl;
  final int order;
  final bool isDownloaded; // для отображения значка загрузки на главном экране

  const AudioBookPreview({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    required this.reader,
    required this.coverUrl,
    required this.order,
    this.isDownloaded = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'description': description,
    'reader': reader,
    'coverUrl': coverUrl,
    'order': order,
    'isDownloaded': isDownloaded ? 1 : 0,
  };

  factory AudioBookPreview.fromJson(Map<String, dynamic> json) {
    return AudioBookPreview(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      description: json['description'],
      reader: json['reader'],
      coverUrl: json['coverUrl'],
      order: json['order'],
      isDownloaded: json['isDownloaded'] == 1,
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
    isDownloaded,
  ];
}
