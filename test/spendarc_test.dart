import 'package:assesment/app/core/di/injection_container.dart' as di;
import 'package:assesment/app/core/error/failures.dart';
import 'package:assesment/app/data/datasources/transaction_local_datasource.dart';
import 'package:assesment/app/data/datasources/transaction_remote_datasource.dart';
import 'package:assesment/app/data/models/transaction_model.dart';
import 'package:assesment/app/data/repositories/transaction_repository_impl.dart';
import 'package:assesment/app/domain/entities/transaction.dart';
import 'package:assesment/app/domain/repositories/transaction_repository.dart';
import 'package:assesment/app/domain/usecases/add_transaction.dart';

import 'package:assesment/main.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('unit', () {
    test('AddTransaction rejects empty titles', () async {
      final useCase = AddTransaction(_FakeRepository());
      final result = await useCase(_transaction(title: ''));

      expect(result.isLeft(), isTrue);
      expect(
        result.swap().getOrElse(() => const UnexpectedFailure()),
        isA<ValidationFailure>(),
      );
    });

    test('TransactionModel maps to and from the domain entity', () {
      final entity = _transaction(title: 'Lunch', amount: 12.5);
      final model = TransactionModel.fromEntity(entity);

      expect(model.toJson()['transaction_type'], 'expense');
      expect(model.toEntity(), entity);
    });

    test('local datasource stores pending writes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final local = TransactionLocalDataSourceImpl(prefs: prefs);

      await local.addPendingWrite(
        PendingWrite(
          id: '1',
          operation: WriteOperationType.add,
          payload: TransactionModel.fromEntity(_transaction()).toJson(),
          createdAt: DateTime(2026),
        ),
      );

      expect(await local.getPendingWrites(), hasLength(1));
      await local.removePendingWrite('1');
      expect(await local.getPendingWrites(), isEmpty);
    });

    test('repository summarizes income, expense and daily spend', () async {
      final local = _MemoryLocalDataSource([
        TransactionModel.fromEntity(
          _transaction(amount: 100, type: TransactionType.income),
        ),
        TransactionModel.fromEntity(_transaction(id: '2', amount: 40)),
      ]);
      final repository = TransactionRepositoryImpl(
        remoteDataSource: _MemoryRemoteDataSource(),
        localDataSource: local,
      );

      final result = await repository.getSpendingSummary();

      final summary = result.getOrElse(
        () => throw StateError('summary failed'),
      );
      expect(summary.totalIncome, 100);
      expect(summary.totalExpense, 40);
      expect(summary.dailySpends, hasLength(1));
    });

    test('repository sync applies remote diff to local cache', () async {
      final remoteModel = TransactionModel.fromEntity(
        _transaction(id: 'remote', title: 'Remote'),
      );
      final local = _MemoryLocalDataSource();
      final repository = TransactionRepositoryImpl(
        remoteDataSource: _MemoryRemoteDataSource([remoteModel]),
        localDataSource: local,
      );

      final result = await repository.syncTransactions();

      expect(result.isRight(), isTrue);
      expect((await local.getCachedTransactions()).single.id, 'remote');
    });
  });

  group('widgets', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('SpendArc dashboard renders summary and chart', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await di.initDependencies();
      await tester.pumpWidget(const SpendArcApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('SpendArc'), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);
      expect(find.byKey(const ValueKey('spend-line-chart')), findsOneWidget);
    });

    testWidgets('adding a transaction updates the list optimistically', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await di.initDependencies();
      await tester.pumpWidget(const SpendArcApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Add').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.byKey(const ValueKey('title-field')),
        'Books',
      );
      await tester.enterText(find.byKey(const ValueKey('amount-field')), '31');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      tester.testTextInput.hide();
      await tester.pump();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Books'), findsOneWidget);
    });
  });
}

Transaction _transaction({
  String id = '1',
  String title = 'Coffee',
  double amount = 5,
  TransactionType type = TransactionType.expense,
}) {
  return Transaction(
    id: id,
    title: title,
    amount: amount,
    type: type,
    category: type == TransactionType.income
        ? TransactionCategory.salary
        : TransactionCategory.food,
    date: DateTime(2026, 5, 21),
  );
}

class _FakeRepository implements TransactionRepository {
  @override
  Future<Either<Failure, Transaction>> addTransaction(
    Transaction transaction,
  ) async => right(transaction);

  @override
  Future<Either<Failure, String>> deleteTransaction(String id) async =>
      right(id);

  @override
  Future<Either<Failure, SpendingSummary>> getSpendingSummary({
    DateTime? from,
    DateTime? to,
  }) async => right(
    const SpendingSummary(
      totalIncome: 0,
      totalExpense: 0,
      expenseByCategory: {},
      dailySpends: [],
    ),
  );

  @override
  Future<Either<Failure, List<Transaction>>> getTransactions() async =>
      right([]);

  @override
  Future<Either<Failure, SyncResult>> syncTransactions() async => right(
    SyncResult(added: 0, updated: 0, deleted: 0, syncedAt: DateTime(2026)),
  );
}

class _MemoryLocalDataSource implements TransactionLocalDataSource {
  final List<TransactionModel> _transactions;
  final List<PendingWrite> _writes = [];
  DateTime? _lastSync;

  _MemoryLocalDataSource([List<TransactionModel>? transactions])
    : _transactions = [...?transactions];

  @override
  Future<void> addPendingWrite(PendingWrite write) async => _writes.add(write);

  @override
  Future<void> cacheTransaction(TransactionModel transaction) async {
    _transactions.removeWhere((item) => item.id == transaction.id);
    _transactions.add(transaction);
  }

  @override
  Future<void> cacheTransactions(List<TransactionModel> transactions) async {
    _transactions
      ..clear()
      ..addAll(transactions);
  }

  @override
  Future<void> clearPendingWrites() async => _writes.clear();

  @override
  Future<List<TransactionModel>> getCachedTransactions() async => [
    ..._transactions,
  ];

  @override
  Future<DateTime?> getLastSyncTime() async => _lastSync;

  @override
  Future<List<PendingWrite>> getPendingWrites() async => [..._writes];

  @override
  Future<void> removePendingWrite(String id) async =>
      _writes.removeWhere((item) => item.id == id);

  @override
  Future<void> removeTransaction(String id) async =>
      _transactions.removeWhere((item) => item.id == id);

  @override
  Future<void> setLastSyncTime(DateTime time) async => _lastSync = time;
}

class _MemoryRemoteDataSource implements TransactionRemoteDataSource {
  final List<TransactionModel> _transactions;

  _MemoryRemoteDataSource([List<TransactionModel>? transactions])
    : _transactions = [...?transactions];

  @override
  Future<TransactionModel> addTransaction(TransactionModel model) async {
    _transactions.removeWhere((item) => item.id == model.id);
    final synced = model.copyWith(isSynced: true);
    _transactions.add(synced);
    return synced;
  }

  @override
  Future<void> deleteTransaction(String id) async =>
      _transactions.removeWhere((item) => item.id == id);

  @override
  Future<List<TransactionModel>> getTransactions() async => [..._transactions];

  @override
  Future<List<TransactionModel>> getTransactionsSince(
    DateTime lastSync,
  ) async => _transactions
      .where((item) => DateTime.parse(item.date).isAfter(lastSync))
      .toList();
}
