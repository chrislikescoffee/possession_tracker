import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_image_view.dart';
import '../../models/item_model.dart';
import '../../models/storage_location_model.dart';
import '../../state/item_state.dart';
import '../../state/library_state.dart';
import '../../state/repository_provider.dart';
import '../../state/storage_state.dart';
import 'add_edit_location_dialog.dart';

class StorageTreeScreen extends ConsumerStatefulWidget {
  const StorageTreeScreen({super.key});

  @override
  ConsumerState<StorageTreeScreen> createState() => _StorageTreeScreenState();
}

class _StorageTreeScreenState extends ConsumerState<StorageTreeScreen> {
  bool _isGridView = true;
  final _searchController = TextEditingController();
  String _sortBy = 'name'; // 'name', 'date', 'subareas', 'items', 'polygons'
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getSortLabel(String key) {
    switch (key) {
      case 'name':
        return 'Name';
      case 'date':
        return 'Date Added';
      case 'subareas':
        return 'Sub-Areas';
      case 'items':
        return 'Item Count';
      case 'polygons':
        return 'Mapped Polygons';
      default:
        return 'Sort';
    }
  }

  Set<String> _getDescendantIds(String rootId, List<StorageLocation> allLocations) {
    final result = <String>{rootId};
    final queue = <String>[rootId];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final l in allLocations) {
        if (l.parentId == current && !result.contains(l.id)) {
          result.add(l.id);
          queue.add(l.id);
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final selectedLib = ref.watch(selectedLibraryProvider).value;
    final rootLocationsAsync = ref.watch(storageLocationsProvider(null));
    final allLocationsAsync = ref.watch(allStorageLocationsProvider);
    final allItemsAsync = ref.watch(libraryItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Storage Hierarchy'),
            if (selectedLib != null)
              Text(
                selectedLib.name,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(storageLocationsProvider(null));
              ref.invalidate(allStorageLocationsProvider);
              ref.invalidate(libraryItemsProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Root Location'),
        onPressed: () async {
          if (selectedLib == null) return;
          final newLoc = await showDialog<StorageLocation>(
            context: context,
            builder: (ctx) => AddEditLocationDialog(libraryId: selectedLib.id),
          );
          if (newLoc != null) {
            final repo = ref.read(repositoryProvider);
            await repo.saveStorageLocation(newLoc);
            ref.invalidate(storageLocationsProvider(null));
            ref.invalidate(allStorageLocationsProvider);
          }
        },
      ),
      body: Column(
        children: [
          // Search & Filter Toolbar
          Container(
            padding: const EdgeInsets.all(14),
            color: const Color(0xFF131B2E),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search storage areas...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),

                // Controls Row: Sort dropdown, direction toggle, grid/list toggle
                Row(
                  children: [
                    // Sort Dropdown Menu
                    PopupMenuButton<String>(
                      tooltip: 'Sort Options',
                      onSelected: (val) {
                        setState(() {
                          _sortBy = val;
                          _sortAscending = val == 'name';
                        });
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'name',
                          child: Text('Sort by Name (A-Z)'),
                        ),
                        const PopupMenuItem(
                          value: 'date',
                          child: Text('Sort by Date Added'),
                        ),
                        const PopupMenuItem(
                          value: 'subareas',
                          child: Text('Sort by Sub-Area Count'),
                        ),
                        const PopupMenuItem(
                          value: 'items',
                          child: Text('Sort by Item Count'),
                        ),
                        const PopupMenuItem(
                          value: 'polygons',
                          child: Text('Sort by Mapped Polygons'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort, size: 15, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 6),
                            Text(
                              _getSortLabel(_sortBy),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF1F5F9),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Ascending / Descending Toggle
                    IconButton(
                      tooltip: _sortAscending ? 'Ascending' : 'Descending',
                      icon: Icon(
                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 18,
                        color: const Color(0xFF38BDF8),
                      ),
                      onPressed: () => setState(() => _sortAscending = !_sortAscending),
                    ),

                    const Spacer(),

                    // Grid vs List Toggle
                    IconButton(
                      tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid Tiles',
                      icon: Icon(
                        _isGridView ? Icons.view_list : Icons.grid_view,
                        size: 20,
                        color: const Color(0xFF94A3B8),
                      ),
                      onPressed: () => setState(() => _isGridView = !_isGridView),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Storage Content
          Expanded(
            child: rootLocationsAsync.when(
              data: (locations) {
                if (locations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.folder_open, size: 48, color: Color(0xFF6366F1)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No storage locations yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your first storage area (e.g. Workshop, Living Room, Attic)',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  );
                }

                final allLocations = allLocationsAsync.value ?? locations;
                final allItems = allItemsAsync.value ?? <Item>[];

                // 1. Filter by search query
                final query = _searchController.text.trim().toLowerCase();
                final filtered = locations.where((loc) {
                  if (query.isEmpty) return true;
                  final matchName = loc.name.toLowerCase().contains(query);
                  final matchDesc = loc.description?.toLowerCase().contains(query) ?? false;
                  return matchName || matchDesc;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.search_off, size: 48, color: Color(0xFF64748B)),
                        SizedBox(height: 12),
                        Text(
                          'No storage areas match your search',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  );
                }

                // 2. Sort locations
                filtered.sort((a, b) {
                  int comp = 0;
                  switch (_sortBy) {
                    case 'date':
                      comp = a.createdAt.compareTo(b.createdAt);
                      break;
                    case 'polygons':
                      comp = a.regions.length.compareTo(b.regions.length);
                      break;
                    case 'subareas':
                      final aSubs = allLocations.where((l) => l.parentId == a.id).length;
                      final bSubs = allLocations.where((l) => l.parentId == b.id).length;
                      comp = aSubs.compareTo(bSubs);
                      break;
                    case 'items':
                      final aIds = _getDescendantIds(a.id, allLocations);
                      final bIds = _getDescendantIds(b.id, allLocations);
                      final aItems = allItems.where((i) => i.storageLocationId != null && aIds.contains(i.storageLocationId)).length;
                      final bItems = allItems.where((i) => i.storageLocationId != null && bIds.contains(i.storageLocationId)).length;
                      comp = aItems.compareTo(bItems);
                      break;
                    case 'name':
                    default:
                      comp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                      break;
                  }
                  return _sortAscending ? comp : -comp;
                });

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.refresh(storageLocationsProvider(null));
                    ref.refresh(allStorageLocationsProvider);
                    ref.refresh(libraryItemsProvider);
                  },
                  child: _isGridView
                      ? GridView.builder(
                          padding: const EdgeInsets.all(14),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            mainAxisExtent: 255,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final loc = filtered[index];
                            final subCount = allLocations.where((l) => l.parentId == loc.id).length;
                            final descIds = _getDescendantIds(loc.id, allLocations);
                            final itemCount = allItems.where((i) => i.storageLocationId != null && descIds.contains(i.storageLocationId)).length;

                            return _StorageLocationTile(
                              location: loc,
                              subAreaCount: subCount,
                              itemCount: itemCount,
                            );
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final loc = filtered[index];
                            final subCount = allLocations.where((l) => l.parentId == loc.id).length;
                            final descIds = _getDescendantIds(loc.id, allLocations);
                            final itemCount = allItems.where((i) => i.storageLocationId != null && descIds.contains(i.storageLocationId)).length;

                            return _StorageLocationCard(
                              location: loc,
                              subAreaCount: subCount,
                              itemCount: itemCount,
                            );
                          },
                        ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual Grid Tile representing a Storage Area
class _StorageLocationTile extends ConsumerWidget {
  final StorageLocation location;
  final int subAreaCount;
  final int itemCount;

  const _StorageLocationTile({
    required this.location,
    required this.subAreaCount,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage = location.imageUrl != null && location.imageUrl!.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF263352), width: 1),
      ),
      color: const Color(0xFF131B2E),
      elevation: 2,
      child: InkWell(
        onTap: () => context.go('/storage/${location.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Banner
            SizedBox(
              height: 135,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImageView(
                    imageUrl: location.imageUrl,
                    fit: BoxFit.cover,
                    fallbackWidget: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.warehouse_outlined, size: 44, color: Color(0xFF6366F1)),
                      ),
                    ),
                  ),

                  // Bottom gradient overlay for readability
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x990B0F19)],
                      ),
                    ),
                  ),

                  // Storage Areas and Items Badges (Top-left on image)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _StorageCountBadge(
                          icon: Icons.folder_outlined,
                          label: '$subAreaCount ${subAreaCount == 1 ? 'Area' : 'Areas'}',
                          color: const Color(0xFF38BDF8),
                        ),
                        _StorageCountBadge(
                          icon: Icons.inventory_2_outlined,
                          label: '$itemCount ${itemCount == 1 ? 'Item' : 'Items'}',
                          color: const Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ),

                  // Overflow Options Menu (Top-right)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: _LocationMenuButton(location: location),
                    ),
                  ),
                ],
              ),
            ),

            // Card Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          location.description ?? 'No description provided',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: location.description != null
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontStyle: location.description != null ? FontStyle.normal : FontStyle.italic,
                          ),
                        ),
                      ],
                    ),

                    // Badges Row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _StorageCountBadge(
                          icon: Icons.folder_outlined,
                          label: '$subAreaCount ${subAreaCount == 1 ? 'Area' : 'Areas'}',
                          color: const Color(0xFF38BDF8),
                        ),
                        _StorageCountBadge(
                          icon: Icons.inventory_2_outlined,
                          label: '$itemCount ${itemCount == 1 ? 'Item' : 'Items'}',
                          color: const Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List View Card representation for Storage Areas
class _StorageLocationCard extends ConsumerWidget {
  final StorageLocation location;
  final int subAreaCount;
  final int itemCount;

  const _StorageLocationCard({
    required this.location,
    required this.subAreaCount,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage = location.imageUrl != null && location.imageUrl!.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF263352), width: 1),
      ),
      color: const Color(0xFF131B2E),
      child: InkWell(
        onTap: () => context.go('/storage/${location.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image
            if (hasImage)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImageView(
                      imageUrl: location.imageUrl,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC0B0F19)],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 14,
                      child: Row(
                        children: [
                          _StorageCountBadge(
                            icon: Icons.folder_outlined,
                            label: '$subAreaCount ${subAreaCount == 1 ? 'Area' : 'Areas'}',
                            color: const Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 6),
                          _StorageCountBadge(
                            icon: Icons.inventory_2_outlined,
                            label: '$itemCount ${itemCount == 1 ? 'Item' : 'Items'}',
                            color: const Color(0xFF10B981),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Card Details
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_outlined, color: Color(0xFF818CF8), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (location.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            location.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _StorageCountBadge(
                              icon: Icons.folder_outlined,
                              label: '$subAreaCount ${subAreaCount == 1 ? 'Area' : 'Areas'}',
                              color: const Color(0xFF38BDF8),
                            ),
                            const SizedBox(width: 8),
                            _StorageCountBadge(
                              icon: Icons.inventory_2_outlined,
                              label: '$itemCount ${itemCount == 1 ? 'Item' : 'Items'}',
                              color: const Color(0xFF10B981),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _LocationMenuButton(location: location),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact badge displaying count metrics
class _StorageCountBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StorageCountBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable Location Menu button (Edit, Delete)
class _LocationMenuButton extends ConsumerWidget {
  final StorageLocation location;

  const _LocationMenuButton({required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: Colors.white70),
      onSelected: (val) async {
        if (val == 'edit') {
          final updated = await showDialog<StorageLocation>(
            context: context,
            builder: (ctx) => AddEditLocationDialog(
              libraryId: location.libraryId,
              locationToEdit: location,
            ),
          );
          if (updated != null) {
            final repo = ref.read(repositoryProvider);
            await repo.saveStorageLocation(updated);
            ref.invalidate(storageLocationsProvider(null));
            ref.invalidate(storageLocationsProvider(location.parentId));
            ref.invalidate(allStorageLocationsProvider);
            ref.invalidate(storageLocationDetailProvider(location.id));
          }
        } else if (val == 'delete') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Delete Location?'),
              content: Text(
                'Are you sure you want to delete "${location.name}" and all child sub-containers?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            final repo = ref.read(repositoryProvider);
            await repo.deleteStorageLocation(location.id);
            ref.invalidate(storageLocationsProvider(null));
            ref.invalidate(storageLocationsProvider(location.parentId));
            ref.invalidate(allStorageLocationsProvider);
            ref.invalidate(storageLocationDetailProvider(location.id));
          }
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: Color(0xFF94A3B8)),
              SizedBox(width: 8),
              Text('Edit Details'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Delete Location', style: TextStyle(color: Color(0xFFEF4444))),
            ],
          ),
        ),
      ],
    );
  }
}
