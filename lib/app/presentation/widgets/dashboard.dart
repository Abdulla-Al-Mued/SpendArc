import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/transaction.dart';
import '../blocs/summary/summary_bloc.dart';
import '../blocs/transaction/transaction_bloc.dart';
import '../utils/transaction_utils.dart';
import 'chart_card.dart';
import 'empty_state.dart';
import 'summary_card.dart';
import 'transaction_tile.dart';

/// The main scrollable dashboard body: summary card, chart, and transaction list.
class Dashboard extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback onAdd;
  final ValueChanged<Offset> onDeleted;

  const Dashboard({
    super.key,
    required this.transactions,
    required this.onAdd,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final summary = summaryFromTransactions(transactions);
    final daily = dailySpend(transactions);
    final expenseRatio = summary.totalIncome == 0
        ? 0.0
        : (summary.totalExpense / summary.totalIncome).clamp(0.0, 1.0);

    return RefreshIndicator(
      onRefresh: () async {
        context.read<TransactionBloc>().add(const LoadTransactionsEvent());
        context.read<SummaryBloc>().add(const LoadSummaryEvent());
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 680;
              final cards = [
                SummaryCard(summary: summary, ratio: expenseRatio),
                ChartCard(dailySpends: daily),
              ];
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                      ],
                    )
                  : Column(
                      children: [
                        cards[0],
                        const SizedBox(height: 12),
                        cards[1],
                      ],
                    );
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Transactions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_card),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            const EmptyState()
          else
            for (final tx in transactions)
              TransactionTile(
                key: ValueKey(tx.id),
                transaction: tx,
                onDeleted: onDeleted,
              ),
        ],
      ),
    );
  }
}
