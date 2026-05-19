import 'dart:io';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../../domain/entities/audio_book.dart';
import '../../domain/entities/audio_book_part.dart';
import '../../services/download_service.dart';

class PartCacheRepository {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final DownloadService downloadService = DownloadService();

  // Метод для обратной совместимости (без прогресса)
  Future<void> downloadAndSaveBook(AudioBook book) async {
    await downloadAndSaveBookWithProgress(book, (_, __) {});
  }

  // Новый метод с прогрессом
  Future<void> downloadAndSaveBookWithProgress(
    AudioBook book,
    void Function(int completed, int total) onProgress,
  ) async {
    await dbHelper.saveBook(book);
    await dbHelper.saveParts(book.id, book.parts);
    int completed = 0;
    final total = book.parts.length;
    for (final part in book.parts) {
      final fileName = part.audioUrl.split('/').last;
      final localPath = await downloadService.downloadFile(
        part.audioUrl,
        fileName,
      );
      await dbHelper.markPartDownloaded(part.id, localPath);
      completed++;
      onProgress(completed, total);
    }
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
    // 1. Удаляем аудиофайлы
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
    // 2. Сбрасываем статус загрузки (очищаем localFilePath и isDownloaded), но НЕ удаляем части
    await dbHelper.resetBookDownload(bookId);
  }

  /// Сохраняет только метаданные книги и части (без аудиофайлов)
  Future<void> saveBookMetadata(AudioBook book) async {
    await dbHelper.saveBook(book);
    await dbHelper.saveParts(book.id, book.parts);
  }

  Future<void> downloadAndSaveBookWithCancel(
    AudioBook book,
    void Function(int completed, int total) onProgress,
    ValueNotifier<bool> cancelNotifier,
  ) async {
    await dbHelper.saveBook(book);
    await dbHelper.saveParts(book.id, book.parts);
    int completed = 0;
    final total = book.parts.length;
    for (final part in book.parts) {
      if (cancelNotifier.value) {
        await deleteBook(book.id); // удаляем уже скачанные части и аудио
        throw Exception('Загрузка отменена пользователем');
      }
      final fileName = part.audioUrl.split('/').last;
      final localPath = await downloadService.downloadFile(
        part.audioUrl,
        fileName,
      );
      await dbHelper.markPartDownloaded(part.id, localPath);
      completed++;
      onProgress(completed, total);
    }
    await dbHelper.markBookDownloaded(book.id);
  }
}
