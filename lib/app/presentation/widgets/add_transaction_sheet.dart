import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/transaction.dart';
import '../blocs/transaction/transaction_bloc.dart';

/// Redesigned add-transaction modal bottom sheet.
///
/// Features:
/// • Drag handle + rounded top corners
/// • Gradient "Save" button matching the teal/orange palette
/// • Animated type toggle with coloured accent
/// • Clean, spacious form layout
class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.food;

  // Palette constants
  static const _teal = Color(0xFF0E7C7B);
  static const _orange = Color(0xFFF08A4B);

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

  Color get _accentColor =>
      _type == TransactionType.expense ? _orange : _teal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──────────────────────────────────────────────
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ────────────────────────────────────────────────────
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Add Transaction', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 20),

            // ── Type toggle ───────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _TypeButton(
                    label: 'Expense',
                    icon: Icons.arrow_downward_rounded,
                    selected: _type == TransactionType.expense,
                    selectedColor: _orange,
                    onTap: () =>
                        setState(() => _type = TransactionType.expense),
                  ),
                  _TypeButton(
                    label: 'Income',
                    icon: Icons.arrow_upward_rounded,
                    selected: _type == TransactionType.income,
                    selectedColor: _teal,
                    onTap: () =>
                        setState(() => _type = TransactionType.income),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Title field ───────────────────────────────────────────────
            TextField(
              key: const ValueKey('title-field'),
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Title',
                prefixIcon: const Icon(Icons.edit_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Amount field ──────────────────────────────────────────────
            TextField(
              key: const ValueKey('amount-field'),
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixIcon: const Icon(Icons.attach_money_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Category dropdown ─────────────────────────────────────────
            DropdownButtonFormField<TransactionCategory>(
              value: _category,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: const Icon(Icons.label_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: TransactionCategory.values
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c.name[0].toUpperCase() + c.name.substring(1),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 24),

            // ── Save button ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _type == TransactionType.expense
                        ? [_orange, const Color(0xFFE05C1A)]
                        : [_teal, const Color(0xFF0A5554)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(
                    'Save Transaction',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helper: animated type selector button
// ─────────────────────────────────────────────────────────────────────────────

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
