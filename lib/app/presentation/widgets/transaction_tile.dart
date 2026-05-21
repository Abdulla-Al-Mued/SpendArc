import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/transaction.dart';
import '../blocs/transaction/transaction_bloc.dart';
import '../utils/transaction_utils.dart';

/// A dismissible, press-to-scale transaction list tile.
class TransactionTile extends StatefulWidget {
  final Transaction transaction;
  final ValueChanged<Offset> onDeleted;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onDeleted,
  });

  @override
  State<TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<TransactionTile> {
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
                  backgroundColor:
                      (isExpense ? Colors.deepOrange : Colors.teal)
                          .withValues(alpha: 0.12),
                  child: Icon(
                    iconForCategory(transaction.category),
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
