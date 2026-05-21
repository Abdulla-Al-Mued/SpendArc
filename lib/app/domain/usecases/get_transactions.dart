// app/domain/usecases/get_transactions.dart
import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

class GetTransactions implements NoParamsUseCase<List<Transaction>> {
  final TransactionRepository _repository;

  const GetTransactions(this._repository);

  @override
  Future<Either<Failure, List<Transaction>>> call() =>
      _repository.getTransactions();
}
