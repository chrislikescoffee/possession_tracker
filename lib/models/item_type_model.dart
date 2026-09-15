import 'field_definition_model.dart';

class ItemType {
  final String id;
  final String libraryId;
  final String name;
  final String? description;
  final String? icon; // Material icon identifier name, e.g. 'build', 'terrain', 'palette'
  final List<FieldDefinition> fields;
  final DateTime createdAt;

  const ItemType({
    required this.id,
    required this.libraryId,
    required this.name,
    this.description,
    this.icon,
    this.fields = const [],
    required this.createdAt,
  });

  static ItemType genericItem(String libraryId) {
    return ItemType(
      id: 'generic',
      libraryId: libraryId,
      name: 'Generic Item',
      description: 'Standard possession without specialized fields',
      icon: 'inventory_2',
      fields: const [],
      createdAt: DateTime(2026, 1, 1),
    );
  }

  factory ItemType.fromJson(Map<String, dynamic> json) {
    return ItemType(
      id: json['id'] as String,
      libraryId: json['library_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Generic Item',
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      fields: (json['fields'] as List<dynamic>? ?? [])
          .map((f) => FieldDefinition.fromJson(f as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'library_id': libraryId,
        'name': name,
        'description': description,
        'icon': icon,
        'fields': fields.map((f) => f.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  ItemType copyWith({
    String? id,
    String? libraryId,
    String? name,
    String? description,
    String? icon,
    List<FieldDefinition>? fields,
    DateTime? createdAt,
  }) {
    return ItemType(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      fields: fields ?? this.fields,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
