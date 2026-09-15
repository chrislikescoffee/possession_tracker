import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:possession_tracker/core/services/local_database_service.dart';
import 'package:possession_tracker/core/utils/field_query_utils.dart';
import 'package:possession_tracker/models/field_definition_model.dart';
import 'package:possession_tracker/models/item_model.dart';
import 'package:possession_tracker/models/item_type_model.dart';
import 'package:possession_tracker/models/storage_location_model.dart';
import 'package:possession_tracker/repositories/local_inventory_repository.dart';

void main() {
  group('ItemType & FieldDefinition Tests', () {
    test('FieldDefinition JSON serialization & deserialization', () {
      final field = FieldDefinition(
        id: 'field_voltage',
        name: 'Voltage',
        type: ItemFieldType.number,
        defaultValue: '18V',
        unit: 'V',
        isRequired: true,
      );

      final json = field.toJson();
      expect(json['id'], 'field_voltage');
      expect(json['name'], 'Voltage');
      expect(json['type'], 'number');
      expect(json['default_value'], '18V');
      expect(json['unit'], 'V');
      expect(json['is_required'], true);

      final revived = FieldDefinition.fromJson(json);
      expect(revived.id, field.id);
      expect(revived.name, field.name);
      expect(revived.type, ItemFieldType.number);
      expect(revived.defaultValue, '18V');
      expect(revived.unit, 'V');
      expect(revived.isRequired, true);
    });

    test('ItemType JSON serialization with fields', () {
      final itemType = ItemType(
        id: 'type_tool',
        libraryId: 'lib1',
        name: 'Power Tool',
        description: 'Battery & corded power tools',
        icon: 'build',
        createdAt: DateTime.now(),
        fields: [
          FieldDefinition(
            id: 'f1',
            name: 'Battery System',
            type: ItemFieldType.text,
            defaultValue: '18V XR',
          ),
          FieldDefinition(
            id: 'f2',
            name: 'Dimensions',
            type: ItemFieldType.dimension,
            unit: 'mm',
          ),
        ],
      );

      final json = itemType.toJson();
      expect(json['name'], 'Power Tool');
      expect((json['fields'] as List).length, 2);

      final revived = ItemType.fromJson(json);
      expect(revived.name, 'Power Tool');
      expect(revived.fields.length, 2);
      expect(revived.fields[1].type, ItemFieldType.dimension);
    });
  });

  group('FieldQueryUtils Tests', () {
    final item1 = Item(
      id: 'i1',
      libraryId: 'lib1',
      storageLocationId: 'loc1',
      name: 'Dewalt DCD796 Hammer Drill',
      description: 'Brushless compact hammer drill driver',
      itemTypeId: 'type_tool',
      itemTypeName: 'Power Tool',
      customFields: {
        'Battery System': '18V XR',
        'Voltage': 18,
        'Dimensions': {
          'height': '200',
          'width': '75',
          'depth': '190',
          'unit': 'mm'
        },
        'Weight': {'weight': '1.6', 'unit': 'kg'},
        'Purchase Price': {'amount': '199.00', 'currency': 'AUD'},
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final item2 = Item(
      id: 'i2',
      libraryId: 'lib1',
      storageLocationId: 'loc1',
      name: 'Stoneware Mug',
      description: 'Handmade ceramic mug with blue glaze',
      itemTypeId: 'type_pottery',
      itemTypeName: 'Pottery Item',
      customFields: {
        'Clay Body': 'Speckled Buff',
        'Glaze Technique': 'Cobalt Dip',
        'Capacity': '350ml',
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final item3 = Item(
      id: 'i3',
      libraryId: 'lib1',
      storageLocationId: 'loc1',
      name: 'Makita Jigsaw',
      description: 'Variable speed cordless jigsaw',
      itemTypeId: 'type_tool',
      itemTypeName: 'Power Tool',
      customFields: {
        'Battery System': '18V LXT',
        'Voltage': 18,
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('formatFieldValue formats dimension, weight, and currency correctly', () {
      final dimFormatted = FieldQueryUtils.formatFieldValue(item1.customFields['Dimensions']);
      expect(dimFormatted, '200 × 75 × 190 mm');

      final weightFormatted = FieldQueryUtils.formatFieldValue(item1.customFields['Weight']);
      expect(weightFormatted, '1.6 kg');

      final priceFormatted = FieldQueryUtils.formatFieldValue(item1.customFields['Purchase Price']);
      expect(priceFormatted, '\$199');

      // Additional clean formatting tests
      expect(FieldQueryUtils.formatFieldValue({'amount': 45, 'currency': 'AUD'}), '\$45');
      expect(FieldQueryUtils.formatFieldValue({'amount': 45.50, 'currency': 'USD'}), '\$45.50');
      expect(FieldQueryUtils.formatFieldValue({'amount': 120, 'currency': 'EUR'}), '€120');
      expect(FieldQueryUtils.formatFieldValue({'amount': 80, 'currency': 'GBP'}), '£80');
      expect(FieldQueryUtils.formatFieldValue({'length': 10, 'width': 20, 'height': 30, 'unit': 'cm'}), '10 × 20 × 30 cm');
      expect(FieldQueryUtils.formatFieldValue({'value': 2.5, 'unit': 'kg'}), '2.5 kg');
    });

    test('Case-insensitive search matches standard and custom fields', () {
      // Standard name match (case-insensitive)
      expect(FieldQueryUtils.itemMatchesSearch(item1, 'dewalt'), true);
      expect(FieldQueryUtils.itemMatchesSearch(item1, 'DCD796'), true);

      // Custom field value match (case-insensitive)
      expect(FieldQueryUtils.itemMatchesSearch(item1, '18v xr'), true);
      expect(FieldQueryUtils.itemMatchesSearch(item2, 'cobalt dip'), true);
      expect(FieldQueryUtils.itemMatchesSearch(item2, 'COBALT'), true);

      // Non-match
      expect(FieldQueryUtils.itemMatchesSearch(item2, 'dewalt'), false);
    });

    test('discoverFields detects unique canonical fields across items', () {
      final discovered = FieldQueryUtils.discoverFields([item1, item2, item3]);
      final fieldNames = discovered.map((d) => d.canonicalName).toList();

      expect(fieldNames.contains('Battery System'), true);
      expect(fieldNames.contains('Voltage'), true);
      expect(fieldNames.contains('Glaze Technique'), true);

      // Voltage appears in 2 items
      final voltageField = discovered.firstWhere((d) => d.canonicalName == 'Voltage');
      expect(voltageField.count, 2);
    });

    test('groupByItemType groups items accurately', () {
      final grouped = FieldQueryUtils.groupByItemType([item1, item2, item3]);
      expect(grouped.keys.length, 2);
      expect(grouped['Power Tool']?.length, 2);
      expect(grouped['Pottery Item']?.length, 1);
    });

    test('groupByField groups items by custom field values', () {
      final grouped = FieldQueryUtils.groupByField([item1, item2, item3], 'Battery System');
      expect(grouped['18V XR']?.length, 1);
      expect(grouped['18V LXT']?.length, 1);
      expect(grouped['Unspecified']?.length, 1);
    });

    test('buildLocationBreadcrumb constructs recursive hierarchical paths', () {
      final loc1 = StorageLocation(id: 'root', libraryId: 'lib1', name: 'Main Shed', createdAt: DateTime.now());
      final loc2 = StorageLocation(id: 'bench', libraryId: 'lib1', parentId: 'root', name: 'Bench 1', createdAt: DateTime.now());
      final loc3 = StorageLocation(id: 'drawer', libraryId: 'lib1', parentId: 'bench', name: 'Drawer A', createdAt: DateTime.now());
      final locMap = {'root': loc1, 'bench': loc2, 'drawer': loc3};

      expect(FieldQueryUtils.buildLocationBreadcrumb('root', locMap), 'Main Shed');
      expect(FieldQueryUtils.buildLocationBreadcrumb('bench', locMap), 'Main Shed > Bench 1');
      expect(FieldQueryUtils.buildLocationBreadcrumb('drawer', locMap), 'Main Shed > Bench 1 > Drawer A');
      expect(FieldQueryUtils.buildLocationBreadcrumb('non_existent', locMap), 'Unknown Location');
    });

    test('groupByLocation groups items by hierarchical breadcrumb paths', () {
      final loc1 = StorageLocation(id: 'root', libraryId: 'lib1', name: 'Main Shed', createdAt: DateTime.now());
      final loc2 = StorageLocation(id: 'bench', libraryId: 'lib1', parentId: 'root', name: 'Bench 1', createdAt: DateTime.now());
      final locMap = {'root': loc1, 'bench': loc2};

      final i1 = item1.copyWith(storageLocationId: 'bench');
      final i2 = item2.copyWith(storageLocationId: 'root');
      final i3 = Item(
        id: 'i3_unassigned',
        libraryId: 'lib1',
        storageLocationId: null,
        name: 'Makita Jigsaw',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final grouped = FieldQueryUtils.groupByLocation([i1, i2, i3], locMap);
      expect(grouped.containsKey('Main Shed > Bench 1'), true);
      expect(grouped['Main Shed > Bench 1']?.length, 1);
      expect(grouped.containsKey('Main Shed'), true);
      expect(grouped['Main Shed']?.length, 1);
      expect(grouped.containsKey('Unassigned / No Location'), true);
      expect(grouped['Unassigned / No Location']?.length, 1);
    });

    test('sortItems sorts by name, date, location, and custom attributes', () {
      final loc1 = StorageLocation(id: 'loc_a', libraryId: 'lib1', name: 'Alpha Shed', createdAt: DateTime.now());
      final loc2 = StorageLocation(id: 'loc_z', libraryId: 'lib1', name: 'Zulu Shed', createdAt: DateTime.now());
      final locMap = {'loc_a': loc1, 'loc_z': loc2};

      final cheapItem = item1.copyWith(name: 'Apple Drill', storageLocationId: 'loc_z', customFields: {'Price': {'amount': 15, 'currency': 'AUD'}});
      final midItem = item2.copyWith(name: 'Banana Saw', storageLocationId: 'loc_a', customFields: {'Price': {'amount': 45, 'currency': 'AUD'}});
      final expensiveItem = Item(
        id: 'i_exp',
        libraryId: 'lib1',
        storageLocationId: null,
        name: 'Carrot Sander',
        customFields: {'Price': {'amount': 150, 'currency': 'AUD'}},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final list = [expensiveItem, cheapItem, midItem];

      // Sort by name ascending
      final byNameAsc = FieldQueryUtils.sortItems(list, sortBy: 'name', ascending: true);
      expect(byNameAsc.map((i) => i.name).toList(), ['Apple Drill', 'Banana Saw', 'Carrot Sander']);

      // Sort by name descending
      final byNameDesc = FieldQueryUtils.sortItems(list, sortBy: 'name', ascending: false);
      expect(byNameDesc.map((i) => i.name).toList(), ['Carrot Sander', 'Banana Saw', 'Apple Drill']);

      // Sort by Price attribute ascending (numeric comparison: 15 < 45 < 150)
      final byPriceAsc = FieldQueryUtils.sortItems(list, sortBy: 'field:Price', ascending: true);
      expect(byPriceAsc.map((i) => i.name).toList(), ['Apple Drill', 'Banana Saw', 'Carrot Sander']);

      // Sort by Price attribute descending (150 > 45 > 15)
      final byPriceDesc = FieldQueryUtils.sortItems(list, sortBy: 'field:Price', ascending: false);
      expect(byPriceDesc.map((i) => i.name).toList(), ['Carrot Sander', 'Banana Saw', 'Apple Drill']);

      // Sort by location ascending
      final byLocAsc = FieldQueryUtils.sortItems(list, sortBy: 'location', ascending: true, locationMap: locMap);
      expect(byLocAsc.first.storageLocationId, 'loc_a');
    });

    test('LocalInventoryRepository creates and deletes ItemType', () async {
      final tempDir = await Directory.systemTemp.createTemp('pt_item_type_test_');
      final dbPath = '${tempDir.path}/test_db.json';
      final db = LocalDatabaseService();
      await db.init(customPath: dbPath);
      final repo = LocalInventoryRepository(databaseService: db);

      final customType = ItemType(
        id: 'test_custom_type',
        libraryId: 'lib_default',
        name: 'Camping Equipment',
        fields: [
          FieldDefinition(
            id: 'weight_field',
            name: 'Pack Weight',
            type: ItemFieldType.weight,
            unit: 'kg',
          ),
        ],
        createdAt: DateTime.now(),
      );

      await repo.saveItemType(customType);
      var allTypes = await repo.getItemTypes('lib_default');
      expect(allTypes.any((t) => t.id == 'test_custom_type'), true);

      await repo.deleteItemType('test_custom_type');
      allTypes = await repo.getItemTypes('lib_default');
      expect(allTypes.any((t) => t.id == 'test_custom_type'), false);

      await tempDir.delete(recursive: true);
    });
  });
}
