import 'package:flutter/material.dart';

import '../../domain/entities/transaction.dart';

/// Returns a [SpendingSummary] aggregated from [transactions].
SpendingSummary summaryFromTransactions(List<Transaction> transactions) {
  var income = 0.0;
  var expense = 0.0;
  final byCategory = <TransactionCategory, double>{};

  for (final tx in transactions) {
    if (tx.type == TransactionType.income) {
      income += tx.amount;
    } else {
      expense += tx.amount;
      byCategory[tx.category] = (byCategory[tx.category] ?? 0) + tx.amount;
    }
  }

  return SpendingSummary(
    totalIncome: income,
    totalExpense: expense,
    expenseByCategory: byCategory,
    dailySpends: dailySpend(transactions),
  );
}

/// Aggregates daily expense totals, sorted ascending by date.
List<DailySpend> dailySpend(List<Transaction> transactions) {
  final values = <DateTime, double>{};
  for (final tx
      in transactions.where((t) => t.type == TransactionType.expense)) {
    final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
    values[day] = (values[day] ?? 0) + tx.amount;
  }
  return values.entries
      .map((e) => DailySpend(date: e.key, amount: e.value))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

/// Returns the icon [IconData] for a given [TransactionCategory].
IconData iconForCategory(TransactionCategory category) {
  return switch (category) {
    TransactionCategory.food => Icons.restaurant,
    TransactionCategory.transport => Icons.directions_transit,
    TransactionCategory.entertainment => Icons.movie,
    TransactionCategory.utilities => Icons.bolt,
    TransactionCategory.health => Icons.local_hospital,
    TransactionCategory.shopping => Icons.shopping_bag,
    TransactionCategory.salary => Icons.payments,
    TransactionCategory.investment => Icons.trending_up,
    TransactionCategory.other => Icons.category,
  };
}
