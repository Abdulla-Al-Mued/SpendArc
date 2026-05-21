// app/data/models/transaction_model.dart
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/transaction.dart';

/// Data Transfer Object — lives in the data layer only.
/// Maps to/from JSON (API) and to/from the domain entity.
@JsonSerializable()
class TransactionModel {
  final String id;
  final String title;
  final double amount;
  @JsonKey(name: 'transaction_type')
  final String type;
  final String category;
  @JsonKey(name: 'transaction_date')
  final String date;
  final String? note;
  @JsonKey(name: 'is_synced', defaultValue: false)
  final bool isSynced;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note,
    this.isSynced = false,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      _$TransactionModelFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionModelToJson(this);

  /// Factory from domain entity → model (for persistence / API upload)
  factory TransactionModel.fromEntity(Transaction entity) {
    return TransactionModel(
      id: entity.id,
      title: entity.title,
      amount: entity.amount,
      type: entity.type.name,
      category: entity.category.name,
      date: entity.date.toIso8601String(),
      note: entity.note,
      isSynced: entity.isSynced,
    );
  }

  /// Converts model → domain entity (for use in use cases / BLoC)
  Transaction toEntity() {
    return Transaction(
      id: id,
      title: title,
      amount: amount,
      type: TransactionType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => TransactionType.expense,
      ),
      category: TransactionCategory.values.firstWhere(
        (e) => e.name == category,
        orElse: () => TransactionCategory.other,
      ),
      date: DateTime.parse(date),
      note: note,
      isSynced: isSynced,
    );
  }

  TransactionModel copyWith({bool? isSynced}) {
    return TransactionModel(
      id: id,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
      note: note,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

// ─── Manual JSON glue (avoids build_runner in assessment context) ─────────────
TransactionModel _$TransactionModelFromJson(Map<String, dynamic> json) =>
    TransactionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['transaction_type'] as String? ?? 'expense',
      category: json['category'] as String? ?? 'other',
      date: json['transaction_date'] as String,
      note: json['note'] as String?,
      isSynced: json['is_synced'] as bool? ?? false,
    );

Map<String, dynamic> _$TransactionModelToJson(TransactionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'amount': instance.amount,
      'transaction_type': instance.type,
      'category': instance.category,
      'transaction_date': instance.date,
      'note': instance.note,
      'is_synced': instance.isSynced,
    };
