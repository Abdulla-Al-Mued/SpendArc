// app/data/repositories/transaction_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_local_datasource.dart';
import '../datasources/transaction_remote_datasource.dart';
import '../models/transaction_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource remoteDataSource;
  final TransactionLocalDataSource localDataSource;

  const TransactionRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  // ─── Get Transactions (offline-first) ────────────────────────────────────────
  @override
  Future<Either<Failure, List<Transaction>>> getTransactions() async {
    try {
      // 1. Return local data immediately (instant load — Module 4)
      final cached = await localDataSource.getCachedTransactions();
      // Kick off background sync but don't await it here
      _backgroundSync();
      return right(cached.map((m) => m.toEntity()).toList());
    } catch (e) {
      return left(CacheFailure(message: 'Failed to load local data: $e'));
    }
  }

  // ─── Add Transaction (optimistic) ────────────────────────────────────────────
  @override
  Future<Either<Failure, Transaction>> addTransaction(
    Transaction transaction,
  ) async {
    // Generate a local ID if not provided
    final localTransaction = transaction.copyWith(
      id: transaction.id.isNotEmpty ? transaction.id : const Uuid().v4(),
      isSynced: false,
    );
    final model = TransactionModel.fromEntity(localTransaction);

    try {
      // 1. Optimistic local insert
      await localDataSource.cacheTransaction(model);

      // 2. Push to remote
      try {
        final remoteModel = await remoteDataSource.addTransaction(model);
        // Mark as synced after successful push
        await localDataSource.cacheTransaction(
          remoteModel.copyWith(isSynced: true),
        );
        return right(remoteModel.copyWith(isSynced: true).toEntity());
      } catch (e) {
        // 3. Remote failed → enqueue for later sync (write queue)
        await localDataSource.addPendingWrite(
          PendingWrite(
            id: localTransaction.id,
            operation: WriteOperationType.add,
            payload: model.toJson(),
            createdAt: DateTime.now(),
          ),
        );
        // Return the optimistic (unsynced) entity — caller can show sync badge
        return right(localTransaction);
      }
    } catch (e) {
      return left(CacheFailure(message: 'Failed to save transaction: $e'));
    }
  }

  // ─── Delete Transaction (optimistic + rollback) ───────────────────────────────
  @override
  Future<Either<Failure, String>> deleteTransaction(String id) async {
    // 1. Snapshot for rollback
    final cached = await localDataSource.getCachedTransactions();
    final snapshot = cached.firstWhere(
      (t) => t.id == id,
      orElse: () => throw CacheFailure(message: 'Transaction not found'),
    );

    try {
      // 2. Optimistic local delete
      await localDataSource.removeTransaction(id);

      // 3. Remote delete
      try {
        await remoteDataSource.deleteTransaction(id);
        return right(id);
      } catch (e) {
        // 4. Rollback on remote failure
        await localDataSource.cacheTransaction(snapshot);
        return left(
          ServerFailure(
            message: 'Could not delete on server. Changes reverted.',
          ),
        );
      }
    } catch (e) {
      return left(CacheFailure(message: 'Failed to delete transaction: $e'));
    }
  }

  // ─── Sync (with diffing) ─────────────────────────────────────────────────────
  @override
  Future<Either<Failure, SyncResult>> syncTransactions() async {
    try {
      // 1. Flush pending write queue first
      final pending = await localDataSource.getPendingWrites();
      for (final write in pending) {
        try {
          switch (write.operation) {
            case WriteOperationType.add:
              await remoteDataSource.addTransaction(
                TransactionModel.fromJson(write.payload!),
              );
            case WriteOperationType.delete:
              await remoteDataSource.deleteTransaction(write.id);
            case WriteOperationType.update:
              await remoteDataSource.addTransaction(
                TransactionModel.fromJson(write.payload!),
              );
          }
          await localDataSource.removePendingWrite(write.id);
        } catch (_) {
          // Keep in queue if still failing
        }
      }

      // 2. Fetch only changes since last sync (incremental diff)
      final lastSync = await localDataSource.getLastSyncTime();
      final remoteTransactions = lastSync != null
          ? await remoteDataSource.getTransactionsSince(lastSync)
          : await remoteDataSource.getTransactions();

      // 3. Diff: compare remote vs local
      final localTransactions = await localDataSource.getCachedTransactions();
      final localMap = {for (final t in localTransactions) t.id: t};

      int added = 0, updated = 0, deleted = 0;

      for (final remote in remoteTransactions) {
        final local = localMap[remote.id];
        if (local == null) {
          await localDataSource.cacheTransaction(remote);
          added++;
        } else if (local != remote) {
          await localDataSource.cacheTransaction(remote);
          updated++;
        }
      }

      // 4. Update last sync timestamp
      final now = DateTime.now();
      await localDataSource.setLastSyncTime(now);

      return right(
        SyncResult(
          added: added,
          updated: updated,
          deleted: deleted,
          syncedAt: now,
        ),
      );
    } on ServerFailure catch (e) {
      return left(e);
    } catch (e) {
      return left(UnexpectedFailure(message: 'Sync failed: $e'));
    }
  }

  // ─── Spending Summary ────────────────────────────────────────────────────────
  @override
  Future<Either<Failure, SpendingSummary>> getSpendingSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final cached = await localDataSource.getCachedTransactions();
      final entities = cached.map((m) => m.toEntity()).toList();

      final filtered = entities.where((t) {
        if (from != null && t.date.isBefore(from)) return false;
        if (to != null && t.date.isAfter(to)) return false;
        return true;
      }).toList();

      double totalIncome = 0;
      double totalExpense = 0;
      final Map<TransactionCategory, double> expenseByCategory = {};
      final Map<String, double> dailyMap = {};

      for (final t in filtered) {
        if (t.type == TransactionType.income) {
          totalIncome += t.amount;
        } else {
          totalExpense += t.amount;
          expenseByCategory[t.category] =
              (expenseByCategory[t.category] ?? 0) + t.amount;
        }

        final dayKey =
            '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
        if (t.type == TransactionType.expense) {
          dailyMap[dayKey] = (dailyMap[dayKey] ?? 0) + t.amount;
        }
      }

      final dailySpends =
          dailyMap.entries
              .map(
                (e) => DailySpend(date: DateTime.parse(e.key), amount: e.value),
              )
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      return right(
        SpendingSummary(
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          expenseByCategory: expenseByCategory,
          dailySpends: dailySpends,
        ),
      );
    } catch (e) {
      return left(CacheFailure(message: 'Failed to compute summary: $e'));
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  Future<void> _backgroundSync() async {
    try {
      final lastSync = await localDataSource.getLastSyncTime();
      final remote = lastSync != null
          ? await remoteDataSource.getTransactionsSince(lastSync)
          : await remoteDataSource.getTransactions();

      final local = await localDataSource.getCachedTransactions();
      final localMap = {for (final t in local) t.id: t};

      for (final r in remote) {
        if (!localMap.containsKey(r.id) || localMap[r.id] != r) {
          await localDataSource.cacheTransaction(r);
        }
      }
      await localDataSource.setLastSyncTime(DateTime.now());
    } catch (_) {
      // Background sync errors are silent — UI is already showing local data
    }
  }
}
