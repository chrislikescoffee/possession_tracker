import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/polygon_region.dart';

class GeometryUtils {
  /// Ray-casting algorithm to test if an [Offset] point is inside a polygon defined by [points]
  static bool isPointInPolygon(Offset point, List<Offset> points) {
    if (points.length < 3) return false;

    bool isInside = false;
    int j = points.length - 1;

    for (int i = 0; i < points.length; i++) {
      final xi = points[i].dx;
      final yi = points[i].dy;
      final xj = points[j].dx;
      final yj = points[j].dy;
      final dyDiff = yj - yi;

      final intersect = ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx < (xj - xi) * (point.dy - yi) / (dyDiff == 0 ? 1e-12 : dyDiff) + xi);

      if (intersect) {
        isInside = !isInside;
      }
      j = i;
    }

    return isInside;
  }

  /// Calculates the geometric centroid of a list of offsets
  static Offset calculateCentroid(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    if (points.length == 1) return points.first;

    double totalX = 0;
    double totalY = 0;
    for (final pt in points) {
      totalX += pt.dx;
      totalY += pt.dy;
    }
    return Offset(totalX / points.length, totalY / points.length);
  }

  /// Calculates the bounding box of a list of normalized points
  static Rect calculateNormalizedBounds(List<NormalizedPoint> points) {
    if (points.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final pt in points) {
      minX = math.min(minX, pt.x);
      maxX = math.max(maxX, pt.x);
      minY = math.min(minY, pt.y);
      maxY = math.max(maxY, pt.y);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Alias for calculateNormalizedBounds
  static Rect calculateBoundingBox(List<NormalizedPoint> points) =>
      calculateNormalizedBounds(points);

  /// Snaps a candidate offset to nearest existing vertex within [maxDistance] pixels
  static Offset? snapToNearestVertex(
    Offset candidate,
    List<Offset> existingVertices, {
    double maxDistance = 18.0,
  }) {
    Offset? nearest;
    double minDistance = maxDistance;

    for (final vertex in existingVertices) {
      final dist = (vertex - candidate).distance;
      if (dist < minDistance) {
        minDistance = dist;
        nearest = vertex;
      }
    }
    return nearest;
  }

  /// Snaps a normalized candidate point to nearest existing vertex within [snapThreshold]
  static NormalizedPoint snapNormalizedToNearestVertex(
    NormalizedPoint candidate,
    List<NormalizedPoint> existingVertices, {
    double snapThreshold = 0.035,
  }) {
    NormalizedPoint nearest = candidate;
    double minDistance = snapThreshold;

    for (final vertex in existingVertices) {
      final dx = vertex.x - candidate.x;
      final dy = vertex.y - candidate.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < minDistance) {
        minDistance = dist;
        nearest = vertex;
      }
    }
    return nearest;
  }

  /// Snaps candidate line from [origin] to standard angles:
  /// Horizontal (0°, 180°), Vertical (90°, 270°/-90°), and 45° diagonals (±45°, ±135°)
  /// within [toleranceDegrees] (default 6°).
  static Offset snapAngleToStandardAngles(
    Offset origin,
    Offset candidate, {
    double toleranceDegrees = 6.0,
  }) {
    final dx = candidate.dx - origin.dx;
    final dy = candidate.dy - origin.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance < 5.0) return candidate;

    final angleDeg = math.atan2(dy, dx) * 180.0 / math.pi;
    const standardAngles = [0.0, 45.0, 90.0, 135.0, 180.0, -180.0, -135.0, -90.0, -45.0];

    for (final target in standardAngles) {
      final diff = (angleDeg - target).abs();
      if (diff <= toleranceDegrees || (360.0 - diff) <= toleranceDegrees) {
        final rad = target * math.pi / 180.0;
        return Offset(
          origin.dx + distance * math.cos(rad),
          origin.dy + distance * math.sin(rad),
        );
      }
    }

    return candidate;
  }

  /// Snaps candidate normalized line from [origin] to standard angles (0, 45, 90, etc.)
  static NormalizedPoint snapNormalizedAngle(
    NormalizedPoint origin,
    NormalizedPoint candidate, {
    double toleranceDegrees = 8.0,
  }) {
    final dx = candidate.x - origin.x;
    final dy = candidate.y - origin.y;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance < 0.01) return candidate;

    final angleDeg = math.atan2(dy, dx) * 180.0 / math.pi;
    const standardAngles = [0.0, 45.0, 90.0, 135.0, 180.0, -180.0, -135.0, -90.0, -45.0];

    for (final target in standardAngles) {
      final diff = (angleDeg - target).abs();
      if (diff <= toleranceDegrees || (360.0 - diff) <= toleranceDegrees) {
        final rad = target * math.pi / 180.0;
        return NormalizedPoint(
          x: (origin.x + distance * math.cos(rad)).clamp(0.0, 1.0),
          y: (origin.y + distance * math.sin(rad)).clamp(0.0, 1.0),
        );
      }
    }

    return candidate;
  }

  /// Computes a [Matrix4] to center and fit a normalized bounding box into [containerSize]
  /// with safety margin [paddingPercent].
  static Matrix4 calculateFitMatrix(
    Rect normalizedBounds,
    Size containerSize, {
    double paddingPercent = 0.12,
  }) {
    if (normalizedBounds.isEmpty || containerSize.width <= 0 || containerSize.height <= 0) {
      return Matrix4.identity();
    }

    // Convert normalized bounds to pixel bounds
    final pixelLeft = normalizedBounds.left * containerSize.width;
    final pixelTop = normalizedBounds.top * containerSize.height;
    final pixelWidth = normalizedBounds.width * containerSize.width;
    final pixelHeight = normalizedBounds.height * containerSize.height;

    // Calculate scale factor required to fit bounded region
    final scaleX = containerSize.width / (pixelWidth * (1.0 + paddingPercent * 2));
    final scaleY = containerSize.height / (pixelHeight * (1.0 + paddingPercent * 2));
    final scale = math.min(scaleX, scaleY).clamp(1.0, 5.0);

    // Centroid of target region
    final centerX = pixelLeft + (pixelWidth / 2);
    final centerY = pixelTop + (pixelHeight / 2);

    // Compute translation to place centroid at the center of containerSize
    final translateX = (containerSize.width / 2) - (centerX * scale);
    final translateY = (containerSize.height / 2) - (centerY * scale);

    return Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0.0, 1.0)
      ..scaleByDouble(scale, scale, 1.0, 1.0);
  }
}
