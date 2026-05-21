import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../domain/entities/transaction.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/usecases/sync_transactions.dart';

abstract class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

class SyncRequested extends SyncEvent {
  const SyncRequested();
}

class LocalTransactionsChanged extends SyncEvent {
  final List<Transaction> transactions;

  const LocalTransactionsChanged(this.transactions);

  @override
  List<Object?> get props => [transactions];
}

abstract class SyncState extends Equatable {
  const SyncState();

  @override
  List<Object?> get props => [];
}

class SyncIdle extends SyncState {
  const SyncIdle();
}

class SyncInProgress extends SyncState {
  const SyncInProgress();
}

class SyncSuccess extends SyncState {
  final SyncResult result;

  const SyncSuccess(this.result);

  @override
  List<Object?> get props => [result];
}

class SyncFailureState extends SyncState {
  final String message;

  const SyncFailureState(this.message);

  @override
  List<Object?> get props => [message];
}

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncTransactions syncTransactions;
  StreamSubscription<List<Transaction>>? _transactionSubscription;

  SyncBloc({required this.syncTransactions}) : super(const SyncIdle()) {
    on<SyncRequested>(_onSyncRequested);
    on<LocalTransactionsChanged>((event, emit) {
      if (state is! SyncInProgress) add(const SyncRequested());
    });
  }

  void connect(Stream<List<Transaction>> transactionStream) {
    _transactionSubscription?.cancel();
    _transactionSubscription = transactionStream.listen(
      (items) => add(LocalTransactionsChanged(items)),
    );
  }

  Future<void> _onSyncRequested(
    SyncRequested event,
    Emitter<SyncState> emit,
  ) async {
    emit(const SyncInProgress());
    final result = await syncTransactions();
    result.fold(
      (failure) => emit(SyncFailureState(failure.message)),
      (syncResult) => emit(SyncSuccess(syncResult)),
    );
  }

  @override
  Future<void> close() async {
    await _transactionSubscription?.cancel();
    return super.close();
  }
}
