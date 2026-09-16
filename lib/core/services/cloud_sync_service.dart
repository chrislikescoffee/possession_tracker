import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../../models/item_model.dart';
import '../../models/item_type_model.dart';
import '../../models/lending_record_model.dart';
import '../../models/library_model.dart';
import '../../models/storage_location_model.dart';
import '../../models/sync_model.dart';
import 'image_service.dart';
import 'local_database_service.dart';

class CloudSyncService {
  static const _keyUrl = 'supabase_url';
  static const _keyAnonKey = 'supabase_anon_key';
  static const _keySyncEnabled = 'cloud_sync_enabled';

  final LocalDatabaseService db;
  SupabaseClient? _client;

  CloudSyncService({LocalDatabaseService? databaseService})
      : db = databaseService ?? LocalDatabaseService.instance;

  SupabaseClient? get client {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isConfigured() async {
    if (SupabaseConfig.isConfigured) return true;
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keyUrl);
    final key = prefs.getString(_keyAnonKey);
    return url != null && url.isNotEmpty && key != null && key.isNotEmpty;
  }

  Future<Map<String, String>> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': SupabaseConfig.isConfigured ? SupabaseConfig.url : (prefs.getString(_keyUrl) ?? ''),
      'anonKey': SupabaseConfig.isConfigured ? SupabaseConfig.anonKey : (prefs.getString(_keyAnonKey) ?? ''),
      'syncEnabled': (prefs.getBool(_keySyncEnabled) ?? SupabaseConfig.isConfigured).toString(),
    };
  }

  Future<void> saveCredentials({
    required String url,
    required String anonKey,
    bool enableSync = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sanitizedUrl = SupabaseConfig.sanitizeUrl(url);
    await prefs.setString(_keyUrl, sanitizedUrl);
    await prefs.setString(_keyAnonKey, anonKey.trim());
    await prefs.setBool(_keySyncEnabled, enableSync);

    await initializeClient();
  }

  Future<bool> initializeClient() async {
    try {
      // If already initialized by Supabase plugin, adopt client immediately
      try {
        _client = Supabase.instance.client;
        return true;
      } catch (_) {
        // Not initialized yet, proceed
      }

      final prefs = await SharedPreferences.getInstance();

      // Clear any invalid or mock URL entered during earlier testing
      final storedUrl = prefs.getString(_keyUrl);
      if (storedUrl != null && !storedUrl.startsWith('http')) {
        await prefs.remove(_keyUrl);
        await prefs.remove(_keyAnonKey);
      }

      String? url;
      String? key;

      if (SupabaseConfig.isConfigured) {
        url = SupabaseConfig.url;
        key = SupabaseConfig.anonKey;
      } else {
        url = prefs.getString(_keyUrl);
        key = prefs.getString(_keyAnonKey);
      }

      if (url == null || url.isEmpty || key == null || key.isEmpty) {
        _client = null;
        return false;
      }

      url = SupabaseConfig.sanitizeUrl(url);

      await Supabase.initialize(
        url: url,
        anonKey: key.trim(),
        debug: kDebugMode,
      );
      try {
        _client = Supabase.instance.client;
      } catch (_) {}
      return _client != null;
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
      try {
        _client = Supabase.instance.client;
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<SyncStatusInfo> syncNow({bool force = false}) async {
    final configured = await isConfigured();
    if (!configured) {
      return SyncStatusInfo(
        state: SyncState.notConfigured,
        pendingCount: db.syncQueue.length,
        lastSyncedAt: db.lastSyncedAt,
      );
    }

    final hasClient = await initializeClient();
    if (!hasClient || _client == null) {
      return SyncStatusInfo(
        state: SyncState.error,
        errorMessage: 'Unable to connect to Supabase. Check network connectivity.',
        pendingCount: db.syncQueue.length,
        lastSyncedAt: db.lastSyncedAt,
      );
    }

    final currentUser = _client!.auth.currentUser;
    if (currentUser == null) {
      // Offline / Local-only mode until signed in
      return SyncStatusInfo(
        state: SyncState.notConfigured,
        errorMessage: 'Sign in to sync your inventory to the cloud.',
        pendingCount: db.syncQueue.length,
        lastSyncedAt: db.lastSyncedAt,
      );
    }

    try {
      final queue = List<SyncQueueItem>.from(db.syncQueue);
      final syncedQueueIds = <String>[];

      // --- Step 1: Push Local Changes ---
      for (final item in queue) {
        try {
          switch (item.entityType) {
            case SyncEntityType.library:
              // Do not push generic seed demo library if user never added anything to it
              if (item.entityId == 'lib-workshop-01' && !db.hasUserAddedContent('lib-workshop-01')) {
                syncedQueueIds.add(item.id);
                break;
              }
              if (item.operation == SyncOperation.upsert && item.payload != null) {
                final payload = Map<String, dynamic>.from(item.payload!);
                payload['owner_id'] = currentUser.id;
                await _client!.from('libraries').upsert(payload);
              } else if (item.operation == SyncOperation.delete) {
                try {
                  await _client!.from('lending_records').delete().eq('library_id', item.entityId);
                  await _client!.from('items').delete().eq('library_id', item.entityId);
                  await _client!.from('storage_locations').delete().eq('library_id', item.entityId);
                  await _client!.from('item_types').delete().eq('library_id', item.entityId);
                } catch (_) {}
                await _client!.from('libraries').delete().eq('id', item.entityId);
              }
              break;

            case SyncEntityType.storageLocation:
              if (item.operation == SyncOperation.upsert && item.payload != null) {
                final payload = Map<String, dynamic>.from(item.payload!);
                if (payload['image_url'] != null) {
                  payload['image_url'] = await _uploadBase64ImageIfPresent(
                    payload['image_url'] as String?,
                    currentUser.id,
                  );
                }
                await _client!.from('storage_locations').upsert(payload);
              } else if (item.operation == SyncOperation.delete) {
                await _client!.from('storage_locations').delete().eq('id', item.entityId);
              }
              break;

            case SyncEntityType.item:
              if (item.operation == SyncOperation.upsert && item.payload != null) {
                final payload = Map<String, dynamic>.from(item.payload!);
                if (payload['primary_image_url'] != null) {
                  payload['primary_image_url'] = await _uploadBase64ImageIfPresent(
                    payload['primary_image_url'] as String?,
                    currentUser.id,
                  );
                }
                await _client!.from('items').upsert(payload);
              } else if (item.operation == SyncOperation.delete) {
                await _client!.from('items').delete().eq('id', item.entityId);
              }
              break;

            case SyncEntityType.itemType:
              if (item.operation == SyncOperation.upsert && item.payload != null) {
                final payload = Map<String, dynamic>.from(item.payload!);
                payload.remove('color_hex');
                payload.remove('custom_field_definitions');
                payload.remove('icon_name');
                await _client!.from('item_types').upsert(payload);
              } else if (item.operation == SyncOperation.delete) {
                await _client!.from('item_types').delete().eq('id', item.entityId);
              }
              break;

            case SyncEntityType.lendingRecord:
              if (item.operation == SyncOperation.upsert && item.payload != null) {
                await _client!.from('lending_records').upsert(item.payload!);
              }
              break;
          }
          syncedQueueIds.add(item.id);
        } catch (itemError) {
          debugPrint('Sync item error (${item.entityType} ${item.entityId}): $itemError');
        }
      }

      if (syncedQueueIds.isNotEmpty) {
        await db.removeSyncQueueItems(syncedQueueIds);
      }

      // If force is requested, also ensure all local libraries, locations, items, and types are pushed
      if (force) {
        await pushAllLocalData();
      }

      // --- Step 2: Pull Remote Changes (scanned by RLS to current user) ---
      final isIncremental = !force && db.lastSyncedAt != null;
      final sinceIso = db.lastSyncedAt?.toIso8601String();

      try {
        final remoteLibs = await _client!.from('libraries').select();
        final remoteList = (remoteLibs as List)
            .map((json) => Library.fromJson(json as Map<String, dynamic>))
            .toList();

        final genuineRemoteLibs =
            remoteList.where((l) => l.id != 'lib-workshop-01').toList();

        // If the user has genuine cloud libraries, discount any untouched generic demo library
        if (genuineRemoteLibs.isNotEmpty) {
          if (db.libraries.any((l) => l.id == 'lib-workshop-01') &&
              !db.hasUserAddedContent('lib-workshop-01')) {
            await db.removeLibrary('lib-workshop-01', enqueueSync: false);

            // Clean up from cloud if it was previously pushed mistakenly
            if (remoteList.any((l) => l.id == 'lib-workshop-01')) {
              try {
                await _client!.from('lending_records').delete().eq('library_id', 'lib-workshop-01');
                await _client!.from('items').delete().eq('library_id', 'lib-workshop-01');
                await _client!.from('storage_locations').delete().eq('library_id', 'lib-workshop-01');
                await _client!.from('item_types').delete().eq('library_id', 'lib-workshop-01');
                await _client!.from('libraries').delete().eq('id', 'lib-workshop-01');
              } catch (_) {}
            }
          }

          // Also remove any empty local placeholder library that has no content and is not in remote
          final localLibsToCheck = List<Library>.from(db.libraries);
          for (final localLib in localLibsToCheck) {
            final existsInRemote = genuineRemoteLibs.any((r) => r.id == localLib.id);
            if (!existsInRemote && !db.hasUserAddedContent(localLib.id)) {
              await db.removeLibrary(localLib.id, enqueueSync: false);
            }
          }
        }

        for (final remoteLib in remoteList) {
          // Skip seed demo library if genuine libraries exist and seed was untouched
          if (remoteLib.id == 'lib-workshop-01' && genuineRemoteLibs.isNotEmpty) {
            continue;
          }
          // Skip if user intentionally deleted it locally without deleting online backup
          if (!db.locallyDeletedLibraryIds.contains(remoteLib.id)) {
            await db.upsertLibrary(remoteLib, enqueueSync: false);
          }
        }
      } catch (libPullError) {
        debugPrint('Pull libraries error: $libPullError');
        return SyncStatusInfo(
          state: SyncState.error,
          errorMessage: 'Error pulling libraries: $libPullError',
          pendingCount: db.syncQueue.length,
          lastSyncedAt: db.lastSyncedAt,
        );
      }

      for (final lib in db.libraries) {
        if (db.locallyDeletedLibraryIds.contains(lib.id)) continue;
        try {
          // Pull storage locations - always fetch all for intact hierarchy
          final locsResponse = await _client!
              .from('storage_locations')
              .select()
              .eq('library_id', lib.id);
          for (final json in (locsResponse as List)) {
            final remoteLoc = StorageLocation.fromJson(json as Map<String, dynamic>);
            await db.upsertLocation(remoteLoc, enqueueSync: false);
          }

          // Pull items - only incremental if we already have local items for this library
          final hasLocalItems = db.items.any((it) => it.libraryId == lib.id);
          var itemsQuery = _client!
              .from('items')
              .select()
              .eq('library_id', lib.id);
          if (isIncremental && sinceIso != null && hasLocalItems) {
            try {
              itemsQuery = itemsQuery.gte('updated_at', sinceIso);
            } catch (_) {}
          }
          final itemsResponse = await itemsQuery;
          for (final json in (itemsResponse as List)) {
            final remoteItem = Item.fromJson(json as Map<String, dynamic>);
            await db.upsertItem(remoteItem, enqueueSync: false);
          }

          // Pull item types
          final typesResponse = await _client!
              .from('item_types')
              .select()
              .eq('library_id', lib.id);
          for (final json in (typesResponse as List)) {
            final remoteType = ItemType.fromJson(json as Map<String, dynamic>);
            await db.upsertItemType(remoteType, enqueueSync: false);
          }
        } catch (pullError) {
          debugPrint('Pull error for library ${lib.name}: $pullError');
          return SyncStatusInfo(
            state: SyncState.error,
            errorMessage: 'Error pulling data for ${lib.name}: $pullError',
            pendingCount: db.syncQueue.length,
            lastSyncedAt: db.lastSyncedAt,
          );
        }
      }

      final now = DateTime.now();
      await db.setLastSyncedAt(now);

      return SyncStatusInfo(
        state: db.syncQueue.isEmpty ? SyncState.synced : SyncState.pendingSync,
        pendingCount: db.syncQueue.length,
        lastSyncedAt: now,
      );
    } catch (e) {
      debugPrint('Sync error: $e');
      return SyncStatusInfo(
        state: SyncState.error,
        errorMessage: e.toString(),
        pendingCount: db.syncQueue.length,
        lastSyncedAt: db.lastSyncedAt,
      );
    }
  }

  /// Uploads all local libraries, storage locations, items, and item types to Supabase
  Future<void> pushAllLocalData() async {
    final hasClient = await initializeClient();
    if (!hasClient || _client == null) return;
    final currentUser = _client!.auth.currentUser;
    if (currentUser == null) return;

    for (final lib in db.libraries) {
      if (db.locallyDeletedLibraryIds.contains(lib.id)) continue;
      // Do not push generic seed demo library if user never added anything to it
      if (lib.id == 'lib-workshop-01' && !db.hasUserAddedContent(lib.id)) {
        continue;
      }
      try {
        final libPayload = lib.toJson();
        libPayload['owner_id'] = currentUser.id;
        await _client!.from('libraries').upsert(libPayload);

        // Locations
        final locs = db.locations.where((l) => l.libraryId == lib.id);
        for (final loc in locs) {
          final locPayload = loc.toJson();
          if (locPayload['image_url'] != null) {
            locPayload['image_url'] = await _uploadBase64ImageIfPresent(
              locPayload['image_url'] as String?,
              currentUser.id,
            );
          }
          await _client!.from('storage_locations').upsert(locPayload);
        }

        // Items
        final items = db.items.where((i) => i.libraryId == lib.id);
        for (final item in items) {
          final itemPayload = item.toJson();
          if (itemPayload['primary_image_url'] != null) {
            itemPayload['primary_image_url'] = await _uploadBase64ImageIfPresent(
              itemPayload['primary_image_url'] as String?,
              currentUser.id,
            );
          }
          await _client!.from('items').upsert(itemPayload);
        }

        // Item Types
        final types = db.itemTypes.where((t) => t.libraryId == lib.id);
        for (final t in types) {
          final payload = t.toJson();
          payload.remove('color_hex');
          payload.remove('custom_field_definitions');
          payload.remove('icon_name');
          await _client!.from('item_types').upsert(payload);
        }
      } catch (e) {
        debugPrint('Error pushing all local data for ${lib.name}: $e');
      }
    }
  }

  Future<String?> _uploadBase64ImageIfPresent(String? rawUrl, String userId) async {
    if (rawUrl == null || !rawUrl.startsWith('data:image/')) return rawUrl;
    try {
      final commaIdx = rawUrl.indexOf(',');
      final base64Str = commaIdx != -1 ? rawUrl.substring(commaIdx + 1) : rawUrl;
      final bytes = base64Decode(base64Str);
      final uploadedUrl = await ImageService.uploadRawBytesToStorage(bytes: bytes, userId: userId);
      return uploadedUrl ?? rawUrl;
    } catch (e) {
      debugPrint('Sync base64 upload error: $e');
      return rawUrl;
    }
  }

  Future<void> deleteLibraryFromCloud(String libraryId) async {
    await initializeClient();
    final c = client;
    if (c == null) return;
    try {
      try {
        await c.from('lending_records').delete().eq('library_id', libraryId);
      } catch (e) {
        debugPrint('Error deleting remote lending records: $e');
      }
      try {
        await c.from('items').delete().eq('library_id', libraryId);
      } catch (e) {
        debugPrint('Error deleting remote items: $e');
      }
      try {
        await c.from('storage_locations').delete().eq('library_id', libraryId);
      } catch (e) {
        debugPrint('Error deleting remote storage locations: $e');
      }
      try {
        await c.from('item_types').delete().eq('library_id', libraryId);
      } catch (e) {
        debugPrint('Error deleting remote item types: $e');
      }
      try {
        await c.from('libraries').delete().eq('id', libraryId);
      } catch (e) {
        debugPrint('Error deleting remote library: $e');
      }

      // Purge any related sync queue items in local db
      final queueToDelete = db.syncQueue
          .where((q) =>
              q.entityId == libraryId ||
              (q.payload != null && q.payload!['library_id'] == libraryId))
          .map((q) => q.id)
          .toList();
      if (queueToDelete.isNotEmpty) {
        await db.removeSyncQueueItems(queueToDelete);
      }
    } catch (e) {
      debugPrint('Error during cloud library delete: $e');
    }
  }

  RealtimeChannel? _realtimeChannel;

  void startRealtimeSubscription({required VoidCallback onRemoteChange}) {
    final c = client;
    if (c == null) return;
    stopRealtimeSubscription();

    try {
      _realtimeChannel = c.channel('public:inventory_changes');
      _realtimeChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            callback: (payload) async {
              try {
                final table = payload.table;
                final event = payload.eventType;
                final newRecord = payload.newRecord;
                final oldRecord = payload.oldRecord;

                if (event == PostgresChangeEvent.insert || event == PostgresChangeEvent.update) {
                  if (newRecord.isNotEmpty) {
                    switch (table) {
                      case 'libraries':
                        final lib = Library.fromJson(newRecord);
                        if (!db.locallyDeletedLibraryIds.contains(lib.id)) {
                          await db.upsertLibrary(lib, enqueueSync: false);
                        }
                        break;
                      case 'storage_locations':
                        final loc = StorageLocation.fromJson(newRecord);
                        if (!db.locallyDeletedLibraryIds.contains(loc.libraryId)) {
                          await db.upsertLocation(loc, enqueueSync: false);
                        }
                        break;
                      case 'items':
                        final item = Item.fromJson(newRecord);
                        if (!db.locallyDeletedLibraryIds.contains(item.libraryId)) {
                          await db.upsertItem(item, enqueueSync: false);
                        }
                        break;
                      case 'item_types':
                        final itemType = ItemType.fromJson(newRecord);
                        if (!db.locallyDeletedLibraryIds.contains(itemType.libraryId)) {
                          await db.upsertItemType(itemType, enqueueSync: false);
                        }
                        break;
                      case 'lending_records':
                        final lr = LendingRecord.fromJson(newRecord);
                        if (!db.locallyDeletedLibraryIds.contains(lr.libraryId)) {
                          await db.upsertLendingRecord(lr, enqueueSync: false);
                        }
                        break;
                    }
                  }
                } else if (event == PostgresChangeEvent.delete) {
                  final recordId = oldRecord['id'] as String?;
                  if (recordId != null) {
                    switch (table) {
                      case 'libraries':
                        await db.removeLibrary(recordId, enqueueSync: false);
                        break;
                      case 'storage_locations':
                        await db.removeLocation(recordId, enqueueSync: false);
                        break;
                      case 'items':
                        await db.removeItem(recordId, enqueueSync: false);
                        break;
                      case 'item_types':
                        await db.removeItemType(recordId, enqueueSync: false);
                        break;
                    }
                  }
                }
                onRemoteChange();
              } catch (e) {
                debugPrint('Realtime payload handling error: $e');
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Failed to start Realtime subscription: $e');
    }
  }

  void stopRealtimeSubscription() {
    if (_realtimeChannel != null) {
      try {
        _realtimeChannel!.unsubscribe();
      } catch (_) {}
      _realtimeChannel = null;
    }
  }
}
