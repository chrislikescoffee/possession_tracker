import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:possession_tracker/models/item_model.dart';
import 'package:possession_tracker/models/polygon_region.dart';
import 'package:possession_tracker/models/storage_location_model.dart';

void main() {
  group('Polygon Serialization & Sync Compatibility Tests', () {
    test('StorageLocation parses polygon_coordinates from List of Maps (jsonb)', () {
      final json = {
        'id': 'loc-123',
        'library_id': 'lib-1',
        'name': 'Toolbox',
        'polygon_coordinates': [
          {
            'id': 'reg-1',
            'label': 'Screwdrivers',
            'target_item_id': 'item-1',
            'color_hex': 0xFF10B981,
            'points': [
              {'x': 0.1, 'y': 0.2},
              {'x': 0.3, 'y': 0.2},
              {'x': 0.3, 'y': 0.4},
              {'x': 0.1, 'y': 0.4},
            ],
          }
        ],
        'sort_order': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      final loc = StorageLocation.fromJson(json);
      expect(loc.regions.length, 1);
      expect(loc.regions.first.id, 'reg-1');
      expect(loc.regions.first.label, 'Screwdrivers');
      expect(loc.regions.first.points.length, 4);
      expect(loc.regions.first.points[0].x, 0.1);
      expect(loc.regions.first.points[0].y, 0.2);
    });

    test('StorageLocation parses polygon_coordinates from JSON String (text/remote payload)', () {
      final regionsPayload = [
        {
          'id': 'reg-remote-1',
          'label': 'Hammer Slot',
          'target_item_id': 'item-hammer',
          'points': [
            {'x': 0.5, 'y': 0.5},
            {'x': 0.8, 'y': 0.5},
            {'x': 0.8, 'y': 0.9},
          ],
        }
      ];

      final json = {
        'id': 'loc-456',
        'library_id': 'lib-1',
        'name': 'Workshop Wall',
        'polygon_coordinates': jsonEncode(regionsPayload),
        'created_at': DateTime.now().toIso8601String(),
      };

      final loc = StorageLocation.fromJson(json);
      expect(loc.regions.length, 1);
      expect(loc.regions.first.id, 'reg-remote-1');
      expect(loc.regions.first.label, 'Hammer Slot');
      expect(loc.regions.first.points.length, 3);
    });

    test('Item parses polygon_coordinates from List and JSON String', () {
      // 1. List of Maps
      final itemJson1 = {
        'id': 'item-1',
        'library_id': 'lib-1',
        'name': 'Pliers',
        'polygon_coordinates': [
          {'x': 0.2, 'y': 0.2},
          {'x': 0.4, 'y': 0.2},
          {'x': 0.4, 'y': 0.4},
        ],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final item1 = Item.fromJson(itemJson1);
      expect(item1.polygonPoints.length, 3);
      expect(item1.hasPolygon, true);
      expect(item1.polygonPoints[1].x, 0.4);

      // 2. JSON String
      final itemJson2 = {
        'id': 'item-2',
        'library_id': 'lib-1',
        'name': 'Wrench',
        'polygon_coordinates': jsonEncode([
          {'x': 0.6, 'y': 0.6},
          {'x': 0.9, 'y': 0.6},
          {'x': 0.9, 'y': 0.9},
        ]),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final item2 = Item.fromJson(itemJson2);
      expect(item2.polygonPoints.length, 3);
      expect(item2.hasPolygon, true);
    });
  });
}
