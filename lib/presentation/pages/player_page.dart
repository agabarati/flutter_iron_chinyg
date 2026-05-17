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
import '../providers/providers.dart';

class PlayerPage extends ConsumerStatefulWidget {
  final int bookId;
  const PlayerPage({super.key, required this.bookId});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late DraggableScrollableController _draggableController;
  AudioBook? _book;
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  String? _error;

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
      final partCacheRepo = ref.read(partCacheRepositoryProvider);

      // 1. Пытаемся загрузить из локальной БД
      final cachedBook = await partCacheRepo.loadBook(widget.bookId);
      if (cachedBook != null && cachedBook.parts.isNotEmpty) {
        setState(() {
          _book = cachedBook;
          _isLoading = false;
        });
        final downloaded = await partCacheRepo.isBookDownloaded(widget.bookId);
        setState(() => _isDownloaded = downloaded);
        AudioPlayerService.instance.setPlaylist(_book!.parts, startIndex: 0);
        return;
      }

      // 2. Нет в кэше – загружаем из сети
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
          setState(() {
            _book = book;
            _isLoading = false;
            _isDownloaded = false;
          });
          AudioPlayerService.instance.setPlaylist(book.parts, startIndex: 0);
          // Сохраняем метаданные и части в БД (без аудио)
          await partCacheRepo.downloadAndSaveBook(book);
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadBook() async {
    if (_book == null) return;
    setState(() => _isDownloading = true); // показываем индикатор на кнопке

    // Показываем диалог с прогрессом (опционально, для лучшей обратной связи)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final partCacheRepo = ref.read(partCacheRepositoryProvider);
      await partCacheRepo.downloadAndSaveBook(_book!); // дожидаемся завершения
      setState(() => _isDownloaded = true);
      // Обновляем провайдеры
      ref.invalidate(downloadedBooksProvider);
      ref.invalidate(audioBookPreviewsProvider);
      if (mounted) Navigator.pop(context); // закрываем диалог
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Книга загружена и сохранена на устройстве'),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isDownloading = false); // скрываем индикатор на кнопке
    }
  }

  Future<void> _deleteBook() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление книги'),
        content: const Text(
          'Вы уверены, что хотите удалить загруженную книгу? Аудиофайлы будут стёрты с устройства.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    setState(() => _isDownloading = true);
    try {
      final partCacheRepo = ref.read(partCacheRepositoryProvider);
      await partCacheRepo.deleteBook(widget.bookId);
      setState(() => _isDownloaded = false);
      // Обновляем статус загрузки на главном экране
      ref.invalidate(downloadedBooksProvider);
      ref.invalidate(audioBookPreviewsProvider);
      // Перезагружаем текущую книгу (теперь она будет без частей, загрузится из сети)
      await _loadBook();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Книга удалена с устройства')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка удаления: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBook,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    if (_book == null || _book!.parts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Аудиокнига')),
        body: const Center(child: Text('Книга не найдена или нет частей')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_book!.title),
        actions: [
          if (_isDownloaded)
            IconButton(
              onPressed: _isDownloading ? null : _deleteBook,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_done, color: Colors.white),
              tooltip: 'Удалить книгу',
            )
          else
            IconButton(
              onPressed: _isDownloading ? null : _downloadBook,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download, color: Colors.white),
              tooltip: 'Загрузить книгу',
            ),
        ],
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
            initialChildSize: 0.23,
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
                          key: ValueKey(widget.bookId),
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
