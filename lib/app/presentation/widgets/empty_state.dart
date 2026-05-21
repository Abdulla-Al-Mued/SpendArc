import 'package:flutter/material.dart';

/// Shown when the transaction list is empty.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'No transactions yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap + Add to record your first one',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
