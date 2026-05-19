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
  int? _currentBookId; // для отслеживания текущей открытой книги

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

      // 1. Пытаемся загрузить книгу из локальной БД (включая части)
      final cachedBook = await partCacheRepo.loadBook(widget.bookId);
      if (cachedBook != null && cachedBook.parts.isNotEmpty) {
        setState(() {
          _book = cachedBook;
          _isLoading = false;
        });
        final downloaded = await partCacheRepo.isBookDownloaded(widget.bookId);
        setState(() => _isDownloaded = downloaded);

        // Переключаем плеер, если книга другая, иначе ничего не делаем
        if (_currentBookId != widget.bookId) {
          AudioPlayerService.instance.switchToBook(
            widget.bookId,
            cachedBook.parts,
          );
          _currentBookId = widget.bookId;
        }
        return;
      }

      // 2. Кэша нет – загружаем из сети (только метаданные, без аудио)
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
          // Сохраняем метаданные в БД (части без аудио)
          await partCacheRepo.saveBookMetadata(book);
          // Переключаем плеер, если книга другая
          if (_currentBookId != widget.bookId) {
            AudioPlayerService.instance.switchToBook(widget.bookId, book.parts);
            _currentBookId = widget.bookId;
          }
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

    // Диалог подтверждения загрузки
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Загрузка книги'),
        content: const Text(
          'Вы уверены, что хотите загрузить эту книгу для офлайн-прослушивания?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Загрузить',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isDownloading = true);

    final cancelNotifier = ValueNotifier<bool>(false);
    final progressNotifier = ValueNotifier<double>(0.0);
    final total = _book!.parts.length;

    // Диалог прогресса с кнопкой «Отмена»
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ValueListenableBuilder(
          valueListenable: progressNotifier,
          builder: (context, value, _) {
            final completed = (value * total).toInt();
            return AlertDialog(
              title: const Text('Загрузка книги'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('$completed из $total частей'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelNotifier.value = true;
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Отмена',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    try {
      final partCacheRepo = ref.read(partCacheRepositoryProvider);
      await partCacheRepo.downloadAndSaveBookWithCancel(
        _book!,
        (c, t) => progressNotifier.value = c / t,
        cancelNotifier,
      );
      if (mounted) Navigator.pop(context); // закрываем диалог прогресса
      setState(() => _isDownloaded = true);
      ref.invalidate(downloadedBooksProvider);
      ref.invalidate(audioBookPreviewsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Книга загружена и сохранена на устройстве'),
        ),
      );
    } catch (e) {
      if (mounted && cancelNotifier.value) {
        // отмена уже обработана, диалог закрыт
      } else {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isDownloading = false);
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
      ref.invalidate(downloadedBooksProvider);
      // Не перезагружаем страницу, просто обновляем состояние
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
      setState(() => _isDownloading = false);
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
              icon: const Icon(Icons.cloud_done, color: Colors.white),
              tooltip: 'Удалить книгу',
            )
          else
            IconButton(
              onPressed: _isDownloading ? null : _downloadBook,
              icon: const Icon(Icons.download, color: Colors.white),
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
            initialChildSize: 0.30,
            minChildSize: 0.05,
            maxChildSize: 0.30,
            snap: true,
            snapSizes: const [0.05, 0.30],
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
