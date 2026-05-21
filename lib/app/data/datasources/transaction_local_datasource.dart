// app/data/datasources/transaction_local_datasource.dart
import 'dart:convert';
import 'dart:isolate';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

/// Represents a pending write operation that hasn't been synced yet.
enum WriteOperationType { add, delete, update }

class PendingWrite {
  final String id;
  final WriteOperationType operation;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  const PendingWrite({
    required this.id,
    required this.operation,
    this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation.name,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PendingWrite.fromJson(Map<String, dynamic> json) => PendingWrite(
    id: json['id'] as String,
    operation: WriteOperationType.values.firstWhere(
      (e) => e.name == json['operation'],
    ),
    payload: json['payload'] as Map<String, dynamic>?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

abstract class TransactionLocalDataSource {
  Future<List<TransactionModel>> getCachedTransactions();
  Future<void> cacheTransactions(List<TransactionModel> transactions);
  Future<void> cacheTransaction(TransactionModel transaction);
  Future<void> removeTransaction(String id);
  Future<DateTime?> getLastSyncTime();
  Future<void> setLastSyncTime(DateTime time);

  // Write queue for offline-first
  Future<List<PendingWrite>> getPendingWrites();
  Future<void> addPendingWrite(PendingWrite write);
  Future<void> removePendingWrite(String id);
  Future<void> clearPendingWrites();
}

class TransactionLocalDataSourceImpl implements TransactionLocalDataSource {
  final SharedPreferences _prefs;

  static const _transactionsKey = 'cached_transactions';
  static const _lastSyncKey = 'last_sync_time';
  static const _pendingWritesKey = 'pending_writes';

  const TransactionLocalDataSourceImpl({required SharedPreferences prefs})
    : _prefs = prefs;

  @override
  Future<List<TransactionModel>> getCachedTransactions() async {
    final json = _prefs.getString(_transactionsKey);
    if (json == null) return [];

    if (json.length < 5000) {
      final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Use an isolate to decode large JSON off the UI thread (Module 4 requirement).
    return await _decodeTransactionsInIsolate(json);
  }

  /// Decodes JSON in a separate isolate to avoid jank on large datasets.
  static Future<List<TransactionModel>> _decodeTransactionsInIsolate(
    String json,
  ) async {
    final result = await Isolate.run(() {
      final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });
    return result;
  }

  @override
  Future<void> cacheTransactions(List<TransactionModel> transactions) async {
    final json = jsonEncode(transactions.map((t) => t.toJson()).toList());
    await _prefs.setString(_transactionsKey, json);
  }

  @override
  Future<void> cacheTransaction(TransactionModel transaction) async {
    final existing = await getCachedTransactions();
    final index = existing.indexWhere((t) => t.id == transaction.id);
    if (index >= 0) {
      existing[index] = transaction;
    } else {
      existing.insert(0, transaction); // newest first
    }
    await cacheTransactions(existing);
  }

  @override
  Future<void> removeTransaction(String id) async {
    final existing = await getCachedTransactions();
    existing.removeWhere((t) => t.id == id);
    await cacheTransactions(existing);
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    final raw = _prefs.getString(_lastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> setLastSyncTime(DateTime time) async {
    await _prefs.setString(_lastSyncKey, time.toIso8601String());
  }

  // ─── Write Queue ─────────────────────────────────────────────────────────────

  @override
  Future<List<PendingWrite>> getPendingWrites() async {
    final json = _prefs.getString(_pendingWritesKey);
    if (json == null) return [];
    final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
    return decoded
        .map((e) => PendingWrite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> addPendingWrite(PendingWrite write) async {
    final pending = await getPendingWrites();
    pending.add(write);
    await _prefs.setString(
      _pendingWritesKey,
      jsonEncode(pending.map((p) => p.toJson()).toList()),
    );
  }

  @override
  Future<void> removePendingWrite(String id) async {
    final pending = await getPendingWrites();
    pending.removeWhere((p) => p.id == id);
    await _prefs.setString(
      _pendingWritesKey,
      jsonEncode(pending.map((p) => p.toJson()).toList()),
    );
  }

  @override
  Future<void> clearPendingWrites() async {
    await _prefs.remove(_pendingWritesKey);
  }
}
