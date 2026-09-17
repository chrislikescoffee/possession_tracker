import 'package:flutter_test/flutter_test.dart';
import 'package:possession_tracker/models/item_list_model.dart';
import 'package:possession_tracker/models/item_model.dart';
import 'package:possession_tracker/repositories/inventory_repository.dart';
import 'package:possession_tracker/repositories/mock_inventory_repository.dart';

void main() {
  group('Item mustScanIn property and serialization', () {
    test('Item default mustScanIn is false', () {
      final item = Item(
        id: 'test-1',
        libraryId: 'lib-1',
        name: 'Hammer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(item.mustScanIn, isFalse);
    });

    test('Item with mustScanIn serializes and deserializes correctly', () {
      final now = DateTime.now();
      final item = Item(
        id: 'test-item-barcode',
        libraryId: 'lib-1',
        name: 'Barcode Scanner Tool',
        barcode: 'PT-123456',
        barcodeType: 'qr',
        mustScanIn: true,
        createdAt: now,
        updatedAt: now,
      );

      final json = item.toJson();
      expect(json['must_scan_in'], isTrue);
      expect(json['barcode'], equals('PT-123456'));

      final fromJson = Item.fromJson(json);
      expect(fromJson.mustScanIn, isTrue);
      expect(fromJson.barcode, equals('PT-123456'));
      expect(fromJson.name, equals('Barcode Scanner Tool'));
    });

    test('Item copyWith toggles mustScanIn', () {
      final item = Item(
        id: 'test-copy',
        libraryId: 'lib-1',
        name: 'Wrench',
        mustScanIn: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = item.copyWith(mustScanIn: true);
      expect(updated.mustScanIn, isTrue);

      final reverted = updated.copyWith(mustScanIn: false);
      expect(reverted.mustScanIn, isFalse);
    });
  });

  group('ItemList model tests', () {
    test('ItemList serialization roundtrip', () {
      final now = DateTime.now();
      final list = ItemList(
        id: 'list-1',
        libraryId: 'lib-1',
        name: 'Camping List',
        description: 'Gear for mountain trip',
        destinationType: ListDestinationType.storageLocation,
        targetLocationId: 'loc-van',
        items: [
          ItemListItemEntry(
            itemId: 'item-tent',
            isCollected: true,
            collectedAt: now,
          ),
          const ItemListItemEntry(
            itemId: 'item-stove',
            isCollected: false,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final json = list.toJson();
      expect(json['name'], equals('Camping List'));
      expect(json['destination_type'], equals('storageLocation'));
      expect(json['target_location_id'], equals('loc-van'));
      expect((json['items'] as List).length, equals(2));

      final parsed = ItemList.fromJson(json);
      expect(parsed.id, equals('list-1'));
      expect(parsed.name, equals('Camping List'));
      expect(parsed.destinationType, equals(ListDestinationType.storageLocation));
      expect(parsed.totalCount, equals(2));
      expect(parsed.collectedCount, equals(1));
      expect(parsed.progress, equals(0.5));
      expect(parsed.isComplete, isFalse);
    });

    test('ItemList progress calculation and isComplete', () {
      final now = DateTime.now();
      final list = ItemList(
        id: 'list-complete',
        libraryId: 'lib-1',
        name: 'Done List',
        items: const [
          ItemListItemEntry(itemId: 'i1', isCollected: true),
          ItemListItemEntry(itemId: 'i2', isCollected: true),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(list.totalCount, equals(2));
      expect(list.collectedCount, equals(2));
      expect(list.progress, equals(1.0));
      expect(list.isComplete, isTrue);
    });
  });

  group('Must scan in security enforcement in repository', () {
    late MockInventoryRepository repo;

    setUp(() {
      repo = MockInventoryRepository();
    });

    test('Must scan in prevents return without barcode or with wrong barcode', () async {
      // Create item marked as mustScanIn
      final item = await repo.saveItem(Item(
        id: 'must-scan-item',
        libraryId: 'lib-workshop-01',
        name: 'Critical Calibration Meter',
        barcode: 'CAL-9999',
        mustScanIn: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Relocate item
      await repo.temporarilyRelocateItem(item.id, 'At Site B');
      final relocated = await repo.getItem(item.id);
      expect(relocated!.isTemporarilyRelocated, isTrue);

      // Attempt return with NO barcode -> throws MustScanInException
      expect(
        () => repo.returnItemToPermanentLocation(item.id),
        throwsA(isA<MustScanInException>()),
      );

      // Attempt return with WRONG barcode -> throws MustScanInException
      expect(
        () => repo.returnItemToPermanentLocation(item.id, scannedBarcode: 'WRONG-BARCODE'),
        throwsA(isA<MustScanInException>()),
      );

      // Still relocated!
      final stillRelocated = await repo.getItem(item.id);
      expect(stillRelocated!.isTemporarilyRelocated, isTrue);

      // Return with CORRECT barcode -> succeeds!
      await repo.returnItemToPermanentLocation(item.id, scannedBarcode: 'CAL-9999');
      final returned = await repo.getItem(item.id);
      expect(returned!.isTemporarilyRelocated, isFalse);
      expect(returned.isStored, isTrue);
    });

    test('Must scan in prevents lending return without barcode', () async {
      final item = await repo.saveItem(Item(
        id: 'must-scan-lent-tool',
        libraryId: 'lib-workshop-01',
        name: 'Precision Fluke Multimeter',
        barcode: 'FLUKE-8888',
        mustScanIn: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final loan = await repo.lendItem(
        itemId: item.id,
        libraryId: item.libraryId,
        borrowerName: 'Dave Engineer',
      );

      final lentItem = await repo.getItem(item.id);
      expect(lentItem!.isLentOut, isTrue);

      // Attempt lending return without barcode
      expect(
        () => repo.returnLentItem(loan.id),
        throwsA(isA<MustScanInException>()),
      );

      // Return with correct barcode
      await repo.returnLentItem(loan.id, scannedBarcode: 'FLUKE-8888');
      final returnedItem = await repo.getItem(item.id);
      expect(returnedItem!.isLentOut, isFalse);
      expect(returnedItem.isStored, isTrue);
    });

    test('Items without mustScanIn return directly without barcode', () async {
      final item = await repo.saveItem(Item(
        id: 'standard-item',
        libraryId: 'lib-workshop-01',
        name: 'Standard Screwdriver',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await repo.temporarilyRelocateItem(item.id, 'Kitchen');
      await repo.returnItemToPermanentLocation(item.id);
      final returned = await repo.getItem(item.id);
      expect(returned!.isTemporarilyRelocated, isFalse);
    });
  });

  group('ItemList collection workflow and destination actions', () {
    late MockInventoryRepository repo;

    setUp(() {
      repo = MockInventoryRepository();
    });

    test('Collection with Not Relocating destination does not alter item status', () async {
      final list = await repo.saveItemList(ItemList(
        id: 'list-not-relocating',
        libraryId: 'lib-workshop-01',
        name: 'Inventory Count List',
        destinationType: ListDestinationType.notRelocating,
        items: const [
          ItemListItemEntry(itemId: 'item-ratchet', isCollected: false),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Tick item
      await repo.collectItemInList(
        listId: list.id,
        itemId: 'item-ratchet',
        isCollected: true,
      );

      final updatedList = await repo.getItemList(list.id);
      expect(updatedList!.items.first.isCollected, isTrue);

      final item = await repo.getItem('item-ratchet');
      expect(item!.isTemporarilyRelocated, isFalse);
      expect(item.isStored, isTrue);
    });

    test('Collection with Storage Location destination temporarily relocates item', () async {
      final list = await repo.saveItemList(ItemList(
        id: 'list-relocate',
        libraryId: 'lib-workshop-01',
        name: 'Van Loadout',
        destinationType: ListDestinationType.storageLocation,
        targetLocationId: 'loc-bench',
        items: const [
          ItemListItemEntry(itemId: 'item-ratchet', isCollected: false),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Tick item
      await repo.collectItemInList(
        listId: list.id,
        itemId: 'item-ratchet',
        isCollected: true,
      );

      final item = await repo.getItem('item-ratchet');
      expect(item!.isTemporarilyRelocated, isTrue);
      expect(item.temporaryLocationId, equals('loc-bench'));

      // Untick item -> reverts to permanent location
      await repo.collectItemInList(
        listId: list.id,
        itemId: 'item-ratchet',
        isCollected: false,
      );

      final reverted = await repo.getItem('item-ratchet');
      expect(reverted!.isTemporarilyRelocated, isFalse);
    });

    test('Collection with Lend All destination lends item to borrower', () async {
      final list = await repo.saveItemList(ItemList(
        id: 'list-lend',
        libraryId: 'lib-workshop-01',
        name: 'Lend to Bob',
        destinationType: ListDestinationType.lend,
        borrowerName: 'Bob Builder',
        borrowerContact: '0400 000 111',
        items: const [
          ItemListItemEntry(itemId: 'item-ratchet', isCollected: false),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Tick item
      await repo.collectItemInList(
        listId: list.id,
        itemId: 'item-ratchet',
        isCollected: true,
      );

      final updatedList = await repo.getItemList(list.id);
      final entry = updatedList!.items.first;
      expect(entry.isCollected, isTrue);
      expect(entry.lendingRecordId, isNotNull);

      final item = await repo.getItem('item-ratchet');
      expect(item!.isLentOut, isTrue);

      // Untick item -> returns from lending
      await repo.collectItemInList(
        listId: list.id,
        itemId: 'item-ratchet',
        isCollected: false,
      );

      final reverted = await repo.getItem('item-ratchet');
      expect(reverted!.isLentOut, isFalse);
    });

    test('returnSelectedItemsInList bulk returns items and resets collection in list', () async {
      final list = await repo.saveItemList(ItemList(
        id: 'list-bulk',
        libraryId: 'lib-workshop-01',
        name: 'Field Work',
        destinationType: ListDestinationType.freeText,
        freeTextNote: 'Field Site',
        items: const [
          ItemListItemEntry(itemId: 'item-ratchet', isCollected: false),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Collect item
      await repo.collectItemInList(
        listId: list.id,
        itemId: 'item-ratchet',
        isCollected: true,
      );

      var item = await repo.getItem('item-ratchet');
      expect(item!.isTemporarilyRelocated, isTrue);

      // Return selected
      await repo.returnSelectedItemsInList(
        listId: list.id,
        itemIds: ['item-ratchet'],
      );

      item = await repo.getItem('item-ratchet');
      expect(item!.isTemporarilyRelocated, isFalse);

      final updatedList = await repo.getItemList(list.id);
      expect(updatedList!.items.first.isCollected, isFalse);
    });
  });
}
