import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'app/core/di/injection_container.dart' as di;
import 'app/domain/entities/transaction.dart';
import 'app/presentation/blocs/summary/summary_bloc.dart';
import 'app/presentation/blocs/sync/sync_bloc.dart';
import 'app/presentation/blocs/transaction/transaction_bloc.dart';
import 'app/presentation/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.initDependencies();
  runApp(const SpendArcApp());
}

class SpendArcApp extends StatelessWidget {
  const SpendArcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SpendArc',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E7C7B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F4),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                di.sl<TransactionBloc>()..add(const LoadTransactionsEvent()),
          ),
          BlocProvider(create: (_) => di.sl<SyncBloc>()),
          BlocProvider(
            create: (_) => di.sl<SummaryBloc>()..add(const LoadSummaryEvent()),
          ),
        ],
        child: const _BlocConnector(child: SpendArcHomePage()),
      ),
    );
  }
}

class _BlocConnector extends StatefulWidget {
  final Widget child;

  const _BlocConnector({required this.child});

  @override
  State<_BlocConnector> createState() => _BlocConnectorState();
}

class _BlocConnectorState extends State<_BlocConnector> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<SyncBloc>().connect(
      context.read<TransactionBloc>().transactionStream,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

