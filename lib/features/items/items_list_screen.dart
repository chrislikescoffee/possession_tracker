import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/field_query_utils.dart';
import '../../core/widgets/app_image_view.dart';
import '../../models/item_model.dart';
import '../../models/storage_location_model.dart';
import '../../state/item_state.dart';
import '../../state/library_state.dart';
import '../../state/repository_provider.dart';
import '../../state/storage_state.dart';
import 'add_edit_item_dialog.dart';

class ItemsListScreen extends ConsumerStatefulWidget {
  const ItemsListScreen({super.key});

  @override
  ConsumerState<ItemsListScreen> createState() => _ItemsListScreenState();
}

class _ItemsListScreenState extends ConsumerState<ItemsListScreen> {
  String _statusFilter = 'all'; // 'all', 'stored', 'relocated', 'lent'
  String _groupBy = 'location'; // Default: group by location with breadcrumbs!
  String _sortBy = 'name'; // 'name', 'date', 'location', 'type', or 'field:<name>'
  bool _sortAscending = true;
  bool _isGridView = true; // Default: grid tiles
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'name':
        return 'Name';
      case 'date':
        return 'Date Added';
      case 'location':
        return 'Location';
      case 'type':
        return 'Type';
      default:
        if (sortBy.startsWith('field:')) {
          return sortBy.substring('field:'.length);
        }
        return 'Sort';
    }
  }

  String _getGroupLabel(String groupBy) {
    switch (groupBy) {
      case 'location':
        return 'Location';
      case 'type':
        return 'Type';
      case 'none':
        return 'Flat';
      default:
        if (groupBy.startsWith('field:')) {
          return groupBy.substring('field:'.length);
        }
        return 'Group';
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLib = ref.watch(selectedLibraryProvider).value;
    final itemsAsync = ref.watch(libraryItemsProvider);
    final locationsAsync = ref.watch(allStorageLocationsProvider);

    final locationMap = locationsAsync.maybeWhen(
      data: (locs) => {for (final l in locs) l.id: l},
      orElse: () => <String, StorageLocation>{},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Items'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(libraryItemsProvider);
              ref.invalidate(allStorageLocationsProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        onPressed: () async {
          if (selectedLib == null) return;
          final newItem = await showDialog<Item>(
            context: context,
            builder: (ctx) => AddEditItemDialog(libraryId: selectedLib.id),
          );
          if (newItem != null) {
            try {
              final repo = ref.read(repositoryProvider);
              await repo.saveItem(newItem);
              ref.invalidate(libraryItemsProvider);
              ref.invalidate(libraryQuotaProvider);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text(e.toString()),
                  ),
                );
              }
            }
          }
        },
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.all(14),
            color: const Color(0xFF131B2E),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search items, types, or attributes (e.g. Price)...',
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

                // Status Filters Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _statusFilter == 'all',
                        onSelected: (_) => setState(() => _statusFilter = 'all'),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        avatar: const Icon(Icons.inventory, size: 14, color: Color(0xFF10B981)),
                        label: const Text('Stored'),
                        selected: _statusFilter == AppConstants.itemStatusStored,
                        onSelected: (_) =>
                            setState(() => _statusFilter = AppConstants.itemStatusStored),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        avatar: const Icon(Icons.alt_route, size: 14, color: Colors.amber),
                        label: const Text('Relocated'),
                        selected: _statusFilter == AppConstants.itemStatusRelocated,
                        onSelected: (_) =>
                            setState(() => _statusFilter = AppConstants.itemStatusRelocated),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        avatar: const Icon(Icons.handshake, size: 14, color: Colors.purpleAccent),
                        label: const Text('Lent'),
                        selected: _statusFilter == AppConstants.itemStatusLent,
                        onSelected: (_) =>
                            setState(() => _statusFilter = AppConstants.itemStatusLent),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Toolbar: Grouping, Sorting, and View Layout
                itemsAsync.when(
                  data: (items) {
                    final discoveredFields = FieldQueryUtils.discoverFields(items);

                    return Row(
                      children: [
                        // Group By Menu
                        PopupMenuButton<String>(
                          tooltip: 'Group Items',
                          onSelected: (val) => setState(() => _groupBy = val),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'location',
                              child: Row(
                                children: [
                                  Icon(Icons.place_outlined, size: 16, color: Color(0xFF38BDF8)),
                                  SizedBox(width: 8),
                                  Text('Group by Location (Breadcrumbs)'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'type',
                              child: Row(
                                children: [
                                  Icon(Icons.category_outlined, size: 16, color: Color(0xFF818CF8)),
                                  SizedBox(width: 8),
                                  Text('Group by Item Type'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'none',
                              child: Row(
                                children: [
                                  Icon(Icons.list_alt, size: 16, color: Color(0xFF94A3B8)),
                                  SizedBox(width: 8),
                                  Text('No Grouping (Flat)'),
                                ],
                              ),
                            ),
                            if (discoveredFields.isNotEmpty) ...[
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                enabled: false,
                                child: Text('Group by Attribute:',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              for (final f in discoveredFields)
                                PopupMenuItem(
                                  value: 'field:${f.canonicalName}',
                                  child: Text('${f.canonicalName} (${f.count})'),
                                ),
                            ],
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _groupBy != 'none'
                                    ? const Color(0xFF6366F1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.layers_outlined,
                                  size: 15,
                                  color: _groupBy != 'none'
                                      ? const Color(0xFF818CF8)
                                      : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _getGroupLabel(_groupBy),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _groupBy != 'none'
                                        ? const Color(0xFF818CF8)
                                        : const Color(0xFFF1F5F9),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF94A3B8)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Sort By Menu
                        PopupMenuButton<String>(
                          tooltip: 'Sort Items',
                          onSelected: (val) => setState(() => _sortBy = val),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'name',
                              child: Text('Sort by Name'),
                            ),
                            const PopupMenuItem(
                              value: 'date',
                              child: Text('Sort by Date Added'),
                            ),
                            const PopupMenuItem(
                              value: 'location',
                              child: Text('Sort by Location'),
                            ),
                            const PopupMenuItem(
                              value: 'type',
                              child: Text('Sort by Item Type'),
                            ),
                            if (discoveredFields.isNotEmpty) ...[
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                enabled: false,
                                child: Text('Sort by Attribute:',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              for (final f in discoveredFields)
                                PopupMenuItem(
                                  value: 'field:${f.canonicalName}',
                                  child: Text(f.canonicalName),
                                ),
                            ],
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sort, size: 15, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 5),
                                Text(
                                  _getSortLabel(_sortBy),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF1F5F9),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF94A3B8)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 4),

                        // Ascending / Descending Toggle
                        IconButton(
                          tooltip: _sortAscending ? 'Ascending (A-Z / Low-High)' : 'Descending (Z-A / High-Low)',
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
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),

          // Items Display (Grid / List)
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                final query = _searchController.text.trim();

                // 1. Filter by search & status
                final filtered = items.where((it) {
                  if (_statusFilter != 'all' && it.status != _statusFilter) return false;
                  if (query.isNotEmpty && !FieldQueryUtils.itemMatchesSearch(it, query)) return false;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF64748B)),
                        SizedBox(height: 12),
                        Text(
                          'No items match your search or filter',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  );
                }

                // 2. Sort items
                final sorted = FieldQueryUtils.sortItems(
                  filtered,
                  sortBy: _sortBy,
                  ascending: _sortAscending,
                  locationMap: locationMap,
                );

                // 3. Render Grouped or Flat view
                if (_groupBy == 'location') {
                  final groups = FieldQueryUtils.groupByLocation(sorted, locationMap);
                  return _buildGroupedView(
                    groups,
                    locationMap: locationMap,
                    isGridView: _isGridView,
                  );
                } else if (_groupBy == 'type') {
                  final groups = FieldQueryUtils.groupByItemType(sorted);
                  return _buildGroupedView(
                    groups,
                    locationMap: locationMap,
                    isGridView: _isGridView,
                  );
                } else if (_groupBy.startsWith('field:')) {
                  final fieldName = _groupBy.substring('field:'.length);
                  final groups = FieldQueryUtils.groupByField(sorted, fieldName);
                  return _buildGroupedView(
                    groups,
                    headerPrefix: '$fieldName: ',
                    locationMap: locationMap,
                    isGridView: _isGridView,
                  );
                }

                // Flat view
                return _buildFlatView(sorted, locationMap: locationMap, isGridView: _isGridView);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatView(
    List<Item> items, {
    required Map<String, StorageLocation> locationMap,
    required bool isGridView,
  }) {
    if (isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 250,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _ItemTile(item: items[index], locationMap: locationMap);
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _ItemCard(item: items[index], locationMap: locationMap);
      },
    );
  }

  Widget _buildGroupedView(
    Map<String, List<Item>> groups, {
    String headerPrefix = '',
    required Map<String, StorageLocation> locationMap,
    required bool isGridView,
  }) {
    final keys = groups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final groupKey = keys[index];
        final groupItems = groups[groupKey]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF263352)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$headerPrefix$groupKey',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${groupItems.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF818CF8),
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: isGridView
                      ? GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisExtent: 250,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: groupItems.length,
                          itemBuilder: (context, i) => _ItemTile(
                            item: groupItems[i],
                            locationMap: locationMap,
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: groupItems.length,
                          separatorBuilder: (context, i) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _ItemCard(
                            item: groupItems[i],
                            locationMap: locationMap,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Visual Grid Tile representing an inventory item
class _ItemTile extends StatelessWidget {
  final Item item;
  final Map<String, StorageLocation> locationMap;

  const _ItemTile({required this.item, required this.locationMap});

  @override
  Widget build(BuildContext context) {
    final locBreadcrumb = item.storageLocationId != null
        ? FieldQueryUtils.buildLocationBreadcrumb(item.storageLocationId, locationMap)
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF263352), width: 1),
      ),
      color: const Color(0xFF131B2E),
      elevation: 2,
      child: InkWell(
        onTap: () => context.go('/items/${item.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Overlays
            SizedBox(
              height: 125,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImageView(
                    imageUrl: item.primaryImageUrl,
                    fit: BoxFit.cover,
                    fallbackWidget: Container(
                      color: const Color(0xFF1E293B),
                      child: const Center(
                        child: Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF6366F1)),
                      ),
                    ),
                  ),

                  // Status badge top-left
                  if (item.isTemporarilyRelocated)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.alt_route, size: 11, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'Relocated',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (item.isLentOut)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9333EA).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.handshake, size: 11, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'Lent',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Item type tag top-right
                  if (item.effectiveItemTypeName != 'Generic Item')
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          item.effectiveItemTypeName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Card Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                        if (locBreadcrumb != null && locBreadcrumb.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  locBreadcrumb,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    // Custom Fields (Price / Attributes badge)
                    if (item.customFields.isNotEmpty)
                      _buildFieldBadge(item),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldBadge(Item item) {
    MapEntry<String, dynamic>? displayEntry;
    for (final e in item.customFields.entries) {
      final k = e.key.toLowerCase();
      if (k.contains('price') || k.contains('cost') || k.contains('value') || k.contains('amount')) {
        displayEntry = e;
        break;
      }
    }
    displayEntry ??= item.customFields.entries.first;

    final formattedVal = FieldQueryUtils.formatFieldValue(displayEntry.value);
    final isPrice = formattedVal.startsWith(r'$') ||
        formattedVal.startsWith('€') ||
        formattedVal.startsWith('£') ||
        formattedVal.startsWith('¥') ||
        displayEntry.key.toLowerCase().contains('price');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPrice ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isPrice ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFF334155),
        ),
      ),
      child: Text(
        isPrice ? formattedVal : '${displayEntry.key}: $formattedVal',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isPrice ? FontWeight.bold : FontWeight.w500,
          color: isPrice ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

/// Full Row Card for horizontal List View
class _ItemCard extends StatelessWidget {
  final Item item;
  final Map<String, StorageLocation> locationMap;

  const _ItemCard({required this.item, required this.locationMap});

  @override
  Widget build(BuildContext context) {
    final locBreadcrumb = item.storageLocationId != null
        ? FieldQueryUtils.buildLocationBreadcrumb(item.storageLocationId, locationMap)
        : null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/items/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Thumbnail
              AppImageView(
                imageUrl: item.primaryImageUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(10),
                fallbackWidget: Container(
                  color: const Color(0xFF1E293B),
                  child: const Icon(Icons.inventory_2_outlined, size: 28, color: Color(0xFF6366F1)),
                ),
              ),
              const SizedBox(width: 14),

              // Item Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (item.effectiveItemTypeName != 'Generic Item')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.effectiveItemTypeName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                      ],
                    ),

                    if (locBreadcrumb != null && locBreadcrumb.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              locBreadcrumb,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (item.description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Relocation / Lending Status Banner
                    if (item.isTemporarilyRelocated) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alt_route, size: 14, color: Colors.amber),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Relocated: ${item.temporaryLocationNote ?? 'Temporary area'}',
                                style: const TextStyle(fontSize: 11, color: Colors.amber),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (item.isLentOut) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.handshake, size: 14, color: Colors.purpleAccent),
                            SizedBox(width: 6),
                            Text('Lent Out', style: TextStyle(fontSize: 11, color: Colors.purpleAccent)),
                          ],
                        ),
                      ),
                    ],

                    // Custom Attributes Preview Chips
                    if (item.customFields.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: item.customFields.entries.take(3).map((e) {
                          final formatted = FieldQueryUtils.formatFieldValue(e.value);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Text(
                              '${e.key}: $formatted',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
