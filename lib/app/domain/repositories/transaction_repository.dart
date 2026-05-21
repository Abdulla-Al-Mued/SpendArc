// app/domain/repositories/transaction_repository.dart
import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/transaction.dart';

/// Pure abstract contract — the domain layer owns this; data layer implements it.
/// This is the Dependency Inversion boundary.
abstract class TransactionRepository {
  /// Returns cached transactions immediately, then syncs in background.
  Future<Either<Failure, List<Transaction>>> getTransactions();

  /// Optimistically inserts locally, then pushes to remote.
  /// On remote failure, returns [ServerFailure] but local state is preserved
  /// in the write queue for next sync.
  Future<Either<Failure, Transaction>> addTransaction(Transaction transaction);

  /// Optimistically removes locally; rolls back on remote failure.
  Future<Either<Failure, String>> deleteTransaction(String id);

  /// Computes diff between local and remote, applies only changes.
  Future<Either<Failure, SyncResult>> syncTransactions();

  /// Aggregates spending data for the summary widgets.
  Future<Either<Failure, SpendingSummary>> getSpendingSummary({
    DateTime? from,
    DateTime? to,
  });
}

class SyncResult {
  final int added;
  final int updated;
  final int deleted;
  final DateTime syncedAt;

  const SyncResult({
    required this.added,
    required this.updated,
    required this.deleted,
    required this.syncedAt,
  });

  bool get hasChanges => added > 0 || updated > 0 || deleted > 0;
}
