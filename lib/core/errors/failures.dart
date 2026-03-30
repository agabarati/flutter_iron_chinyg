// lib/core/errors/failures.dart
import 'package:equatable/equatable.dart';

/// Базовый класс для всех ошибок
abstract class Failure extends Equatable {
  final String message;

  const Failure({required this.message});

  @override
  List<Object> get props => [message];
}

/// Ошибка сервера (5xx, 4xx)
class ServerFailure extends Failure {
  const ServerFailure({required super.message});

  String getUserFriendlyMessage() {
    return 'Ошибка на сервере. Попробуйте позже.';
  }
}

/// Ошибка сети (нет интернета, таймаут)
class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});

  String getUserFriendlyMessage() {
    return 'Нет подключения к интернету. Проверьте соединение и попробуйте снова.';
  }
}

/// Ошибка парсинга данных
class ParseFailure extends Failure {
  const ParseFailure({required super.message});

  String getUserFriendlyMessage() {
    return 'Ошибка обработки данных.';
  }
}

/// Ошибка хранения данных (SharedPreferences, база данных)
class StorageFailure extends Failure {
  const StorageFailure({required super.message});

  String getUserFriendlyMessage() {
    return 'Ошибка сохранения данных.';
  }
}
