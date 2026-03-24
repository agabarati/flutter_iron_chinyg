// lib/presentation/pages/player_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_iron_chinyg/domain/entities/audio_book_part.dart';
import 'package:flutter_iron_chinyg/presentation/widgets/audio_player_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../widgets/parts_list_tab.dart';
import '../widgets/text_view_tab.dart';
import '../../domain/entities/audio_book.dart';
import '../../core/errors/failures.dart';

class PlayerPage extends ConsumerStatefulWidget {
  final int bookId;
  const PlayerPage({super.key, required this.bookId});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  AudioBookPart? _currentPart;

  void _onPartSelected(AudioBookPart part) {
    setState(() => _currentPart = part);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(audioBookDetailsProvider(widget.bookId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Аудиокнига'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Части'),
            Tab(icon: Icon(Icons.text_fields), text: 'Текст'),
          ],
        ),
      ),
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(error),
        data: (book) => Column(
          children: [
            AudioPlayerWidget(
              parts: book.parts,
              currentPart: _currentPart,
              onPartChanged: _onPartSelected,
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: const Center(child: Text('Аудиоплеер будет здесь')),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  PartsListTab(
                    parts: book.parts,
                    currentPart: _currentPart,
                    onPartSelected: _onPartSelected,
                  ),
                  _currentPart != null
                      ? TextViewTab(part: _currentPart!)
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_back,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Выберите часть для отображения текста',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    final message = error is Failure ? error.message : error.toString();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(audioBookDetailsProvider(widget.bookId)),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
