import '../core/constants/app_constants.dart';
import 'polygon_region.dart';

/// Represents an item in the possession tracker.
/// Supports flexible dynamic custom attributes, canonical storage hierarchy placement,
/// dual-state relocation (permanent vs temporary with descriptive notes), and lending custody status.
class Item {
  final String id;
  final String libraryId;
  final String? storageLocationId;
  final String? itemTypeId;
  final String? itemTypeName;
  final String name;
  final String? description;
  final String? primaryImageUrl;
  final List<NormalizedPoint> polygonPoints;
  final Map<String, dynamic> customFields;

  // Dual-state relocation tracking
  final bool isTemporarilyRelocated;
  final String? temporaryLocationNote;
  final String? temporaryLocationId;

  // Status: 'stored', 'relocated', 'lent'
  final String status;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Item({
    required this.id,
    required this.libraryId,
    this.storageLocationId,
    this.itemTypeId,
    this.itemTypeName,
    required this.name,
    this.description,
    this.primaryImageUrl,
    this.polygonPoints = const [],
    this.customFields = const {},
    this.isTemporarilyRelocated = false,
    this.temporaryLocationNote,
    this.temporaryLocationId,
    this.status = AppConstants.itemStatusStored,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLentOut => status == AppConstants.itemStatusLent;
  bool get hasPolygon => polygonPoints.length >= 3;
  String get effectiveItemTypeName => (itemTypeName != null && itemTypeName!.isNotEmpty)
      ? itemTypeName!
      : 'Generic Item';

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String,
      libraryId: json['library_id'] as String,
      storageLocationId: json['storage_location_id'] as String?,
      itemTypeId: json['item_type_id'] as String?,
      itemTypeName: json['item_type_name'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      primaryImageUrl: json['primary_image_url'] as String?,
      polygonPoints: (json['polygon_coordinates'] as List<dynamic>? ?? [])
          .map((p) => NormalizedPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      customFields: (json['custom_fields'] as Map<String, dynamic>?) ?? {},
      isTemporarilyRelocated: json['is_temporarily_relocated'] as bool? ?? false,
      temporaryLocationNote: json['temporary_location_note'] as String?,
      temporaryLocationId: json['temporary_location_id'] as String?,
      status: json['status'] as String? ?? AppConstants.itemStatusStored,
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
        'storage_location_id': storageLocationId,
        'item_type_id': itemTypeId,
        'item_type_name': itemTypeName,
        'name': name,
        'description': description,
        'primary_image_url': primaryImageUrl,
        'polygon_coordinates': polygonPoints.map((p) => p.toJson()).toList(),
        'custom_fields': customFields,
        'is_temporarily_relocated': isTemporarilyRelocated,
        'temporary_location_note': temporaryLocationNote,
        'temporary_location_id': temporaryLocationId,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Item copyWith({
    String? id,
    String? libraryId,
    String? storageLocationId,
    String? itemTypeId,
    String? itemTypeName,
    String? name,
    String? description,
    String? primaryImageUrl,
    List<NormalizedPoint>? polygonPoints,
    Map<String, dynamic>? customFields,
    bool? isTemporarilyRelocated,
    String? temporaryLocationNote,
    String? temporaryLocationId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      storageLocationId: storageLocationId ?? this.storageLocationId,
      itemTypeId: itemTypeId ?? this.itemTypeId,
      itemTypeName: itemTypeName ?? this.itemTypeName,
      name: name ?? this.name,
      description: description ?? this.description,
      primaryImageUrl: primaryImageUrl ?? this.primaryImageUrl,
      polygonPoints: polygonPoints ?? this.polygonPoints,
      customFields: customFields ?? this.customFields,
      isTemporarilyRelocated: isTemporarilyRelocated ?? this.isTemporarilyRelocated,
      temporaryLocationNote: temporaryLocationNote ?? this.temporaryLocationNote,
      temporaryLocationId: temporaryLocationId ?? this.temporaryLocationId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
