// lib/presentation/providers/book_list_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/audio_book_preview.dart';
import '../../data/repositories/audio_book_repository_impl.dart';
import '../../data/datasources/audio_book_remote_datasource.dart';
import 'package:http/http.dart' as http;

// Состояние списка книг
class BookListState {
  final bool isLoading;
  final List<AudioBookPreview> books;
  final String? error;

  const BookListState({
    required this.isLoading,
    required this.books,
    this.error,
  });

  // Начальное состояние
  factory BookListState.initial() =>
      const BookListState(isLoading: false, books: [], error: null);

  // Состояние загрузки
  BookListState copyWithLoading() =>
      BookListState(isLoading: true, books: books, error: null);

  // Состояние успеха
  BookListState copyWithSuccess(List<AudioBookPreview> newBooks) =>
      BookListState(isLoading: false, books: newBooks, error: null);

  // Состояние ошибки
  BookListState copyWithError(String message) =>
      BookListState(isLoading: false, books: [], error: message);
}

// Notifier для управления списком книг
class BookListNotifier extends StateNotifier<BookListState> {
  BookListNotifier() : super(BookListState.initial());

  final _repository = AudioBookRepositoryImpl(
    remoteDataSource: AudioBookRemoteDataSource(client: http.Client()),
  );

  // Загрузка книг
  Future<void> loadBooks() async {
    // Устанавливаем состояние загрузки
    state = state.copyWithLoading();

    try {
      final result = await _repository.getAudioBookPreviews();

      result.fold(
        (failure) => state = state.copyWithError(failure.message),
        (books) => state = state.copyWithSuccess(books),
      );
    } catch (e) {
      state = state.copyWithError(e.toString());
    }
  }

  // Повторная загрузка (для кнопки)
  Future<void> refresh() async {
    await loadBooks();
  }
}

// Провайдер для доступа к состоянию
final bookListProvider = StateNotifierProvider<BookListNotifier, BookListState>(
  (ref) {
    final notifier = BookListNotifier();
    // Автоматическая загрузка при первом обращении
    Future.microtask(() => notifier.loadBooks());
    return notifier;
  },
);
