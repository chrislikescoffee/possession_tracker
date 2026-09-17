import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/app_image_view.dart';
import '../../core/widgets/barcode_scanner_dialog.dart';
import '../../models/item_list_model.dart';
import '../../models/item_model.dart';
import '../../models/storage_location_model.dart';
import '../../state/item_list_state.dart';
import '../../state/item_state.dart';
import '../../state/repository_provider.dart';
import '../../state/storage_state.dart';
import 'add_edit_list_dialog.dart';
import 'continuous_scanner_dialog.dart';

class ListDetailScreen extends ConsumerStatefulWidget {
  final String listId;

  const ListDetailScreen({super.key, required this.listId});

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  final Set<String> _selectedItemIdsForReturn = {};

  String _buildLocationPath(String? locationId, Map<String, StorageLocation> map) {
    if (locationId == null) return 'Unassigned';
    final segments = <String>[];
    String? curr = locationId;
    final visited = <String>{};
    while (curr != null && !visited.contains(curr)) {
      visited.add(curr);
      final loc = map[curr];
      if (loc == null) break;
      segments.insert(0, loc.name);
      curr = loc.parentId;
    }
    return segments.isEmpty ? 'Unassigned' : segments.join(' > ');
  }

  void _openContinuousScanner(ItemList list) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ContinuousScannerDialog(
        listId: list.id,
        libraryId: list.libraryId,
        destinationType: list.destinationType,
        listItemIds: list.items.map((e) => e.itemId).toSet(),
        onItemTicked: (itemId) async {
          final repo = ref.read(repositoryProvider);
          await repo.collectItemInList(
            listId: list.id,
            itemId: itemId,
            isCollected: true,
          );
          ref.invalidate(itemListDetailProvider(list.id));
          ref.invalidate(itemListsProvider);
          ref.invalidate(libraryItemsProvider);
          ref.invalidate(lendingRecordsProvider);
        },
        onItemAddedAndTicked: (itemId) async {
          final repo = ref.read(repositoryProvider);
          await repo.addItemToList(
            listId: list.id,
            itemId: itemId,
            isCollected: true,
          );
          ref.invalidate(itemListDetailProvider(list.id));
          ref.invalidate(itemListsProvider);
          ref.invalidate(libraryItemsProvider);
          ref.invalidate(lendingRecordsProvider);
        },
      ),
    );
  }

  Future<void> _editDestination(ItemList list) async {
    final updated = await showDialog<ItemList>(
      context: context,
      builder: (ctx) => AddEditListDialog(
        libraryId: list.libraryId,
        listToEdit: list,
      ),
    );
    if (updated != null) {
      final repo = ref.read(repositoryProvider);
      await repo.saveItemList(updated);
      ref.invalidate(itemListDetailProvider(list.id));
      ref.invalidate(itemListsProvider);
    }
  }

  Future<void> _toggleItemCollected(ItemList list, String itemId, bool currentCollected) async {
    final repo = ref.read(repositoryProvider);
    try {
      await repo.collectItemInList(
        listId: list.id,
        itemId: itemId,
        isCollected: !currentCollected,
      );
      ref.invalidate(itemListDetailProvider(list.id));
      ref.invalidate(itemListsProvider);
      ref.invalidate(libraryItemsProvider);
      ref.invalidate(lendingRecordsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleReturnSelected(ItemList list, List<Item> allItems) async {
    if (_selectedItemIdsForReturn.isEmpty) return;

    final itemsMap = {for (final i in allItems) i.id: i};
    final selectedItems = _selectedItemIdsForReturn
        .map((id) => itemsMap[id])
        .whereType<Item>()
        .toList();

    // Check which selected items require a scan
    final scanRequiredItems = selectedItems.where((i) => i.mustScanIn).toList();
    final verifiedBarcodes = <String, String>{};

    if (scanRequiredItems.isNotEmpty) {
      // Prompt user to scan each required item
      for (final reqItem in scanRequiredItems) {
        if (!mounted) return;
        final scanned = await BarcodeScannerDialog.show(
          context,
          title: 'Scan Barcode for "${reqItem.name}" to return',
        );

        if (scanned == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Return cancelled: Barcode verification needed for ${reqItem.name}')),
            );
          }
          return;
        }

        if (scanned.trim() != (reqItem.barcode ?? '').trim()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Scanned code did not match ${reqItem.name}! Return cancelled.'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          return;
        }

        verifiedBarcodes[reqItem.id] = scanned.trim();
      }
    }

    try {
      final repo = ref.read(repositoryProvider);
      await repo.returnSelectedItemsInList(
        listId: list.id,
        itemIds: _selectedItemIdsForReturn.toList(),
        verifiedBarcodes: verifiedBarcodes,
      );

      setState(() {
        _selectedItemIdsForReturn.clear();
      });

      ref.invalidate(itemListDetailProvider(list.id));
      ref.invalidate(itemListsProvider);
      ref.invalidate(libraryItemsProvider);
      ref.invalidate(lendingRecordsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedItems.length} item(s) returned to permanent locations.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Return error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final listAsync = ref.watch(itemListDetailProvider(widget.listId));
    final itemsAsync = ref.watch(libraryItemsProvider);
    final locationsAsync = ref.watch(allStorageLocationsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/lists'),
          tooltip: 'Back to Lists',
        ),
        title: listAsync.when(
          data: (list) => Text(list?.name ?? 'List Details'),
          loading: () => const Text('Loading List...'),
          error: (_, _) => const Text('List Error'),
        ),
        actions: [
          listAsync.when(
            data: (list) {
              if (list == null) return const SizedBox.shrink();
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit List',
                    onPressed: () => _editDestination(list),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh',
                    onPressed: () {
                      ref.invalidate(itemListDetailProvider(list.id));
                      ref.invalidate(libraryItemsProvider);
                    },
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading list: $e')),
        data: (list) {
          if (list == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.amber),
                  const SizedBox(height: 12),
                  const Text('List not found.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/lists'),
                    child: const Text('Back to Lists'),
                  ),
                ],
              ),
            );
          }

          return itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading items: $e')),
            data: (allItems) {
              return locationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading locations: $e')),
                data: (allLocations) {
                  final locMap = {for (final l in allLocations) l.id: l};
                  final itemsMap = {for (final i in allItems) i.id: i};

                  // Split list items into Ticked vs Unticked
                  final entriesMap = {for (final e in list.items) e.itemId: e};
                  final untickedItems = <Item>[];
                  final tickedItems = <Item>[];

                  for (final entry in list.items) {
                    final it = itemsMap[entry.itemId];
                    if (it != null) {
                      if (entry.isCollected) {
                        tickedItems.add(it);
                      } else {
                        untickedItems.add(it);
                      }
                    }
                  }

                  // Sub-group by Storage Area
                  Map<String, List<Item>> groupByLocation(List<Item> items) {
                    final map = <String, List<Item>>{};
                    for (final it in items) {
                      final locPath = _buildLocationPath(it.storageLocationId, locMap);
                      map.putIfAbsent(locPath, () => []).add(it);
                    }
                    return map;
                  }

                  final untickedGrouped = groupByLocation(untickedItems);
                  final tickedGrouped = groupByLocation(tickedItems);

                  // Relocated / Lent items in this list eligible for "Select Relocated / Lent"
                  final relocatedOrLentIds = list.items
                      .where((e) {
                        final it = itemsMap[e.itemId];
                        return it != null && (it.isRelocated || it.isLentOut);
                      })
                      .map((e) => e.itemId)
                      .toSet();

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // Top Progress & Destination Card
                      _buildHeaderCard(context, list, locMap),
                      const SizedBox(height: 12),

                      // TOP SCAN BUTTON & ACTIONS
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                              label: const Text(
                                'Scan to Collect',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              onPressed: () => _openContinuousScanner(list),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.playlist_add_rounded, size: 20),
                            label: const Text('Add / Edit Items'),
                            onPressed: () => _editDestination(list),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // "RETURN SELECTED" BAR
                      if (list.items.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${_selectedItemIdsForReturn.length} for Return',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Spacer(),
                              TextButton(
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () {
                                  setState(() {
                                    _selectedItemIdsForReturn.clear();
                                    _selectedItemIdsForReturn.addAll(list.items.map((e) => e.itemId));
                                  });
                                },
                                child: const Text('Select All'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () {
                                  setState(() {
                                    _selectedItemIdsForReturn.clear();
                                    _selectedItemIdsForReturn.addAll(relocatedOrLentIds);
                                  });
                                },
                                child: const Text('Select Lent/Relocated'),
                              ),
                              if (_selectedItemIdsForReturn.isNotEmpty) ...[
                                TextButton(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () {
                                    setState(() => _selectedItemIdsForReturn.clear());
                                  },
                                  child: const Text('Clear'),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.assignment_return_rounded, size: 16),
                                  label: const Text('Return Selected'),
                                  onPressed: () => _handleReturnSelected(list, allItems),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // SECTION 1: TO COLLECT (UNTICKED)
                      _buildSectionHeader(
                        context,
                        title: 'To Collect (Pending)',
                        count: untickedItems.length,
                        icon: Icons.pending_actions_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(height: 8),
                      if (untickedItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'All items collected!',
                                style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      else
                        ...untickedGrouped.entries.map((group) {
                          return _buildLocationGroup(
                            context: context,
                            list: list,
                            locationPath: group.key,
                            items: group.value,
                            entriesMap: entriesMap,
                            isCollected: false,
                          );
                        }),

                      const SizedBox(height: 24),

                      // SECTION 2: COLLECTED (TICKED)
                      _buildSectionHeader(
                        context,
                        title: 'Collected',
                        count: tickedItems.length,
                        icon: Icons.task_alt_rounded,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 8),
                      if (tickedItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'No items ticked yet. Scan barcodes or check items above to collect.',
                              style: TextStyle(color: theme.hintColor, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ...tickedGrouped.entries.map((group) {
                          return _buildLocationGroup(
                            context: context,
                            list: list,
                            locationPath: group.key,
                            items: group.value,
                            entriesMap: entriesMap,
                            isCollected: true,
                          );
                        }),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, ItemList list, Map<String, StorageLocation> locMap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String destinationText = list.destinationType.displayName;
    if (list.destinationType == ListDestinationType.storageLocation) {
      final loc = locMap[list.targetLocationId];
      destinationText = 'Relocating to: ${loc != null ? _buildLocationPath(loc.id, locMap) : "Selected Area"}';
    } else if (list.destinationType == ListDestinationType.freeText) {
      destinationText = 'Custom Note: "${list.freeTextNote ?? "Temporary Location"}"';
    } else if (list.destinationType == ListDestinationType.lend) {
      destinationText = 'Lending to: ${list.borrowerName ?? "Borrower"}';
      if (list.dueDate != null) {
        destinationText += ' (Due ${DateFormat.yMMMd().format(list.dueDate!)})';
      }
    } else {
      destinationText = 'Not Relocating (Item states unchanged)';
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        list.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (list.description != null && list.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          list.description!,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${list.collectedCount}/${list.totalCount} Collected',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: list.progress,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
              ),
            ),
            const SizedBox(height: 12),

            // Destination details bar
            Row(
              children: [
                const Icon(Icons.near_me_rounded, size: 16, color: Color(0xFF38BDF8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    destinationText,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _editDestination(list),
                  child: const Text('Change', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          '$title ($count)',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildLocationGroup({
    required BuildContext context,
    required ItemList list,
    required String locationPath,
    required List<Item> items,
    required Map<String, ItemListItemEntry> entriesMap,
    required bool isCollected,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-heading for Storage Area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    locationPath,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
                Text(
                  '${items.length} item(s)',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Items List in this area
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
            itemBuilder: (ctx, idx) {
              final item = items[idx];
              final isForReturnSelected = _selectedItemIdsForReturn.contains(item.id);

              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Collection Checkbox
                    Checkbox(
                      value: isCollected,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (_) => _toggleItemCollected(list, item.id, isCollected),
                    ),
                    AppImageView(
                      imageUrl: item.primaryImageUrl,
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: isCollected ? TextDecoration.lineThrough : null,
                          color: isCollected ? theme.hintColor : null,
                        ),
                      ),
                    ),
                    if (item.mustScanIn) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_scanner, size: 12, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text(
                              'Must Scan',
                              style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Row(
                  children: [
                    if (item.isLentOut)
                      Container(
                        margin: const EdgeInsets.only(top: 2, right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Lent', style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    else if (item.isRelocated)
                      Container(
                        margin: const EdgeInsets.only(top: 2, right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.temporaryLocationNote ?? 'Relocated',
                          style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      Text(
                        'Home location',
                        style: TextStyle(fontSize: 11, color: theme.hintColor),
                      ),
                  ],
                ),
                trailing: Tooltip(
                  message: 'Select for Return',
                  child: Checkbox(
                    value: isForReturnSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedItemIdsForReturn.add(item.id);
                        } else {
                          _selectedItemIdsForReturn.remove(item.id);
                        }
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
