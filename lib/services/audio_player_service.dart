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

  PlaybackStatus({
    required this.playing,
    required this.position,
    required this.duration,
    required this.currentIndex,
  });
}

/// Сервис фонового воспроизведения
class AudioPlayerService extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  List<AudioBookPart> _parts = [];
  int _currentIndex = -1;

  final _statusController = StreamController<PlaybackStatus>.broadcast();
  Stream<PlaybackStatus> get statusStream => _statusController.stream;

  AudioPlayerService() {
    _setup();
  }

  void _setup() {
    _player.positionStream.listen((pos) => _broadcast());
    _player.durationStream.listen((_) => _broadcast());
    _player.playerStateStream.listen((state) {
      _broadcast();
      if (state.processingState == ProcessingState.completed) {
        _skipToNext();
      }
    });
  }

  void _broadcast() {
    _statusController.add(
      PlaybackStatus(
        playing: _player.playing,
        position: _player.position,
        duration: _player.duration ?? Duration.zero,
        currentIndex: _currentIndex,
      ),
    );
  }

  void setQueue(List<AudioBookPart> parts, {int startIndex = 0}) {
    _parts = parts;
    _currentIndex = startIndex;

    final items = _parts.asMap().entries.map((entry) {
      final part = entry.value;
      return MediaItem(
        id: part.id.toString(),
        title: part.title ?? 'Часть ${entry.key + 1}',
        artist: part.reader,
        duration: part.duration,
        artUri: part.coverUrl.isNotEmpty ? Uri.parse(part.coverUrl) : null,
      );
    }).toList();

    queue.add(items);
    if (_currentIndex >= 0 && _currentIndex < items.length) {
      mediaItem.add(items[_currentIndex]);
    }
  }

  Future<void> playPart(int index, {Duration? startPosition}) async {
    if (index < 0 || index >= _parts.length) return;

    _currentIndex = index;
    final part = _parts[index];

    mediaItem.add(
      MediaItem(
        id: part.id.toString(),
        title: part.title ?? 'Часть ${index + 1}',
        artist: part.reader,
        duration: part.duration,
        artUri: part.coverUrl.isNotEmpty ? Uri.parse(part.coverUrl) : null,
      ),
    );

    await _player.setAudioSource(AudioSource.uri(Uri.parse(part.audioUrl)));
    if (startPosition != null && startPosition.inSeconds > 0) {
      await _player.seek(startPosition);
    }
    await _player.play();
  }

  @override
  Future<void> play() async => _player.play();

  @override
  Future<void> pause() async => _player.pause();

  @override
  Future<void> stop() async => _player.stop();

  @override
  Future<void> seek(Duration position) async => _player.seek(position);

  @override
  Future<void> skipToNext() async => _skipToNext();

  @override
  Future<void> skipToPrevious() async => _skipToPrevious();

  Future<void> _skipToNext() async {
    if (_currentIndex + 1 < _parts.length) {
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
