import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/field_definition_model.dart';
import '../../models/item_model.dart';
import '../../models/item_type_model.dart';
import '../../models/lending_record_model.dart';
import '../../models/library_model.dart';
import '../../models/polygon_region.dart';
import '../../models/storage_location_model.dart';
import '../../models/sync_model.dart';

class LocalDatabaseService {
  static LocalDatabaseService? _instance;
  static LocalDatabaseService get instance =>
      _instance ??= LocalDatabaseService._internal();

  LocalDatabaseService._internal() {
    _seedInitialData();
  }

  factory LocalDatabaseService() => instance;

  String? _filePath;
  bool _isInitialized = false;

  final List<Library> _libraries = [];
  final List<StorageLocation> _locations = [];
  final List<Item> _items = [];
  final List<ItemType> _itemTypes = [];
  final List<LendingRecord> _lendingRecords = [];
  final List<SyncQueueItem> _syncQueue = [];
  final Set<String> _locallyDeletedLibraryIds = {};
  DateTime? _lastSyncedAt;
  bool _autoSyncEnabled = true;

  VoidCallback? onDataChanged;

  List<Library> get libraries => List.unmodifiable(_libraries);
  List<StorageLocation> get locations => List.unmodifiable(_locations);
  List<Item> get items => List.unmodifiable(_items);
  List<ItemType> get itemTypes => List.unmodifiable(_itemTypes);
  List<LendingRecord> get lendingRecords => List.unmodifiable(_lendingRecords);
  List<SyncQueueItem> get syncQueue => List.unmodifiable(_syncQueue);
  Set<String> get locallyDeletedLibraryIds => Set.unmodifiable(_locallyDeletedLibraryIds);
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get autoSyncEnabled => _autoSyncEnabled;
  bool get isInitialized => _isInitialized;

  Future<void> setAutoSyncEnabled(bool enabled) async {
    _autoSyncEnabled = enabled;
    await saveToDisk();
  }

  void clearLocallyDeletedLibraryId(String id) {
    _locallyDeletedLibraryIds.remove(id);
  }

  Future<void> init({String? customPath}) async {
    if (_isInitialized && customPath == null) return;

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final content = prefs.getString('possession_tracker_web_db');
        if (content != null && content.trim().isNotEmpty) {
          final data = jsonDecode(content) as Map<String, dynamic>;
          _loadFromMap(data);
          _isInitialized = true;
          return;
        }
      } catch (e) {
        debugPrint('Error reading web local database: $e');
      }
      _seedInitialData();
      await saveToDisk();
      _isInitialized = true;
      return;
    }

    if (customPath != null) {
      _filePath = customPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _filePath = '${dir.path}/possession_tracker_db.json';
    }

    final path = _filePath!;
    final file = File(path);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final data = jsonDecode(content) as Map<String, dynamic>;
          _loadFromMap(data);
          _isInitialized = true;
          return;
        }
      } catch (e) {
        debugPrint('Error reading local database: $e. Falling back to fresh seed.');
      }
    }

    // First time launch or fresh install -> seed initial demo data and persist
    _seedInitialData();
    await saveToDisk();
    _isInitialized = true;
  }

  void _loadFromMap(Map<String, dynamic> data) {
    _libraries.clear();
    _locations.clear();
    _items.clear();
    _itemTypes.clear();
    _lendingRecords.clear();
    _syncQueue.clear();

    bool hadDuplicates = false;

    if (data['libraries'] is List) {
      final seen = <String>{};
      for (final json in data['libraries']) {
        final lib = Library.fromJson(json as Map<String, dynamic>);
        if (seen.add(lib.id)) {
          _libraries.add(lib);
        } else {
          hadDuplicates = true;
        }
      }
    }

    if (data['locations'] is List) {
      final seen = <String>{};
      for (final json in data['locations']) {
        final loc = StorageLocation.fromJson(json as Map<String, dynamic>);
        if (seen.add(loc.id)) {
          _locations.add(loc);
        } else {
          hadDuplicates = true;
        }
      }
    }

    if (data['items'] is List) {
      final seen = <String>{};
      for (final json in data['items']) {
        final item = Item.fromJson(json as Map<String, dynamic>);
        if (seen.add(item.id)) {
          _items.add(item);
        } else {
          hadDuplicates = true;
        }
      }
    }

    if (data['item_types'] is List) {
      final seen = <String>{};
      for (final json in data['item_types']) {
        final it = ItemType.fromJson(json as Map<String, dynamic>);
        if (seen.add(it.id)) {
          _itemTypes.add(it);
        } else {
          hadDuplicates = true;
        }
      }
    }

    if (data['lending_records'] is List) {
      final seen = <String>{};
      for (final json in data['lending_records']) {
        final lr = LendingRecord.fromJson(json as Map<String, dynamic>);
        if (seen.add(lr.id)) {
          _lendingRecords.add(lr);
        } else {
          hadDuplicates = true;
        }
      }
    }

    if (data['sync_queue'] is List) {
      final seen = <String>{};
      for (final json in data['sync_queue']) {
        final q = SyncQueueItem.fromJson(json as Map<String, dynamic>);
        if (seen.add(q.id)) {
          _syncQueue.add(q);
        } else {
          hadDuplicates = true;
        }
      }
    }

    if (data['auto_sync_enabled'] != null) {
      _autoSyncEnabled = data['auto_sync_enabled'] as bool;
    }

    if (data['locally_deleted_library_ids'] is List) {
      _locallyDeletedLibraryIds.clear();
      for (final id in data['locally_deleted_library_ids']) {
        if (id is String) _locallyDeletedLibraryIds.add(id);
      }
    }

    if (data['last_synced_at'] != null) {
      _lastSyncedAt = DateTime.tryParse(data['last_synced_at'] as String);
    }

    // Automatically clean up persisted storage if duplicates were found
    if (hadDuplicates) {
      saveToDisk();
    }
  }

  Map<String, dynamic> _toMap() {
    return {
      'version': 1,
      'last_synced_at': _lastSyncedAt?.toIso8601String(),
      'auto_sync_enabled': _autoSyncEnabled,
      'locally_deleted_library_ids': _locallyDeletedLibraryIds.toList(),
      'libraries': _libraries.map((e) => e.toJson()).toList(),
      'locations': _locations.map((e) => e.toJson()).toList(),
      'items': _items.map((e) => e.toJson()).toList(),
      'item_types': _itemTypes.map((e) => e.toJson()).toList(),
      'lending_records': _lendingRecords.map((e) => e.toJson()).toList(),
      'sync_queue': _syncQueue.map((e) => e.toJson()).toList(),
    };
  }

  Future<void> saveToDisk() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = jsonEncode(_toMap());
        await prefs.setString('possession_tracker_web_db', jsonString);
      } catch (e) {
        debugPrint('Error saving web local database: $e');
      }
      return;
    }

    final path = _filePath;
    if (path == null) return;
    try {
      final jsonString = jsonEncode(_toMap());
      final tmpFile = File('$path.tmp');
      await tmpFile.writeAsString(jsonString, flush: true);
      await tmpFile.rename(path);
    } catch (e) {
      debugPrint('Error saving local database: $e');
    }
  }

  // --- Mutation Helpers ---

  Future<void> upsertLibrary(Library library, {bool enqueueSync = true}) async {
    final idx = _libraries.indexWhere((l) => l.id == library.id);
    if (idx != -1) {
      _libraries[idx] = library;
    } else {
      _libraries.add(library);
    }
    _locallyDeletedLibraryIds.remove(library.id);
    if (enqueueSync) {
      enqueue(SyncEntityType.library, library.id, SyncOperation.upsert, library.toJson());
    }
    await saveToDisk();
    if (enqueueSync) onDataChanged?.call();
  }

  Future<void> removeLibrary(String id, {bool enqueueSync = true}) async {
    _libraries.removeWhere((l) => l.id == id);
    _locations.removeWhere((loc) => loc.libraryId == id);
    _items.removeWhere((item) => item.libraryId == id);
    _itemTypes.removeWhere((it) => it.libraryId == id);
    _lendingRecords.removeWhere((lr) => lr.libraryId == id);

    // Clean up sync queue items related to this library
    _syncQueue.removeWhere((q) {
      if (q.entityId == id) return true;
      if (q.payload != null && q.payload!['library_id'] == id) return true;
      return false;
    });

    if (enqueueSync) {
      _locallyDeletedLibraryIds.remove(id);
      enqueue(SyncEntityType.library, id, SyncOperation.delete, null);
    } else {
      _locallyDeletedLibraryIds.add(id);
    }
    await saveToDisk();
    if (enqueueSync) onDataChanged?.call();
  }

  Future<void> upsertLocation(StorageLocation location, {bool enqueueSync = true}) async {
    final idx = _locations.indexWhere((l) => l.id == location.id);
    if (idx != -1) {
      _locations[idx] = location;
    } else {
      _locations.add(location);
    }
    if (enqueueSync) {
      enqueue(SyncEntityType.storageLocation, location.id, SyncOperation.upsert, location.toJson());
    }
    await saveToDisk();
    if (enqueueSync) onDataChanged?.call();
  }

  Future<void> removeLocation(String id, {bool enqueueSync = true}) async {
    _locations.removeWhere((l) => l.id == id);
    if (enqueueSync) {
      enqueue(SyncEntityType.storageLocation, id, SyncOperation.delete, null);
    }
    await saveToDisk();
    if (enqueueSync) onDataChanged?.call();
  }

  Future<void> upsertItem(Item item, {bool enqueueSync = true}) async {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx != -1) {
      _items[idx] = item;
    } else {
      _items.add(item);
    }
    if (enqueueSync) {
      enqueue(SyncEntityType.item, item.id, SyncOperation.upsert, item.toJson());
    }
    await saveToDisk();
    if (enqueueSync) onDataChanged?.call();
  }

  Future<void> removeItem(String id, {bool enqueueSync = true}) async {
    _items.removeWhere((i) => i.id == id);
    if (enqueueSync) {
      enqueue(SyncEntityType.item, id, SyncOperation.delete, null);
    }
    await saveToDisk();
    if (enqueueSync) onDataChanged?.call();
  }

  Future<void> upsertItemType(ItemType itemType, {bool enqueueSync = true}) async {
    final idx = _itemTypes.indexWhere((t) => t.id == itemType.id);
    if (idx != -1) {
      _itemTypes[idx] = itemType;
    } else {
      _itemTypes.add(itemType);
    }
    if (enqueueSync) {
      enqueue(SyncEntityType.itemType, itemType.id, SyncOperation.upsert, itemType.toJson());
    }
    await saveToDisk();
    if (enqueueSync) onDataChanged?.call();
  }

  Future<void> removeItemType(String id, {bool enqueueSync = true}) async {
    _itemTypes.removeWhere((t) => t.id == id);
    if (enqueueSync) {
      enqueue(SyncEntityType.itemType, id, SyncOperation.delete, null);
    }
    await saveToDisk();
    if (enqueueSync) onDataChanged?.call();
  }

  Future<void> upsertLendingRecord(LendingRecord record, {bool enqueueSync = true}) async {
    final idx = _lendingRecords.indexWhere((r) => r.id == record.id);
    if (idx != -1) {
      _lendingRecords[idx] = record;
    } else {
      _lendingRecords.add(record);
    }
    if (enqueueSync) {
      enqueue(SyncEntityType.lendingRecord, record.id, SyncOperation.upsert, record.toJson());
    }
    await saveToDisk();
    if (enqueueSync) onDataChanged?.call();
  }

  // --- Sync Queue Helpers ---

  void enqueue(SyncEntityType entityType, String entityId, SyncOperation operation, Map<String, dynamic>? payload) {
    // Remove previous pending actions for the same entity if superceded
    _syncQueue.removeWhere((q) => q.entityType == entityType && q.entityId == entityId);
    _syncQueue.add(
      SyncQueueItem(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> removeSyncQueueItems(List<String> ids) async {
    _syncQueue.removeWhere((q) => ids.contains(q.id));
    await saveToDisk();
  }

  Future<void> setLastSyncedAt(DateTime timestamp) async {
    _lastSyncedAt = timestamp;
    await saveToDisk();
  }

  // --- Seed Data on First Launch ---

  void _seedInitialData() {
    _libraries.clear();
    _locations.clear();
    _items.clear();
    _itemTypes.clear();
    _lendingRecords.clear();
    _syncQueue.clear();

    final now = DateTime.now();
    const defaultLibId = 'lib-workshop-01';

    _libraries.add(
      Library(
        id: defaultLibId,
        name: 'Home & Workshop Library',
        ownerId: 'user-chris-01',
        itemLimit: 50,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
    );

    const workshopId = 'loc-workshop';
    const benchId = 'loc-bench';
    const drawerId = 'loc-drawer';
    const socketBoxId = 'loc-socketbox';
    const livingRoomId = 'loc-livingroom';

    _locations.addAll([
      StorageLocation(
        id: workshopId,
        libraryId: defaultLibId,
        name: 'Workshop & Garage',
        description: 'Main workshop bay on ground floor',
        imageUrl:
            'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=1200&q=80',
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
        description:
            'Solid oak bench with mounted vise and multi-drawer chest',
        imageUrl:
            'https://images.unsplash.com/photo-1530124566582-a618bc2615dc?auto=format&fit=crop&w=1200&q=80',
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
        imageUrl:
            'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=1200&q=80',
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
        description:
            'Black molded steel case with 1/2-inch and 3/8-inch metric sockets',
        imageUrl:
            'https://images.unsplash.com/photo-1581244277943-fe4a9c777189?auto=format&fit=crop&w=1200&q=80',
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
        imageUrl:
            'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=1200&q=80',
        regions: [],
        sortOrder: 5,
        createdAt: now.subtract(const Duration(days: 20)),
      ),
    ]);

    _items.addAll([
      Item(
        id: 'item-10mm-socket',
        libraryId: defaultLibId,
        storageLocationId: socketBoxId,
        name: '10mm Deep Metric Socket',
        description: 'Chrome vanadium 6-point 1/2-inch drive socket',
        itemTypeId: 'type-tool',
        itemTypeName: 'Power Tool',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1581244277943-fe4a9c777189?auto=format&fit=crop&w=600&q=80',
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
        status: 'stored',
        createdAt: now.subtract(const Duration(days: 24)),
        updatedAt: now.subtract(const Duration(days: 24)),
      ),
      Item(
        id: 'item-ratchet',
        libraryId: defaultLibId,
        storageLocationId: socketBoxId,
        name: '1/2-inch Sealed Head Ratchet',
        description:
            '72-tooth teardrop ratchet handle with quick-release button',
        itemTypeId: 'type-tool',
        itemTypeName: 'Power Tool',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1572981779307-38b8cabb2407?auto=format&fit=crop&w=600&q=80',
        customFields: {
          'Brand': 'DeWalt',
          'Gear Teeth': 72,
          'Length': '10.5 inches',
        },
        status: 'stored',
        createdAt: now.subtract(const Duration(days: 24)),
        updatedAt: now.subtract(const Duration(days: 24)),
      ),
      Item(
        id: 'item-impact-driver',
        libraryId: defaultLibId,
        storageLocationId: benchId,
        name: '20V MAX Brushless Cordless Impact Driver',
        description: 'Primary cordless driver with belt hook',
        itemTypeId: 'type-tool',
        itemTypeName: 'Power Tool',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=600&q=80',
        customFields: {
          'Brand': 'DeWalt',
          'Voltage': '20V',
          'Motor': 'Brushless',
          'Serial Number': 'DW-2024-9988',
        },
        isTemporarilyRelocated: true,
        temporaryLocationNote: 'In car trunk - left after job site visit',
        status: 'relocated',
        createdAt: now.subtract(const Duration(days: 22)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      Item(
        id: 'item-laser-level',
        libraryId: defaultLibId,
        storageLocationId: benchId,
        name: 'Self-Leveling 360-Degree Cross Line Laser',
        description:
            'Green beam self-leveling laser with magnetic bracket',
        itemTypeId: 'type-tool',
        itemTypeName: 'Power Tool',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=600&q=80',
        customFields: {
          'Brand': 'Bosch',
          'Beam Color': 'Green',
          'Accuracy': '±1/8 in at 30 ft',
        },
        status: 'lent',
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      Item(
        id: 'item-knipex-pliers',
        libraryId: defaultLibId,
        storageLocationId: drawerId,
        name: 'Knipex Cobra Water Pump Pliers 250mm',
        description:
            'Quick push-button adjustment with hardened teeth',
        itemTypeId: 'type-tool',
        itemTypeName: 'Power Tool',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1530124566582-a618bc2615dc?auto=format&fit=crop&w=600&q=80',
        customFields: {
          'Brand': 'Knipex',
          'Length': '250mm',
          'Made In': 'Germany',
        },
        status: 'stored',
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 15)),
      ),
    ]);

    _lendingRecords.add(
      LendingRecord(
        id: 'lend-laser-01',
        libraryId: defaultLibId,
        itemId: 'item-laser-level',
        borrowerName: 'Sarah Miller',
        borrowerContact: '+1 (555) 234-5678',
        lentAt: now.subtract(const Duration(days: 5)),
        expectedReturnAt: now.add(const Duration(days: 2)),
        notes: 'Borrowed for kitchen cabinet installation',
      ),
    );

    _itemTypes.addAll([
      ItemType(
        id: 'type-tool',
        libraryId: defaultLibId,
        name: 'Power Tool',
        description: 'Cordless, pneumatic, or corded tools and accessories',
        icon: 'build',
        fields: [
          FieldDefinition(
            id: 'field-brand',
            name: 'Brand',
            type: ItemFieldType.text,
            defaultValue: 'DeWalt',
          ),
          FieldDefinition(
            id: 'field-voltage',
            name: 'Voltage',
            type: ItemFieldType.number,
            unit: 'V',
          ),
          FieldDefinition(
            id: 'field-dimensions',
            name: 'Dimensions',
            type: ItemFieldType.dimension,
            unit: 'mm',
          ),
          FieldDefinition(
            id: 'field-weight',
            name: 'Weight',
            type: ItemFieldType.weight,
            unit: 'kg',
          ),
          FieldDefinition(
            id: 'field-price',
            name: 'Purchase Price',
            type: ItemFieldType.currency,
            unit: 'AUD',
          ),
        ],
        createdAt: now.subtract(const Duration(days: 28)),
      ),
      ItemType(
        id: 'type-pottery',
        libraryId: defaultLibId,
        name: 'Pottery Item',
        description: 'Ceramic bowls, mugs, vases, and sculptures',
        icon: 'palette',
        fields: [
          FieldDefinition(
            id: 'field-clay',
            name: 'Clay Body',
            type: ItemFieldType.text,
            defaultValue: 'Speckled Stoneware',
          ),
          FieldDefinition(
            id: 'field-glaze',
            name: 'Glaze Technique',
            type: ItemFieldType.text,
          ),
          FieldDefinition(
            id: 'field-firing',
            name: 'Cone / Firing',
            type: ItemFieldType.text,
            defaultValue: 'Cone 6 Oxidation',
          ),
        ],
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      ItemType(
        id: 'type-camping',
        libraryId: defaultLibId,
        name: 'Camping Gear',
        description: 'Tents, sleeping bags, stoves, and outdoor equipment',
        icon: 'terrain',
        fields: [
          FieldDefinition(
            id: 'field-capacity',
            name: 'Person Capacity',
            type: ItemFieldType.number,
          ),
          FieldDefinition(
            id: 'field-weight-camp',
            name: 'Pack Weight',
            type: ItemFieldType.weight,
            unit: 'kg',
          ),
          FieldDefinition(
            id: 'field-season',
            name: 'Season Rating',
            type: ItemFieldType.text,
            defaultValue: '3-Season',
          ),
        ],
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      ItemType.genericItem(defaultLibId),
    ]);
  }
}
