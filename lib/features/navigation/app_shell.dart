import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../state/library_state.dart';

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
                    child: quotaAsync.when(
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
}
