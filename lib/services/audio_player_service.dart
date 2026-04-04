// lib/services/audio_player_service.dart
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../domain/entities/audio_book_part.dart';

/// Состояние воспроизведения для UI
class PlaybackStatus {
  final bool playing;
  final Duration position;
  final Duration duration;
  final int currentIndex;
  final List<AudioBookPart> parts;
  final bool isInitialized;

  PlaybackStatus({
    required this.playing,
    required this.position,
    required this.duration,
    required this.currentIndex,
    required this.parts,
    required this.isInitialized,
  });

  static PlaybackStatus empty() => PlaybackStatus(
    playing: false,
    position: Duration.zero,
    duration: Duration.zero,
    currentIndex: -1,
    parts: [],
    isInitialized: false,
  );
}

/// Сервис фонового воспроизведения
class AudioPlayerService extends BaseAudioHandler {
  static AudioPlayerService? _instance;

  AudioPlayerService() {
    _instance = this;
    _init();
  }

  static AudioPlayerService get instance {
    _instance ??= AudioPlayerService();
    return _instance!;
  }

  final AudioPlayer _player = AudioPlayer();
  List<AudioBookPart> _parts = [];
  int _currentIndex = -1;

  final _statusController = StreamController<PlaybackStatus>.broadcast();
  Stream<PlaybackStatus> get statusStream => _statusController.stream;

  bool get isPlaying => _player.playing;
  Duration get currentPosition => _player.position;
  Duration get currentDuration => _player.duration ?? Duration.zero;
  int get currentIndex => _currentIndex;
  AudioBookPart? get currentPart =>
      _currentIndex >= 0 ? _parts[_currentIndex] : null;
  List<AudioBookPart> get parts => List.unmodifiable(_parts);

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

  void setPlaylist(List<AudioBookPart> parts, {int startIndex = 0}) {
    _parts = List.from(parts);
    _currentIndex = startIndex.clamp(0, _parts.length - 1);

    // Создаем MediaItem для каждой части для фонового воспроизведения
    final items = _parts.asMap().entries.map((entry) {
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

    if (_currentIndex >= 0 && _currentIndex < items.length) {
      mediaItem.add(items[_currentIndex]);
    }

    _broadcastState();
  }

  Future<void> playPart(int index, {Duration? startPosition}) async {
    if (index < 0 || index >= _parts.length) return;

    _currentIndex = index;
    final part = _parts[index];

    // Создаем MediaItem для этой части
    final mediaItemForPart = MediaItem(
      id: part.id.toString(),
      title: part.title ?? 'Часть ${index + 1}',
      artist: part.reader,
      duration: part.duration,
      artUri: part.coverUrl.isNotEmpty ? Uri.tryParse(part.coverUrl) : null,
    );

    // Устанавливаем источник с обязательным MediaItem тегом
    await _player.setAudioSource(
      AudioSource.uri(
        Uri.parse(part.audioUrl),
        tag: mediaItemForPart, // Обязательно!
      ),
    );

    if (startPosition != null && startPosition.inSeconds > 0) {
      await _player.seek(startPosition);
    }

    await _player.play();
    _broadcastState();
  }

  @override
  Future<void> play() async {
    await _player.play();
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
    if (_currentIndex + 1 < _parts.length) {
      _currentIndex++;
      await playPart(_currentIndex);
    }
  }

  Future<void> _skipToPrevious() async {
    if (_currentIndex - 1 >= 0) {
      _currentIndex--;
      await playPart(_currentIndex);
    }
  }

  void dispose() {
    _player.dispose();
    _statusController.close();
  }
}
