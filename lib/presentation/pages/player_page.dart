import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/audio_player_widget.dart';
import '../widgets/parts_list_tab.dart';
import '../widgets/text_view_tab.dart';
import '../../services/audio_player_service.dart';
import '../../domain/entities/audio_book.dart';
import '../../core/errors/failures.dart';
import '../../data/repositories/audio_book_repository_impl.dart';
import '../../data/datasources/audio_book_remote_datasource.dart';

class PlayerPage extends StatefulWidget {
  final int bookId;
  const PlayerPage({super.key, required this.bookId});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with TickerProviderStateMixin {
  late TabController _tabController;
  AudioBook? _book;
  bool _isLoading = true;
  String? _error;
  late DraggableScrollableController _draggableController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _draggableController = DraggableScrollableController();
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
        (book) async {
          final service = AudioPlayerService.instance;
          final isDifferentBook = service.bookId != widget.bookId;

          setState(() {
            _book = book;
            _isLoading = false;
          });

          if (isDifferentBook) {
            // Переключаем плеер на новую книгу
            await service.switchToBook(widget.bookId, book.parts);
            // Останавливаем, чтобы не играло автоматически
            await service.stop();
          }
          // Если та же книга – ничего не делаем, воспроизведение продолжается
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
    _draggableController.dispose();
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Theme.of(context).primaryColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              tabs: const [
                Tab(text: 'НОМХЫГЪД'),
                Tab(text: 'КÆСЫН'),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              PartsListTab(book: _book!),
              TextViewTab(book: _book!),
            ],
          ),
          DraggableScrollableSheet(
            controller: _draggableController,
            initialChildSize: 0.12,
            minChildSize: 0.12,
            maxChildSize: 0.23,
            snap: true,
            snapSizes: const [0.12, 0.23],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        physics: const ClampingScrollPhysics(),
                        child: AudioPlayerWidget(
                          key: ValueKey(_book!.id),
                          book: _book!,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
