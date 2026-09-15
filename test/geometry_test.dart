import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:possession_tracker/core/utils/geometry.dart';
import 'package:possession_tracker/models/polygon_region.dart';

void main() {
  group('GeometryUtils & Normalization Tests', () {
    test('Ray-casting detects point inside rectangle', () {
      final points = [
        const Offset(10, 10),
        const Offset(100, 10),
        const Offset(100, 100),
        const Offset(10, 100),
      ];

      // Point inside
      expect(GeometryUtils.isPointInPolygon(const Offset(50, 50), points), isTrue);

      // Point outside
      expect(GeometryUtils.isPointInPolygon(const Offset(5, 5), points), isFalse);
      expect(GeometryUtils.isPointInPolygon(const Offset(150, 50), points), isFalse);
    });

    test('NormalizedPoint converts to and from Offset accurately', () {
      const imageSize = Size(1000, 500);
      const norm = NormalizedPoint(x: 0.25, y: 0.50);

      final offset = norm.toOffset(imageSize);
      expect(offset.dx, 250.0);
      expect(offset.dy, 250.0);

      final backToNorm = NormalizedPoint.fromOffset(offset, imageSize);
      expect(backToNorm.x, closeTo(0.25, 0.001));
      expect(backToNorm.y, closeTo(0.50, 0.001));
    });

    test('Calculates polygon centroid accurately', () {
      final points = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 100),
        const Offset(0, 100),
      ];
      final centroid = GeometryUtils.calculateCentroid(points);
      expect(centroid.dx, 50.0);
      expect(centroid.dy, 50.0);
    });

    test('Calculates normalized bounding box correctly', () {
      final points = [
        const NormalizedPoint(x: 0.2, y: 0.3),
        const NormalizedPoint(x: 0.8, y: 0.3),
        const NormalizedPoint(x: 0.7, y: 0.9),
        const NormalizedPoint(x: 0.1, y: 0.8),
      ];
      final bounds = GeometryUtils.calculateBoundingBox(points);
      expect(bounds.left, closeTo(0.1, 0.001));
      expect(bounds.top, closeTo(0.3, 0.001));
      expect(bounds.right, closeTo(0.8, 0.001));
      expect(bounds.bottom, closeTo(0.9, 0.001));
    });

    test('Snaps to nearest vertex within proximity threshold', () {
      final vertices = [
        const NormalizedPoint(x: 0.10, y: 0.10),
        const NormalizedPoint(x: 0.50, y: 0.50),
        const NormalizedPoint(x: 0.90, y: 0.90),
      ];

      // Point very close to (0.50, 0.50) -> should snap
      const closeCandidate = NormalizedPoint(x: 0.51, y: 0.49);
      final snapped = GeometryUtils.snapNormalizedToNearestVertex(
        closeCandidate,
        vertices,
        snapThreshold: 0.035,
      );
      expect(snapped.x, 0.50);
      expect(snapped.y, 0.50);

      // Point far away -> should remain unchanged
      const farCandidate = NormalizedPoint(x: 0.30, y: 0.30);
      final unsnapped = GeometryUtils.snapNormalizedToNearestVertex(
        farCandidate,
        vertices,
        snapThreshold: 0.035,
      );
      expect(unsnapped.x, 0.30);
      expect(unsnapped.y, 0.30);
    });

    test('Snaps line angles to horizontal, vertical, and 45 degree diagonals', () {
      const origin = NormalizedPoint(x: 0.50, y: 0.50);

      // Candidate at ~2 degrees from horizontal (almost horizontal right)
      const nearHorizontal = NormalizedPoint(x: 0.80, y: 0.51);
      final snappedH = GeometryUtils.snapNormalizedAngle(origin, nearHorizontal, toleranceDegrees: 8.0);
      expect(snappedH.y, closeTo(0.50, 0.001)); // Snapped exactly horizontal

      // Candidate at ~88 degrees (almost vertical down)
      const nearVertical = NormalizedPoint(x: 0.51, y: 0.80);
      final snappedV = GeometryUtils.snapNormalizedAngle(origin, nearVertical, toleranceDegrees: 8.0);
      expect(snappedV.x, closeTo(0.50, 0.001)); // Snapped exactly vertical

      // Candidate at ~44 degrees (almost 45 deg diagonal)
      const near45 = NormalizedPoint(x: 0.70, y: 0.69);
      final snapped45 = GeometryUtils.snapNormalizedAngle(origin, near45, toleranceDegrees: 8.0);
      final dx = (snapped45.x - origin.x).abs();
      final dy = (snapped45.y - origin.y).abs();
      expect(dx, closeTo(dy, 0.001)); // Equal dx and dy means 45 degrees
    });

    test('Calculates fit matrix for viewport zooming into bounded sub-area', () {
      const bounds = Rect.fromLTRB(0.2, 0.2, 0.6, 0.6);
      const containerSize = Size(400, 300);

      final matrix = GeometryUtils.calculateFitMatrix(bounds, containerSize);
      expect(matrix.isIdentity(), isFalse);

      // Scale factor should be > 1.0 (zoomed in)
      final scale = matrix.getMaxScaleOnAxis();
      expect(scale, greaterThan(1.0));
    });
  });
}
