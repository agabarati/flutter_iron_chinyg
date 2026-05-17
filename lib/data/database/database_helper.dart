import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/audio_book_preview.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'iron_chinyg.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        description TEXT,
        reader TEXT NOT NULL,
        coverUrl TEXT NOT NULL,
        book_order INTEGER,
        lastUpdate INTEGER,
        isFavorite INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> saveBooks(List<AudioBookPreview> books) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('books');
      for (final book in books) {
        await txn.insert('books', {
          'id': book.id,
          'title': book.title,
          'author': book.author,
          'description': book.description,
          'reader': book.reader,
          'coverUrl': book.coverUrl,
          'book_order': book.order,
          'lastUpdate': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  /// Возвращает null, если таблица пуста (нет сохранённых книг)
  Future<List<AudioBookPreview>?> loadBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      orderBy: 'book_order DESC',
    );
    if (maps.isEmpty) return null;
    return maps
        .map(
          (map) => AudioBookPreview(
            id: map['id'],
            title: map['title'],
            author: map['author'],
            description: map['description'],
            reader: map['reader'],
            coverUrl: map['coverUrl'],
            order: map['book_order'],
          ),
        )
        .toList();
  }

  Future<void> toggleFavorite(int bookId, bool isFavorite) async {
    final db = await database;
    await db.update(
      'books',
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<List<AudioBookPreview>> loadFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'book_order ASC',
    );
    return maps
        .map(
          (map) => AudioBookPreview(
            id: map['id'],
            title: map['title'],
            author: map['author'],
            description: map['description'],
            reader: map['reader'],
            coverUrl: map['coverUrl'],
            order: map['book_order'],
          ),
        )
        .toList();
  }
}
