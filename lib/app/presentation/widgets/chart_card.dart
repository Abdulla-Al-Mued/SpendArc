import 'package:flutter/material.dart';

import '../../domain/entities/transaction.dart';
import '../animations/spend_line_chart_painter.dart';

/// Card containing the daily spend line chart.
class ChartCard extends StatelessWidget {
  final List<DailySpend> dailySpends;

  const ChartCard({super.key, required this.dailySpends});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Spend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: CustomPaint(
                key: const ValueKey('spend-line-chart'),
                painter: SpendLineChartPainter(dailySpends),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
