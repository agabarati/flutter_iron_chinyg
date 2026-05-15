class ApiConstants {
  static const String baseUrl = 'https://audiobooks.ironapps.ru/audio/';

  /// Список всех книг (превью)
  static String get books => baseUrl;

  /// Части с текстом (старый, медленный метод)
  static String bookPartsWithText(int bookId) =>
      '${baseUrl}parts_with_text/$bookId';

  /// Части без текста (легковесный)
  static String bookParts(int bookId) => '${baseUrl}parts/$bookId';

  /// Оптимизированный эндпоинт: полная книга со всеми частями (с текстом) одним запросом
  static String audioBookDetails(int bookId) => '${baseUrl}audiobook/$bookId';
}
