// lib/presentation/widgets/audio_player_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import '../../domain/entities/audio_book_part.dart';

class AudioPlayerWidget extends StatefulWidget {
  final List<AudioBookPart> parts;
  final AudioBookPart? currentPart;
  final Function(AudioBookPart) onPartChanged;

  const AudioPlayerWidget({
    super.key,
    required this.parts,
    required this.currentPart,
    required this.onPartChanged,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;
  bool _isInitialized = false;
  AudioSession? _audioSession;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudioSession();
    _setupPlayerListeners();

    if (widget.currentPart != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPart(widget.currentPart!);
      });
    }
  }

  /// Инициализация аудио-сессии для корректного управления аудио-фокусом
  Future<void> _initAudioSession() async {
    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      print('Ошибка инициализации AudioSession: $e');
    }
  }

  void _setupPlayerListeners() {
    _player.positionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _player.durationStream.listen((duration) {
      if (mounted) setState(() => _duration = duration ?? Duration.zero);
    });

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isLoading =
              state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
          _isInitialized = state.processingState == ProcessingState.ready;
        });

        // Автоматическое переключение на следующую часть при завершении
        if (state.processingState == ProcessingState.completed) {
          _nextPart();
        }
      }
    });
  }

  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPart != oldWidget.currentPart &&
        widget.currentPart != null) {
      _loadPart(widget.currentPart!);
    }
  }

  /// Загрузка и воспроизведение части с поддержкой фонового режима
  Future<void> _loadPart(AudioBookPart part) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _isInitialized = false;
    });

    try {
      await _player.stop();

      // КЛЮЧЕВОЙ МОМЕНТ: Создаем MediaItem для отображения в уведомлении
      final mediaItem = MediaItem(
        id: part.id.toString(),
        title: part.title ?? 'Аудиокнига',
        artist: part.reader,
        duration: part.duration,
        artUri: part.coverUrl.isNotEmpty ? Uri.tryParse(part.coverUrl) : null,
      );

      // Устанавливаем источник с метаданными для фонового уведомления
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(part.audioUrl),
          tag: mediaItem, // <-- БЕЗ ЭТОГО НЕ БУДЕТ УВЕДОМЛЕНИЯ!
        ),
      );

      // Запрос аудио-фокуса перед воспроизведением
      if (_audioSession != null) {
        await _audioSession!.setActive(true);
      }

      await _player.play();
    } catch (e) {
      print('Ошибка загрузки аудио: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить: ${part.title ?? "часть"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _playPause() {
    if (!_isInitialized) return;
    if (_isPlaying) {
      _player.pause();
      // При паузе можно отпустить аудио-фокус
      _audioSession?.setActive(false);
    } else {
      _audioSession?.setActive(true);
      _player.play();
    }
  }

  void _seekForward() {
    if (!_isInitialized) return;
    final newPosition = _position + const Duration(seconds: 10);
    if (newPosition < _duration) {
      _player.seek(newPosition);
    }
  }

  void _seekBackward() {
    if (!_isInitialized) return;
    final newPosition = _position - const Duration(seconds: 10);
    if (newPosition > Duration.zero) {
      _player.seek(newPosition);
    } else {
      _player.seek(Duration.zero);
    }
  }

  void _previousPart() {
    if (widget.currentPart == null) return;
    final currentIndex = widget.parts.indexOf(widget.currentPart!);
    if (currentIndex > 0) {
      widget.onPartChanged(widget.parts[currentIndex - 1]);
    }
  }

  void _nextPart() {
    if (widget.currentPart == null) return;
    final currentIndex = widget.parts.indexOf(widget.currentPart!);
    if (currentIndex < widget.parts.length - 1) {
      widget.onPartChanged(widget.parts[currentIndex + 1]);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasPart = widget.currentPart != null;
    final progress = _duration.inSeconds > 0 && _isInitialized
        ? _position.inSeconds / _duration.inSeconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          // Название текущей части
          Text(
            hasPart ? (widget.currentPart!.title ?? 'Часть') : 'Выберите часть',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Индикатор загрузки
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),

          // Ползунок прогресса
          Slider(
            value: progress,
            onChanged: hasPart && _isInitialized && !_isLoading
                ? (value) {
                    final position = Duration(
                      seconds: (value * _duration.inSeconds).round(),
                    );
                    _player.seek(position);
                  }
                : null,
          ),

          // Время
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position)),
              Text(_formatDuration(_duration)),
            ],
          ),
          const SizedBox(height: 8),

          // Кнопки управления
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 32),
                onPressed:
                    hasPart &&
                        _isInitialized &&
                        !_isLoading &&
                        widget.parts.length > 1
                    ? _previousPart
                    : null,
                tooltip: 'Предыдущая часть',
              ),
              IconButton(
                icon: const Icon(Icons.replay_10, size: 32),
                onPressed: hasPart && _isInitialized && !_isLoading
                    ? _seekBackward
                    : null,
                tooltip: 'Назад 10 секунд',
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 56,
                  ),
                  onPressed: hasPart && _isInitialized && !_isLoading
                      ? _playPause
                      : null,
                  tooltip: _isPlaying ? 'Пауза' : 'Воспроизвести',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10, size: 32),
                onPressed: hasPart && _isInitialized && !_isLoading
                    ? _seekForward
                    : null,
                tooltip: 'Вперед 10 секунд',
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 32),
                onPressed:
                    hasPart &&
                        _isInitialized &&
                        !_isLoading &&
                        widget.parts.length > 1
                    ? _nextPart
                    : null,
                tooltip: 'Следующая часть',
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
