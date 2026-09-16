import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/cloud_sync_service.dart';
import '../core/services/local_database_service.dart';
import '../models/sync_model.dart';
import 'item_state.dart';
import 'item_type_state.dart';
import 'library_state.dart';
import 'storage_state.dart';

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  return CloudSyncService(databaseService: LocalDatabaseService.instance);
});

class AutoSyncNotifier extends Notifier<bool> {
  @override
  bool build() {
    return LocalDatabaseService.instance.autoSyncEnabled;
  }

  Future<void> toggle(bool enabled) async {
    state = enabled;
    await LocalDatabaseService.instance.setAutoSyncEnabled(enabled);
    if (enabled) {
      final syncService = ref.read(cloudSyncServiceProvider);
      if (syncService.client?.auth.currentUser != null) {
        ref.read(syncStatusProvider.notifier).syncNow();
      }
    }
  }
}

final autoSyncProvider = NotifierProvider<AutoSyncNotifier, bool>(AutoSyncNotifier.new);

class SyncStatusNotifier extends Notifier<SyncStatusInfo> {
  Timer? _autoSyncDebounce;

  @override
  SyncStatusInfo build() {
    final pending = LocalDatabaseService.instance.syncQueue.length;
    final lastSynced = LocalDatabaseService.instance.lastSyncedAt;

    // Connect mutation hook to auto-sync handler
    LocalDatabaseService.instance.onDataChanged = _handleDataChanged;

    ref.onDispose(() {
      _autoSyncDebounce?.cancel();
    });

    Future.microtask(() => checkStatus());
    return SyncStatusInfo(
      state: SyncState.notConfigured,
      pendingCount: pending,
      lastSyncedAt: lastSynced,
    );
  }

  void _handleDataChanged() {
    final isAutoSync = ref.read(autoSyncProvider);
    final syncService = ref.read(cloudSyncServiceProvider);
    final currentUser = syncService.client?.auth.currentUser;

    if (isAutoSync && currentUser != null) {
      _autoSyncDebounce?.cancel();
      _autoSyncDebounce = Timer(const Duration(milliseconds: 500), () {
        syncNow();
      });
    } else {
      checkStatus();
    }
  }

  void startRealtime() {
    final syncService = ref.read(cloudSyncServiceProvider);
    syncService.startRealtimeSubscription(
      onRemoteChange: () {
        checkStatus();
        ref.invalidate(librariesProvider);
        ref.invalidate(selectedLibraryProvider);
        ref.invalidate(allStorageLocationsProvider);
        ref.invalidate(storageLocationsProvider(null));
        ref.invalidate(libraryItemsProvider);
        ref.invalidate(itemTypesProvider);
      },
    );
  }

  void stopRealtime() {
    final syncService = ref.read(cloudSyncServiceProvider);
    syncService.stopRealtimeSubscription();
  }

  Future<void> checkStatus() async {
    final syncService = ref.read(cloudSyncServiceProvider);
    final configured = await syncService.isConfigured();
    final pending = LocalDatabaseService.instance.syncQueue.length;
    final lastSynced = LocalDatabaseService.instance.lastSyncedAt;

    if (!configured) {
      state = SyncStatusInfo(
        state: SyncState.notConfigured,
        pendingCount: pending,
        lastSyncedAt: lastSynced,
      );
    } else if (pending > 0) {
      state = SyncStatusInfo(
        state: SyncState.pendingSync,
        pendingCount: pending,
        lastSyncedAt: lastSynced,
      );
    } else {
      state = SyncStatusInfo(
        state: SyncState.synced,
        pendingCount: 0,
        lastSyncedAt: lastSynced,
      );
    }
  }

  Future<SyncStatusInfo> syncNow({bool force = false}) async {
    state = state.copyWith(state: SyncState.syncing);
    final syncService = ref.read(cloudSyncServiceProvider);
    final result = await syncService.syncNow(force: force);
    state = result;

    if (result.state == SyncState.synced || result.state == SyncState.pendingSync) {
      // Invalidate entity providers so UI refreshes with any pulled data
      ref.invalidate(librariesProvider);
      ref.invalidate(selectedLibraryProvider);
      ref.invalidate(allStorageLocationsProvider);
      ref.invalidate(storageLocationsProvider(null));
      ref.invalidate(libraryItemsProvider);
      ref.invalidate(itemTypesProvider);
    }
    return result;
  }

  Future<void> saveCredentials({
    required String url,
    required String anonKey,
    bool enableSync = true,
  }) async {
    final syncService = ref.read(cloudSyncServiceProvider);
    await syncService.saveCredentials(
      url: url,
      anonKey: anonKey,
      enableSync: enableSync,
    );
    await checkStatus();
    if (enableSync) {
      await syncNow();
    }
  }
}

final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncStatusInfo>(SyncStatusNotifier.new);
