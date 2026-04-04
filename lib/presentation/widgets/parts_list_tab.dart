// lib/presentation/widgets/parts_list_tab.dart
import 'package:flutter/material.dart';
import '../../services/audio_player_service.dart';
import '../../domain/entities/audio_book.dart';

class PartsListTab extends StatefulWidget {
  final AudioBook book;

  const PartsListTab({super.key, required this.book});

  @override
  State<PartsListTab> createState() => _PartsListTabState();
}

class _PartsListTabState extends State<PartsListTab> {
  AudioPlayerService? _service;
  int _currentIndex = -1;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    final service = await AudioPlayerService.forBook(
      widget.book.id,
      widget.book.parts,
    );

    if (mounted) {
      setState(() {
        _service = service;
        _currentIndex = service.currentIndex;
      });

      service.statusStream.listen((status) {
        if (mounted) {
          setState(() {
            _currentIndex = status.currentIndex;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_service == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final parts = widget.book.parts;

    if (parts.isEmpty) {
      return const Center(child: Text('Нет доступных частей'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: parts.length,
      itemBuilder: (context, index) {
        final part = parts[index];
        final isSelected = index == _currentIndex;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300],
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              part.title ?? 'Часть ${index + 1}',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).primaryColor : null,
              ),
            ),
            subtitle: Text(_formatDuration(part.duration)),
            trailing: isSelected
                ? Icon(Icons.play_circle, color: Theme.of(context).primaryColor)
                : null,
            selected: isSelected,
            onTap: () {
              _service?.playPart(index);
            },
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
