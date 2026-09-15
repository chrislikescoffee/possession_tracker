import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:possession_tracker/features/polygon_canvas/polygon_editor_sheet.dart';
import 'package:possession_tracker/models/item_model.dart';
import 'package:possession_tracker/models/polygon_region.dart';
import 'package:possession_tracker/models/storage_location_model.dart';

void main() {
  group('Polygon Editor & Entity Linking Tests', () {
    testWidgets('Defaults to linking existing unlinked location when available',
        (WidgetTester tester) async {
      final unlinkedLoc = StorageLocation(
        id: 'loc-unlinked-1',
        libraryId: 'lib-1',
        name: 'Top Drawer',
        parentId: 'loc-parent-1',
        createdAt: DateTime.now(),
      );

      const points = [
        NormalizedPoint(x: 0.1, y: 0.1),
        NormalizedPoint(x: 0.5, y: 0.1),
        NormalizedPoint(x: 0.5, y: 0.5),
        NormalizedPoint(x: 0.1, y: 0.5),
      ];

      Map<String, dynamic>? sheetResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  sheetResult = await showModalBottomSheet<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => PolygonEditorSheet(
                      points: points,
                      unlinkedLocations: [unlinkedLoc],
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify the dropdown / segment indicates linking to Top Drawer
      expect(find.text('Assign to Unlinked Area (1)'), findsOneWidget);
      expect(find.text('Top Drawer'), findsWidgets);

      // Scroll and tap "Link to Area"
      await tester.ensureVisible(find.text('Link to Area'));
      await tester.tap(find.text('Link to Area'));
      await tester.pumpAndSettle();

      // Assert sheet result
      expect(sheetResult, isNotNull);
      expect(sheetResult!['isAssigningExisting'], isTrue);
      expect(sheetResult!['selectedExistingLocationId'], equals('loc-unlinked-1'));

      final PolygonRegion region = sheetResult!['region'] as PolygonRegion;
      expect(region.targetLocationId, equals('loc-unlinked-1'));
      expect(region.label, equals('Top Drawer'));
    });

    testWidgets('Displays in-area unlinked items and unallocated items with badges in PolygonEditorSheet',
        (WidgetTester tester) async {
      final inAreaItem = Item(
        id: 'it-in-area',
        libraryId: 'lib-1',
        storageLocationId: 'loc-drawer-1',
        name: 'Screwdriver Set',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final unallocatedItem = Item(
        id: 'it-unallocated',
        libraryId: 'lib-1',
        storageLocationId: null,
        name: 'Flashlight',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const points = [
        NormalizedPoint(x: 0.1, y: 0.1),
        NormalizedPoint(x: 0.5, y: 0.1),
        NormalizedPoint(x: 0.5, y: 0.5),
        NormalizedPoint(x: 0.1, y: 0.5),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showModalBottomSheet<Map<String, dynamic>>(
                    context: context,
                    builder: (_) => PolygonEditorSheet(
                      points: points,
                      unlinkedItems: [inAreaItem, unallocatedItem],
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Switch to Specific Item
      await tester.tap(find.text('Specific Item'));
      await tester.pumpAndSettle();

      // Should show Assign to Unlinked Item (2)
      expect(find.text('Assign to Unlinked Item (2)'), findsOneWidget);

      // Select Assign to Unlinked Item segment
      await tester.tap(find.text('Assign to Unlinked Item (2)'));
      await tester.pumpAndSettle();

      // Verify badges exist in tree
      expect(find.text('In this area'), findsOneWidget);
    });
  });
}
