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
      final url = Uri.parse('$baseUrl?word=${Uri.encodeComponent(word)}');

      final response = await client
          .get(url, headers: {'Content-Type': 'text/html; charset=utf-8'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return utf8.decode(response.bodyBytes);
      } else if (response.statusCode == 404) {
        return '<div>Перевод не найден</div>';
      } else {
        throw ServerFailure(message: 'Ошибка перевода: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw NetworkFailure(message: 'Ошибка сети при переводе: $e');
    } on TimeoutException catch (_) {
      throw NetworkFailure(message: 'Превышено время ожидания');
    } catch (e) {
      throw ServerFailure(message: 'Неизвестная ошибка при переводе: $e');
    }
  }
}
