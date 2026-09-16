import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../core/services/cloud_sync_service.dart';
import '../core/services/local_database_service.dart';
import '../models/item_model.dart';
import '../models/item_type_model.dart';
import '../models/lending_record_model.dart';
import '../models/library_model.dart';
import '../models/storage_location_model.dart';
import 'inventory_repository.dart';

class LocalInventoryRepository implements InventoryRepository {
  static const _uuid = Uuid();
  final LocalDatabaseService db;

  LocalInventoryRepository({LocalDatabaseService? databaseService})
      : db = databaseService ?? LocalDatabaseService.instance;

  // --- Library Operations ---

  @override
  Future<List<Library>> getLibraries() async {
    final seenIds = <String>{};
    return db.libraries.where((l) => seenIds.add(l.id)).toList();
  }

  @override
  Future<Library?> getLibrary(String id) async {
    final list = db.libraries;
    final index = list.indexWhere((l) => l.id == id);
    return index != -1 ? list[index] : null;
  }

  @override
  Future<Library> createLibrary(String name, {int itemLimit = 50}) async {
    String ownerId = 'local-user';
    try {
      if (Supabase.instance.isInitialized) {
        ownerId = Supabase.instance.client.auth.currentUser?.id ?? 'local-user';
      }
    } catch (_) {}

    final library = Library(
      id: _uuid.v4(),
      name: name,
      ownerId: ownerId,
      itemLimit: itemLimit,
      createdAt: DateTime.now(),
    );
    await db.upsertLibrary(library);
    return library;
  }

  @override
  Future<void> updateLibrary(Library library) async {
    await db.upsertLibrary(library);
  }

  @override
  Future<void> deleteLibrary(String id, {bool deleteOnlineBackup = false}) async {
    await db.removeLibrary(id, enqueueSync: deleteOnlineBackup);
    if (deleteOnlineBackup) {
      final syncService = CloudSyncService(databaseService: db);
      await syncService.deleteLibraryFromCloud(id);
    }
  }

  // --- Storage Location Operations ---

  @override
  Future<List<StorageLocation>> getStorageLocations(
    String libraryId, {
    String? parentId,
  }) async {
    final seenIds = <String>{};
    return db.locations.where((loc) {
      if (loc.libraryId != libraryId) return false;
      if (!seenIds.add(loc.id)) return false;
      if (parentId == null) return loc.parentId == null || loc.parentId!.isEmpty;
      return loc.parentId == parentId;
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<List<StorageLocation>> getAllStorageLocations(String libraryId) async {
    final seenIds = <String>{};
    return db.locations
        .where((loc) => loc.libraryId == libraryId && seenIds.add(loc.id))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<StorageLocation?> getStorageLocation(String id) async {
    final list = db.locations;
    final index = list.indexWhere((l) => l.id == id);
    return index != -1 ? list[index] : null;
  }

  @override
  Future<StorageLocation> saveStorageLocation(StorageLocation location) async {
    final effectiveLocation = location.id.isEmpty
        ? location.copyWith(id: _uuid.v4(), createdAt: DateTime.now())
        : location;
    await db.upsertLocation(effectiveLocation);
    return effectiveLocation;
  }

  @override
  Future<void> deleteStorageLocation(String id) async {
    // Collect all recursive child location IDs
    final idsToDelete = <String>{id};
    void findChildren(String parent) {
      for (final loc in db.locations) {
        if (loc.parentId == parent && !idsToDelete.contains(loc.id)) {
          idsToDelete.add(loc.id);
          findChildren(loc.id);
        }
      }
    }

    findChildren(id);

    for (final locId in idsToDelete) {
      await db.removeLocation(locId);
    }

    // Unassign items stored in deleted locations
    for (final item in db.items) {
      if (item.storageLocationId != null && idsToDelete.contains(item.storageLocationId)) {
        await saveItem(item.copyWith(storageLocationId: null));
      }
    }
  }

  @override
  Future<List<StorageLocation>> getLocationBreadcrumbs(String locationId) async {
    final breadcrumbs = <StorageLocation>[];
    String? currentId = locationId;

    while (currentId != null && currentId.isNotEmpty) {
      final loc = await getStorageLocation(currentId);
      if (loc == null) break;
      breadcrumbs.insert(0, loc);
      currentId = loc.parentId;
    }

    return breadcrumbs;
  }

  @override
  Future<StorageLocation> createParentAbove({
    required List<String> childLocationIds,
    required String libraryId,
    required String parentName,
    String? parentDescription,
    String? parentImageUrl,
  }) async {
    // 1. Identify common parent of the children if they share one
    String? commonParentId;
    if (childLocationIds.isNotEmpty) {
      final firstChild = await getStorageLocation(childLocationIds.first);
      commonParentId = firstChild?.parentId;
    }

    // 2. Create the new parent location
    final newParent = StorageLocation(
      id: _uuid.v4(),
      libraryId: libraryId,
      parentId: commonParentId,
      name: parentName,
      description: parentDescription,
      imageUrl: parentImageUrl,
      createdAt: DateTime.now(),
    );
    await db.upsertLocation(newParent);

    // 3. Re-parent the child locations to this new parent
    for (final childId in childLocationIds) {
      final child = await getStorageLocation(childId);
      if (child != null) {
        final updatedChild = child.copyWith(parentId: newParent.id);
        await db.upsertLocation(updatedChild);
      }
    }

    return newParent;
  }

  @override
  Future<void> reparentLocation({
    required String locationId,
    required String? newParentId,
  }) async {
    if (locationId == newParentId) return;
    final loc = await getStorageLocation(locationId);
    if (loc != null) {
      final updated = loc.copyWith(parentId: newParentId);
      await db.upsertLocation(updated);
    }
  }

  // --- Item Operations ---

  @override
  Future<List<Item>> getItems(
    String libraryId, {
    String? storageLocationId,
    String? searchQuery,
    bool includeSubLocations = false,
  }) async {
    final seenIds = <String>{};
    var result =
        db.items.where((it) => it.libraryId == libraryId && seenIds.add(it.id)).toList();

    if (storageLocationId != null) {
      if (includeSubLocations) {
        final targetLocationIds = <String>{storageLocationId};
        void collectDescendants(String parentId) {
          for (final loc in db.locations) {
            if (loc.parentId == parentId && !targetLocationIds.contains(loc.id)) {
              targetLocationIds.add(loc.id);
              collectDescendants(loc.id);
            }
          }
        }
        collectDescendants(storageLocationId);
        result = result.where((it) =>
            it.storageLocationId != null &&
            targetLocationIds.contains(it.storageLocationId)).toList();
      } else {
        result = result.where((it) => it.storageLocationId == storageLocationId).toList();
      }
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((it) {
        if (it.name.toLowerCase().contains(q)) return true;
        if (it.description != null && it.description!.toLowerCase().contains(q)) return true;
        if (it.itemTypeName != null && it.itemTypeName!.toLowerCase().contains(q)) return true;
        for (final val in it.customFields.values) {
          if (val.toString().toLowerCase().contains(q)) return true;
        }
        return false;
      }).toList();
    }

    return result;
  }

  @override
  Future<Item?> getItem(String id) async {
    final list = db.items;
    final index = list.indexWhere((i) => i.id == id);
    return index != -1 ? list[index] : null;
  }

  @override
  Future<Item> saveItem(Item item) async {
    if (item.id.isNotEmpty) {
      final existingItem = await getItem(item.id);
      if (existingItem != null) {
        final oldLocId = existingItem.storageLocationId;
        final newLocId = item.storageLocationId;
        if (oldLocId != null && oldLocId != newLocId) {
          // Erase polygon region targeting this item from the old storage area
          final oldLocation = await getStorageLocation(oldLocId);
          if (oldLocation != null) {
            final updatedRegions = oldLocation.regions
                .where((r) => r.targetItemId != item.id)
                .toList();
            if (updatedRegions.length != oldLocation.regions.length) {
              await saveStorageLocation(oldLocation.copyWith(regions: updatedRegions));
            }
          }
          // Clear polygon points if not newly specified
          if (item.polygonPoints == existingItem.polygonPoints && existingItem.polygonPoints.isNotEmpty) {
            item = item.copyWith(polygonPoints: []);
          }
        }
      }
    }

    final effectiveItem = item.id.isEmpty
        ? item.copyWith(
            id: _uuid.v4(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        : item.copyWith(updatedAt: DateTime.now());
    await db.upsertItem(effectiveItem);
    return effectiveItem;
  }

  @override
  Future<void> deleteItem(String id) async {
    await db.removeItem(id);
  }

  @override
  Future<int> getItemCount(String libraryId) async {
    return db.items.where((it) => it.libraryId == libraryId).length;
  }

  // --- Relocation Operations ---

  @override
  Future<void> permanentlyRelocateItem(String itemId, String newLocationId) async {
    final item = await getItem(itemId);
    if (item != null) {
      final oldLocationId = item.storageLocationId;
      if (oldLocationId != null && oldLocationId != newLocationId) {
        // Erase any polygon region pointing to this item in the old storage location
        final oldLocation = await getStorageLocation(oldLocationId);
        if (oldLocation != null) {
          final updatedRegions = oldLocation.regions
              .where((r) => r.targetItemId != itemId)
              .toList();
          if (updatedRegions.length != oldLocation.regions.length) {
            await saveStorageLocation(oldLocation.copyWith(regions: updatedRegions));
          }
        }
      }

      await saveItem(item.copyWith(
        storageLocationId: newLocationId,
        polygonPoints: (oldLocationId != null && oldLocationId != newLocationId)
            ? []
            : item.polygonPoints,
        isTemporarilyRelocated: false,
        temporaryLocationNote: null,
        temporaryLocationId: null,
        status: AppConstants.itemStatusStored,
        updatedAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> temporarilyRelocateItem(String itemId, String note, {String? tempLocationId}) async {
    final item = await getItem(itemId);
    if (item != null) {
      await saveItem(item.copyWith(
        isTemporarilyRelocated: true,
        temporaryLocationNote: note,
        temporaryLocationId: tempLocationId,
        status: AppConstants.itemStatusRelocated,
        updatedAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> returnItemToPermanentLocation(String itemId) async {
    final item = await getItem(itemId);
    if (item != null) {
      await saveItem(item.copyWith(
        isTemporarilyRelocated: false,
        temporaryLocationNote: null,
        temporaryLocationId: null,
        status: AppConstants.itemStatusStored,
        updatedAt: DateTime.now(),
      ));
    }
  }

  // --- Lending Operations ---

  @override
  Future<List<LendingRecord>> getLendingRecords(String libraryId, {String? itemId}) async {
    return db.lendingRecords.where((r) {
      if (r.libraryId != libraryId) return false;
      if (itemId != null && r.itemId != itemId) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.lentAt.compareTo(a.lentAt));
  }

  @override
  Future<LendingRecord> lendItem({
    required String itemId,
    required String libraryId,
    required String borrowerName,
    String? borrowerContact,
    DateTime? expectedReturnAt,
    String? notes,
  }) async {
    final record = LendingRecord(
      id: _uuid.v4(),
      libraryId: libraryId,
      itemId: itemId,
      borrowerName: borrowerName,
      borrowerContact: borrowerContact,
      lentAt: DateTime.now(),
      expectedReturnAt: expectedReturnAt,
      notes: notes,
    );
    await db.upsertLendingRecord(record);

    final item = await getItem(itemId);
    if (item != null) {
      await saveItem(item.copyWith(
        status: AppConstants.itemStatusLent,
      ));
    }

    return record;
  }

  @override
  Future<void> returnLentItem(String lendingRecordId) async {
    final list = db.lendingRecords;
    final idx = list.indexWhere((r) => r.id == lendingRecordId);
    if (idx != -1) {
      final record = list[idx];
      final updatedRecord = record.copyWith(returnedAt: DateTime.now());
      await db.upsertLendingRecord(updatedRecord);

      final item = await getItem(record.itemId);
      if (item != null) {
        final wasTemp = item.isTemporarilyRelocated;
        await saveItem(item.copyWith(
          status: wasTemp ? AppConstants.itemStatusRelocated : AppConstants.itemStatusStored,
        ));
      }
    }
  }

  // --- Item Types (Schemas) ---

  @override
  Future<List<ItemType>> getItemTypes(String libraryId) async {
    final list = <ItemType>[];
    final seenIds = <String>{};

    // Standard Generic Item is always the first template
    list.add(ItemType.genericItem(libraryId));
    seenIds.add('generic');

    for (final t in db.itemTypes) {
      final isGeneric = t.id == 'generic' ||
          t.id == 'generic_type' ||
          t.id == 'default_type' ||
          t.name.trim().toLowerCase() == 'generic item';

      if (isGeneric) {
        continue; // Prevent duplicates of the built-in generic template
      }

      if (t.libraryId == libraryId && seenIds.add(t.id)) {
        list.add(t);
      }
    }

    return list;
  }

  @override
  Future<ItemType?> getItemType(String id) async {
    if (id == 'generic') return ItemType.genericItem('');
    final list = db.itemTypes;
    final idx = list.indexWhere((t) => t.id == id);
    return idx != -1 ? list[idx] : null;
  }

  @override
  Future<ItemType> saveItemType(ItemType itemType) async {
    final effectiveType = itemType.id.isEmpty
        ? itemType.copyWith(id: _uuid.v4(), createdAt: DateTime.now())
        : itemType;
    await db.upsertItemType(effectiveType);
    return effectiveType;
  }

  @override
  Future<void> deleteItemType(String id) async {
    if (id == 'generic') return;
    await db.removeItemType(id);
  }
}
