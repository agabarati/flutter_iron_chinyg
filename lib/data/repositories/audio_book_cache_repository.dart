import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/audio_book_preview.dart';
import '../database/database_helper.dart';

class AudioBookCacheRepository {
  static const String _lastUpdateKey = 'last_update_timestamp';

  final SharedPreferences prefs;
  final DatabaseHelper dbHelper = DatabaseHelper();

  AudioBookCacheRepository({required this.prefs});

  Future<void> saveBooks(List<AudioBookPreview> books) async {
    await dbHelper.saveBooks(books);
    await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<AudioBookPreview>?> loadBooks() async {
    return await dbHelper.loadBooks();
  }

  Future<int?> getLastUpdateTimestamp() async {
    return prefs.getInt(_lastUpdateKey);
  }

  Future<void> toggleFavorite(int bookId, bool isFavorite) async {
    await dbHelper.toggleFavorite(bookId, isFavorite);
  }

  Future<List<AudioBookPreview>> loadFavorites() async {
    return await dbHelper.loadFavorites();
  }
}
