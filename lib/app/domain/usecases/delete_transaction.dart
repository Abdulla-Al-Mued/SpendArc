import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/transaction_repository.dart';

class DeleteTransaction implements UseCase<String, String> {
  final TransactionRepository _repository;

  const DeleteTransaction(this._repository);

  @override
  Future<Either<Failure, String>> call(String id) {
    if (id.trim().isEmpty) {
      return Future.value(
        left(
          const ValidationFailure(
            message: 'Transaction ID cannot be empty',
            field: 'id',
          ),
        ),
      );
    }
    return _repository.deleteTransaction(id);
  }
}
