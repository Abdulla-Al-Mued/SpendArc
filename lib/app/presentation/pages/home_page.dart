import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../animations/particle_burst_painter.dart';
import '../blocs/summary/summary_bloc.dart';
import '../blocs/sync/sync_bloc.dart';
import '../blocs/transaction/transaction_bloc.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/dashboard.dart';

class SpendArcHomePage extends StatefulWidget {
  const SpendArcHomePage({super.key});

  @override
  State<SpendArcHomePage> createState() => _SpendArcHomePageState();
}

class _SpendArcHomePageState extends State<SpendArcHomePage>
    with TickerProviderStateMixin {
  late final AnimationController _particleController;
  Offset _burstOrigin = Offset.zero;

  // Palette
  static const _teal = Color(0xFF0E7C7B);
  static const _orange = Color(0xFFF08A4B);

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
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<TransactionBloc>(),
        child: const AddTransactionSheet(),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loaded.optimisticError!)),
            );
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
                  tooltip: syncing ? 'Syncing…' : 'Sync now',
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
            // ── Main content ────────────────────────────────────────────
            BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, state) {
                if (state is TransactionLoading || state is TransactionInitial) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is TransactionError) {
                  return Center(child: Text(state.message));
                }
                final transactions = (state as TransactionLoaded).transactions;
                return Dashboard(
                  transactions: transactions,
                  onAdd: _showAddSheet,
                  onDeleted: _triggerBurst,
                );
              },
            ),

            // ── Particle burst overlay ───────────────────────────────────
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

        // ── Gradient pill FAB ────────────────────────────────────────────
        floatingActionButton: _GradientFab(onPressed: _showAddSheet),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom gradient pill FAB that matches the app's teal→orange palette.
// ─────────────────────────────────────────────────────────────────────────────

class _GradientFab extends StatefulWidget {
  final VoidCallback onPressed;
  const _GradientFab({required this.onPressed});

  @override
  State<_GradientFab> createState() => _GradientFabState();
}

class _GradientFabState extends State<_GradientFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hover;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _hover = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1, end: 1.05).animate(
      CurvedAnimation(parent: _hover, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _hover.forward(),
        onTapUp: (_) {
          _hover.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _hover.reverse(),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0E7C7B), Color(0xFFF08A4B)],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0E7C7B).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Add',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}