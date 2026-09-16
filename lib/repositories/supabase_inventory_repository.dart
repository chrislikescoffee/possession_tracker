import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/library_model.dart';
import '../models/storage_location_model.dart';
import '../models/item_model.dart';
import '../models/item_type_model.dart';
import '../models/lending_record_model.dart';
import 'inventory_repository.dart';

class SupabaseInventoryRepository implements InventoryRepository {
  final SupabaseClient client;

  SupabaseInventoryRepository({required this.client});

  @override
  Future<List<Library>> getLibraries() async {
    final response = await client.from('libraries').select().order('created_at');
    return (response as List).map((json) => Library.fromJson(json)).toList();
  }

  @override
  Future<Library?> getLibrary(String id) async {
    final response = await client.from('libraries').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return Library.fromJson(response);
  }

  @override
  Future<Library> createLibrary(String name, {int itemLimit = 50}) async {
    final user = client.auth.currentUser;
    final response = await client.from('libraries').insert({
      'name': name,
      'owner_id': user?.id,
      'item_limit': itemLimit,
    }).select().single();
    return Library.fromJson(response);
  }

  @override
  Future<void> updateLibrary(Library library) async {
    await client.from('libraries').update(library.toJson()).eq('id', library.id);
  }

  @override
  Future<void> deleteLibrary(String id, {bool deleteOnlineBackup = false}) async {
    try {
      await client.from('lending_records').delete().eq('library_id', id);
    } catch (_) {}
    try {
      await client.from('items').delete().eq('library_id', id);
    } catch (_) {}
    try {
      await client.from('storage_locations').delete().eq('library_id', id);
    } catch (_) {}
    try {
      await client.from('item_types').delete().eq('library_id', id);
    } catch (_) {}
    await client.from('libraries').delete().eq('id', id);
  }

  @override
  Future<List<StorageLocation>> getStorageLocations(String libraryId, {String? parentId}) async {
    var query = client.from('storage_locations').select().eq('library_id', libraryId);
    if (parentId == null) {
      query = query.filter('parent_id', 'is', null);
    } else {
      query = query.eq('parent_id', parentId);
    }
    final response = await query.order('sort_order');
    return (response as List).map((json) => StorageLocation.fromJson(json)).toList();
  }

  @override
  Future<List<StorageLocation>> getAllStorageLocations(String libraryId) async {
    final response = await client
        .from('storage_locations')
        .select()
        .eq('library_id', libraryId)
        .order('sort_order');
    return (response as List).map((json) => StorageLocation.fromJson(json)).toList();
  }

  @override
  Future<StorageLocation?> getStorageLocation(String id) async {
    final response = await client.from('storage_locations').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return StorageLocation.fromJson(response);
  }

  @override
  Future<StorageLocation> saveStorageLocation(StorageLocation location) async {
    final response = await client
        .from('storage_locations')
        .upsert(location.toJson())
        .select()
        .single();
    return StorageLocation.fromJson(response);
  }

  @override
  Future<void> deleteStorageLocation(String id) async {
    await client.from('storage_locations').delete().eq('id', id);
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
    final response = await client
        .from('storage_locations')
        .insert({
          'library_id': libraryId,
          'name': parentName,
          'description': parentDescription,
          'image_url': parentImageUrl,
        })
        .select()
        .single();
    final parentLocation = StorageLocation.fromJson(response);

    if (childLocationIds.isNotEmpty) {
      await client
          .from('storage_locations')
          .update({'parent_id': parentLocation.id})
          .filter('id', 'in', childLocationIds);
    }

    return parentLocation;
  }

  @override
  Future<void> reparentLocation({
    required String locationId,
    required String? newParentId,
  }) async {
    if (locationId == newParentId) return;
    await client
        .from('storage_locations')
        .update({'parent_id': newParentId})
        .eq('id', locationId);
  }

  @override
  Future<List<Item>> getItems(
    String libraryId, {
    String? storageLocationId,
    String? searchQuery,
    bool includeSubLocations = false,
  }) async {
    var query = client.from('items').select().eq('library_id', libraryId);
    if (storageLocationId != null) {
      query = query.eq('storage_location_id', storageLocationId);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('name', '%${searchQuery.trim()}%');
    }
    final response = await query.order('created_at', ascending: false);
    return (response as List).map((json) => Item.fromJson(json)).toList();
  }

  @override
  Future<Item?> getItem(String id) async {
    final response = await client.from('items').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return Item.fromJson(response);
  }

  @override
  Future<Item> saveItem(Item item) async {
    // Check count for 50-item quota
    final count = await getItemCount(item.libraryId);
    final lib = await getLibrary(item.libraryId);
    final limit = lib?.itemLimit ?? AppConstants.defaultItemLimit;
    if (count >= limit) {
      throw StateError('Library item limit of $limit items reached. Upgrade to add more items.');
    }

    final response = await client
        .from('items')
        .upsert(item.toJson())
        .select()
        .single();
    return Item.fromJson(response);
  }

  @override
  Future<void> deleteItem(String id) async {
    await client.from('items').delete().eq('id', id);
  }

  @override
  Future<int> getItemCount(String libraryId) async {
    final count = await client
        .from('items')
        .count()
        .eq('library_id', libraryId);
    return count;
  }

  // --- Item Type Operations ---
  @override
  Future<List<ItemType>> getItemTypes(String libraryId) async {
    try {
      final response = await client
          .from('item_types')
          .select()
          .eq('library_id', libraryId)
          .order('name');
      final rawList = (response as List).map((json) => ItemType.fromJson(json)).toList();
      final list = <ItemType>[];
      final seenIds = <String>{};

      list.add(ItemType.genericItem(libraryId));
      seenIds.add('generic');

      for (final t in rawList) {
        final isGeneric = t.id == 'generic' ||
            t.id == 'generic_type' ||
            t.id == 'default_type' ||
            t.name.trim().toLowerCase() == 'generic item';
        if (isGeneric) continue;
        if (seenIds.add(t.id)) {
          list.add(t);
        }
      }
      return list;
    } catch (_) {
      return [ItemType.genericItem(libraryId)];
    }
  }

  @override
  Future<ItemType?> getItemType(String id) async {
    if (id == 'generic') return ItemType.genericItem('');
    try {
      final response = await client.from('item_types').select().eq('id', id).maybeSingle();
      if (response == null) return null;
      return ItemType.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ItemType> saveItemType(ItemType itemType) async {
    try {
      final response = await client
          .from('item_types')
          .upsert(itemType.toJson())
          .select()
          .single();
      return ItemType.fromJson(response);
    } catch (_) {
      return itemType;
    }
  }

  @override
  Future<void> deleteItemType(String id) async {
    if (id == 'generic') return;
    try {
      await client.from('item_types').delete().eq('id', id);
    } catch (_) {}
  }

  @override
  Future<void> permanentlyRelocateItem(String itemId, String newLocationId) async {
    await client.from('items').update({
      'storage_location_id': newLocationId,
      'is_temporarily_relocated': false,
      'temporary_location_note': null,
      'temporary_location_id': null,
      'status': AppConstants.itemStatusStored,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', itemId);
  }

  @override
  Future<void> temporarilyRelocateItem(String itemId, String note, {String? tempLocationId}) async {
    await client.from('items').update({
      'is_temporarily_relocated': true,
      'temporary_location_note': note,
      'temporary_location_id': tempLocationId,
      'status': AppConstants.itemStatusRelocated,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', itemId);
  }

  @override
  Future<void> returnItemToPermanentLocation(String itemId) async {
    await client.from('items').update({
      'is_temporarily_relocated': false,
      'temporary_location_note': null,
      'temporary_location_id': null,
      'status': AppConstants.itemStatusStored,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', itemId);
  }

  @override
  Future<List<LendingRecord>> getLendingRecords(String libraryId, {String? itemId}) async {
    var query = client.from('lending_records').select().eq('library_id', libraryId);
    if (itemId != null) {
      query = query.eq('item_id', itemId);
    }
    final response = await query.order('lent_at', ascending: false);
    return (response as List).map((json) => LendingRecord.fromJson(json)).toList();
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
    final response = await client.from('lending_records').insert({
      'item_id': itemId,
      'library_id': libraryId,
      'borrower_name': borrowerName,
      'borrower_contact': borrowerContact,
      'lent_at': DateTime.now().toIso8601String(),
      'expected_return_at': expectedReturnAt?.toIso8601String(),
      'notes': notes,
    }).select().single();

    await client.from('items').update({
      'status': AppConstants.itemStatusLent,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', itemId);

    return LendingRecord.fromJson(response);
  }

  @override
  Future<void> returnLentItem(String lendingRecordId) async {
    final now = DateTime.now().toIso8601String();
    final response = await client
        .from('lending_records')
        .update({'returned_at': now})
        .eq('id', lendingRecordId)
        .select()
        .single();
    final record = LendingRecord.fromJson(response);

    await client.from('items').update({
      'status': AppConstants.itemStatusStored,
      'updated_at': now,
    }).eq('id', record.itemId);
  }
}
