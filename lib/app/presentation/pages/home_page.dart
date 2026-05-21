import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/transaction.dart';
import '../blocs/summary/summary_bloc.dart';
import '../blocs/sync/sync_bloc.dart';
import '../blocs/transaction/transaction_bloc.dart';

class SpendArcHomePage extends StatefulWidget {
  const SpendArcHomePage({super.key});

  @override
  State<SpendArcHomePage> createState() => _SpendArcHomePageState();
}

class _SpendArcHomePageState extends State<SpendArcHomePage>
    with TickerProviderStateMixin {
  late final AnimationController _particleController;
  Offset _burstOrigin = Offset.zero;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  void _showAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<TransactionBloc>(),
        child: const _AddTransactionSheet(),
      ),
    );
  }

  void _triggerBurst(Offset origin) {
    setState(() => _burstOrigin = origin);
    _particleController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TransactionBloc, TransactionState>(
          listenWhen: (previous, current) =>
          current is TransactionLoaded && current.optimisticError != null,
          listener: (context, state) {
            final loaded = state as TransactionLoaded;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(loaded.optimisticError!)));
          },
        ),
        BlocListener<SyncBloc, SyncState>(
          listener: (context, state) {
            if (state is SyncSuccess) {
              context.read<SummaryBloc>().add(const LoadSummaryEvent());
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SpendArc'),
          actions: [
            BlocBuilder<SyncBloc, SyncState>(
              builder: (context, state) {
                final syncing = state is SyncInProgress;
                return IconButton(
                  tooltip: syncing ? 'Syncing' : 'Sync now',
                  onPressed: syncing
                      ? null
                      : () =>
                      context.read<SyncBloc>().add(const SyncRequested()),
                  icon: syncing
                      ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.sync),
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, state) {
                if (state is TransactionLoading ||
                    state is TransactionInitial) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is TransactionError) {
                  return Center(child: Text(state.message));
                }
                final transactions = (state as TransactionLoaded).transactions;
                return _Dashboard(
                  transactions: transactions,
                  onAdd: _showAddSheet,
                  onDeleted: _triggerBurst,
                );
              },
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) => CustomPaint(
                  painter: ParticleBurstPainter(
                    progress: _particleController.value,
                    origin: _burstOrigin,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddSheet,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback onAdd;
  final ValueChanged<Offset> onDeleted;

  const _Dashboard({
    required this.transactions,
    required this.onAdd,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final summary = _summaryFromTransactions(transactions);
    final daily = _dailySpend(transactions);
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
                _SummaryCard(summary: summary, ratio: expenseRatio),
                _ChartCard(dailySpends: daily),
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
            const _EmptyState()
          else
            for (final transaction in transactions)
              _TransactionTile(
                key: ValueKey(transaction.id),
                transaction: transaction,
                onDeleted: onDeleted,
              ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final SpendingSummary summary;
  final double ratio;

  const _SummaryCard({required this.summary, required this.ratio});

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
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MetricRow(
                    label: 'Income',
                    value: money.format(summary.totalIncome),
                    color: Colors.teal,
                  ),
                  _MetricRow(
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

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final List<DailySpend> dailySpends;

  const _ChartCard({required this.dailySpends});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Spend', style: Theme.of(context).textTheme.titleMedium),
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

class _TransactionTile extends StatefulWidget {
  final Transaction transaction;
  final ValueChanged<Offset> onDeleted;

  const _TransactionTile({
    super.key,
    required this.transaction,
    required this.onDeleted,
  });

  @override
  State<_TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<_TransactionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final money = NumberFormat.currency(symbol: r'$');
    final isExpense = transaction.type == TransactionType.expense;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: _pressed ? 0.97 : 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Dismissible(
          key: ValueKey('dismiss-${transaction.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade500,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) {
            final box = context.findRenderObject() as RenderBox?;
            final origin =
                box?.localToGlobal(box.size.center(Offset.zero)) ?? Offset.zero;
            widget.onDeleted(origin);
            context.read<TransactionBloc>().add(
              DeleteTransactionEvent(transaction.id),
            );
          },
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (isExpense ? Colors.deepOrange : Colors.teal)
                      .withValues(alpha: 0.12),
                  child: Icon(
                    _iconForCategory(transaction.category),
                    color: isExpense ? Colors.deepOrange : Colors.teal,
                  ),
                ),
                title: Text(transaction.title),
                subtitle: Text(
                  '${transaction.category.name} • ${DateFormat.MMMd().format(transaction.date)}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isExpense ? '-' : '+'}${money.format(transaction.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isExpense ? Colors.deepOrange : Colors.teal,
                      ),
                    ),
                    Icon(
                      transaction.isSynced
                          ? Icons.cloud_done
                          : Icons.cloud_queue,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTransactionSheet extends StatefulWidget {
  const _AddTransactionSheet();

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.food;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (_titleController.text.trim().isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title and a positive amount.')),
      );
      return;
    }
    final transaction = Transaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      amount: amount,
      type: _type,
      category: _category,
      date: DateTime.now(),
    );
    context.read<TransactionBloc>().add(AddTransactionEvent(transaction));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add transaction',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) =>
                  setState(() => _type = value.first),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('title-field'),
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('amount-field'),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TransactionCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: TransactionCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                  value: category,
                  child: Text(category.name),
                ),
              )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No transactions yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}

class ArcMeterPainter extends CustomPainter {
  final double value;

  const ArcMeterPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.1;
    final rect =
    Offset(stroke / 2, stroke / 2) &
    Size(size.width - stroke, size.height - stroke);
    final start = math.pi * 0.78;
    final sweep = math.pi * 1.44;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = const Color(0xFFE2E5DD);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = const SweepGradient(
        colors: [Color(0xFF0E7C7B), Color(0xFFF08A4B), Color(0xFF0E7C7B)],
      ).createShader(rect);

    canvas.drawArc(rect, start, sweep, false, base);
    canvas.drawArc(rect, start, sweep * value.clamp(0, 1), false, active);
  }

  @override
  bool shouldRepaint(covariant ArcMeterPainter oldDelegate) =>
      oldDelegate.value != value;
}

class SpendLineChartPainter extends CustomPainter {
  final List<DailySpend> points;

  const SpendLineChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = const Color(0xFFE3E5DE)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), axisPaint);
    }

    if (points.isEmpty) return;
    final maxAmount = points
        .map((point) => point.amount)
        .reduce(math.max)
        .clamp(1, double.infinity);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : i * size.width / (points.length - 1);
      final y =
          size.height - (points[i].amount / maxAmount * size.height * 0.86) - 8;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x550E7C7B), Color(0x000E7C7B)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0E7C7B)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant SpendLineChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class ParticleBurstPainter extends CustomPainter {
  final double progress;
  final Offset origin;

  const ParticleBurstPainter({required this.progress, required this.origin});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || origin == Offset.zero) return;
    final paint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 1 - progress);
    for (var i = 0; i < 18; i++) {
      final angle = (math.pi * 2 / 18) * i;
      final distance = 8 + 46 * Curves.easeOut.transform(progress);
      final offset =
          origin + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(offset, 4 * (1 - progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticleBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.origin != origin;
}

SpendingSummary _summaryFromTransactions(List<Transaction> transactions) {
  var income = 0.0;
  var expense = 0.0;
  final byCategory = <TransactionCategory, double>{};
  for (final transaction in transactions) {
    if (transaction.type == TransactionType.income) {
      income += transaction.amount;
    } else {
      expense += transaction.amount;
      byCategory[transaction.category] =
          (byCategory[transaction.category] ?? 0) + transaction.amount;
    }
  }
  return SpendingSummary(
    totalIncome: income,
    totalExpense: expense,
    expenseByCategory: byCategory,
    dailySpends: _dailySpend(transactions),
  );
}

List<DailySpend> _dailySpend(List<Transaction> transactions) {
  final values = <DateTime, double>{};
  for (final transaction in transactions.where(
        (item) => item.type == TransactionType.expense,
  )) {
    final day = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    values[day] = (values[day] ?? 0) + transaction.amount;
  }
  return values.entries
      .map((entry) => DailySpend(date: entry.key, amount: entry.value))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

IconData _iconForCategory(TransactionCategory category) {
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