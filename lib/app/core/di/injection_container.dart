// app/core/di/injection_container.dart
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Data layer
import '../../data/datasources/transaction_remote_datasource.dart';
import '../../data/datasources/transaction_local_datasource.dart';
import '../../data/repositories/transaction_repository_impl.dart';

// Domain layer
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/get_transactions.dart';
import '../../domain/usecases/add_transaction.dart';
import '../../domain/usecases/delete_transaction.dart';
import '../../domain/usecases/sync_transactions.dart';
import '../../domain/usecases/get_spending_summary.dart';
import '../../data/models/transaction_model.dart';

// BLoCs
import '../../presentation/blocs/transaction/transaction_bloc.dart';
import '../../presentation/blocs/sync/sync_bloc.dart';
import '../../presentation/blocs/summary/summary_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  if (sl.isRegistered<SharedPreferences>()) {
    await sl.reset();
  }
  // ─── External ───────────────────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => prefs);

  sl.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.spendarc.dev/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    // Add logging in debug mode
    dio.interceptors.add(LogInterceptor(responseBody: true));
    return dio;
  });

  // ─── Data Sources ────────────────────────────────────────────────────────────
  sl.registerLazySingleton<TransactionRemoteDataSource>(
    () => TransactionRemoteDataSourceImpl(dio: sl()),
  );

  sl.registerLazySingleton<TransactionLocalDataSource>(
    () => TransactionLocalDataSourceImpl(prefs: sl()),
  );

  final local = sl<TransactionLocalDataSource>();
  if ((await local.getCachedTransactions()).isEmpty) {
    await local.cacheTransactions([
      TransactionModel(
        id: 'seed-1',
        title: 'Grocery run',
        amount: 54.20,
        type: 'expense',
        category: 'food',
        date: DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        note: 'Weekly essentials',
        isSynced: false,
      ),
      TransactionModel(
        id: 'seed-2',
        title: 'Metro card',
        amount: 22,
        type: 'expense',
        category: 'transport',
        date: DateTime.now()
            .subtract(const Duration(days: 3))
            .toIso8601String(),
        isSynced: false,
      ),
      TransactionModel(
        id: 'seed-3',
        title: 'Salary',
        amount: 1250,
        type: 'income',
        category: 'salary',
        date: DateTime.now()
            .subtract(const Duration(days: 4))
            .toIso8601String(),
        isSynced: true,
      ),
      TransactionModel(
        id: 'seed-4',
        title: 'Streaming',
        amount: 14.99,
        type: 'expense',
        category: 'entertainment',
        date: DateTime.now()
            .subtract(const Duration(days: 6))
            .toIso8601String(),
        isSynced: true,
      ),
    ]);
  }

  // ─── Repositories ────────────────────────────────────────────────────────────
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );

  // ─── Use Cases ───────────────────────────────────────────────────────────────
  sl.registerLazySingleton(() => GetTransactions(sl()));
  sl.registerLazySingleton(() => AddTransaction(sl()));
  sl.registerLazySingleton(() => DeleteTransaction(sl()));
  sl.registerLazySingleton(() => SyncTransactions(sl()));
  sl.registerLazySingleton(() => GetSpendingSummary(sl()));

  // ─── BLoCs ───────────────────────────────────────────────────────────────────
  // Registered as factories so each Page gets a fresh instance.
  sl.registerFactory(
    () => TransactionBloc(
      getTransactions: sl(),
      addTransaction: sl(),
      deleteTransaction: sl(),
    ),
  );

  sl.registerFactory(
    () => SyncBloc(
      syncTransactions: sl(),
      // SyncBloc listens to TransactionBloc events via stream
    ),
  );

  sl.registerFactory(() => SummaryBloc(getSpendingSummary: sl()));
}
