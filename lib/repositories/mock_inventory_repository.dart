import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../models/field_definition_model.dart';
import '../models/item_list_model.dart';
import '../models/item_model.dart';
import '../models/item_type_model.dart';
import '../models/lending_record_model.dart';
import '../models/library_model.dart';
import '../models/polygon_region.dart';
import '../models/storage_location_model.dart';
import 'inventory_repository.dart';

class MockInventoryRepository implements InventoryRepository {
  static const _uuid = Uuid();

  final List<Library> _libraries = [];
  final List<StorageLocation> _locations = [];
  final List<Item> _items = [];
  final List<LendingRecord> _lendingRecords = [];
  final List<ItemType> _itemTypes = [];
  final List<ItemList> _itemLists = [];

  MockInventoryRepository() {
    _seedData();
  }

  void _seedData() {
    final now = DateTime.now();
    const defaultLibId = 'lib-workshop-01';

    // 1. Seed Library
    _libraries.add(
      Library(
        id: defaultLibId,
        name: 'Home & Workshop Library',
        ownerId: 'user-chris-01',
        itemLimit: AppConstants.defaultItemLimit,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
    );

    // 2. Seed Storage Locations (Arbitrary Tree Hierarchy)
    // Root Level: Workshop
    const workshopId = 'loc-workshop';
    // Sub-level 1: Heavy Duty Workbench
    const benchId = 'loc-bench';
    // Sub-level 2: Top Tool Drawer
    const drawerId = 'loc-drawer';
    // Sub-level 3: Socket Set Box
    const socketBoxId = 'loc-socketbox';
    // Another Root: Living Room
    const livingRoomId = 'loc-livingroom';

    _locations.addAll([
      StorageLocation(
        id: workshopId,
        libraryId: defaultLibId,
        name: 'Workshop & Garage',
        description: 'Main workshop bay on ground floor',
        imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=1200&q=80',
        regions: [
          PolygonRegion(
            id: 'poly-bench',
            label: 'Tool Workbench',
            targetLocationId: benchId,
            points: [
              const NormalizedPoint(x: 0.15, y: 0.40),
              const NormalizedPoint(x: 0.85, y: 0.40),
              const NormalizedPoint(x: 0.88, y: 0.88),
              const NormalizedPoint(x: 0.12, y: 0.88),
            ],
            colorHex: 0xFF6366F1,
          ),
        ],
        sortOrder: 1,
        createdAt: now.subtract(const Duration(days: 28)),
      ),
      StorageLocation(
        id: benchId,
        libraryId: defaultLibId,
        parentId: workshopId,
        name: 'Heavy Duty Tool Bench',
        description: 'Solid oak bench with mounted vise and multi-drawer chest',
        imageUrl: 'https://images.unsplash.com/photo-1530124566582-a618bc2615dc?auto=format&fit=crop&w=1200&q=80',
        regions: [
          PolygonRegion(
            id: 'poly-drawer',
            label: 'Top Tool Drawer',
            targetLocationId: drawerId,
            points: [
              const NormalizedPoint(x: 0.20, y: 0.25),
              const NormalizedPoint(x: 0.80, y: 0.25),
              const NormalizedPoint(x: 0.80, y: 0.50),
              const NormalizedPoint(x: 0.20, y: 0.50),
            ],
            colorHex: 0xFF06B6D4,
          ),
        ],
        sortOrder: 2,
        createdAt: now.subtract(const Duration(days: 27)),
      ),
      StorageLocation(
        id: drawerId,
        libraryId: defaultLibId,
        parentId: benchId,
        name: 'Top Tool Drawer',
        description: 'First drawer with socket sets and precision drivers',
        imageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=1200&q=80',
        regions: [
          PolygonRegion(
            id: 'poly-socketbox',
            label: 'Socket Organizer Box',
            targetLocationId: socketBoxId,
            points: [
              const NormalizedPoint(x: 0.22, y: 0.35),
              const NormalizedPoint(x: 0.78, y: 0.35),
              const NormalizedPoint(x: 0.76, y: 0.82),
              const NormalizedPoint(x: 0.24, y: 0.82),
            ],
            colorHex: 0xFF10B981,
          ),
        ],
        sortOrder: 3,
        createdAt: now.subtract(const Duration(days: 26)),
      ),
      StorageLocation(
        id: socketBoxId,
        libraryId: defaultLibId,
        parentId: drawerId,
        name: 'Socket Organizer Box',
        description: 'Black molded steel case with 1/2-inch and 3/8-inch metric sockets',
        imageUrl: 'https://images.unsplash.com/photo-1581244277943-fe4a9c777189?auto=format&fit=crop&w=1200&q=80',
        regions: [
          PolygonRegion(
            id: 'poly-item-10mm',
            label: '10mm Metric Socket',
            targetItemId: 'item-10mm-socket',
            points: [
              const NormalizedPoint(x: 0.38, y: 0.42),
              const NormalizedPoint(x: 0.52, y: 0.42),
              const NormalizedPoint(x: 0.52, y: 0.62),
              const NormalizedPoint(x: 0.38, y: 0.62),
            ],
            colorHex: 0xFFF59E0B,
          ),
        ],
        sortOrder: 4,
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      StorageLocation(
        id: livingRoomId,
        libraryId: defaultLibId,
        name: 'Living Room Cabinet',
        description: 'Hardwood display cabinet with lower drawers',
        imageUrl: 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=1200&q=80',
        regions: [],
        sortOrder: 5,
        createdAt: now.subtract(const Duration(days: 20)),
      ),
    ]);

    // 3. Seed Items
    _items.addAll([
      Item(
        id: 'item-10mm-socket',
        libraryId: defaultLibId,
        storageLocationId: socketBoxId,
        name: '10mm Deep Metric Socket',
        description: 'Chrome vanadium 6-point 1/2-inch drive socket',
        primaryImageUrl: 'https://images.unsplash.com/photo-1581244277943-fe4a9c777189?auto=format&fit=crop&w=600&q=80',
        polygonPoints: [
          const NormalizedPoint(x: 0.38, y: 0.42),
          const NormalizedPoint(x: 0.52, y: 0.42),
          const NormalizedPoint(x: 0.52, y: 0.62),
          const NormalizedPoint(x: 0.38, y: 0.62),
        ],
        customFields: {
          'Brand': 'DeWalt',
          'Drive Size': '1/2 inch',
          'Socket Size': '10mm',
          'Material': 'Chrome Vanadium',
        },
        status: AppConstants.itemStatusStored,
        createdAt: now.subtract(const Duration(days: 24)),
        updatedAt: now.subtract(const Duration(days: 24)),
      ),
      Item(
        id: 'item-ratchet',
        libraryId: defaultLibId,
        storageLocationId: socketBoxId,
        name: '1/2-inch Sealed Head Ratchet',
        description: '72-tooth teardrop ratchet handle with quick-release button',
        primaryImageUrl: 'https://images.unsplash.com/photo-1572981779307-38b8cabb2407?auto=format&fit=crop&w=600&q=80',
        customFields: {
          'Brand': 'DeWalt',
          'Gear Teeth': 72,
          'Length': '10.5 inches',
        },
        status: AppConstants.itemStatusStored,
        createdAt: now.subtract(const Duration(days: 24)),
        updatedAt: now.subtract(const Duration(days: 24)),
      ),
      Item(
        id: 'item-impact-driver',
        libraryId: defaultLibId,
        storageLocationId: benchId,
        name: '20V MAX Brushless Cordless Impact Driver',
        description: 'Primary cordless driver with belt hook',
        primaryImageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=600&q=80',
        customFields: {
          'Brand': 'DeWalt',
          'Voltage': '20V',
          'Motor': 'Brushless',
          'Serial Number': 'DW-2024-9988',
        },
        isTemporarilyRelocated: true,
        temporaryLocationNote: 'In car trunk - left after job site visit',
        status: AppConstants.itemStatusRelocated,
        createdAt: now.subtract(const Duration(days: 22)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      Item(
        id: 'item-laser-level',
        libraryId: defaultLibId,
        storageLocationId: benchId,
        name: 'Self-Leveling 360-Degree Cross Line Laser',
        description: 'Green beam self-leveling laser with magnetic bracket',
        primaryImageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=600&q=80',
        customFields: {
          'Brand': 'Bosch',
          'Beam Color': 'Green',
          'Accuracy': '±1/8 in at 30 ft',
        },
        status: AppConstants.itemStatusLent,
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      Item(
        id: 'item-knipex-pliers',
        libraryId: defaultLibId,
        storageLocationId: drawerId,
        name: 'Knipex Cobra Water Pump Pliers 250mm',
        description: 'Quick push-button adjustment with hardened teeth',
        primaryImageUrl: 'https://images.unsplash.com/photo-1530124566582-a618bc2615dc?auto=format&fit=crop&w=600&q=80',
        customFields: {
          'Brand': 'Knipex',
          'Length': '250mm',
          'Made In': 'Germany',
        },
        status: AppConstants.itemStatusStored,
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 15)),
      ),
    ]);

    // 4. Seed Lending Record
    _lendingRecords.add(
      LendingRecord(
        id: 'lend-01',
        itemId: 'item-laser-level',
        libraryId: defaultLibId,
        borrowerName: 'David Miller',
        borrowerContact: '+1 (555) 234-8901',
        lentAt: now.subtract(const Duration(days: 5)),
        expectedReturnAt: now.add(const Duration(days: 3)),
        notes: 'Borrowing to align suspended ceiling grid in garage',
      ),
    );

    // 5. Seed Item Types
    _itemTypes.addAll([
      ItemType.genericItem(defaultLibId),
      ItemType(
        id: 'type-powertool',
        libraryId: defaultLibId,
        name: 'Power Tool',
        description: 'Cordless and corded power machinery & drivers',
        icon: 'build',
        fields: const [
          FieldDefinition(id: 'f-pt-brand', name: 'Brand', type: ItemFieldType.text),
          FieldDefinition(id: 'f-pt-voltage', name: 'Voltage', type: ItemFieldType.number, unit: 'V'),
          FieldDefinition(id: 'f-pt-weight', name: 'Weight', type: ItemFieldType.weight, unit: 'kg'),
          FieldDefinition(id: 'f-pt-price', name: 'Price', type: ItemFieldType.currency, unit: 'AUD'),
          FieldDefinition(id: 'f-pt-cordless', name: 'Cordless', type: ItemFieldType.text, defaultValue: 'Yes'),
        ],
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      ItemType(
        id: 'type-pottery',
        libraryId: defaultLibId,
        name: 'Pottery Item',
        description: 'Ceramics, glazed bowls, and hand-thrown vessels',
        icon: 'palette',
        fields: const [
          FieldDefinition(id: 'f-pot-clay', name: 'Clay Body', type: ItemFieldType.text),
          FieldDefinition(id: 'f-pot-glaze', name: 'Glaze', type: ItemFieldType.text),
          FieldDefinition(id: 'f-pot-dim', name: 'Dimensions', type: ItemFieldType.dimension, unit: 'cm'),
          FieldDefinition(id: 'f-pot-date', name: 'Date Created', type: ItemFieldType.date),
          FieldDefinition(id: 'f-pot-temp', name: 'Firing Temp', type: ItemFieldType.number, unit: '°C'),
        ],
        createdAt: now.subtract(const Duration(days: 28)),
      ),
      ItemType(
        id: 'type-camping',
        libraryId: defaultLibId,
        name: 'Camping Gear',
        description: 'Outdoor, backpacking, cooking & shelter equipment',
        icon: 'terrain',
        fields: const [
          FieldDefinition(id: 'f-camp-cat', name: 'Category', type: ItemFieldType.text),
          FieldDefinition(id: 'f-camp-wt', name: 'Weight', type: ItemFieldType.weight, unit: 'g'),
          FieldDefinition(id: 'f-camp-dim', name: 'Packed Size', type: ItemFieldType.dimension, unit: 'cm'),
          FieldDefinition(id: 'f-camp-date', name: 'Purchase Date', type: ItemFieldType.date),
          FieldDefinition(id: 'f-camp-price', name: 'Price', type: ItemFieldType.currency, unit: 'AUD'),
        ],
        createdAt: now.subtract(const Duration(days: 25)),
      ),
    ]);
  }

  // --- Library Operations ---
  @override
  Future<List<Library>> getLibraries() async {
    return List.unmodifiable(_libraries);
  }

  @override
  Future<Library?> getLibrary(String id) async {
    try {
      return _libraries.firstWhere((lib) => lib.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Library> createLibrary(String name, {int itemLimit = 50}) async {
    final newLib = Library(
      id: _uuid.v4(),
      name: name,
      ownerId: 'current-user',
      itemLimit: itemLimit,
      createdAt: DateTime.now(),
    );
    _libraries.add(newLib);
    return newLib;
  }

  @override
  Future<void> updateLibrary(Library library) async {
    final idx = _libraries.indexWhere((l) => l.id == library.id);
    if (idx != -1) {
      _libraries[idx] = library;
    }
  }

  @override
  Future<void> deleteLibrary(String id, {bool deleteOnlineBackup = false}) async {
    _libraries.removeWhere((l) => l.id == id);
    _locations.removeWhere((loc) => loc.libraryId == id);
    _items.removeWhere((item) => item.libraryId == id);
    _itemTypes.removeWhere((it) => it.libraryId == id);
    _lendingRecords.removeWhere((lr) => lr.libraryId == id);
  }

  // --- Storage Location Operations ---
  @override
  Future<List<StorageLocation>> getStorageLocations(String libraryId, {String? parentId}) async {
    return _locations.where((loc) {
      final matchesLib = loc.libraryId == libraryId;
      if (parentId == null) {
        return matchesLib && (loc.parentId == null || loc.parentId!.isEmpty);
      }
      return matchesLib && loc.parentId == parentId;
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<List<StorageLocation>> getAllStorageLocations(String libraryId) async {
    return _locations.where((loc) => loc.libraryId == libraryId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<StorageLocation?> getStorageLocation(String id) async {
    try {
      return _locations.firstWhere((loc) => loc.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<StorageLocation> saveStorageLocation(StorageLocation location) async {
    final idx = _locations.indexWhere((l) => l.id == location.id);
    if (idx != -1) {
      _locations[idx] = location;
      return location;
    } else {
      _locations.add(location);
      return location;
    }
  }

  @override
  Future<void> deleteStorageLocation(String id) async {
    // Cascade delete child locations and unassign items
    final childIds = _locations.where((l) => l.parentId == id).map((l) => l.id).toList();
    for (final cid in childIds) {
      await deleteStorageLocation(cid);
    }
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].storageLocationId == id) {
        _items[i] = _items[i].copyWith(storageLocationId: null);
      }
    }
    _locations.removeWhere((l) => l.id == id);
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
    // 1. Create the new overarching parent location
    final parentLocation = StorageLocation(
      id: _uuid.v4(),
      libraryId: libraryId,
      name: parentName,
      description: parentDescription,
      imageUrl: parentImageUrl,
      createdAt: DateTime.now(),
    );
    _locations.add(parentLocation);

    // 2. Point all specified children to this new parent
    for (final childId in childLocationIds) {
      final idx = _locations.indexWhere((l) => l.id == childId);
      if (idx != -1) {
        _locations[idx] = _locations[idx].copyWith(parentId: parentLocation.id);
      }
    }

    return parentLocation;
  }

  @override
  Future<void> reparentLocation({
    required String locationId,
    required String? newParentId,
  }) async {
    // Prevent setting self as parent
    if (locationId == newParentId) return;

    final idx = _locations.indexWhere((l) => l.id == locationId);
    if (idx != -1) {
      _locations[idx] = _locations[idx].copyWith(parentId: newParentId);
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
    final targetLocationIds = storageLocationId != null
        ? (includeSubLocations
            ? () {
                final ids = <String>{storageLocationId};
                void collectDescendants(String parentId) {
                  for (final loc in _locations) {
                    if (loc.parentId == parentId && !ids.contains(loc.id)) {
                      ids.add(loc.id);
                      collectDescendants(loc.id);
                    }
                  }
                }
                collectDescendants(storageLocationId);
                return ids;
              }()
            : <String>{storageLocationId})
        : null;

    return _items.where((item) {
      if (item.libraryId != libraryId) return false;
      if (targetLocationIds != null) {
        if (item.storageLocationId == null || !targetLocationIds.contains(item.storageLocationId)) {
          return false;
        }
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        final nameMatch = item.name.toLowerCase().contains(q);
        final descMatch = (item.description ?? '').toLowerCase().contains(q);
        final fieldsMatch = item.customFields.values
            .any((v) => v.toString().toLowerCase().contains(q));
        return nameMatch || descMatch || fieldsMatch;
      }
      return true;
    }).toList();
  }

  @override
  Future<Item?> getItem(String id) async {
    try {
      return _items.firstWhere((it) => it.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Item> saveItem(Item item) async {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx != -1) {
      _items[idx] = item.copyWith(updatedAt: DateTime.now());
      return _items[idx];
    } else {
      // Check quota limit
      final count = await getItemCount(item.libraryId);
      final lib = await getLibrary(item.libraryId);
      final limit = lib?.itemLimit ?? AppConstants.defaultItemLimit;
      if (count >= limit) {
        throw StateError('Library item limit of $limit items reached. Upgrade to add more items.');
      }
      _items.add(item);
      return item;
    }
  }

  @override
  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    _lendingRecords.removeWhere((lr) => lr.itemId == id);
  }

  @override
  Future<int> getItemCount(String libraryId) async {
    return _items.where((i) => i.libraryId == libraryId).length;
  }

  // --- Item Type Operations ---
  @override
  Future<List<ItemType>> getItemTypes(String libraryId) async {
    final list = <ItemType>[];
    final seenIds = <String>{};

    list.add(ItemType.genericItem(libraryId));
    seenIds.add('generic');

    for (final t in _itemTypes) {
      final isGeneric = t.id == 'generic' ||
          t.id == 'generic_type' ||
          t.id == 'default_type' ||
          t.name.trim().toLowerCase() == 'generic item';

      if (isGeneric) continue;

      if (t.libraryId == libraryId && seenIds.add(t.id)) {
        list.add(t);
      }
    }

    return list;
  }

  @override
  Future<ItemType?> getItemType(String id) async {
    if (id == 'generic') return ItemType.genericItem('');
    try {
      return _itemTypes.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ItemType> saveItemType(ItemType itemType) async {
    final idx = _itemTypes.indexWhere((t) => t.id == itemType.id);
    if (idx != -1) {
      _itemTypes[idx] = itemType;
      return itemType;
    } else {
      _itemTypes.add(itemType);
      return itemType;
    }
  }

  @override
  Future<void> deleteItemType(String id) async {
    if (id == 'generic') return; // Cannot delete generic
    _itemTypes.removeWhere((t) => t.id == id);
  }

  // --- Relocation Operations ---
  @override
  Future<void> permanentlyRelocateItem(String itemId, String newLocationId) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx != -1) {
      final oldLocationId = _items[idx].storageLocationId;
      if (oldLocationId != null && oldLocationId != newLocationId) {
        final oldLocIdx = _locations.indexWhere((l) => l.id == oldLocationId);
        if (oldLocIdx != -1) {
          final updatedRegions = _locations[oldLocIdx]
              .regions
              .where((r) => r.targetItemId != itemId)
              .toList();
          _locations[oldLocIdx] = _locations[oldLocIdx].copyWith(regions: updatedRegions);
        }
      }

      _items[idx] = _items[idx].copyWith(
        storageLocationId: newLocationId,
        polygonPoints: (oldLocationId != null && oldLocationId != newLocationId)
            ? []
            : _items[idx].polygonPoints,
        isTemporarilyRelocated: false,
        temporaryLocationNote: null,
        temporaryLocationId: null,
        status: AppConstants.itemStatusStored,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> temporarilyRelocateItem(String itemId, String note, {String? tempLocationId}) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx != -1) {
      _items[idx] = _items[idx].copyWith(
        isTemporarilyRelocated: true,
        temporaryLocationNote: note,
        temporaryLocationId: tempLocationId,
        status: AppConstants.itemStatusRelocated,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> returnItemToPermanentLocation(String itemId, {String? scannedBarcode, bool bypassScanVerification = false}) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx != -1) {
      final item = _items[idx];
      if (item.mustScanIn && !bypassScanVerification) {
        final expected = (item.barcode ?? '').trim();
        final actual = (scannedBarcode ?? '').trim();
        if (expected.isEmpty || actual != expected) {
          throw MustScanInException('Item "${item.name}" requires barcode scan to return.');
        }
      }
      _items[idx] = item.copyWith(
        isTemporarilyRelocated: false,
        temporaryLocationNote: null,
        temporaryLocationId: null,
        status: AppConstants.itemStatusStored,
        updatedAt: DateTime.now(),
      );
    }
  }

  // --- Lending Operations ---
  @override
  Future<List<LendingRecord>> getLendingRecords(String libraryId, {String? itemId}) async {
    return _lendingRecords.where((lr) {
      if (lr.libraryId != libraryId) return false;
      if (itemId != null && lr.itemId != itemId) return false;
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
      itemId: itemId,
      libraryId: libraryId,
      borrowerName: borrowerName,
      borrowerContact: borrowerContact,
      lentAt: DateTime.now(),
      expectedReturnAt: expectedReturnAt,
      notes: notes,
    );
    _lendingRecords.add(record);

    // Update item status
    final itemIdx = _items.indexWhere((i) => i.id == itemId);
    if (itemIdx != -1) {
      _items[itemIdx] = _items[itemIdx].copyWith(
        status: AppConstants.itemStatusLent,
        updatedAt: DateTime.now(),
      );
    }

    return record;
  }

  @override
  Future<void> returnLentItem(String lendingRecordId, {String? scannedBarcode, bool bypassScanVerification = false}) async {
    final idx = _lendingRecords.indexWhere((r) => r.id == lendingRecordId);
    if (idx != -1) {
      final updatedRecord = _lendingRecords[idx].copyWith(returnedAt: DateTime.now());
      final itemIdx = _items.indexWhere((i) => i.id == updatedRecord.itemId);
      if (itemIdx != -1) {
        final item = _items[itemIdx];
        if (item.mustScanIn && !bypassScanVerification) {
          final expected = (item.barcode ?? '').trim();
          final actual = (scannedBarcode ?? '').trim();
          if (expected.isEmpty || actual != expected) {
            throw MustScanInException('Item "${item.name}" requires barcode scan to return.');
          }
        }
        final wasTemp = item.isTemporarilyRelocated;
        _items[itemIdx] = item.copyWith(
          status: wasTemp ? AppConstants.itemStatusRelocated : AppConstants.itemStatusStored,
          updatedAt: DateTime.now(),
        );
      }
      _lendingRecords[idx] = updatedRecord;
    }
  }

  // --- Item List Operations ---

  @override
  Future<List<ItemList>> getItemLists(String libraryId) async {
    return _itemLists
        .where((l) => l.libraryId == libraryId)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<ItemList?> getItemList(String id) async {
    final idx = _itemLists.indexWhere((l) => l.id == id);
    if (idx == -1) return null;
    return _itemLists[idx];
  }

  @override
  Future<ItemList> saveItemList(ItemList list) async {
    final effective = list.id.isEmpty
        ? list.copyWith(
            id: _uuid.v4(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        : list.copyWith(updatedAt: DateTime.now());
    final idx = _itemLists.indexWhere((l) => l.id == effective.id);
    if (idx != -1) {
      _itemLists[idx] = effective;
    } else {
      _itemLists.add(effective);
    }
    return effective;
  }

  @override
  Future<void> deleteItemList(String id) async {
    _itemLists.removeWhere((l) => l.id == id);
  }

  @override
  Future<void> collectItemInList({
    required String listId,
    required String itemId,
    required bool isCollected,
  }) async {
    final list = await getItemList(listId);
    if (list == null) return;

    final existingEntryIdx = list.items.indexWhere((e) => e.itemId == itemId);
    final entry = existingEntryIdx != -1 ? list.items[existingEntryIdx] : null;

    String? newLendingRecordId = entry?.lendingRecordId;

    if (isCollected) {
      switch (list.destinationType) {
        case ListDestinationType.notRelocating:
          break;
        case ListDestinationType.storageLocation:
          await temporarilyRelocateItem(
            itemId,
            'Relocated via list: ${list.name}',
            tempLocationId: list.targetLocationId,
          );
          break;
        case ListDestinationType.freeText:
          await temporarilyRelocateItem(
            itemId,
            list.freeTextNote?.isNotEmpty == true
                ? list.freeTextNote!
                : 'Relocated via list: ${list.name}',
          );
          break;
        case ListDestinationType.lend:
          final rec = await lendItem(
            itemId: itemId,
            libraryId: list.libraryId,
            borrowerName: list.borrowerName?.isNotEmpty == true
                ? list.borrowerName!
                : 'List Borrower',
            borrowerContact: list.borrowerContact,
            expectedReturnAt: list.dueDate,
            notes: 'Lent via list: ${list.name}',
          );
          newLendingRecordId = rec.id;
          break;
      }
    } else {
      if (entry != null && entry.isCollected) {
        if (list.destinationType == ListDestinationType.lend && entry.lendingRecordId != null) {
          await returnLentItem(entry.lendingRecordId!, bypassScanVerification: true);
          newLendingRecordId = null;
        } else if (list.destinationType == ListDestinationType.storageLocation ||
            list.destinationType == ListDestinationType.freeText) {
          await returnItemToPermanentLocation(itemId, bypassScanVerification: true);
        }
      }
    }

    final updatedEntry = ItemListItemEntry(
      itemId: itemId,
      isCollected: isCollected,
      collectedAt: isCollected ? DateTime.now() : null,
      lendingRecordId: newLendingRecordId,
    );

    final updatedItems = List<ItemListItemEntry>.from(list.items);
    if (existingEntryIdx != -1) {
      updatedItems[existingEntryIdx] = updatedEntry;
    } else {
      updatedItems.add(updatedEntry);
    }

    await saveItemList(list.copyWith(items: updatedItems));
  }

  @override
  Future<void> addItemToList({
    required String listId,
    required String itemId,
    bool isCollected = false,
  }) async {
    final list = await getItemList(listId);
    if (list == null) return;

    if (!list.items.any((e) => e.itemId == itemId)) {
      final updatedItems = List<ItemListItemEntry>.from(list.items)
        ..add(ItemListItemEntry(
          itemId: itemId,
          isCollected: false,
        ));
      await saveItemList(list.copyWith(items: updatedItems));
    }

    if (isCollected) {
      await collectItemInList(listId: listId, itemId: itemId, isCollected: true);
    }
  }

  @override
  Future<void> returnSelectedItemsInList({
    required String listId,
    required List<String> itemIds,
    Map<String, String>? verifiedBarcodes,
  }) async {
    final list = await getItemList(listId);
    if (list == null) return;

    final updatedItems = List<ItemListItemEntry>.from(list.items);

    for (final itemId in itemIds) {
      final idx = updatedItems.indexWhere((e) => e.itemId == itemId);
      if (idx == -1) continue;
      final entry = updatedItems[idx];

      final barcode = verifiedBarcodes?[itemId];

      if (entry.lendingRecordId != null) {
        await returnLentItem(entry.lendingRecordId!, scannedBarcode: barcode);
      } else {
        await returnItemToPermanentLocation(itemId, scannedBarcode: barcode);
      }

      updatedItems[idx] = entry.copyWith(
        isCollected: false,
        collectedAt: null,
        lendingRecordId: null,
      );
    }

    await saveItemList(list.copyWith(items: updatedItems));
  }
}
