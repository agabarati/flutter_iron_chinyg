// lib/data/datasources/audio_book_remote_datasource.dart (обновим константы)
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../models/audio_book_model.dart';
import '../models/audio_book_part_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';

class AudioBookRemoteDataSource {
  final http.Client client;

  AudioBookRemoteDataSource({required this.client});

  /// Получить список всех аудиокниг (без частей)
  Future<List<AudioBookModel>> getBooks() async {
    try {
      final response = await client
          .get(
            Uri.parse(ApiConstants.books),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList
            .map((json) => AudioBookModel.fromJson(json))
            .where((book) => book.published)
            .toList();
      } else {
        throw ServerFailure(message: 'Ошибка сервера: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw NetworkFailure(message: 'Ошибка сети: $e');
    } on TimeoutException catch (_) {
      throw NetworkFailure(message: 'Превышено время ожидания');
    } on FormatException catch (e) {
      throw ParseFailure(message: 'Ошибка формата данных: $e');
    } catch (e) {
      throw ServerFailure(message: 'Неизвестная ошибка: $e');
    }
  }

  /// Получить части аудиокниги с текстом по ID книги
  Future<List<AudioBookPartModel>> getBookPartsWithText(int bookId) async {
    try {
      final response = await client
          .get(
            Uri.parse(ApiConstants.bookPartsWithText(bookId)),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList
            .map((json) => AudioBookPartModel.fromJson(json))
            .where((part) => part.published)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw ServerFailure(message: 'Ошибка сервера: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw NetworkFailure(message: 'Ошибка сети при загрузке частей: $e');
    } on TimeoutException catch (_) {
      throw NetworkFailure(
        message: 'Превышено время ожидания при загрузке частей',
      );
    } on FormatException catch (e) {
      throw ParseFailure(message: 'Ошибка формата данных частей: $e');
    } catch (e) {
      throw ServerFailure(
        message: 'Неизвестная ошибка при загрузке частей: $e',
      );
    }
  }

  /// Получить части аудиокниги без текста (если понадобится)
  Future<List<AudioBookPartModel>> getBookParts(int bookId) async {
    try {
      final response = await client
          .get(
            Uri.parse(ApiConstants.bookParts(bookId)),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList
            .map((json) => AudioBookPartModel.fromJson(json))
            .toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw ServerFailure(message: 'Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(message: 'Ошибка при загрузке частей: $e');
    }
  }
}
