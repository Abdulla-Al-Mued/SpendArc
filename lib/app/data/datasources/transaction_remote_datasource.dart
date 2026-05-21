// app/data/datasources/transaction_remote_datasource.dart
import 'package:dio/dio.dart';
import '../../core/error/failures.dart';
import '../models/transaction_model.dart';

abstract class TransactionRemoteDataSource {
  Future<List<TransactionModel>> getTransactions();
  Future<TransactionModel> addTransaction(TransactionModel model);
  Future<void> deleteTransaction(String id);
  Future<List<TransactionModel>> getTransactionsSince(DateTime lastSync);
}

class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  final Dio _dio;
  final List<TransactionModel> _memory = [
    TransactionModel(
      id: 'remote-1',
      title: 'Coffee beans',
      amount: 18.50,
      type: 'expense',
      category: 'food',
      date: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      note: 'Remote demo transaction',
      isSynced: true,
    ),
    TransactionModel(
      id: 'remote-2',
      title: 'Freelance payout',
      amount: 420,
      type: 'income',
      category: 'salary',
      date: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      isSynced: true,
    ),
  ];

  TransactionRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  @override
  Future<List<TransactionModel>> getTransactions() async {
    if (_dio.options.baseUrl.contains('spendarc.dev')) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      return List<TransactionModel>.from(_memory);
    }
    try {
      final response = await _dio.get('/transactions');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      return data
          .map(
            (json) => TransactionModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<TransactionModel> addTransaction(TransactionModel model) async {
    if (_dio.options.baseUrl.contains('spendarc.dev')) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      final synced = model.copyWith(isSynced: true);
      _memory
        ..removeWhere((item) => item.id == synced.id)
        ..insert(0, synced);
      return synced;
    }
    try {
      final response = await _dio.post('/transactions', data: model.toJson());
      return TransactionModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    if (_dio.options.baseUrl.contains('spendarc.dev')) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
      _memory.removeWhere((item) => item.id == id);
      return;
    }
    try {
      await _dio.delete('/transactions/$id');
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<List<TransactionModel>> getTransactionsSince(DateTime lastSync) async {
    if (_dio.options.baseUrl.contains('spendarc.dev')) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
      return _memory
          .where((item) => DateTime.parse(item.date).isAfter(lastSync))
          .toList();
    }
    try {
      final response = await _dio.get(
        '/transactions',
        queryParameters: {'since': lastSync.toIso8601String()},
      );
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      return data
          .map(
            (json) => TransactionModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  ServerFailure _mapDioError(DioException e) {
    return ServerFailure(
      message:
          e.response?.data?['message'] as String? ??
          e.message ??
          'Server error',
      statusCode: e.response?.statusCode,
      code: 'SERVER_${e.response?.statusCode ?? 0}',
    );
  }
}
