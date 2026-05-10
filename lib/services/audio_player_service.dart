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
  // Единственный экземпляр
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  static AudioPlayerService get instance => _instance;

  // Состояние текущей книги
  int _bookId = -1;
  List<AudioBookPart> _parts = [];
  int _currentIndex = -1;
  bool _isAudioSourceSet = false;

  final AudioPlayer _player = AudioPlayer();
  final _statusController = StreamController<PlaybackStatus>.broadcast();
  Stream<PlaybackStatus> get statusStream => _statusController.stream;

  // Публичные геттеры
  bool get isPlaying => _player.playing;
  Duration get currentPosition => _player.position;
  Duration get currentDuration => _player.duration ?? Duration.zero;
  int get currentIndex => _currentIndex;
  int get bookId => _bookId;
  List<AudioBookPart> get parts => List.unmodifiable(_parts);
  AudioBookPart? get currentPart =>
      _currentIndex >= 0 && _currentIndex < _parts.length
      ? _parts[_currentIndex]
      : null;

  // Приватный конструктор
  AudioPlayerService._internal() {
    _init();
  }

  Future<void> _init() async {
    _player.playerStateStream.listen((state) {
      _broadcastState();
      if (state.processingState == ProcessingState.completed &&
          _currentIndex < _parts.length - 1) {
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
        parts: _parts,
        isInitialized: _parts.isNotEmpty && _currentIndex >= 0,
        bookId: _bookId,
      ),
    );
    if (_currentIndex >= 0 && _currentIndex < _parts.length) {
      final part = _parts[_currentIndex];
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

  /// Полностью сбросить плеер и переключиться на новую книгу
  Future<void> switchToBook(int bookId, List<AudioBookPart> parts) async {
    if (_bookId == bookId) return; // уже эта книга – ничего не делаем
    await _player.stop();
    await _player.seek(Duration.zero); // <-- ОБНУЛЯЕМ ПОЗИЦИЮ
    _bookId = bookId;
    _parts = List.from(parts);
    _currentIndex = 0;
    _isAudioSourceSet = false;

    final items = _parts
        .map(
          (part) => MediaItem(
            id: part.id.toString(),
            title: part.title ?? 'Часть',
            artist: part.reader,
            duration: part.duration,
            artUri: part.coverUrl.isNotEmpty
                ? Uri.tryParse(part.coverUrl)
                : null,
          ),
        )
        .toList();
    queue.add(items);
    if (_currentIndex >= 0 && _currentIndex < items.length) {
      mediaItem.add(items[_currentIndex]);
    } else {
      mediaItem.add(null);
    }
    _broadcastState();
  }

  /// Загрузить и воспроизвести конкретную часть (по индексу)
  Future<void> playPart(int index, {Duration? startPosition}) async {
    if (index < 0 || index >= _parts.length) return;
    _currentIndex = index;
    final part = _parts[index];
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

  @override
  Future<void> play() async {
    if (!_isAudioSourceSet &&
        _currentIndex >= 0 &&
        _currentIndex < _parts.length) {
      await playPart(_currentIndex);
    } else {
      await _player.play();
    }
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _broadcastState();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState();
  }

  @override
  Future<void> skipToNext() async => _skipToNext();
  @override
  Future<void> skipToPrevious() async => _skipToPrevious();

  Future<void> _skipToNext() async {
    if (_currentIndex + 1 < _parts.length) await playPart(_currentIndex + 1);
  }

  Future<void> _skipToPrevious() async {
    if (_currentIndex - 1 >= 0) await playPart(_currentIndex - 1);
  }

  void dispose() {
    _player.dispose();
    _statusController.close();
  }
}
