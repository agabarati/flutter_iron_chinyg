// lib/services/audio_player_service.dart
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../domain/entities/audio_book_part.dart';

class PlaybackStatus {
  final bool playing;
  final Duration position;
  final Duration duration;
  final int currentIndex;
  final List<AudioBookPart> parts;
  final bool isInitialized;
  final int bookId;

  PlaybackStatus({
    required this.playing,
    required this.position,
    required this.duration,
    required this.currentIndex,
    required this.parts,
    required this.isInitialized,
    required this.bookId,
  });

  static PlaybackStatus empty() => PlaybackStatus(
    playing: false,
    position: Duration.zero,
    duration: Duration.zero,
    currentIndex: -1,
    parts: [],
    isInitialized: false,
    bookId: -1,
  );
}

class AudioPlayerService extends BaseAudioHandler {
  // Статический словарь для хранения экземпляров по bookId
  static final Map<int, AudioPlayerService> _instances = {};

  // Получить или создать экземпляр для конкретной книги
  static Future<AudioPlayerService> forBook(
    int bookId,
    List<AudioBookPart> parts,
  ) async {
    if (_instances.containsKey(bookId)) {
      return _instances[bookId]!;
    }

    final instance = AudioPlayerService._internal(bookId, parts);
    _instances[bookId] = instance;
    await instance._init();
    return instance;
  }

  // Получить текущий активный экземпляр (для UI)
  static AudioPlayerService? get current {
    if (_instances.isEmpty) return null;
    return _instances.values.last;
  }

  // Удалить экземпляр для книги (при выходе из плеера)
  static void disposeForBook(int bookId) {
    final instance = _instances.remove(bookId);
    if (instance != null) {
      instance.stop();
      instance._player.dispose();
    }
  }

  // Публичный конструктор для AudioService.init()
  // Не используйте его напрямую. Используйте AudioPlayerService.forBook()
  AudioPlayerService()
    : bookId = -1,
      parts = [],
      _player = AudioPlayer(),
      _currentIndex = 0,
      _isAudioSourceSet = false;

  final int bookId;
  final List<AudioBookPart> parts;
  final AudioPlayer _player;
  int _currentIndex;
  bool _isAudioSourceSet;

  final _statusController = StreamController<PlaybackStatus>.broadcast();
  Stream<PlaybackStatus> get statusStream => _statusController.stream;

  bool get isPlaying => _player.playing;
  Duration get currentPosition => _player.position;
  Duration get currentDuration => _player.duration ?? Duration.zero;
  int get currentIndex => _currentIndex;
  AudioBookPart? get currentPart =>
      _currentIndex >= 0 && _currentIndex < parts.length
      ? parts[_currentIndex]
      : null;

  AudioPlayerService._internal(this.bookId, this.parts)
    : _player = AudioPlayer(),
      _currentIndex = 0,
      _isAudioSourceSet = false;

  Future<void> _init() async {
    if (parts.isEmpty) return;

    // Настраиваем плейлист для фонового воспроизведения
    final items = parts.asMap().entries.map((entry) {
      final part = entry.value;
      return MediaItem(
        id: part.id.toString(),
        title: part.title ?? 'Часть ${entry.key + 1}',
        artist: part.reader,
        duration: part.duration,
        artUri: part.coverUrl.isNotEmpty ? Uri.tryParse(part.coverUrl) : null,
      );
    }).toList();

    queue.add(items);

    // Подписываемся на события плеера
    _player.playerStateStream.listen((state) {
      _broadcastState();
      if (state.processingState == ProcessingState.completed &&
          _currentIndex < parts.length - 1) {
        _skipToNext();
      }
    });

    _player.positionStream.listen((_) => _broadcastState());
    _player.playbackEventStream.listen((_) => _broadcastState());

    _broadcastState();
  }

  void _broadcastState() {
    _statusController.add(
      PlaybackStatus(
        playing: _player.playing,
        position: _player.position,
        duration: _player.duration ?? Duration.zero,
        currentIndex: _currentIndex,
        parts: parts,
        isInitialized: parts.isNotEmpty,
        bookId: bookId,
      ),
    );

    if (_currentIndex >= 0 && _currentIndex < parts.length) {
      final part = parts[_currentIndex];
      mediaItem.add(
        MediaItem(
          id: part.id.toString(),
          title: part.title ?? 'Часть ${_currentIndex + 1}',
          artist: part.reader,
          duration: part.duration,
          artUri: part.coverUrl.isNotEmpty ? Uri.tryParse(part.coverUrl) : null,
        ),
      );
    }
  }

  Future<void> playPart(int index, {Duration? startPosition}) async {
    if (index < 0 || index >= parts.length) return;

    _currentIndex = index;
    final part = parts[index];

    final mediaItemForPart = MediaItem(
      id: part.id.toString(),
      title: part.title ?? 'Часть ${index + 1}',
      artist: part.reader,
      duration: part.duration,
      artUri: part.coverUrl.isNotEmpty ? Uri.tryParse(part.coverUrl) : null,
    );

    await _player.setAudioSource(
      AudioSource.uri(Uri.parse(part.audioUrl), tag: mediaItemForPart),
    );
    _isAudioSourceSet = true;

    if (startPosition != null && startPosition.inSeconds > 0) {
      await _player.seek(startPosition);
    }

    await _player.play();
    _broadcastState();
  }

  Future<void> play() async {
    // Если аудио не загружено, загружаем текущую часть
    if (!_isAudioSourceSet &&
        _currentIndex >= 0 &&
        _currentIndex < parts.length) {
      await playPart(_currentIndex);
    } else {
      await _player.play();
    }
    _broadcastState();
  }

  Future<void> pause() async {
    await _player.pause();
    _broadcastState();
  }

  Future<void> stop() async {
    await _player.stop();
    _broadcastState();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState();
  }

  Future<void> skipToNext() async => _skipToNext();
  Future<void> skipToPrevious() async => _skipToPrevious();

  Future<void> _skipToNext() async {
    if (_currentIndex + 1 < parts.length) {
      await playPart(_currentIndex + 1);
    }
  }

  Future<void> _skipToPrevious() async {
    if (_currentIndex - 1 >= 0) {
      await playPart(_currentIndex - 1);
    }
  }

  void dispose() {
    _player.dispose();
    _statusController.close();
  }
}
