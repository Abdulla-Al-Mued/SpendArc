// app/core/error/failures.dart
import 'package:equatable/equatable.dart';

/// Base failure class — all domain-layer errors extend this.
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Network / API failures
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure({required super.message, super.code, this.statusCode});

  @override
  List<Object?> get props => [...super.props, statusCode];
}

/// Local database failures
class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.code});
}

/// Input validation failures
class ValidationFailure extends Failure {
  final String field;

  const ValidationFailure({
    required super.message,
    required this.field,
    super.code,
  });

  @override
  List<Object?> get props => [...super.props, field];
}

/// Network connectivity failures
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection',
    super.code = 'NETWORK_UNAVAILABLE',
  });
}

/// Unexpected / unknown failures
class UnexpectedFailure extends Failure {
  final Object? originalError;

  const UnexpectedFailure({
    super.message = 'An unexpected error occurred',
    super.code = 'UNEXPECTED',
    this.originalError,
  });

  @override
  List<Object?> get props => [...super.props, originalError];
}
