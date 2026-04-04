// lib/presentation/widgets/audio_player_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_iron_chinyg/domain/entities/audio_book_part.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/audio_player_service.dart';
import '../../domain/entities/audio_book.dart';

class AudioPlayerWidget extends ConsumerStatefulWidget {
  final AudioBook book;

  const AudioPlayerWidget({super.key, required this.book});

  @override
  ConsumerState<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<AudioPlayerWidget> {
  late final AudioPlayerService _service;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _service = AudioPlayerService.instance;

    // Подписываемся на изменения состояния сервиса
    _service.statusStream.listen((status) {
      if (mounted) {
        setState(() {});
      }
    });

    // Устанавливаем плейлист, если еще не установлен
    if (_service.parts.isEmpty) {
      _service.setPlaylist(widget.book.parts, startIndex: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _service.currentIndex >= 0
        ? PlaybackStatusWrapper(
            playing: _service.isPlaying,
            position: _service.currentPosition,
            duration: _service.currentDuration,
            currentIndex: _service.currentIndex,
            parts: _service.parts,
          )
        : null;

    final hasPart = status != null && status.currentIndex >= 0;
    final currentPart = hasPart ? status.parts[status.currentIndex] : null;
    final duration = status?.duration ?? Duration.zero;
    final position = status?.position ?? Duration.zero;
    final isPlaying = status?.playing ?? false;
    final progress = duration.inSeconds > 0
        ? position.inSeconds / duration.inSeconds
        : 0.0;
    final partsCount = widget.book.parts.length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          Text(
            hasPart
                ? (currentPart!.title ?? 'Часть ${status!.currentIndex + 1}')
                : 'Выберите часть',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          Slider(
            value: progress,
            onChanged: hasPart
                ? (value) {
                    final newPosition = Duration(
                      seconds: (value * duration.inSeconds).round(),
                    );
                    _service.seek(newPosition);
                  }
                : null,
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(position)),
              Text(_formatDuration(duration)),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 32),
                onPressed: hasPart && partsCount > 1
                    ? _service.skipToPrevious
                    : null,
                tooltip: 'Предыдущая часть',
              ),
              IconButton(
                icon: const Icon(Icons.replay_10, size: 32),
                onPressed: hasPart
                    ? () =>
                          _service.seek(position - const Duration(seconds: 10))
                    : null,
                tooltip: 'Назад 10 секунд',
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: IconButton(
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 56,
                  ),
                  onPressed: hasPart
                      ? () => isPlaying ? _service.pause() : _service.play()
                      : null,
                  tooltip: isPlaying ? 'Пауза' : 'Воспроизвести',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10, size: 32),
                onPressed: hasPart
                    ? () =>
                          _service.seek(position + const Duration(seconds: 10))
                    : null,
                tooltip: 'Вперед 10 секунд',
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 32),
                onPressed: hasPart && partsCount > 1
                    ? _service.skipToNext
                    : null,
                tooltip: 'Следующая часть',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// Вспомогательный класс для передачи состояния
class PlaybackStatusWrapper {
  final bool playing;
  final Duration position;
  final Duration duration;
  final int currentIndex;
  final List<AudioBookPart> parts;

  PlaybackStatusWrapper({
    required this.playing,
    required this.position,
    required this.duration,
    required this.currentIndex,
    required this.parts,
  });
}
