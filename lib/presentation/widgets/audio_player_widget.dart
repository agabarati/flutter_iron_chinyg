// lib/presentation/widgets/audio_player_widget.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    _setupPlayerListeners();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
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
        setState(() => _isPlaying = state.playing);
      }
    });
  }

  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPart != oldWidget.currentPart) {
      _loadPart(widget.currentPart);
    }
  }

  Future<void> _loadPart(AudioBookPart? part) async {
    if (part == null) return;

    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(part.audioUrl)));
      _player.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _playPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _seekForward() {
    final newPosition = _position + const Duration(seconds: 10);
    if (newPosition < _duration) {
      _player.seek(newPosition);
    }
  }

  void _seekBackward() {
    final newPosition = _position - const Duration(seconds: 10);
    if (newPosition > Duration.zero) {
      _player.seek(newPosition);
    } else {
      _player.seek(Duration.zero);
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
    final progress = _duration.inSeconds > 0
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

          // Прогресс-бар
          Slider(
            value: progress,
            onChanged: hasPart
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
                onPressed: hasPart ? _previousPart : null,
              ),
              IconButton(
                icon: const Icon(Icons.replay_10, size: 32),
                onPressed: hasPart ? _seekBackward : null,
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
                  onPressed: hasPart ? _playPause : null,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10, size: 32),
                onPressed: hasPart ? _seekForward : null,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 32),
                onPressed: hasPart ? _nextPart : null,
              ),
            ],
          ),
        ],
      ),
    );
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

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
