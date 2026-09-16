import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:possession_tracker/core/services/local_database_service.dart';
import 'package:possession_tracker/models/item_model.dart';
import 'package:possession_tracker/models/polygon_region.dart';
import 'package:possession_tracker/models/storage_location_model.dart';
import 'package:possession_tracker/models/sync_model.dart';
import 'package:possession_tracker/repositories/local_inventory_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('possession_tracker_test_');
    dbPath = '${tempDir.path}/test_db.json';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('LocalDatabaseService seeds data on first run and creates json file', () async {
    final db = LocalDatabaseService();
    await db.init(customPath: dbPath);

    expect(File(dbPath).existsSync(), isTrue);
    expect(db.libraries, isNotEmpty);
    expect(db.locations, isNotEmpty);
    expect(db.items, isNotEmpty);
  });

  test('Data persists across app restarts (re-instantiating LocalDatabaseService from disk)', () async {
    final db1 = LocalDatabaseService();
    await db1.init(customPath: dbPath);

    final repo1 = LocalInventoryRepository(databaseService: db1);
    final lib = (await repo1.getLibraries()).first;

    // Create a new location with polygon regions
    final newLocation = await repo1.saveStorageLocation(
      StorageLocation(
        id: 'persisted-loc-1',
        libraryId: lib.id,
        name: 'Top Shelf In Shed',
        description: 'Heavy duty storage shelf',
        regions: const [
          PolygonRegion(
            id: 'reg-shelf-1',
            label: 'Shelf Level 1',
            points: [
              NormalizedPoint(x: 0.1, y: 0.1),
              NormalizedPoint(x: 0.9, y: 0.1),
              NormalizedPoint(x: 0.9, y: 0.5),
              NormalizedPoint(x: 0.1, y: 0.5),
            ],
          ),
        ],
        createdAt: DateTime.now(),
      ),
    );

    // Create a new item stored in that location with polygon points
    final newItem = await repo1.saveItem(
      Item(
        id: 'persisted-item-1',
        libraryId: lib.id,
        storageLocationId: newLocation.id,
        name: 'Milwaukee Cordless Grinder',
        description: 'Brushless 18V angle grinder',
        polygonPoints: const [
          NormalizedPoint(x: 0.2, y: 0.2),
          NormalizedPoint(x: 0.4, y: 0.2),
          NormalizedPoint(x: 0.4, y: 0.4),
          NormalizedPoint(x: 0.2, y: 0.4),
        ],
        customFields: const {
          'Brand': 'Milwaukee',
          'Voltage': '18V',
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    expect(newLocation.id, equals('persisted-loc-1'));
    expect(newItem.id, equals('persisted-item-1'));

    // Verify sync queue received upsert entries
    expect(
      db1.syncQueue.any((q) => q.entityId == 'persisted-loc-1' && q.operation == SyncOperation.upsert),
      isTrue,
    );
    expect(
      db1.syncQueue.any((q) => q.entityId == 'persisted-item-1' && q.operation == SyncOperation.upsert),
      isTrue,
    );

    // SIMULATE APP CLOSE & RESTART:
    // Create a fresh instance reading directly from dbPath
    final db2 = LocalDatabaseService();
    // Force re-init with file
    await db2.init(customPath: dbPath);
    final repo2 = LocalInventoryRepository(databaseService: db2);

    final loadedLoc = await repo2.getStorageLocation('persisted-loc-1');
    expect(loadedLoc, isNotNull);
    expect(loadedLoc!.name, equals('Top Shelf In Shed'));
    expect(loadedLoc.regions, isNotEmpty);
    expect(loadedLoc.regions.first.points.length, equals(4));
    expect(loadedLoc.regions.first.points.first.x, closeTo(0.1, 0.001));

    final loadedItem = await repo2.getItem('persisted-item-1');
    expect(loadedItem, isNotNull);
    expect(loadedItem!.name, equals('Milwaukee Cordless Grinder'));
    expect(loadedItem.storageLocationId, equals('persisted-loc-1'));
    expect(loadedItem.polygonPoints.length, equals(4));
    expect(loadedItem.customFields['Brand'], equals('Milwaukee'));
  });

  test('Offline mutations queue deletion properly', () async {
    final db = LocalDatabaseService();
    await db.init(customPath: dbPath);
    final repo = LocalInventoryRepository(databaseService: db);

    // Save and then delete
    final item = await repo.saveItem(
      Item(
        id: 'to-delete-item',
        libraryId: 'lib-1',
        name: 'Item to delete',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await repo.deleteItem(item.id);

    expect(await repo.getItem('to-delete-item'), isNull);
    expect(
      db.syncQueue.any((q) => q.entityId == 'to-delete-item' && q.operation == SyncOperation.delete),
      isTrue,
    );
  });

  test('Relocating an item to a new storage location erases polygon points and removes region from old location', () async {
    final db = LocalDatabaseService();
    await db.init(customPath: dbPath);
    final repo = LocalInventoryRepository(databaseService: db);

    // 1. Create source and target locations
    await repo.saveStorageLocation(
      StorageLocation(
        id: 'source-loc',
        libraryId: 'lib-1',
        name: 'Drawer 1',
        regions: const [
          PolygonRegion(
            id: 'reg-item-1',
            label: '10mm Socket',
            targetItemId: 'item-to-move',
            points: [
              NormalizedPoint(x: 0.1, y: 0.1),
              NormalizedPoint(x: 0.3, y: 0.1),
              NormalizedPoint(x: 0.3, y: 0.3),
              NormalizedPoint(x: 0.1, y: 0.3),
            ],
          ),
        ],
        createdAt: DateTime.now(),
      ),
    );

    await repo.saveStorageLocation(
      StorageLocation(
        id: 'target-loc',
        libraryId: 'lib-1',
        name: 'Drawer 2',
        createdAt: DateTime.now(),
      ),
    );

    // 2. Create item located in source-loc with polygon points
    await repo.saveItem(
      Item(
        id: 'item-to-move',
        libraryId: 'lib-1',
        storageLocationId: 'source-loc',
        name: '10mm Socket',
        polygonPoints: const [
          NormalizedPoint(x: 0.1, y: 0.1),
          NormalizedPoint(x: 0.3, y: 0.1),
          NormalizedPoint(x: 0.3, y: 0.3),
          NormalizedPoint(x: 0.1, y: 0.3),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // 3. Relocate item to target-loc
    await repo.permanentlyRelocateItem('item-to-move', 'target-loc');

    // 4. Assertions:
    // Item should now be in target-loc with empty polygonPoints
    final movedItem = await repo.getItem('item-to-move');
    expect(movedItem, isNotNull);
    expect(movedItem!.storageLocationId, equals('target-loc'));
    expect(movedItem.polygonPoints, isEmpty);

    // Source location should have had the region targeting this item erased
    final sourceLoc = await repo.getStorageLocation('source-loc');
    expect(sourceLoc, isNotNull);
    expect(sourceLoc!.regions.any((r) => r.targetItemId == 'item-to-move'), isFalse);
  });

  test('deleteLibrary with deleteOnlineBackup=false keeps cloud backup and tracks local deletion', () async {
    final db = LocalDatabaseService();
    await db.init(customPath: dbPath);
    final repo = LocalInventoryRepository(databaseService: db);

    final lib = await repo.createLibrary('Workshop Tools');
    await repo.saveStorageLocation(
      StorageLocation(
        id: 'bench-1',
        libraryId: lib.id,
        name: 'Work Bench',
        createdAt: DateTime.now(),
      ),
    );

    // Initial state check
    expect((await repo.getLibraries()).any((l) => l.id == lib.id), isTrue);

    // Delete locally only (keep online backup)
    await repo.deleteLibrary(lib.id, deleteOnlineBackup: false);

    // Library and children should be removed locally
    expect((await repo.getLibraries()).any((l) => l.id == lib.id), isFalse);
    expect((await repo.getAllStorageLocations(lib.id)), isEmpty);

    // Should NOT have a delete operation in syncQueue
    final deleteInQueue = db.syncQueue.any(
      (q) => q.entityId == lib.id && q.operation == SyncOperation.delete,
    );
    expect(deleteInQueue, isFalse);

    // Should be tracked in locallyDeletedLibraryIds
    expect(db.locallyDeletedLibraryIds.contains(lib.id), isTrue);
  });

  test('deleteLibrary with deleteOnlineBackup=true enqueues cloud deletion', () async {
    final db = LocalDatabaseService();
    await db.init(customPath: dbPath);
    final repo = LocalInventoryRepository(databaseService: db);

    final lib = await repo.createLibrary('Temporary Library');
    await repo.deleteLibrary(lib.id, deleteOnlineBackup: true);

    expect((await repo.getLibraries()).any((l) => l.id == lib.id), isFalse);

    // Should have a delete operation in syncQueue
    final deleteInQueue = db.syncQueue.any(
      (q) => q.entityId == lib.id && q.operation == SyncOperation.delete,
    );
    expect(deleteInQueue, isTrue);
  });

  test('autoSync setting persists to disk and defaults to true', () async {
    final db = LocalDatabaseService();
    await db.init(customPath: dbPath);

    expect(db.autoSyncEnabled, isTrue);

    await db.setAutoSyncEnabled(false);
    expect(db.autoSyncEnabled, isFalse);

    // Re-instantiate from disk
    final dbRestarted = LocalDatabaseService();
    await dbRestarted.init(customPath: dbPath);
    expect(dbRestarted.autoSyncEnabled, isFalse);
  });

  test('hasUserAddedContent correctly detects untouched seed data vs modified data', () async {
    final db = LocalDatabaseService();
    await db.init(customPath: dbPath);

    // Untouched seed library
    expect(db.hasUserAddedContent('lib-workshop-01'), isFalse);

    // Add a custom item to the seed library
    final repo = LocalInventoryRepository(databaseService: db);
    await repo.saveItem(
      Item(
        id: 'new-custom-tool-1',
        libraryId: 'lib-workshop-01',
        name: 'New Custom Tool',
        itemTypeId: 'type-tool',
        status: 'stored',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    expect(db.hasUserAddedContent('lib-workshop-01'), isTrue);
  });

  test('discounting untouched seed library removes it completely from local database', () async {
    final db = LocalDatabaseService();
    await db.init(customPath: dbPath);

    expect(db.libraries.any((l) => l.id == 'lib-workshop-01'), isTrue);
    expect(db.hasUserAddedContent('lib-workshop-01'), isFalse);

    // Simulate discounting the untouched generic library
    await db.removeLibrary('lib-workshop-01', enqueueSync: false);

    expect(db.libraries.any((l) => l.id == 'lib-workshop-01'), isFalse);
    expect(db.locations.any((loc) => loc.libraryId == 'lib-workshop-01'), isFalse);
    expect(db.items.any((item) => item.libraryId == 'lib-workshop-01'), isFalse);
    expect(db.syncQueue.any((q) => q.entityId == 'lib-workshop-01'), isFalse);
  });
}
