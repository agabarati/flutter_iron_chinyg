// lib/core/constants/api_constants.dart
class ApiConstants {
  static const String baseUrl = 'https://audiobooks.ironapps.ru/audio/';

  /// Получить список всех книг
  static String get books => baseUrl;

  /// Получить части книги с текстом
  static String bookPartsWithText(int bookId) =>
      '${baseUrl}parts_with_text/$bookId';

  /// Получить части книги без текста (если понадобится)
  static String bookParts(int bookId) => '${baseUrl}parts/$bookId';
}
