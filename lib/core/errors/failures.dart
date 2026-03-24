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
}

/// Ошибка сети (нет интернета, таймаут)
class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

/// Ошибка парсинга данных
class ParseFailure extends Failure {
  const ParseFailure({required super.message});
}
