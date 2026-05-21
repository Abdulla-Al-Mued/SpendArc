import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

class AddTransaction implements UseCase<Transaction, Transaction> {
  final TransactionRepository _repository;

  const AddTransaction(this._repository);

  @override
  Future<Either<Failure, Transaction>> call(Transaction params) {
    if (params.title.trim().isEmpty) {
      return Future.value(
        left(
          const ValidationFailure(
            message: 'Title cannot be empty',
            field: 'title',
          ),
        ),
      );
    }
    if (params.amount <= 0) {
      return Future.value(
        left(
          const ValidationFailure(
            message: 'Amount must be greater than zero',
            field: 'amount',
          ),
        ),
      );
    }
    return _repository.addTransaction(params);
  }
}
