import '../models/library_model.dart';
import '../models/storage_location_model.dart';
import '../models/item_model.dart';
import '../models/item_type_model.dart';
import '../models/lending_record_model.dart';

abstract class InventoryRepository {
  // Library operations
  Future<List<Library>> getLibraries();
  Future<Library?> getLibrary(String id);
  Future<Library> createLibrary(String name, {int itemLimit = 50});
  Future<void> updateLibrary(Library library);
  Future<void> deleteLibrary(String id, {bool deleteOnlineBackup = false});

  // Storage Location operations
  Future<List<StorageLocation>> getStorageLocations(String libraryId, {String? parentId});
  Future<List<StorageLocation>> getAllStorageLocations(String libraryId);
  Future<StorageLocation?> getStorageLocation(String id);
  Future<StorageLocation> saveStorageLocation(StorageLocation location);
  Future<void> deleteStorageLocation(String id);
  Future<List<StorageLocation>> getLocationBreadcrumbs(String locationId);
  Future<StorageLocation> createParentAbove({
    required List<String> childLocationIds,
    required String libraryId,
    required String parentName,
    String? parentDescription,
    String? parentImageUrl,
  });
  Future<void> reparentLocation({
    required String locationId,
    required String? newParentId,
  });

  // Item operations
  Future<List<Item>> getItems(String libraryId, {String? storageLocationId, String? searchQuery});
  Future<Item?> getItem(String id);
  Future<Item> saveItem(Item item);
  Future<void> deleteItem(String id);
  Future<int> getItemCount(String libraryId);

  // Item Type operations
  Future<List<ItemType>> getItemTypes(String libraryId);
  Future<ItemType?> getItemType(String id);
  Future<ItemType> saveItemType(ItemType itemType);
  Future<void> deleteItemType(String id);

  // Relocation
  Future<void> permanentlyRelocateItem(String itemId, String newLocationId);
  Future<void> temporarilyRelocateItem(String itemId, String note, {String? tempLocationId});
  Future<void> returnItemToPermanentLocation(String itemId);

  // Lending operations
  Future<List<LendingRecord>> getLendingRecords(String libraryId, {String? itemId});
  Future<LendingRecord> lendItem({
    required String itemId,
    required String libraryId,
    required String borrowerName,
    String? borrowerContact,
    DateTime? expectedReturnAt,
    String? notes,
  });
  Future<void> returnLentItem(String lendingRecordId);
}
