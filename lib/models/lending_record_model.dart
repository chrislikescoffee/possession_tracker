/// Represents a loan custody transaction for an item
class LendingRecord {
  final String id;
  final String itemId;
  final String libraryId;
  final String borrowerName;
  final String? borrowerContact;
  final DateTime lentAt;
  final DateTime? expectedReturnAt;
  final DateTime? returnedAt;
  final String? notes;

  const LendingRecord({
    required this.id,
    required this.itemId,
    required this.libraryId,
    required this.borrowerName,
    this.borrowerContact,
    required this.lentAt,
    this.expectedReturnAt,
    this.returnedAt,
    this.notes,
  });

  bool get isActive => returnedAt == null;

  factory LendingRecord.fromJson(Map<String, dynamic> json) {
    return LendingRecord(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      libraryId: json['library_id'] as String,
      borrowerName: json['borrower_name'] as String,
      borrowerContact: json['borrower_contact'] as String?,
      lentAt: json['lent_at'] != null
          ? DateTime.parse(json['lent_at'] as String)
          : DateTime.now(),
      expectedReturnAt: json['expected_return_at'] != null
          ? DateTime.parse(json['expected_return_at'] as String)
          : null,
      returnedAt: json['returned_at'] != null
          ? DateTime.parse(json['returned_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_id': itemId,
        'library_id': libraryId,
        'borrower_name': borrowerName,
        'borrower_contact': borrowerContact,
        'lent_at': lentAt.toIso8601String(),
        'expected_return_at': expectedReturnAt?.toIso8601String(),
        'returned_at': returnedAt?.toIso8601String(),
        'notes': notes,
      };

  LendingRecord copyWith({
    String? id,
    String? itemId,
    String? libraryId,
    String? borrowerName,
    String? borrowerContact,
    DateTime? lentAt,
    DateTime? expectedReturnAt,
    DateTime? returnedAt,
    String? notes,
  }) {
    return LendingRecord(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      libraryId: libraryId ?? this.libraryId,
      borrowerName: borrowerName ?? this.borrowerName,
      borrowerContact: borrowerContact ?? this.borrowerContact,
      lentAt: lentAt ?? this.lentAt,
      expectedReturnAt: expectedReturnAt ?? this.expectedReturnAt,
      returnedAt: returnedAt ?? this.returnedAt,
      notes: notes ?? this.notes,
    );
  }
}
