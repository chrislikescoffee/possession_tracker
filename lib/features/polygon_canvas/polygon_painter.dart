import 'package:flutter/material.dart';
import '../../core/utils/geometry.dart';
import '../../models/polygon_region.dart';

class PolygonPainter extends CustomPainter {
  final List<PolygonRegion> regions;
  final String? highlightedRegionId;
  final String? selectedRegionId;
  final List<NormalizedPoint> draftPoints;
  final NormalizedPoint? draftCursorPoint;
  final double pulseAnimationValue; // 0.0 to 1.0 for pulsating locator halo
  final bool isDrawing;
  final int? activeVertexIndex;
  final Set<String> lentItemIds;

  PolygonPainter({
    required this.regions,
    this.highlightedRegionId,
    this.selectedRegionId,
    this.draftPoints = const [],
    this.draftCursorPoint,
    this.pulseAnimationValue = 0.0,
    this.isDrawing = false,
    this.activeVertexIndex,
    this.lentItemIds = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Draw existing regions
    for (final region in regions) {
      if (region.points.length < 3) continue;

      final isHighlighted = region.id == highlightedRegionId;
      final isSelected = region.id == selectedRegionId;
      final isLent = region.targetItemId != null && lentItemIds.contains(region.targetItemId);
      final baseColor = isLent ? const Color(0xFFF59E0B) : Color(region.colorHex);

      final path = Path();
      final offsets = region.points.map((p) => p.toOffset(size)).toList();
      path.moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 1; i < offsets.length; i++) {
        path.lineTo(offsets[i].dx, offsets[i].dy);
      }
      path.close();

      // Pulsing halo for locator highlight
      if (isHighlighted) {
        final haloRadius = 4.0 + (pulseAnimationValue * 12.0);
        final haloOpacity = (1.0 - pulseAnimationValue).clamp(0.1, 0.8);
        final haloPaint = Paint()
          ..color = const Color(0xFFF59E0B).withValues(alpha: haloOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = haloRadius
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, haloPaint);
      }

      // Region Fill
      final fillOpacity = isHighlighted ? 0.45 : (isSelected ? 0.35 : 0.22);
      final fillPaint = Paint()
        ..color = (isHighlighted ? const Color(0xFFF59E0B) : baseColor).withValues(alpha: fillOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Region Stroke
      final strokePaint = Paint()
        ..color = isHighlighted
            ? const Color(0xFFF59E0B)
            : (isSelected ? Colors.white : baseColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 3.5 : (isSelected ? 3.0 : 2.0)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, strokePaint);

      // Vertex Handles (when selected or highlighted)
      if (isSelected || isHighlighted) {
        for (int i = 0; i < offsets.length; i++) {
          final pt = offsets[i];
          final isActiveVertex = isSelected && activeVertexIndex == i;

          final vertexPaint = Paint()
            ..color = isActiveVertex ? const Color(0xFFF59E0B) : Colors.white
            ..style = PaintingStyle.fill;
          final vertexBorder = Paint()
            ..color = isHighlighted
                ? const Color(0xFFF59E0B)
                : (isActiveVertex ? Colors.white : baseColor)
            ..style = PaintingStyle.stroke
            ..strokeWidth = isActiveVertex ? 3.0 : 2.0;

          final radius = isActiveVertex ? 9.0 : (isSelected ? 7.5 : 5.0);
          canvas.drawCircle(pt, radius, vertexPaint);
          canvas.drawCircle(pt, radius, vertexBorder);
        }
      }

      // Draw Region Label Badge at Centroid
      if (region.label.isNotEmpty) {
        final centroid = GeometryUtils.calculateCentroid(offsets);
        _drawLabelBadge(
          canvas,
          centroid,
          region.label,
          isHighlighted ? const Color(0xFFF59E0B) : baseColor,
          isHighlighted,
          isLent: isLent,
        );
      }
    }

    // 2. Draw active drafting polygon
    if (isDrawing && draftPoints.isNotEmpty) {
      final draftOffsets = draftPoints.map((p) => p.toOffset(size)).toList();
      final draftPath = Path()..moveTo(draftOffsets.first.dx, draftOffsets.first.dy);
      for (int i = 1; i < draftOffsets.length; i++) {
        draftPath.lineTo(draftOffsets[i].dx, draftOffsets[i].dy);
      }

      if (draftCursorPoint != null) {
        final cursorOffset = draftCursorPoint!.toOffset(size);
        draftPath.lineTo(cursorOffset.dx, cursorOffset.dy);
      }

      final draftStroke = Paint()
        ..color = const Color(0xFF6366F1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(draftPath, draftStroke);

      // Dotted closing line when >= 3 points placed
      if (draftOffsets.length >= 3) {
        final dottedPaint = Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.85)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        _drawDottedLine(canvas, draftOffsets.last, draftOffsets.first, dottedPaint);
      }

      // Draw draft vertices
      final vertexPaint = Paint()
        ..color = const Color(0xFF6366F1)
        ..style = PaintingStyle.fill;
      final vertexInner = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      for (int i = 0; i < draftOffsets.length; i++) {
        final pt = draftOffsets[i];
        canvas.drawCircle(pt, 6.0, vertexPaint);
        canvas.drawCircle(pt, 3.5, vertexInner);
      }
    }
  }

  void _drawDottedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final distance = (p2 - p1).distance;
    if (distance < 5.0) return;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double currentDist = 0.0;
    final dx = (p2.dx - p1.dx) / distance;
    final dy = (p2.dy - p1.dy) / distance;

    while (currentDist < distance) {
      final start = Offset(p1.dx + dx * currentDist, p1.dy + dy * currentDist);
      final nextDist = (currentDist + dashWidth).clamp(0.0, distance);
      final end = Offset(p1.dx + dx * nextDist, p1.dy + dy * nextDist);
      canvas.drawLine(start, end, paint);
      currentDist += dashWidth + dashSpace;
    }
  }

  void _drawLabelBadge(
    Canvas canvas,
    Offset position,
    String text,
    Color accentColor,
    bool isHighlighted, {
    bool isLent = false,
  }) {
    final effectiveAccent = isLent ? const Color(0xFFF59E0B) : accentColor;
    final displayText = isLent ? '🤝 $text (Lent)' : text;

    final textSpan = TextSpan(
      text: displayText,
      style: TextStyle(
        color: isLent ? const Color(0xFFFDE68A) : Colors.white,
        fontSize: isHighlighted ? 13 : 11,
        fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final paddingH = isHighlighted ? 10.0 : 8.0;
    final paddingV = isHighlighted ? 5.0 : 3.5;
    final badgeRect = Rect.fromCenter(
      center: position,
      width: textPainter.width + (paddingH * 2),
      height: textPainter.height + (paddingV * 2),
    );

    final bgPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = effectiveAccent.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHighlighted ? 2.0 : 1.2;

    final rrect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(8));
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    textPainter.paint(
      canvas,
      Offset(badgeRect.left + paddingH, badgeRect.top + paddingV),
    );
  }

  @override
  bool shouldRepaint(covariant PolygonPainter oldDelegate) {
    return oldDelegate.regions != regions ||
        oldDelegate.highlightedRegionId != highlightedRegionId ||
        oldDelegate.selectedRegionId != selectedRegionId ||
        oldDelegate.draftPoints != draftPoints ||
        oldDelegate.draftCursorPoint != draftCursorPoint ||
        oldDelegate.pulseAnimationValue != pulseAnimationValue ||
        oldDelegate.isDrawing != isDrawing ||
        oldDelegate.activeVertexIndex != activeVertexIndex ||
        oldDelegate.lentItemIds != lentItemIds;
  }
}
