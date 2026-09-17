import 'dart:convert';
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

  // Status lifecycle: stored, in_use, lent, lost
  final String status;

  // Barcode / QR Code metadata
  final String? barcode;
  final String? barcodeType;
  final DateTime? barcodeGeneratedAt;
  final DateTime? barcodeLastPrintedAt;
  final bool mustScanIn;
  final List<String> tags;

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
    this.barcode,
    this.barcodeType,
    this.barcodeGeneratedAt,
    this.barcodeLastPrintedAt,
    this.mustScanIn = false,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isStored => status == AppConstants.itemStatusStored;
  bool get isRelocated => status == AppConstants.itemStatusRelocated;
  bool get isLentOut => status == AppConstants.itemStatusLent;
  bool get hasPolygon => polygonPoints.length >= 3;
  bool get hasBarcode => barcode != null && barcode!.trim().isNotEmpty;
  String get effectiveItemTypeName => (itemTypeName != null && itemTypeName!.isNotEmpty)
      ? itemTypeName!
      : 'Generic Item';

  factory Item.fromJson(Map<String, dynamic> json) {
    dynamic rawPoly = json['polygon_coordinates'];
    if (rawPoly is String && rawPoly.isNotEmpty) {
      try {
        rawPoly = jsonDecode(rawPoly);
      } catch (_) {}
    }
    final polyList = <NormalizedPoint>[];
    if (rawPoly is List) {
      for (final p in rawPoly) {
        if (p is Map) {
          try {
            polyList.add(NormalizedPoint.fromJson(Map<String, dynamic>.from(p)));
          } catch (_) {}
        }
      }
    }

    return Item(
      id: json['id'] as String,
      libraryId: json['library_id'] as String,
      storageLocationId: json['storage_location_id'] as String?,
      itemTypeId: json['item_type_id'] as String?,
      itemTypeName: json['item_type_name'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      primaryImageUrl: json['primary_image_url'] as String?,
      polygonPoints: polyList,
      customFields: (json['custom_fields'] as Map<String, dynamic>?) ?? {},
      isTemporarilyRelocated: json['is_temporarily_relocated'] as bool? ?? false,
      temporaryLocationNote: json['temporary_location_note'] as String?,
      temporaryLocationId: json['temporary_location_id'] as String?,
      status: json['status'] as String? ?? AppConstants.itemStatusStored,
      barcode: json['barcode'] as String?,
      barcodeType: json['barcode_type'] as String?,
      barcodeGeneratedAt: json['barcode_generated_at'] != null
          ? DateTime.tryParse(json['barcode_generated_at'] as String)
          : null,
      barcodeLastPrintedAt: json['barcode_last_printed_at'] != null
          ? DateTime.tryParse(json['barcode_last_printed_at'] as String)
          : null,
      mustScanIn: json['must_scan_in'] as bool? ?? false,
      tags: (json['tags'] is List)
          ? (json['tags'] as List).map((e) => e.toString()).toList()
          : const [],
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
        'barcode': barcode,
        'barcode_type': barcodeType,
        'barcode_generated_at': barcodeGeneratedAt?.toIso8601String(),
        'barcode_last_printed_at': barcodeLastPrintedAt?.toIso8601String(),
        'must_scan_in': mustScanIn,
        'tags': tags,
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
    String? barcode,
    String? barcodeType,
    DateTime? barcodeGeneratedAt,
    DateTime? barcodeLastPrintedAt,
    bool? mustScanIn,
    List<String>? tags,
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
      barcode: barcode ?? this.barcode,
      barcodeType: barcodeType ?? this.barcodeType,
      barcodeGeneratedAt: barcodeGeneratedAt ?? this.barcodeGeneratedAt,
      barcodeLastPrintedAt: barcodeLastPrintedAt ?? this.barcodeLastPrintedAt,
      mustScanIn: mustScanIn ?? this.mustScanIn,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
