import 'dart:convert';
import 'polygon_region.dart';

/// Represents a physical or conceptual storage node in an arbitrary-depth hierarchy
/// (e.g., House -> Room -> Cabinet -> Shelf -> Box)
class StorageLocation {
  final String id;
  final String libraryId;
  final String? parentId;
  final String name;
  final String? description;
  final String? imageUrl;
  final List<PolygonRegion> regions;
  final int sortOrder;
  final String? barcode;
  final String? barcodeType;
  final DateTime? barcodeGeneratedAt;
  final DateTime? barcodeLastPrintedAt;
  final DateTime createdAt;

  const StorageLocation({
    required this.id,
    required this.libraryId,
    this.parentId,
    required this.name,
    this.description,
    this.imageUrl,
    this.regions = const [],
    this.sortOrder = 0,
    this.barcode,
    this.barcodeType,
    this.barcodeGeneratedAt,
    this.barcodeLastPrintedAt,
    required this.createdAt,
  });

  bool get isRoot => parentId == null || parentId!.isEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasBarcode => barcode != null && barcode!.trim().isNotEmpty;

  factory StorageLocation.fromJson(Map<String, dynamic> json) {
    dynamic rawCoords = json['polygon_coordinates'];
    if (rawCoords is String && rawCoords.isNotEmpty) {
      try {
        rawCoords = jsonDecode(rawCoords);
      } catch (_) {}
    }
    final regionsList = <PolygonRegion>[];
    if (rawCoords is List) {
      for (final r in rawCoords) {
        if (r is Map) {
          try {
            regionsList.add(PolygonRegion.fromJson(Map<String, dynamic>.from(r)));
          } catch (_) {}
        }
      }
    }

    return StorageLocation(
      id: json['id'] as String,
      libraryId: json['library_id'] as String,
      parentId: json['parent_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      regions: regionsList,
      sortOrder: json['sort_order'] as int? ?? 0,
      barcode: json['barcode'] as String?,
      barcodeType: json['barcode_type'] as String?,
      barcodeGeneratedAt: json['barcode_generated_at'] != null
          ? DateTime.tryParse(json['barcode_generated_at'] as String)
          : null,
      barcodeLastPrintedAt: json['barcode_last_printed_at'] != null
          ? DateTime.tryParse(json['barcode_last_printed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'library_id': libraryId,
        'parent_id': parentId,
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'polygon_coordinates': regions.map((r) => r.toJson()).toList(),
        'sort_order': sortOrder,
        'barcode': barcode,
        'barcode_type': barcodeType,
        'barcode_generated_at': barcodeGeneratedAt?.toIso8601String(),
        'barcode_last_printed_at': barcodeLastPrintedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  StorageLocation copyWith({
    String? id,
    String? libraryId,
    String? parentId,
    String? name,
    String? description,
    String? imageUrl,
    List<PolygonRegion>? regions,
    int? sortOrder,
    String? barcode,
    String? barcodeType,
    DateTime? barcodeGeneratedAt,
    DateTime? barcodeLastPrintedAt,
    DateTime? createdAt,
  }) {
    return StorageLocation(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      regions: regions ?? this.regions,
      sortOrder: sortOrder ?? this.sortOrder,
      barcode: barcode ?? this.barcode,
      barcodeType: barcodeType ?? this.barcodeType,
      barcodeGeneratedAt: barcodeGeneratedAt ?? this.barcodeGeneratedAt,
      barcodeLastPrintedAt: barcodeLastPrintedAt ?? this.barcodeLastPrintedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
