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
                await _client!.from('item_types').upsert(item.payload!);
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

      // --- Step 2: Pull Remote Changes (scanned by RLS to current user) ---
      final isIncremental = !force && db.lastSyncedAt != null;
      final sinceIso = db.lastSyncedAt?.toIso8601String();

      try {
        var libQuery = _client!.from('libraries').select();
        if (isIncremental && sinceIso != null) {
          libQuery = libQuery.gte('created_at', sinceIso);
        }
        final remoteLibs = await libQuery;
        for (final json in (remoteLibs as List)) {
          final remoteLib = Library.fromJson(json as Map<String, dynamic>);
          // Skip if user intentionally deleted it locally without deleting online backup
          if (!db.locallyDeletedLibraryIds.contains(remoteLib.id)) {
            await db.upsertLibrary(remoteLib, enqueueSync: false);
          }
        }
      } catch (libPullError) {
        debugPrint('Pull libraries error: $libPullError');
      }

      for (final lib in db.libraries) {
        if (db.locallyDeletedLibraryIds.contains(lib.id)) continue;
        try {
          // Pull storage locations
          var locsQuery = _client!
              .from('storage_locations')
              .select()
              .eq('library_id', lib.id);
          if (isIncremental && sinceIso != null) {
            locsQuery = locsQuery.gte('created_at', sinceIso);
          }
          final locsResponse = await locsQuery;
          for (final json in (locsResponse as List)) {
            final remoteLoc = StorageLocation.fromJson(json as Map<String, dynamic>);
            await db.upsertLocation(remoteLoc, enqueueSync: false);
          }

          // Pull items
          var itemsQuery = _client!
              .from('items')
              .select()
              .eq('library_id', lib.id);
          if (isIncremental && sinceIso != null) {
            try {
              itemsQuery = itemsQuery.gte('updated_at', sinceIso);
            } catch (_) {
              itemsQuery = itemsQuery.gte('created_at', sinceIso);
            }
          }
          final itemsResponse = await itemsQuery;
          for (final json in (itemsResponse as List)) {
            final remoteItem = Item.fromJson(json as Map<String, dynamic>);
            await db.upsertItem(remoteItem, enqueueSync: false);
          }

          // Pull item types
          var typesQuery = _client!
              .from('item_types')
              .select()
              .eq('library_id', lib.id);
          if (isIncremental && sinceIso != null) {
            typesQuery = typesQuery.gte('created_at', sinceIso);
          }
          final typesResponse = await typesQuery;
          for (final json in (typesResponse as List)) {
            final remoteType = ItemType.fromJson(json as Map<String, dynamic>);
            await db.upsertItemType(remoteType, enqueueSync: false);
          }
        } catch (pullError) {
          debugPrint('Pull error for library ${lib.name}: $pullError');
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
