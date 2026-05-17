import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/audio_book_preview.dart';
import '../../domain/entities/audio_book_part.dart';
import '../../domain/entities/audio_book.dart';

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
    return await openDatabase(
      path,
      version: 3, // увеличиваем версию
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
        isFavorite INTEGER DEFAULT 0,
        isDownloaded INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE book_parts (
        id INTEGER PRIMARY KEY,
        bookId INTEGER NOT NULL,
        title TEXT,
        text TEXT,
        reader TEXT NOT NULL,
        audioUrl TEXT NOT NULL,
        localFilePath TEXT,
        duration INTEGER,
        order_index INTEGER,
        dialect TEXT NOT NULL,
        FOREIGN KEY (bookId) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE books ADD COLUMN isDownloaded INTEGER DEFAULT 0',
      );
    }
  }

  // ---- Книги (список) ----
  Future<void> saveBooks(List<AudioBookPreview> books) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final book in books) {
        final existing = await txn.query(
          'books',
          where: 'id = ?',
          whereArgs: [book.id],
        );
        if (existing.isNotEmpty) {
          // Обновляем метаданные, но НЕ трогаем isDownloaded
          await txn.update(
            'books',
            {
              'title': book.title,
              'author': book.author,
              'description': book.description,
              'reader': book.reader,
              'coverUrl': book.coverUrl,
              'book_order': book.order,
              'lastUpdate': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [book.id],
          );
        } else {
          await txn.insert('books', {
            'id': book.id,
            'title': book.title,
            'author': book.author,
            'description': book.description,
            'reader': book.reader,
            'coverUrl': book.coverUrl,
            'book_order': book.order,
            'lastUpdate': DateTime.now().millisecondsSinceEpoch,
            'isFavorite': 0,
            'isDownloaded': 0,
          });
        }
      }
    });
  }

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
            id: map['id'] as int,
            title: map['title'] as String,
            author: map['author'] as String,
            description: map['description'] as String?,
            reader: map['reader'] as String,
            coverUrl: map['coverUrl'] as String,
            order: map['book_order'] as int,
          ),
        )
        .toList();
  }

  // ---- Загрузка / удаление ----
  Future<void> markBookDownloaded(int bookId) async {
    final db = await database;
    await db.update(
      'books',
      {'isDownloaded': 1},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> markBookNotDownloaded(int bookId) async {
    final db = await database;
    await db.update(
      'books',
      {'isDownloaded': 0},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<bool> isBookDownloaded(int bookId) async {
    final db = await database;
    final result = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [bookId],
    );
    if (result.isEmpty) return false;
    return (result.first['isDownloaded'] as int) == 1;
  }

  // ---- Полная книга с частями (для загрузки/воспроизведения) ----
  Future<void> saveBook(AudioBook book) async {
    final db = await database;
    await db.insert('books', {
      'id': book.id,
      'title': book.title,
      'author': book.author,
      'description': book.description,
      'reader': book.reader,
      'coverUrl': book.coverUrl,
      'book_order': book.order,
      'lastUpdate': DateTime.now().millisecondsSinceEpoch,
      'isDownloaded': 0, // пока не загружена
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveParts(int bookId, List<AudioBookPart> parts) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('book_parts', where: 'bookId = ?', whereArgs: [bookId]);
      for (final part in parts) {
        await txn.insert('book_parts', {
          'id': part.id,
          'bookId': bookId,
          'title': part.title,
          'text': part.text,
          'reader': part.reader,
          'audioUrl': part.audioUrl,
          'localFilePath': null,
          'duration': part.duration.inMilliseconds,
          'order_index': part.order,
          'dialect': part.dialect.name,
        });
      }
    });
  }

  Future<AudioBook?> loadBook(int bookId) async {
    final db = await database;
    final bookMaps = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [bookId],
    );
    if (bookMaps.isEmpty) return null;
    final bookMap = bookMaps.first;

    final partsMaps = await db.query(
      'book_parts',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'order_index ASC',
    );
    final parts = partsMaps
        .map(
          (map) => AudioBookPart(
            id: map['id'] as int,
            bookId: map['bookId'] as int,
            title: map['title'] as String?,
            text: map['text'] as String?,
            reader: map['reader'] as String,
            audioUrl: map['audioUrl'] as String,
            duration: Duration(milliseconds: map['duration'] as int),
            order: map['order_index'] as int,
            dialect: (map['dialect'] as String) == 'iron'
                ? Dialect.iron
                : Dialect.digor,
            coverUrl: '',
          ),
        )
        .toList();

    return AudioBook(
      id: bookMap['id'] as int,
      title: bookMap['title'] as String,
      author: bookMap['author'] as String,
      description: bookMap['description'] as String?,
      reader: bookMap['reader'] as String,
      coverUrl: bookMap['coverUrl'] as String,
      order: bookMap['book_order'] as int,
      parts: parts,
    );
  }

  Future<void> markPartDownloaded(int partId, String localFilePath) async {
    final db = await database;
    await db.update(
      'book_parts',
      {'localFilePath': localFilePath},
      where: 'id = ?',
      whereArgs: [partId],
    );
  }

  // ---- Избранное ----
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
      orderBy: 'book_order DESC',
    );
    return maps
        .map(
          (map) => AudioBookPreview(
            id: map['id'] as int,
            title: map['title'] as String,
            author: map['author'] as String,
            description: map['description'] as String?,
            reader: map['reader'] as String,
            coverUrl: map['coverUrl'] as String,
            order: map['book_order'] as int,
          ),
        )
        .toList();
  }
}
