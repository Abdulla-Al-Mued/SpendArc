import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../domain/entities/transaction.dart';
import '../../../domain/usecases/get_spending_summary.dart';

abstract class SummaryEvent extends Equatable {
  const SummaryEvent();

  @override
  List<Object?> get props => [];
}

class LoadSummaryEvent extends SummaryEvent {
  const LoadSummaryEvent();
}

abstract class SummaryState extends Equatable {
  const SummaryState();

  @override
  List<Object?> get props => [];
}

class SummaryInitial extends SummaryState {
  const SummaryInitial();
}

class SummaryLoading extends SummaryState {
  const SummaryLoading();
}

class SummaryLoaded extends SummaryState {
  final SpendingSummary summary;

  const SummaryLoaded(this.summary);

  @override
  List<Object?> get props => [summary];
}

class SummaryError extends SummaryState {
  final String message;

  const SummaryError(this.message);

  @override
  List<Object?> get props => [message];
}

class SummaryBloc extends Bloc<SummaryEvent, SummaryState> {
  final GetSpendingSummary getSpendingSummary;

  SummaryBloc({required this.getSpendingSummary})
    : super(const SummaryInitial()) {
    on<LoadSummaryEvent>(_onLoad);
  }

  Future<void> _onLoad(
    LoadSummaryEvent event,
    Emitter<SummaryState> emit,
  ) async {
    emit(const SummaryLoading());
    final result = await getSpendingSummary(const GetSpendingSummaryParams());
    result.fold(
      (failure) => emit(SummaryError(failure.message)),
      (summary) => emit(SummaryLoaded(summary)),
    );
  }
}
