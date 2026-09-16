import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/sync_model.dart';
import '../../state/auth_state.dart';
import '../../state/library_state.dart';
import '../../state/sync_state.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/storage')) return 0;
    if (location.startsWith('/items')) return 1;
    if (location.startsWith('/locator')) return 2;
    if (location.startsWith('/lending')) return 3;
    if (location.startsWith('/settings')) return 4;
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
        context.go('/locator');
        break;
      case 3:
        context.go('/lending');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final quotaAsync = ref.watch(libraryQuotaProvider);
    // Keep auth state and cloud sync active continuously across all screens
    ref.watch(authProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      body: Row(
        children: [
          // Responsive Navigation Rail for Web / Desktop
          if (isWide)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (idx) => _onItemTapped(idx, context),
              labelType: NavigationRailLabelType.all,
              backgroundColor: const Color(0xFF131B2E),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
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
                                    ? Colors.red.withOpacity(0.2)
                                    : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: quota.current >= quota.max
                                      ? Colors.red
                                      : const Color(0xFF334155),
                                ),
                              ),
                              child: Text(
                                '${quota.current}/${quota.max}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: quota.current >= quota.max
                                      ? Colors.redAccent
                                      : const Color(0xFF06B6D4),
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
