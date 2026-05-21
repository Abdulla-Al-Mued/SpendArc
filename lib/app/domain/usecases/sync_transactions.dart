// app/domain/usecases/sync_transactions.dart
import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/transaction_repository.dart'
    show SyncResult, TransactionRepository;

class SyncTransactions implements NoParamsUseCase<SyncResult> {
  final TransactionRepository _repository;

  const SyncTransactions(this._repository);

  @override
  Future<Either<Failure, SyncResult>> call() => _repository.syncTransactions();
}
