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
    required this.createdAt,
  });

  bool get isRoot => parentId == null || parentId!.isEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
