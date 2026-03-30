// lib/presentation/widgets/parts_list_tab.dart
import 'package:flutter/material.dart';
import '../../domain/entities/audio_book_part.dart';

class PartsListTab extends StatelessWidget {
  final List<AudioBookPart> parts;
  final AudioBookPart? currentPart;
  final Function(AudioBookPart) onPartSelected;

  const PartsListTab({
    super.key,
    required this.parts,
    this.currentPart,
    required this.onPartSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: parts.length,
      itemBuilder: (context, index) {
        final part = parts[index];
        final isSelected = currentPart?.id == part.id;

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
              print('Выбрана часть: ${part.title}');
              onPartSelected(part);
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
