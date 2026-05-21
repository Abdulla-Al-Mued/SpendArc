import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/error/failures.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/usecases/add_transaction.dart';
import '../../../domain/usecases/delete_transaction.dart';
import '../../../domain/usecases/get_transactions.dart';

abstract class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactionsEvent extends TransactionEvent {
  const LoadTransactionsEvent();
}

class AddTransactionEvent extends TransactionEvent {
  final Transaction transaction;

  const AddTransactionEvent(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

class DeleteTransactionEvent extends TransactionEvent {
  final String id;

  const DeleteTransactionEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class TransactionsSyncedEvent extends TransactionEvent {
  final List<Transaction> syncedTransactions;

  const TransactionsSyncedEvent(this.syncedTransactions);

  @override
  List<Object?> get props => [syncedTransactions];
}

abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

class TransactionInitial extends TransactionState {
  const TransactionInitial();
}

class TransactionLoading extends TransactionState {
  const TransactionLoading();
}

class TransactionLoaded extends TransactionState {
  final List<Transaction> transactions;
  final bool isSyncing;
  final String? optimisticError;

  const TransactionLoaded({
    required this.transactions,
    this.isSyncing = false,
    this.optimisticError,
  });

  TransactionLoaded copyWith({
    List<Transaction>? transactions,
    bool? isSyncing,
    String? optimisticError,
    bool clearError = false,
  }) {
    return TransactionLoaded(
      transactions: transactions ?? this.transactions,
      isSyncing: isSyncing ?? this.isSyncing,
      optimisticError: clearError ? null : optimisticError,
    );
  }

  @override
  List<Object?> get props => [transactions, isSyncing, optimisticError];
}

class TransactionError extends TransactionState {
  final String message;

  const TransactionError(this.message);

  @override
  List<Object?> get props => [message];
}

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final GetTransactions getTransactions;
  final AddTransaction addTransaction;
  final DeleteTransaction deleteTransaction;

  final _syncStreamController = StreamController<List<Transaction>>.broadcast();
  Stream<List<Transaction>> get transactionStream =>
      _syncStreamController.stream;

  TransactionBloc({
    required this.getTransactions,
    required this.addTransaction,
    required this.deleteTransaction,
  }) : super(const TransactionInitial()) {
    on<LoadTransactionsEvent>(_onLoad);
    on<AddTransactionEvent>(_onAdd);
    on<DeleteTransactionEvent>(_onDelete);
    on<TransactionsSyncedEvent>(_onSynced);
  }

  Future<void> _onLoad(
    LoadTransactionsEvent event,
    Emitter<TransactionState> emit,
  ) async {
    emit(const TransactionLoading());
    final result = await getTransactions();
    result.fold(
      (failure) => emit(TransactionError(_mapFailureMessage(failure))),
      (transactions) {
        final sorted = [...transactions]
          ..sort((a, b) => b.date.compareTo(a.date));
        emit(TransactionLoaded(transactions: sorted, isSyncing: true));
        _syncStreamController.add(sorted);
      },
    );
  }

  Future<void> _onAdd(
    AddTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! TransactionLoaded) return;

    final optimisticList = [event.transaction, ...currentState.transactions];
    emit(currentState.copyWith(transactions: optimisticList, clearError: true));

    final result = await addTransaction(event.transaction);
    result.fold(
      (failure) {
        emit(
          currentState.copyWith(
            transactions: currentState.transactions,
            optimisticError: _mapFailureMessage(failure),
          ),
        );
      },
      (savedTransaction) {
        final updated = optimisticList
            .map(
              (item) =>
                  item.id == savedTransaction.id ? savedTransaction : item,
            )
            .toList();
        emit(currentState.copyWith(transactions: updated, clearError: true));
        _syncStreamController.add(updated);
      },
    );
  }

  Future<void> _onDelete(
    DeleteTransactionEvent event,
    Emitter<TransactionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! TransactionLoaded) return;

    final snapshot = List<Transaction>.from(currentState.transactions);
    final optimisticList = currentState.transactions
        .where((item) => item.id != event.id)
        .toList();
    emit(currentState.copyWith(transactions: optimisticList, clearError: true));

    final result = await deleteTransaction(event.id);
    result.fold(
      (_) => emit(
        currentState.copyWith(
          transactions: snapshot,
          optimisticError: 'Delete failed. Changes reverted.',
        ),
      ),
      (_) => _syncStreamController.add(optimisticList),
    );
  }

  Future<void> _onSynced(
    TransactionsSyncedEvent event,
    Emitter<TransactionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! TransactionLoaded) return;

    final mergedById = {
      for (final item in currentState.transactions) item.id: item,
      for (final item in event.syncedTransactions)
        item.id: item.copyWith(isSynced: true),
    };
    final merged = mergedById.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    emit(currentState.copyWith(transactions: merged, isSyncing: false));
  }

  @override
  Future<void> close() {
    _syncStreamController.close();
    return super.close();
  }
}

String _mapFailureMessage(Failure failure) {
  return switch (failure) {
    ServerFailure() => 'Server error: ${failure.message}',
    CacheFailure() => 'Local storage error: ${failure.message}',
    ValidationFailure() => failure.message,
    NetworkFailure() => failure.message,
    UnexpectedFailure() => failure.message,
    _ => 'An unexpected error occurred',
  };
}
