import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/barcode_scanner_dialog.dart';
import '../../models/item_model.dart';
import '../../models/storage_location_model.dart';
import '../../models/sync_model.dart';
import '../../state/auth_state.dart';
import '../../state/item_state.dart';
import '../../state/library_state.dart';
import '../../state/repository_provider.dart';
import '../../state/storage_state.dart';
import '../../state/sync_state.dart';
import '../items/add_edit_item_dialog.dart';
import '../storage/add_edit_location_dialog.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/storage')) return 0;
    if (location.startsWith('/items')) return 1;
    if (location.startsWith('/lists')) return 2;
    if (location.startsWith('/locator')) return 3;
    if (location.startsWith('/lending')) return 4;
    if (location.startsWith('/settings')) return 5;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/storage');
        break;
      case 1:
        context.go('/items');
        break;
      case 2:
        context.go('/lists');
        break;
      case 3:
        context.go('/locator');
        break;
      case 4:
        context.go('/lending');
        break;
      case 5:
        context.go('/settings');
        break;
    }
  }

  Future<void> _handleGlobalScan(BuildContext context, WidgetRef ref) async {
    final scanned = await BarcodeScannerDialog.show(context, title: 'Scan Barcode or QR Code');
    if (scanned == null || scanned.trim().isEmpty) return;

    final query = scanned.trim();
    final allLocations = ref.read(allStorageLocationsProvider).value ?? [];
    final allItems = ref.read(libraryItemsProvider).value ?? [];

    // 1. Check if matching storage location
    final matchingLoc = allLocations.where((l) => l.barcode?.trim().toLowerCase() == query.toLowerCase()).firstOrNull;
    if (matchingLoc != null) {
      if (context.mounted) {
        context.go('/storage/${matchingLoc.id}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found Storage Location: ${matchingLoc.name}'),
            backgroundColor: const Color(0xFF38BDF8),
          ),
        );
      }
      return;
    }

    // 2. Check if matching item
    final matchingItem = allItems.where((i) => i.barcode?.trim().toLowerCase() == query.toLowerCase()).firstOrNull;
    if (matchingItem != null) {
      if (context.mounted) {
        context.go('/items/${matchingItem.id}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found Item: ${matchingItem.name}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
      return;
    }

    // 3. Not found - offer to create a new storage area or item with this scanned barcode
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.search_off_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('No Match Found'),
          ],
        ),
        content: Text(
          'No storage container or item was found with code:\n\n"$query"\n\nWould you like to assign this code to a new record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_outlined, size: 16),
            label: const Text('New Storage Area'),
            onPressed: () {
              Navigator.of(ctx).pop();
              final selectedLib = ref.read(selectedLibraryProvider).value;
              if (selectedLib != null) {
                showDialog(
                  context: context,
                  builder: (dCtx) => AddEditLocationDialog(
                    libraryId: selectedLib.id,
                    initialBarcode: query,
                    initialBarcodeType: 'scanned',
                  ),
                ).then((res) async {
                  final loc = res is LocationDialogResult ? res.location : (res is StorageLocation ? res : null);
                  if (loc != null) {
                    await ref.read(repositoryProvider).saveStorageLocation(loc);
                    ref.invalidate(allStorageLocationsProvider);
                    ref.invalidate(storageLocationsProvider(null));
                    if (context.mounted) context.go('/storage/${loc.id}');
                  }
                });
              }
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.inventory_2_outlined, size: 16),
            label: const Text('New Item'),
            onPressed: () {
              Navigator.of(ctx).pop();
              final selectedLib = ref.read(selectedLibraryProvider).value;
              if (selectedLib != null) {
                showDialog(
                  context: context,
                  builder: (dCtx) => AddEditItemDialog(
                    libraryId: selectedLib.id,
                    initialBarcode: query,
                    initialBarcodeType: 'scanned',
                  ),
                ).then((res) async {
                  final item = res is ItemDialogResult ? res.item : (res is Item ? res : null);
                  if (item != null) {
                    await ref.read(repositoryProvider).saveItem(item);
                    ref.invalidate(libraryItemsProvider);
                    if (context.mounted) context.go('/items/${item.id}');
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final quotaAsync = ref.watch(libraryQuotaProvider);
    // Keep auth state and cloud sync active continuously across all screens
    ref.watch(authProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final isWide = MediaQuery.of(context).size.width >= 800;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      floatingActionButtonLocation: isWide ? null : FloatingActionButtonLocation.startFloat,
      floatingActionButton: isWide
          ? null
          : FloatingActionButton.small(
              heroTag: 'global_scanner_fab',
              backgroundColor: colorScheme.secondary,
              foregroundColor: Colors.white,
              tooltip: 'Scan Barcode / QR Code',
              onPressed: () => _handleGlobalScan(context, ref),
              child: const Icon(Icons.qr_code_scanner_rounded),
            ),
      body: Row(
        children: [
          // Responsive Navigation Rail for Web / Desktop
          if (isWide)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (idx) => _onItemTapped(idx, context),
              labelType: NavigationRailLabelType.all,
              backgroundColor: theme.scaffoldBackgroundColor,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.layers, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Possession\nTracker',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        backgroundColor: colorScheme.secondary.withValues(alpha: 0.15),
                        foregroundColor: colorScheme.secondary,
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                      label: const Text('Scan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _handleGlobalScan(context, ref),
                    ),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Cloud sync indicator
                        _buildSyncIndicator(context, ref, syncStatus),
                        const SizedBox(height: 8),
                        quotaAsync.when(
                          data: (quota) => Tooltip(
                            message: '${quota.current}/${quota.max} items used',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: quota.current >= quota.max
                                    ? Colors.red.withValues(alpha: 0.2)
                                    : (theme.cardTheme.color ?? colorScheme.surface),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: quota.current >= quota.max
                                      ? Colors.red
                                      : colorScheme.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '${quota.current}/${quota.max}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: quota.current >= quota.max
                                      ? Colors.redAccent
                                      : colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: Text('Storage'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Items'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.checklist_rounded),
                  selectedIcon: Icon(Icons.checklist_rounded),
                  label: Text('Lists'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.my_location_outlined),
                  selectedIcon: Icon(Icons.my_location),
                  label: Text('Locator'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.handshake_outlined),
                  selectedIcon: Icon(Icons.handshake),
                  label: Text('Lending'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),

          // Main View Content
          Expanded(child: child),
        ],
      ),

      // Bottom Navigation for Mobile Devices
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: selectedIndex,
              onTap: (idx) => _onItemTapped(idx, context),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.folder_outlined),
                  activeIcon: Icon(Icons.folder),
                  label: 'Storage',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined),
                  activeIcon: Icon(Icons.inventory_2),
                  label: 'Items',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.checklist_rounded),
                  activeIcon: Icon(Icons.checklist_rounded),
                  label: 'Lists',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.my_location_outlined),
                  activeIcon: Icon(Icons.my_location),
                  label: 'Locator',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.handshake_outlined),
                  activeIcon: Icon(Icons.handshake),
                  label: 'Lending',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }

  Widget _buildSyncIndicator(BuildContext context, WidgetRef ref, SyncStatusInfo syncStatus) {
    IconData icon;
    Color color;
    String tooltip;

    switch (syncStatus.state) {
      case SyncState.syncing:
        icon = Icons.sync;
        color = const Color(0xFF818CF8);
        tooltip = 'Syncing with cloud...';
        break;
      case SyncState.synced:
        icon = Icons.cloud_done_outlined;
        color = const Color(0xFF10B981);
        tooltip = 'Cloud synced. Tap to force refresh.';
        break;
      case SyncState.pendingSync:
        icon = Icons.cloud_upload_outlined;
        color = const Color(0xFFF59E0B);
        tooltip = '${syncStatus.pendingCount} pending change(s). Tap to sync now.';
        break;
      case SyncState.error:
        icon = Icons.cloud_off_outlined;
        color = const Color(0xFFEF4444);
        tooltip = 'Sync error: ${syncStatus.errorMessage ?? 'Tap to retry'}';
        break;
      case SyncState.offline:
      case SyncState.notConfigured:
        icon = Icons.cloud_queue_outlined;
        color = const Color(0xFF64748B);
        tooltip = 'Sign in via Settings to enable cloud sync.';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          ref.read(syncStatusProvider.notifier).syncNow(force: true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              if (syncStatus.state == SyncState.syncing) ...[
                const SizedBox(width: 4),
                Text(
                  'Syncing',
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
