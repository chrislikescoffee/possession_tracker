enum ListDestinationType {
  storageLocation,
  freeText,
  lend,
  notRelocating;

  String get displayName {
    switch (this) {
      case ListDestinationType.storageLocation:
        return 'Storage Location';
      case ListDestinationType.freeText:
        return 'Custom Note';
      case ListDestinationType.lend:
        return 'Lend All';
      case ListDestinationType.notRelocating:
        return 'Not Relocating';
    }
  }
}

class ItemListItemEntry {
  final String itemId;
  final bool isCollected;
  final DateTime? collectedAt;
  final String? lendingRecordId;
  final String? relocationNote;

  const ItemListItemEntry({
    required this.itemId,
    this.isCollected = false,
    this.collectedAt,
    this.lendingRecordId,
    this.relocationNote,
  });

  ItemListItemEntry copyWith({
    String? itemId,
    bool? isCollected,
    DateTime? collectedAt,
    String? lendingRecordId,
    String? relocationNote,
  }) {
    return ItemListItemEntry(
      itemId: itemId ?? this.itemId,
      isCollected: isCollected ?? this.isCollected,
      collectedAt: collectedAt ?? this.collectedAt,
      lendingRecordId: lendingRecordId ?? this.lendingRecordId,
      relocationNote: relocationNote ?? this.relocationNote,
    );
  }

  factory ItemListItemEntry.fromJson(Map<String, dynamic> json) {
    return ItemListItemEntry(
      itemId: json['item_id'] as String,
      isCollected: json['is_collected'] as bool? ?? false,
      collectedAt: json['collected_at'] != null
          ? DateTime.tryParse(json['collected_at'] as String)
          : null,
      lendingRecordId: json['lending_record_id'] as String?,
      relocationNote: json['relocation_note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'is_collected': isCollected,
        'collected_at': collectedAt?.toIso8601String(),
        'lending_record_id': lendingRecordId,
        'relocation_note': relocationNote,
      };
}

class ItemList {
  final String id;
  final String libraryId;
  final String name;
  final String? description;
  final ListDestinationType destinationType;
  final String? targetLocationId;
  final String? freeTextNote;
  final String? borrowerName;
  final String? borrowerContact;
  final DateTime? dueDate;
  final List<ItemListItemEntry> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItemList({
    required this.id,
    required this.libraryId,
    required this.name,
    this.description,
    this.destinationType = ListDestinationType.notRelocating,
    this.targetLocationId,
    this.freeTextNote,
    this.borrowerName,
    this.borrowerContact,
    this.dueDate,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalCount => items.length;
  int get collectedCount => items.where((e) => e.isCollected).length;
  double get progress => totalCount == 0 ? 0.0 : collectedCount / totalCount;
  bool get isComplete => totalCount > 0 && collectedCount == totalCount;

  factory ItemList.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['items'] as List? ?? [];
    final parsedEntries = rawEntries
        .whereType<Map<String, dynamic>>()
        .map((m) => ItemListItemEntry.fromJson(m))
        .toList();

    ListDestinationType destType = ListDestinationType.notRelocating;
    final rawTypeStr = json['destination_type'] as String?;
    if (rawTypeStr != null) {
      destType = ListDestinationType.values.firstWhere(
        (v) => v.name == rawTypeStr,
        orElse: () => ListDestinationType.notRelocating,
      );
    }

    return ItemList(
      id: json['id'] as String,
      libraryId: json['library_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      destinationType: destType,
      targetLocationId: json['target_location_id'] as String?,
      freeTextNote: json['free_text_note'] as String?,
      borrowerName: json['borrower_name'] as String?,
      borrowerContact: json['borrower_contact'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      items: parsedEntries,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'library_id': libraryId,
        'name': name,
        'description': description,
        'destination_type': destinationType.name,
        'target_location_id': targetLocationId,
        'free_text_note': freeTextNote,
        'borrower_name': borrowerName,
        'borrower_contact': borrowerContact,
        'due_date': dueDate?.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ItemList copyWith({
    String? id,
    String? libraryId,
    String? name,
    String? description,
    ListDestinationType? destinationType,
    String? targetLocationId,
    String? freeTextNote,
    String? borrowerName,
    String? borrowerContact,
    DateTime? dueDate,
    List<ItemListItemEntry>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemList(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      name: name ?? this.name,
      description: description ?? this.description,
      destinationType: destinationType ?? this.destinationType,
      targetLocationId: targetLocationId ?? this.targetLocationId,
      freeTextNote: freeTextNote ?? this.freeTextNote,
      borrowerName: borrowerName ?? this.borrowerName,
      borrowerContact: borrowerContact ?? this.borrowerContact,
      dueDate: dueDate ?? this.dueDate,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
