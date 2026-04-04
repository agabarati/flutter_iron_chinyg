// lib/presentation/pages/player_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../widgets/audio_player_widget.dart';
import '../widgets/parts_list_tab.dart';
import '../widgets/text_view_tab.dart';
import '../../services/audio_player_service.dart';
import '../../domain/entities/audio_book.dart';
import '../../core/errors/failures.dart';
import '../../data/repositories/audio_book_repository_impl.dart';
import '../../data/datasources/audio_book_remote_datasource.dart';

class PlayerPage extends ConsumerStatefulWidget {
  final int bookId;

  const PlayerPage({super.key, required this.bookId});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  AudioBook? _book;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBook();
  }

  Future<void> _loadBook() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final remoteDataSource = AudioBookRemoteDataSource(client: http.Client());
      final repository = AudioBookRepositoryImpl(
        remoteDataSource: remoteDataSource,
      );

      final result = await repository.getAudioBookDetails(widget.bookId);

      result.fold(
        (failure) {
          setState(() {
            _error = failure.message;
            _isLoading = false;
          });
        },
        (book) {
          setState(() {
            _book = book;
            _isLoading = false;
          });

          // После загрузки книги, устанавливаем плейлист в сервис
          final service = AudioPlayerService.instance;
          service.setPlaylist(book.parts, startIndex: 0);
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Аудиокнига')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Аудиокнига')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Ошибка загрузки',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadBook,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_book == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Аудиокнига')),
        body: const Center(child: Text('Книга не найдена')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_book!.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Части'),
            Tab(icon: Icon(Icons.text_fields), text: 'Текст'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Аудиоплеер получает книгу напрямую
          AudioPlayerWidget(book: _book!),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Список частей получает книгу напрямую
                PartsListTab(book: _book!),
                // Текстовая вкладка получает книгу напрямую
                TextViewTab(book: _book!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
