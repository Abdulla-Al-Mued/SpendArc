// app/domain/usecases/get_spending_summary.dart
import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

class GetSpendingSummaryParams {
  final DateTime? from;
  final DateTime? to;

  const GetSpendingSummaryParams({this.from, this.to});
}

class GetSpendingSummary
    implements UseCase<SpendingSummary, GetSpendingSummaryParams> {
  final TransactionRepository _repository;

  const GetSpendingSummary(this._repository);

  @override
  Future<Either<Failure, SpendingSummary>> call(
    GetSpendingSummaryParams params,
  ) => _repository.getSpendingSummary(from: params.from, to: params.to);
}
