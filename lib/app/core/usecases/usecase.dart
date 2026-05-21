import 'package:dartz/dartz.dart';

import '../error/failures.dart';

/// [Result] is the return type on success; [Params] is the input object.
abstract class UseCase<Result, Params> {
  Future<Either<Failure, Result>> call(Params params);
}

abstract class NoParamsUseCase<Result> {
  Future<Either<Failure, Result>> call();
}

abstract class SyncUseCase<Result, Params> {
  Either<Failure, Result> call(Params params);
}

class NoParams {
  const NoParams();
}
