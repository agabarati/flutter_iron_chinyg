// lib/data/datasources/translation_remote_datasource.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../domain/entities/audio_book_part.dart';
import '../../core/errors/failures.dart';

class TranslationRemoteDataSource {
  final http.Client client;

  static const String _baseUrlIron =
      'https://audiobooks.ironapps.ru/dict/ir_to_rus/';
  static const String _baseUrlDigor =
      'https://audiobooks.ironapps.ru/dict/dig_to_rus/';

  TranslationRemoteDataSource({required this.client});

  Future<String> translateWord(String word, Dialect dialect) async {
    try {
      final baseUrl = dialect == Dialect.iron ? _baseUrlIron : _baseUrlDigor;

      // Формируем URL: baseUrl + слово (без кодирования, как есть)
      final url = Uri.parse('$baseUrl$word');
      print('📡 Запрос перевода: $url');

      final response = await client
          .get(url, headers: {'Content-Type': 'text/html; charset=utf-8'})
          .timeout(const Duration(seconds: 10));

      print('📡 Статус: ${response.statusCode}');

      if (response.statusCode == 200) {
        final html = utf8.decode(response.bodyBytes);
        // Проверяем, есть ли в HTML перевод или сообщение об ошибке
        if (html.contains('не найдено') ||
            html.contains('not found') ||
            html.contains('Не найдено') ||
            html.length < 50) {
          print('⚠️ Перевод не найден для слова: $word');
          return '<div class="translation">Перевод для слова "$word" не найден</div>';
        }
        return html;
      } else if (response.statusCode == 404) {
        print('⚠️ Слово "$word" не найдено (404)');
        return '<div class="translation">Перевод для слова "$word" не найден</div>';
      } else {
        throw ServerFailure(message: 'Ошибка перевода: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw NetworkFailure(message: 'Ошибка сети при переводе: $e');
    } on TimeoutException catch (_) {
      throw NetworkFailure(message: 'Превышено время ожидания');
    } catch (e) {
      throw ServerFailure(message: 'Ошибка перевода: $e');
    }
  }
}
