import 'dart:io';
import '../database/database_helper.dart';
import '../../domain/entities/audio_book.dart';
import '../../domain/entities/audio_book_part.dart';
import '../../services/download_service.dart';

class PartCacheRepository {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final DownloadService downloadService = DownloadService();

  Future<void> downloadAndSaveBook(AudioBook book) async {
    await dbHelper.saveBook(book);
    await dbHelper.saveParts(book.id, book.parts);
    for (final part in book.parts) {
      final fileName = part.audioUrl.split('/').last;
      final localPath = await downloadService.downloadFile(
        part.audioUrl,
        fileName,
      );
      await dbHelper.markPartDownloaded(part.id, localPath);
    }
    // После успешной загрузки всех частей помечаем книгу как загруженную
    await dbHelper.markBookDownloaded(book.id);
  }

  Future<AudioBook?> loadBook(int bookId) async {
    return await dbHelper.loadBook(bookId);
  }

  Future<bool> isBookDownloaded(int bookId) async {
    return await dbHelper.isBookDownloaded(bookId);
  }

  Future<String?> getLocalFilePath(int partId) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'book_parts',
      where: 'id = ?',
      whereArgs: [partId],
    );
    if (result.isNotEmpty) {
      return result.first['localFilePath'] as String?;
    }
    return null;
  }

  Future<void> deleteBook(int bookId) async {
    // Удаляем аудиофайлы
    final book = await loadBook(bookId);
    if (book != null) {
      for (final part in book.parts) {
        final localPath = await getLocalFilePath(part.id);
        if (localPath != null) {
          final file = File(localPath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    }
    // Удаляем все части из БД
    final db = await dbHelper.database;
    await db.delete('book_parts', where: 'bookId = ?', whereArgs: [bookId]);
    // Сбрасываем флаг загрузки книги
    await dbHelper.markBookNotDownloaded(bookId);
  }
}
