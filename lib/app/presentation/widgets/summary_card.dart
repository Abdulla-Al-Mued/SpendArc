import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/transaction.dart';
import '../animations/arc_meter_painter.dart';
import 'metric_row.dart';

/// Card showing balance, income, expense and the animated arc gauge.
class SummaryCard extends StatelessWidget {
  final SpendingSummary summary;
  final double ratio;

  const SummaryCard({super.key, required this.summary, required this.ratio});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: r'$');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 142,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 850),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CustomPaint(
                  painter: ArcMeterPainter(value: value),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${(value * 100).round()}%'),
                        const Text('spent'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    money.format(summary.balance),
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  MetricRow(
                    label: 'Income',
                    value: money.format(summary.totalIncome),
                    color: Colors.teal,
                  ),
                  MetricRow(
                    label: 'Expenses',
                    value: money.format(summary.totalExpense),
                    color: Colors.deepOrange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
