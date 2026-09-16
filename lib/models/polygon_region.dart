import 'dart:convert';
import 'dart:ui';

/// Represents a single normalized point (0.0 to 1.0) on an image
class NormalizedPoint {
  final double x;
  final double y;

  const NormalizedPoint({required this.x, required this.y});

  factory NormalizedPoint.fromJson(Map<String, dynamic> json) {
    return NormalizedPoint(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  Offset toOffset(Size imageSize) => Offset(x * imageSize.width, y * imageSize.height);

  static NormalizedPoint fromOffset(Offset offset, Size imageSize) {
    final w = imageSize.width > 0 ? imageSize.width : 1.0;
    final h = imageSize.height > 0 ? imageSize.height : 1.0;
    return NormalizedPoint(
      x: (offset.dx / w).clamp(0.0, 1.0),
      y: (offset.dy / h).clamp(0.0, 1.0),
    );
  }

  @override
  String toString() => 'NormalizedPoint(x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)})';
}

/// A polygon region mapped on a storage image.
/// Can be linked to either a child [StorageLocation] or an [Item].
class PolygonRegion {
  final String id;
  final String label;
  final List<NormalizedPoint> points;
  final String? targetLocationId;
  final String? targetItemId;
  final int colorHex; // Hex color for custom rendering

  const PolygonRegion({
    required this.id,
    required this.label,
    required this.points,
    this.targetLocationId,
    this.targetItemId,
    this.colorHex = 0xFF3B82F6, // Default bright blue
  });

  bool get isLinkedToLocation => targetLocationId != null && targetLocationId!.isNotEmpty;
  bool get isLinkedToItem => targetItemId != null && targetItemId!.isNotEmpty;

  factory PolygonRegion.fromJson(Map<String, dynamic> json) {
    dynamic rawPoints = json['points'];
    if (rawPoints is String && rawPoints.isNotEmpty) {
      try {
        rawPoints = jsonDecode(rawPoints);
      } catch (_) {}
    }
    final pointsList = <NormalizedPoint>[];
    if (rawPoints is List) {
      for (final p in rawPoints) {
        if (p is Map) {
          try {
            pointsList.add(NormalizedPoint.fromJson(Map<String, dynamic>.from(p)));
          } catch (_) {}
        }
      }
    }

    final rawColor = json['color_hex'];
    final parsedColor = rawColor is int
        ? rawColor
        : (rawColor is String
            ? int.tryParse(rawColor) ?? 0xFF3B82F6
            : 0xFF3B82F6);

    return PolygonRegion(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      points: pointsList,
      targetLocationId: json['target_location_id'] as String?,
      targetItemId: json['target_item_id'] as String?,
      colorHex: parsedColor,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'points': points.map((p) => p.toJson()).toList(),
        'target_location_id': targetLocationId,
        'target_item_id': targetItemId,
        'color_hex': colorHex,
      };

  PolygonRegion copyWith({
    String? id,
    String? label,
    List<NormalizedPoint>? points,
    String? targetLocationId,
    String? targetItemId,
    int? colorHex,
  }) {
    return PolygonRegion(
      id: id ?? this.id,
      label: label ?? this.label,
      points: points ?? this.points,
      targetLocationId: targetLocationId ?? this.targetLocationId,
      targetItemId: targetItemId ?? this.targetItemId,
      colorHex: colorHex ?? this.colorHex,
    );
  }
}
