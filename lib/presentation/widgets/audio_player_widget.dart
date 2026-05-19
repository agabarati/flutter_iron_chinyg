import 'package:flutter/material.dart';
import '../../services/audio_player_service.dart';
import '../../domain/entities/audio_book.dart';

class AudioPlayerWidget extends StatefulWidget {
  final AudioBook book;
  const AudioPlayerWidget({super.key, required this.book});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final AudioPlayerService _service = AudioPlayerService.instance;

  @override
  void initState() {
    super.initState();
    _service.statusStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPart = _service!.currentIndex >= 0 && _service!.parts.isNotEmpty;
    final currentPart = _service!.currentPart;
    final duration = currentPart?.duration ?? Duration.zero;
    final position = _service!.currentPosition;
    final isPlaying = _service!.isPlaying;
    final progress = duration.inSeconds > 0
        ? position.inSeconds / duration.inSeconds
        : 0.0;
    final partsCount = widget.book.parts.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: progress,
                    activeColor: Theme.of(context).primaryColor,
                    inactiveColor: Colors.grey[300],
                    onChanged: hasPart
                        ? (value) {
                            _service.seek(
                              Duration(
                                seconds: (value * duration.inSeconds).round(),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
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
                margin: const EdgeInsets.symmetric(horizontal: 12),
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
