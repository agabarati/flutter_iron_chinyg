// lib/presentation/widgets/audio_player_widget.dart
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
  AudioPlayerService? _service;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    // Создаем или получаем сервис для этой книги
    final service = await AudioPlayerService.forBook(
      widget.book.id,
      widget.book.parts,
    );

    if (mounted) {
      setState(() {
        _service = service;
      });

      // Подписываемся на изменения
      _service!.statusStream.listen((status) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_service == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.grey[100],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final hasPart = _service!.currentIndex >= 0 && _service!.parts.isNotEmpty;
    final currentPart = _service!.currentPart;
    final duration = _service!.currentDuration;
    final position = _service!.currentPosition;
    final isPlaying = _service!.isPlaying;
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
                ? (currentPart!.title ?? 'Часть ${_service!.currentIndex + 1}')
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
                    _service!.seek(newPosition);
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
                    ? _service!.skipToPrevious
                    : null,
                tooltip: 'Предыдущая часть',
              ),
              IconButton(
                icon: const Icon(Icons.replay_10, size: 32),
                onPressed: hasPart
                    ? () =>
                          _service!.seek(position - const Duration(seconds: 10))
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
                      ? () => isPlaying ? _service!.pause() : _service!.play()
                      : null,
                  tooltip: isPlaying ? 'Пауза' : 'Воспроизвести',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10, size: 32),
                onPressed: hasPart
                    ? () =>
                          _service!.seek(position + const Duration(seconds: 10))
                    : null,
                tooltip: 'Вперед 10 секунд',
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 32),
                onPressed: hasPart && partsCount > 1
                    ? _service!.skipToNext
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
