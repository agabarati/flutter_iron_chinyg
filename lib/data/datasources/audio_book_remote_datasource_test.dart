// test/data/datasources/audio_book_remote_datasource_test.dart
import 'dart:convert';

import 'package:flutter_iron_chinyg/core/errors/failures.dart';
import 'package:flutter_iron_chinyg/data/datasources/audio_book_remote_datasource.dart';
import 'package:flutter_iron_chinyg/data/models/audio_book_model.dart';
import 'package:flutter_iron_chinyg/data/models/audio_book_part_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

// Создаем мок-класс для http.Client
class MockHttpClient extends Mock implements http.Client {}

void main() {
  late AudioBookRemoteDataSource dataSource;
  late MockHttpClient mockHttpClient;

  setUp(() {
    mockHttpClient = MockHttpClient();
    dataSource = AudioBookRemoteDataSource(client: mockHttpClient);
  });

  group('getBooks', () {
    const tBookId = 37;
    final tBookJson = [
      {
        "id": 37,
        "title": "Æрвгæнæн",
        "author": "Кокайты Тотрадз",
        "description": "Описание книги",
        "reader": "Гæбуты Жаннæ",
        "folder": "37_kokaev_t_arvganan",
        "cover": "images/37_kokaev_t_arvganan.jpg",
        "order": 51,
        "published": true,
      },
    ];

    test(
      'should return List<AudioBookModel> when response code is 200',
      () async {
        // Arrange
        when(
          mockHttpClient.get(
            Uri.parse('https://audiobooks.ironapps.ru/audio/'),
            headers: anyNamed('headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode(tBookJson),
            200,
            headers: {'content-type': 'application/json'},
          ),
        );

        // Act
        final result = await dataSource.getBooks();

        // Assert
        expect(result, isA<List<AudioBookModel>>());
        expect(result.length, 1);
        expect(result.first.id, 37);
        expect(result.first.title, 'Æрвгæнæн');
        expect(result.first.published, true);

        // Verify that the correct URL was called
        verify(
          mockHttpClient.get(
            Uri.parse('https://audiobooks.ironapps.ru/audio/'),
            headers: anyNamed('headers'),
          ),
        ).called(1);
      },
    );

    test('should filter out unpublished books', () async {
      // Arrange
      final jsonWithUnpublished = [
        {
          "id": 37,
          "title": "Æрвгæнæн",
          "author": "Кокайты Тотрадз",
          "reader": "Гæбуты Жаннæ",
          "folder": "37_kokaev_t_arvganan",
          "cover": "images/37_kokaev_t_arvganan.jpg",
          "order": 51,
          "published": true,
        },
        {
          "id": 36,
          "title": "Джыккайты Шамил",
          "author": "Намыс",
          "reader": "Æлбегаты Алан",
          "folder": "36_djagkajty_namys",
          "cover": "images/36_djagkajty_namys.png",
          "order": 50,
          "published": false,
        },
      ];

      when(
        mockHttpClient.get(
          Uri.parse('https://audiobooks.ironapps.ru/audio/'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode(jsonWithUnpublished),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      // Act
      final result = await dataSource.getBooks();

      // Assert
      expect(result.length, 1);
      expect(result.first.id, 37);
      expect(result.first.published, true);
    });

    test('should throw ServerFailure when response code is not 200', () async {
      // Arrange
      when(
        mockHttpClient.get(
          Uri.parse('https://audiobooks.ironapps.ru/audio/'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      // Act
      final call = dataSource.getBooks;

      // Assert
      expect(() => call(), throwsA(isA<ServerFailure>()));
    });

    test('should throw NetworkFailure on ClientException', () async {
      // Arrange
      when(
        mockHttpClient.get(
          Uri.parse('https://audiobooks.ironapps.ru/audio/'),
          headers: anyNamed('headers'),
        ),
      ).thenThrow(http.ClientException('Network error'));

      // Act
      final call = dataSource.getBooks;

      // Assert
      expect(() => call(), throwsA(isA<NetworkFailure>()));
    });

    test('should throw ParseFailure on FormatException', () async {
      // Arrange
      when(
        mockHttpClient.get(
          Uri.parse('https://audiobooks.ironapps.ru/audio/'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          'Invalid JSON',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      // Act
      final call = dataSource.getBooks;

      // Assert
      expect(() => call(), throwsA(isA<ParseFailure>()));
    });
  });

  group('getBookPartsWithText', () {
    const tBookId = 37;
    final tPartJson = [
      {
        "id": 11648,
        "book_id": 37,
        "title": "Сабыр сагъæс",
        "text": "Текст уыдзæн тагъд рæстæджы ...",
        "reader": "Гæбуты Жаннæ",
        "audiofile": "audio/37_kokaev_t_arvganan/07_gabueva_sabyr_sagas.mp3",
        "length": "1:58",
        "dialect": "IRN",
        "order": 7,
        "published": true,
        "listened": 1710,
        "listened_ios": 239,
      },
    ];

    test(
      'should return List<AudioBookPartModel> when response code is 200',
      () async {
        // Arrange
        when(
          mockHttpClient.get(
            Uri.parse(
              'https://audiobooks.ironapps.ru/audio/parts_with_text/$tBookId',
            ),
            headers: anyNamed('headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode(tPartJson),
            200,
            headers: {'content-type': 'application/json'},
          ),
        );

        // Act
        final result = await dataSource.getBookPartsWithText(tBookId);

        // Assert
        expect(result, isA<List<AudioBookPartModel>>());
        expect(result.length, 1);
        expect(result.first.id, 11648);
        expect(result.first.bookId, 37);
        expect(result.first.title, 'Сабыр сагъæс');
        expect(result.first.text, isNotNull);

        verify(
          mockHttpClient.get(
            Uri.parse(
              'https://audiobooks.ironapps.ru/audio/parts_with_text/$tBookId',
            ),
            headers: anyNamed('headers'),
          ),
        ).called(1);
      },
    );

    test('should return empty list when response code is 404', () async {
      // Arrange
      when(
        mockHttpClient.get(
          Uri.parse(
            'https://audiobooks.ironapps.ru/audio/parts_with_text/$tBookId',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      // Act
      final result = await dataSource.getBookPartsWithText(tBookId);

      // Assert
      expect(result, isEmpty);
    });

    test('should sort parts by order', () async {
      // Arrange
      final unsortedParts = [
        {
          "id": 11643,
          "book_id": 37,
          "title": "Æнхъæлдтон",
          "text": "Текст...",
          "reader": "Гæбуты Жаннæ",
          "audiofile": "audio/37_kokaev_t_arvganan/02_gabueva_anqaldton.mp3",
          "length": "1:21",
          "dialect": "IRN",
          "order": 2,
          "published": true,
          "listened": 2574,
          "listened_ios": 374,
        },
        {
          "id": 11642,
          "book_id": 37,
          "title": "Æз фæзынын",
          "text": "Текст...",
          "reader": "Гæбуты Жаннæ",
          "audiofile": "audio/37_kokaev_t_arvganan/01_gabueva_az_fazinin.mp3",
          "length": "1:37",
          "dialect": "IRN",
          "order": 1,
          "published": true,
          "listened": 2909,
          "listened_ios": 493,
        },
      ];

      when(
        mockHttpClient.get(
          Uri.parse(
            'https://audiobooks.ironapps.ru/audio/parts_with_text/$tBookId',
          ),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode(unsortedParts),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      // Act
      final result = await dataSource.getBookPartsWithText(tBookId);

      // Assert
      expect(result.length, 2);
      expect(result.first.id, 11642); // order 1 должен быть первым
      expect(result.last.id, 11643); // order 2 должен быть вторым
    });
  });
}
