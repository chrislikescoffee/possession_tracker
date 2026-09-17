import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/field_query_utils.dart';
import '../../core/widgets/app_image_view.dart';
import '../../models/item_list_model.dart';
import '../../models/item_model.dart';
import '../../models/storage_location_model.dart';
import '../../state/item_state.dart';
import '../../state/item_type_state.dart';
import '../../state/storage_state.dart';

class AddEditListDialog extends ConsumerStatefulWidget {
  final String libraryId;
  final ItemList? listToEdit;

  const AddEditListDialog({
    super.key,
    required this.libraryId,
    this.listToEdit,
  });

  @override
  ConsumerState<AddEditListDialog> createState() => _AddEditListDialogState();
}

class _AddEditListDialogState extends ConsumerState<AddEditListDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedItemIds = {};
  final List<String> _orderedItemIds = [];
  bool _initializedOrder = false;

  String _searchQuery = '';
  String? _selectedItemTypeId;

  @override
  void initState() {
    super.initState();
    final edit = widget.listToEdit;
    _nameController = TextEditingController(text: edit?.name ?? '');
    _descController = TextEditingController(text: edit?.description ?? '');

    if (edit != null) {
      for (final e in edit.items) {
        _selectedItemIds.add(e.itemId);
        _orderedItemIds.add(e.itemId);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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

  void _syncInitialOrder(List<Item> allItems) {
    if (_initializedOrder) return;
    final existingSet = _orderedItemIds.toSet();
    for (final item in allItems) {
      if (!existingSet.contains(item.id)) {
        _orderedItemIds.add(item.id);
      }
    }
    _initializedOrder = true;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final edit = widget.listToEdit;

    // Retain existing entry collection states if editing
    final existingEntriesMap = {
      for (final e in edit?.items ?? <ItemListItemEntry>[]) e.itemId: e
    };

    // Build entries in the reordered sequence
    final entries = _orderedItemIds
        .where((id) => _selectedItemIds.contains(id))
        .map((itemId) {
      if (existingEntriesMap.containsKey(itemId)) {
        return existingEntriesMap[itemId]!;
      }
      return ItemListItemEntry(
        itemId: itemId,
        isCollected: false,
      );
    }).toList();

    final result = ItemList(
      id: edit?.id ?? const Uuid().v4(),
      libraryId: widget.libraryId,
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      destinationType: edit?.destinationType ?? ListDestinationType.notRelocating,
      targetLocationId: edit?.targetLocationId,
      freeTextNote: edit?.freeTextNote,
      borrowerName: edit?.borrowerName,
      borrowerContact: edit?.borrowerContact,
      dueDate: edit?.dueDate,
      items: entries,
      createdAt: edit?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.listToEdit != null;

    final itemsAsync = ref.watch(libraryItemsProvider);
    final locationsAsync = ref.watch(allStorageLocationsProvider);
    final typesAsync = ref.watch(itemTypesProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 820),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                child: Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit_note_rounded : Icons.playlist_add_rounded,
                      color: colorScheme.primary,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit List' : 'Create New List',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Top Inputs (Name, Description, Search, Type Filter)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // List Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'List Name *',
                        hintText: 'e.g. Camping Weekend Packing, Tool Service Batch',
                        prefixIcon: Icon(Icons.title_rounded, size: 20),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Please enter a list name' : null,
                    ),
                    const SizedBox(height: 10),

                    // Description
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Add details about the purpose or instructions...',
                        prefixIcon: Icon(Icons.notes_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search & Item Type Filter Row
                    Row(
                      children: [
                        // Search Box
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search items, tags, codes, types...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              isDense: true,
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (val) {
                              setState(() => _searchQuery = val.trim().toLowerCase());
                            },
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Item Type Dropdown Filter
                        Expanded(
                          flex: 2,
                          child: typesAsync.when(
                            data: (types) {
                              return DropdownButtonFormField<String?>(
                                initialValue: _selectedItemTypeId,
                                isDense: true,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Item Type',
                                  prefixIcon: Icon(Icons.category_outlined, size: 18),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All Types', style: TextStyle(fontSize: 13)),
                                  ),
                                  ...types.map((t) => DropdownMenuItem<String?>(
                                        value: t.id,
                                        child: Text(t.name, style: const TextStyle(fontSize: 13)),
                                      )),
                                ],
                                onChanged: (val) {
                                  setState(() => _selectedItemTypeId = val);
                                },
                              );
                            },
                            loading: () => const SizedBox(),
                            error: (_, _) => const SizedBox(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Items Header & Selection Controls
              itemsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Error loading items: $err'),
                ),
                data: (allItems) {
                  _syncInitialOrder(allItems);
                  final itemMap = {for (final i in allItems) i.id: i};

                  return locationsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text('Error loading locations: $err'),
                    data: (locations) {
                      final locMap = {for (final l in locations) l.id: l};

                      // Filter items while respecting _orderedItemIds sequence
                      final filteredItems = _orderedItemIds
                          .map((id) => itemMap[id])
                          .whereType<Item>()
                          .where((it) {
                            if (_selectedItemTypeId != null &&
                                _selectedItemTypeId!.isNotEmpty &&
                                it.itemTypeId != _selectedItemTypeId) {
                              return false;
                            }
                            if (_searchQuery.isNotEmpty &&
                                !FieldQueryUtils.itemMatchesSearch(it, _searchQuery)) {
                              return false;
                            }
                            return true;
                          })
                          .toList();

                      final allFilteredSelected = filteredItems.isNotEmpty &&
                          filteredItems.every((it) => _selectedItemIds.contains(it.id));

                      return Expanded(
                        child: Column(
                          children: [
                            // Toolbar: count & Select All / Deselect All
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    'Items (${_selectedItemIds.length} Selected)',
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  if (filteredItems.isNotEmpty)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: Icon(
                                        allFilteredSelected
                                            ? Icons.deselect_rounded
                                            : Icons.select_all_rounded,
                                        size: 18,
                                      ),
                                      label: Text(allFilteredSelected ? 'Deselect All' : 'Select All'),
                                      onPressed: () {
                                        setState(() {
                                          if (allFilteredSelected) {
                                            for (final it in filteredItems) {
                                              _selectedItemIds.remove(it.id);
                                            }
                                          } else {
                                            for (final it in filteredItems) {
                                              _selectedItemIds.add(it.id);
                                            }
                                          }
                                        });
                                      },
                                    ),
                                  if (_selectedItemIds.isNotEmpty)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () {
                                        setState(() => _selectedItemIds.clear());
                                      },
                                      child: const Text('Clear All'),
                                    ),
                                ],
                              ),
                            ),

                            // Items Reorderable List
                            Expanded(
                              child: filteredItems.isEmpty
                                  ? Center(
                                      child: Text(
                                        allItems.isEmpty
                                            ? 'No items found in this library.'
                                            : 'No items matching your search or filters.',
                                        style: TextStyle(color: theme.hintColor),
                                      ),
                                    )
                                  : Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: ReorderableListView.builder(
                                          buildDefaultDragHandles: false,
                                          itemCount: filteredItems.length,
                                          onReorder: (oldIndex, newIndex) {
                                            setState(() {
                                              if (newIndex > oldIndex) newIndex -= 1;
                                              final movedItem = filteredItems[oldIndex];
                                              _orderedItemIds.remove(movedItem.id);

                                              if (newIndex >= filteredItems.length - 1) {
                                                final targetAfter = filteredItems.last;
                                                final targetIdx =
                                                    _orderedItemIds.indexOf(targetAfter.id);
                                                _orderedItemIds.insert(targetIdx + 1, movedItem.id);
                                              } else {
                                                final targetBefore = filteredItems[newIndex];
                                                final targetIdx =
                                                    _orderedItemIds.indexOf(targetBefore.id);
                                                _orderedItemIds.insert(targetIdx, movedItem.id);
                                              }
                                            });
                                          },
                                          itemBuilder: (ctx, idx) {
                                            final it = filteredItems[idx];
                                            final isSelected = _selectedItemIds.contains(it.id);
                                            final locPath =
                                                _buildLocationPath(it.storageLocationId, locMap);

                                            return ListTile(
                                              key: ValueKey(it.id),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                              leading: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Checkbox(
                                                    value: isSelected,
                                                    onChanged: (val) {
                                                      setState(() {
                                                        if (val == true) {
                                                          _selectedItemIds.add(it.id);
                                                        } else {
                                                          _selectedItemIds.remove(it.id);
                                                        }
                                                      });
                                                    },
                                                  ),
                                                  AppImageView(
                                                    imageUrl: it.primaryImageUrl,
                                                    width: 40,
                                                    height: 40,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ],
                                              ),
                                              title: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      it.name,
                                                      style: TextStyle(
                                                        fontWeight: isSelected
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (it.mustScanIn) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF10B981)
                                                            .withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(
                                                            color: const Color(0xFF10B981)
                                                                .withValues(alpha: 0.4)),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.qr_code_scanner,
                                                              size: 12, color: Color(0xFF10B981)),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            'Must Scan',
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                color: Color(0xFF10B981),
                                                                fontWeight: FontWeight.bold),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              subtitle: Row(
                                                children: [
                                                  if (it.effectiveItemTypeName != 'Generic Item') ...[
                                                    Container(
                                                      margin: const EdgeInsets.only(right: 6),
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 5, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF38BDF8)
                                                            .withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        it.effectiveItemTypeName,
                                                        style: const TextStyle(
                                                          color: Color(0xFF38BDF8),
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      locPath,
                                                      style: theme.textTheme.bodySmall
                                                          ?.copyWith(color: theme.hintColor),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              trailing: Tooltip(
                                                message: 'Drag to reorder',
                                                child: ReorderableDragStartListener(
                                                  index: idx,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    child: const Icon(
                                                      Icons.drag_handle_rounded,
                                                      color: Color(0xFF94A3B8),
                                                      size: 22,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              onTap: () {
                                                setState(() {
                                                  if (isSelected) {
                                                    _selectedItemIds.remove(it.id);
                                                  } else {
                                                    _selectedItemIds.add(it.id);
                                                  }
                                                });
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: Border(
                      top: BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _submit,
                      child: Text(isEditing ? 'Save Changes' : 'Create List'),
                    ),
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
