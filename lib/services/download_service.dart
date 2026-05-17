import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  Future<String> downloadFile(String url, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/audio/$fileName';
    final file = File(filePath);

    if (await file.exists()) {
      print('✅ Файл уже существует: $filePath');
      return filePath;
    }

    print('⬇️ Начинаем загрузку: $url');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await file.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);
      print('✅ Загрузка завершена: $filePath');
      return filePath;
    } else {
      print('❌ Ошибка загрузки: ${response.statusCode}');
      throw Exception('Failed to download audio: $url');
    }
  }
}
