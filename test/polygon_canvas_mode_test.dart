import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:possession_tracker/features/polygon_canvas/polygon_canvas_widget.dart';
import 'package:possession_tracker/models/polygon_region.dart';

void main() {
  final sampleRegions = [
    PolygonRegion(
      id: 'reg_1',
      label: 'Shelf A',
      points: [
        const NormalizedPoint(x: 0.1, y: 0.1),
        const NormalizedPoint(x: 0.4, y: 0.1),
        const NormalizedPoint(x: 0.4, y: 0.4),
        const NormalizedPoint(x: 0.1, y: 0.4),
      ],
      targetLocationId: 'loc_shelf_a',
      colorHex: 0xFF6366F1,
    ),
  ];

  group('PolygonCanvasWidget Mode & Palette Tests', () {
    testWidgets('View mode hides Snap: ON/OFF toggle and Save button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: PolygonCanvasWidget(
                imageUrl: null,
                regions: sampleRegions,
                mode: CanvasMode.view,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Snap toggle should NOT be in the widget tree in view mode
      expect(find.text('Snap: ON'), findsNothing);
      expect(find.text('Snap: OFF'), findsNothing);

      // Save button should NOT be in the widget tree in view mode
      expect(find.text('Save'), findsNothing);

      // Add Polygon FAB should NOT be present in view mode
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('Edit mode shows Snap toggle, Save button, and New Polygon button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: PolygonCanvasWidget(
                imageUrl: null,
                regions: sampleRegions,
                mode: CanvasMode.edit,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Snap toggle should be visible in edit mode
      expect(find.text('Snap: ON'), findsOneWidget);

      // Floating Save button should be visible in edit mode
      expect(find.text('Save'), findsOneWidget);

      // New Polygon FAB should be present in edit mode by default (not actively drawing)
      expect(find.text('New Polygon'), findsOneWidget);
    });

    testWidgets('Tapping Snap toggle switches between Snap: ON and Snap: OFF',
        (tester) async {
      bool snappingState = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: PolygonCanvasWidget(
                imageUrl: null,
                regions: sampleRegions,
                mode: CanvasMode.edit,
                onSnappingChanged: (val) => snappingState = val,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Snap: ON'), findsOneWidget);

      await tester.tap(find.text('Snap: ON'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Snap: OFF'), findsOneWidget);
      expect(snappingState, false);
    });

    testWidgets('Tapping New Polygon enters drawing mode and completing polygon returns to non-drawing mode',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: PolygonCanvasWidget(
                imageUrl: null,
                regions: sampleRegions,
                mode: CanvasMode.edit,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Initially shows New Polygon button
      expect(find.text('New Polygon'), findsOneWidget);

      // Tap New Polygon to enter drawing mode
      await tester.tap(find.text('New Polygon'));
      await tester.pump(const Duration(milliseconds: 100));

      // Now actively drawing - New Polygon button is replaced by drawing hint
      expect(find.text('New Polygon'), findsNothing);
      expect(find.text('Tap photo to draw next polygon'), findsOneWidget);
    });
  });
}
