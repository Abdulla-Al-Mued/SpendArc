// app/domain/entities/transaction.dart
import 'package:equatable/equatable.dart';

enum TransactionType { income, expense }

enum TransactionCategory {
  food,
  transport,
  entertainment,
  utilities,
  health,
  shopping,
  salary,
  investment,
  other,
}

/// Pure domain entity — no serialisation annotations, no framework dependencies.
class Transaction extends Equatable {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final TransactionCategory category;
  final DateTime date;
  final String? note;
  final bool isSynced;

  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note,
    this.isSynced = false,
  });

  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    TransactionCategory? category,
    DateTime? date,
    String? note,
    bool? isSynced,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    amount,
    type,
    category,
    date,
    note,
    isSynced,
  ];
}

/// Value object for spending summary
class SpendingSummary extends Equatable {
  final double totalIncome;
  final double totalExpense;
  final Map<TransactionCategory, double> expenseByCategory;
  final List<DailySpend> dailySpends;

  const SpendingSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.expenseByCategory,
    required this.dailySpends,
  });

  double get balance => totalIncome - totalExpense;
  double get savingsRate => totalIncome > 0 ? (balance / totalIncome) * 100 : 0;

  @override
  List<Object?> get props => [
    totalIncome,
    totalExpense,
    expenseByCategory,
    dailySpends,
  ];
}

class DailySpend extends Equatable {
  final DateTime date;
  final double amount;

  const DailySpend({required this.date, required this.amount});

  @override
  List<Object?> get props => [date, amount];
}
