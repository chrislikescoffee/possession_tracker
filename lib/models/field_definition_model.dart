enum ItemFieldType {
  text,
  number,
  dimension,
  weight,
  currency,
  date,
}

extension ItemFieldTypeExtension on ItemFieldType {
  String get displayName {
    switch (this) {
      case ItemFieldType.text:
        return 'Text';
      case ItemFieldType.number:
        return 'Number';
      case ItemFieldType.dimension:
        return 'Dimension (H × W × D)';
      case ItemFieldType.weight:
        return 'Weight';
      case ItemFieldType.currency:
        return 'Currency';
      case ItemFieldType.date:
        return 'Date';
    }
  }

  static ItemFieldType fromString(String? typeStr) {
    if (typeStr == null) return ItemFieldType.text;
    return ItemFieldType.values.firstWhere(
      (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
      orElse: () => ItemFieldType.text,
    );
  }
}

class FieldDefinition {
  final String id;
  final String name;
  final ItemFieldType type;
  final String? unit; // e.g. 'cm', 'mm', 'kg', 'g', 'AUD', 'USD'
  final dynamic defaultValue;
  final bool isRequired;

  const FieldDefinition({
    required this.id,
    required this.name,
    required this.type,
    this.unit,
    this.defaultValue,
    this.isRequired = false,
  });

  factory FieldDefinition.fromJson(Map<String, dynamic> json) {
    return FieldDefinition(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: ItemFieldTypeExtension.fromString(json['type'] as String?),
      unit: json['unit'] as String?,
      defaultValue: json['default_value'] ?? json['defaultValue'],
      isRequired: (json['is_required'] ?? json['isRequired']) as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'unit': unit,
        'default_value': defaultValue,
        'is_required': isRequired,
      };

  FieldDefinition copyWith({
    String? id,
    String? name,
    ItemFieldType? type,
    String? unit,
    dynamic defaultValue,
    bool? isRequired,
  }) {
    return FieldDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      unit: unit ?? this.unit,
      defaultValue: defaultValue ?? this.defaultValue,
      isRequired: isRequired ?? this.isRequired,
    );
  }
}
