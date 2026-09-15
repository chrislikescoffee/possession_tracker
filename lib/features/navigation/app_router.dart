import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../items/item_detail_screen.dart';
import '../items/items_list_screen.dart';
import '../lending/lending_ledger_screen.dart';
import '../locator/item_locator_screen.dart';
import '../settings/settings_screen.dart';
import '../storage/storage_location_detail_screen.dart';
import '../storage/storage_tree_screen.dart';
import 'app_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/storage',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return AppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/storage',
          builder: (context, state) => const StorageTreeScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return StorageLocationDetailScreen(locationId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/items',
          builder: (context, state) => const ItemsListScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return ItemDetailScreen(itemId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/locator',
          builder: (context, state) {
            final itemId = state.uri.queryParameters['itemId'];
            return ItemLocatorScreen(initialItemId: itemId);
          },
        ),
        GoRoute(
          path: '/lending',
          builder: (context, state) => const LendingLedgerScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
