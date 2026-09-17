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

  Future<void> _editListItems(ItemList list) async {
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

  Future<void> _showDestinationSettings(BuildContext context, ItemList list, List<StorageLocation> locations) async {
    final locMap = {for (final l in locations) l.id: l};
    ListDestinationType destType = list.destinationType;
    String? targetLocId = list.targetLocationId;
    final freeTextCtrl = TextEditingController(text: list.freeTextNote ?? '');
    final borrowerNameCtrl = TextEditingController(text: list.borrowerName ?? '');
    final borrowerContactCtrl = TextEditingController(text: list.borrowerContact ?? '');
    DateTime? dueDate = list.dueDate;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final theme = Theme.of(ctx);
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.near_me_rounded, color: Color(0xFF38BDF8)),
                  SizedBox(width: 8),
                  Text('Collection Destination', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Set where items are moving to when collected or scanned on this list:',
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ListDestinationType>(
                          initialValue: destType,
                          decoration: const InputDecoration(
                            labelText: 'Destination Mode',
                            prefixIcon: Icon(Icons.swap_horiz_rounded),
                          ),
                          items: ListDestinationType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.displayName),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => destType = val);
                            }
                          },
                        ),
                        if (destType == ListDestinationType.storageLocation) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: targetLocId,
                            decoration: const InputDecoration(
                              labelText: 'Target Storage Area *',
                              prefixIcon: Icon(Icons.folder_outlined),
                            ),
                            validator: (val) => val == null ? 'Please select a storage area' : null,
                            items: locations.map((loc) {
                              final path = _buildLocationPath(loc.id, locMap);
                              return DropdownMenuItem(
                                value: loc.id,
                                child: Text(path, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() => targetLocId = val);
                            },
                          ),
                        ] else if (destType == ListDestinationType.freeText) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: freeTextCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Temporary Location Note *',
                              hintText: 'e.g. Workbench Bay 2, Truck Trunk',
                              prefixIcon: Icon(Icons.edit_location_alt_rounded),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty ? 'Please enter a note' : null,
                          ),
                        ] else if (destType == ListDestinationType.lend) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: borrowerNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Borrower Name *',
                              hintText: 'e.g. John Doe',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty ? 'Borrower name is required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: borrowerContactCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Borrower Contact (Optional)',
                              hintText: 'e.g. +61 400 123 456',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: dueDate ?? DateTime.now().add(const Duration(days: 7)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() => dueDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Expected Due Date (Optional)',
                                prefixIcon: Icon(Icons.calendar_today_rounded),
                              ),
                              child: Text(
                                dueDate != null ? DateFormat.yMMMd().format(dueDate!) : 'No return date specified',
                                style: TextStyle(
                                  color: dueDate != null ? theme.textTheme.bodyMedium?.color : theme.hintColor,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Text(
                            'Items will be checked on this list without changing their stored or relocated status in your inventory.',
                            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final updatedList = ItemList(
                      id: list.id,
                      libraryId: list.libraryId,
                      name: list.name,
                      description: list.description,
                      destinationType: destType,
                      targetLocationId: destType == ListDestinationType.storageLocation ? targetLocId : null,
                      freeTextNote: destType == ListDestinationType.freeText ? freeTextCtrl.text.trim() : null,
                      borrowerName: destType == ListDestinationType.lend ? borrowerNameCtrl.text.trim() : null,
                      borrowerContact: destType == ListDestinationType.lend ? borrowerContactCtrl.text.trim() : null,
                      dueDate: destType == ListDestinationType.lend ? dueDate : null,
                      items: list.items,
                      createdAt: list.createdAt,
                      updatedAt: DateTime.now(),
                    );
                    final repo = ref.read(repositoryProvider);
                    await repo.saveItemList(updatedList);
                    ref.invalidate(itemListDetailProvider(list.id));
                    ref.invalidate(itemListsProvider);
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Save Destination'),
                ),
              ],
            );
          },
        );
      },
    );
    freeTextCtrl.dispose();
    borrowerNameCtrl.dispose();
    borrowerContactCtrl.dispose();
  }

  Future<void> _toggleItemCollected(ItemList list, String itemId, bool currentCollected) async {
    final repo = ref.read(repositoryProvider);
    try {
      await repo.collectItemInList(
        listId: list.id,
        itemId: itemId,
        isCollected: !currentCollected,
      );
      // Clean up return selection if unticked/uncollected
      if (currentCollected) {
        _selectedItemIdsForReturn.remove(itemId);
      }
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

  Future<void> _collectAllPending(ItemList list, List<Item> pendingItems) async {
    if (pendingItems.isEmpty) return;
    final repo = ref.read(repositoryProvider);
    try {
      for (final it in pendingItems) {
        await repo.collectItemInList(
          listId: list.id,
          itemId: it.id,
          isCollected: true,
        );
      }
      ref.invalidate(itemListDetailProvider(list.id));
      ref.invalidate(itemListsProvider);
      ref.invalidate(libraryItemsProvider);
      ref.invalidate(lendingRecordsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error collecting items: $e'),
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

        verifiedBarcodes[reqItem.id] = scanned;
      }
    }

    try {
      final repo = ref.read(repositoryProvider);
      final count = _selectedItemIdsForReturn.length;
      await repo.returnSelectedItemsInList(
        listId: list.id,
        itemIds: _selectedItemIdsForReturn.toList(),
        verifiedBarcodes: verifiedBarcodes,
      );

      setState(() => _selectedItemIdsForReturn.clear());

      ref.invalidate(itemListDetailProvider(list.id));
      ref.invalidate(itemListsProvider);
      ref.invalidate(libraryItemsProvider);
      ref.invalidate(lendingRecordsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully returned $count item(s) to home location!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error returning items: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteList(ItemList list) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete List?'),
        content: Text('Are you sure you want to delete "${list.name}"? Items in inventory will remain unaffected.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(repositoryProvider);
      await repo.deleteItemList(list.id);
      ref.invalidate(itemListsProvider);
      if (mounted) {
        context.go('/lists');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final listAsync = ref.watch(itemListDetailProvider(widget.listId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/lists'),
        ),
        title: listAsync.when(
          data: (list) => Text(list?.name ?? 'List Details'),
          loading: () => const Text('Loading List...'),
          error: (_, _) => const Text('List Error'),
        ),
        actions: [
          listAsync.maybeWhen(
            data: (list) {
              if (list == null) return const SizedBox();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (val) {
                  if (val == 'edit') {
                    _editListItems(list);
                  } else if (val == 'delete') {
                    _deleteList(list);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Name & Items'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: colorScheme.error),
                        const SizedBox(width: 8),
                        Text('Delete List', style: TextStyle(color: colorScheme.error)),
                      ],
                    ),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (list) {
          if (list == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.amber),
                  const SizedBox(height: 12),
                  const Text('List not found or has been deleted.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/lists'),
                    child: const Text('Back to Lists'),
                  ),
                ],
              ),
            );
          }

          final allItemsAsync = ref.watch(libraryItemsProvider);
          final allLocationsAsync = ref.watch(allStorageLocationsProvider);

          return allItemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading items: $e')),
            data: (allItems) {
              return allLocationsAsync.when(
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

                  final allTickedSelected = tickedItems.isNotEmpty &&
                      tickedItems.every((it) => _selectedItemIdsForReturn.contains(it.id));

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // Top Progress & Destination Card
                      _buildHeaderCard(context, list, allLocations, locMap),
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
                            onPressed: () => _editListItems(list),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // SECTION 1: TO COLLECT (UNTICKED)
                      _buildSectionHeader(
                        context,
                        title: 'To Collect (Pending)',
                        count: untickedItems.length,
                        icon: Icons.pending_actions_rounded,
                        color: const Color(0xFFF59E0B),
                        action: untickedItems.isNotEmpty
                            ? TextButton.icon(
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                icon: const Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF10B981)),
                                label: const Text(
                                  'Collect all',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () => _collectAllPending(list, untickedItems),
                              )
                            : null,
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

                      // SECTION 2: COLLECTED
                      _buildSectionHeader(
                        context,
                        title: 'Collected',
                        count: tickedItems.length,
                        icon: Icons.task_alt_rounded,
                        color: const Color(0xFF10B981),
                        action: tickedItems.isNotEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                    icon: Icon(
                                      allTickedSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                                      size: 18,
                                    ),
                                    label: Text(allTickedSelected ? 'Deselect all' : 'Select all'),
                                    onPressed: () {
                                      setState(() {
                                        if (allTickedSelected) {
                                          for (final it in tickedItems) {
                                            _selectedItemIdsForReturn.remove(it.id);
                                          }
                                        } else {
                                          for (final it in tickedItems) {
                                            _selectedItemIdsForReturn.add(it.id);
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  if (_selectedItemIdsForReturn.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                      icon: const Icon(Icons.assignment_return_rounded, size: 16),
                                      label: Text('Return Selected (${_selectedItemIdsForReturn.length})'),
                                      onPressed: () => _handleReturnSelected(list, allItems),
                                    ),
                                  ],
                                ],
                              )
                            : null,
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
                              'No items collected yet. Scan barcodes or tick items above to collect.',
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

  Widget _buildHeaderCard(
    BuildContext context,
    ItemList list,
    List<StorageLocation> allLocations,
    Map<String, StorageLocation> locMap,
  ) {
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
                  onPressed: () => _showDestinationSettings(context, list, allLocations),
                  child: const Text('Change Destination', style: TextStyle(fontSize: 12)),
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
    Widget? action,
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
        const Spacer(),
        ?action,
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
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
            itemBuilder: (ctx, idx) {
              final item = items[idx];
              final isForReturnSelected = _selectedItemIdsForReturn.contains(item.id);

              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Single Checkbox on the left
                    Checkbox(
                      value: isCollected ? isForReturnSelected : false,
                      activeColor: isCollected ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                      onChanged: (val) {
                        if (isCollected) {
                          // In Collected section: checkbox toggles return selection
                          setState(() {
                            if (val == true) {
                              _selectedItemIdsForReturn.add(item.id);
                            } else {
                              _selectedItemIdsForReturn.remove(item.id);
                            }
                          });
                        } else {
                          // In To Collect section: checkbox collects the item
                          _toggleItemCollected(list, item.id, false);
                        }
                      },
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
                          color: isCollected ? theme.textTheme.bodyMedium?.color : null,
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
                trailing: isCollected
                    ? Tooltip(
                        message: 'Move back to To Collect',
                        child: IconButton(
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          color: theme.hintColor,
                          onPressed: () => _toggleItemCollected(list, item.id, true),
                        ),
                      )
                    : null,
                onTap: () {
                  if (isCollected) {
                    setState(() {
                      if (isForReturnSelected) {
                        _selectedItemIdsForReturn.remove(item.id);
                      } else {
                        _selectedItemIdsForReturn.add(item.id);
                      }
                    });
                  } else {
                    _toggleItemCollected(list, item.id, false);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
