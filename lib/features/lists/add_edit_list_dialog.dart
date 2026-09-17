import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/widgets/app_image_view.dart';
import '../../models/item_list_model.dart';
import '../../models/storage_location_model.dart';
import '../../state/item_state.dart';
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
  late final TextEditingController _freeTextNoteController;
  late final TextEditingController _borrowerNameController;
  late final TextEditingController _borrowerContactController;
  final TextEditingController _searchController = TextEditingController();

  late ListDestinationType _destinationType;
  String? _selectedLocationId;
  DateTime? _dueDate;
  final Set<String> _selectedItemIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final edit = widget.listToEdit;
    _nameController = TextEditingController(text: edit?.name ?? '');
    _descController = TextEditingController(text: edit?.description ?? '');
    _destinationType = edit?.destinationType ?? ListDestinationType.notRelocating;
    _selectedLocationId = edit?.targetLocationId;
    _freeTextNoteController = TextEditingController(text: edit?.freeTextNote ?? '');
    _borrowerNameController = TextEditingController(text: edit?.borrowerName ?? '');
    _borrowerContactController = TextEditingController(text: edit?.borrowerContact ?? '');
    _dueDate = edit?.dueDate;

    if (edit != null) {
      _selectedItemIds.addAll(edit.items.map((e) => e.itemId));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _freeTextNoteController.dispose();
    _borrowerNameController.dispose();
    _borrowerContactController.dispose();
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final edit = widget.listToEdit;

    // Retain existing entry collection states if editing
    final existingEntriesMap = {
      for (final e in edit?.items ?? <ItemListItemEntry>[]) e.itemId: e
    };

    final entries = _selectedItemIds.map((itemId) {
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
      destinationType: _destinationType,
      targetLocationId: _destinationType == ListDestinationType.storageLocation ? _selectedLocationId : null,
      freeTextNote: _destinationType == ListDestinationType.freeText
          ? (_freeTextNoteController.text.trim().isEmpty ? null : _freeTextNoteController.text.trim())
          : null,
      borrowerName: _destinationType == ListDestinationType.lend
          ? (_borrowerNameController.text.trim().isEmpty ? null : _borrowerNameController.text.trim())
          : null,
      borrowerContact: _destinationType == ListDestinationType.lend
          ? (_borrowerContactController.text.trim().isEmpty ? null : _borrowerContactController.text.trim())
          : null,
      dueDate: _destinationType == ListDestinationType.lend ? _dueDate : null,
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: Form(
          key: _formKey,
          child: Column(
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

              // Scrollable content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
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
                    const SizedBox(height: 14),

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
                    const SizedBox(height: 20),

                    // Destination Setting Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.near_me_rounded, size: 20, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Items Moving To (Destination)',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Decide what happens when an item is collected / ticked on this list.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<ListDestinationType>(
                            initialValue: _destinationType,
                            decoration: const InputDecoration(
                              labelText: 'Destination Mode',
                              prefixIcon: Icon(Icons.swap_horiz_rounded, size: 20),
                            ),
                            items: ListDestinationType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type.displayName),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _destinationType = val);
                              }
                            },
                          ),

                          // Secondary inputs based on mode
                          if (_destinationType == ListDestinationType.storageLocation) ...[
                            const SizedBox(height: 12),
                            locationsAsync.when(
                              data: (locations) {
                                final locMap = {for (final l in locations) l.id: l};
                                return DropdownButtonFormField<String>(
                                  initialValue: _selectedLocationId,
                                  decoration: const InputDecoration(
                                    labelText: 'Target Storage Area *',
                                    prefixIcon: Icon(Icons.folder_outlined, size: 20),
                                  ),
                                  validator: (val) =>
                                      val == null ? 'Please select a storage location' : null,
                                  items: locations.map((loc) {
                                    final path = _buildLocationPath(loc.id, locMap);
                                    return DropdownMenuItem(
                                      value: loc.id,
                                      child: Text(
                                        path,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedLocationId = val);
                                  },
                                );
                              },
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text('Error loading locations: $e'),
                            ),
                          ] else if (_destinationType == ListDestinationType.freeText) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _freeTextNoteController,
                              decoration: const InputDecoration(
                                labelText: 'Temporary Location Note *',
                                hintText: 'e.g. Workbench Bay 2, Van Trunk, Job Site Alpha',
                                prefixIcon: Icon(Icons.edit_location_alt_rounded, size: 20),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Please enter a note' : null,
                            ),
                          ] else if (_destinationType == ListDestinationType.lend) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _borrowerNameController,
                              decoration: const InputDecoration(
                                labelText: 'Borrower Name *',
                                hintText: 'e.g. John Doe',
                                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Borrower name is required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _borrowerContactController,
                              decoration: const InputDecoration(
                                labelText: 'Borrower Contact (Optional)',
                                hintText: 'e.g. +61 400 123 456, email@example.com',
                                prefixIcon: Icon(Icons.phone_outlined, size: 20),
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setState(() => _dueDate = picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Expected Due Date (Optional)',
                                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                                ),
                                child: Text(
                                  _dueDate != null ? DateFormat.yMMMd().format(_dueDate!) : 'No return date specified',
                                  style: TextStyle(
                                    color: _dueDate != null ? theme.textTheme.bodyMedium?.color : theme.hintColor,
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
                    const SizedBox(height: 20),

                    // Item Selection Header
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 20, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Select Items (${_selectedItemIds.length} Selected)',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedItemIds.clear());
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Search box for items
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Filter items by name or code...',
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
                    const SizedBox(height: 12),

                    // Item List Checkboxes
                    itemsAsync.when(
                      loading: () => const Center(child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      )),
                      error: (err, _) => Text('Error loading items: $err'),
                      data: (items) {
                        return locationsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Text('Error loading locations: $err'),
                          data: (locations) {
                            final locMap = {for (final l in locations) l.id: l};

                            final filtered = items.where((it) {
                              if (_searchQuery.isEmpty) return true;
                              return it.name.toLowerCase().contains(_searchQuery) ||
                                  (it.barcode?.toLowerCase().contains(_searchQuery) ?? false) ||
                                  (it.description?.toLowerCase().contains(_searchQuery) ?? false);
                            }).toList();

                            if (filtered.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    items.isEmpty
                                        ? 'No items found in this library.'
                                        : 'No items matching "$_searchQuery"',
                                    style: TextStyle(color: theme.hintColor),
                                  ),
                                ),
                              );
                            }

                            return Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (ctx, idx) {
                                    final it = filtered[idx];
                                    final isSelected = _selectedItemIds.contains(it.id);
                                    final locPath = _buildLocationPath(it.storageLocationId, locMap);

                                    return CheckboxListTile(
                                      value: isSelected,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      secondary: AppImageView(
                                        imageUrl: it.primaryImageUrl,
                                        width: 44,
                                        height: 44,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              it.name,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          if (it.mustScanIn) ...[
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
                                      subtitle: Text(
                                        locPath,
                                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedItemIds.add(it.id);
                                          } else {
                                            _selectedItemIds.remove(it.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
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
