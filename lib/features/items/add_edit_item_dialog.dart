import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_image_view.dart';
import '../../core/widgets/image_picker_bottom_sheet.dart';
import '../../models/field_definition_model.dart';
import '../../models/item_model.dart';
import '../../models/item_type_model.dart';
import '../../state/item_type_state.dart';
import 'typed_field_input_widget.dart';

class AddEditItemDialog extends ConsumerStatefulWidget {
  final String libraryId;
  final String? initialLocationId;
  final Item? itemToEdit;

  const AddEditItemDialog({
    super.key,
    required this.libraryId,
    this.initialLocationId,
    this.itemToEdit,
  });

  @override
  ConsumerState<AddEditItemDialog> createState() => _AddEditItemDialogState();
}

class _AddEditItemDialogState extends ConsumerState<AddEditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String? _selectedItemTypeId;
  String? _selectedItemTypeName;

  // Active field definitions (from item type or ad-hoc)
  final List<FieldDefinition> _fieldDefinitions = [];
  final Map<String, dynamic> _fieldValues = {};
  final Set<String> _typeManagedFieldNames = {};
  bool _hasSyncedInitialType = false;

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      final it = widget.itemToEdit!;
      _nameController.text = it.name;
      _descController.text = it.description ?? '';
      _imageUrlController.text = it.primaryImageUrl ?? '';
      _selectedItemTypeId = it.itemTypeId ?? 'generic';
      _selectedItemTypeName = it.itemTypeName ?? 'Generic Item';

      // Load existing custom fields
      for (final entry in it.customFields.entries) {
        _fieldValues[entry.key] = entry.value;

        // Guess field type if not predefined
        ItemFieldType guessedType = ItemFieldType.text;
        if (entry.value is Map) {
          final m = entry.value as Map;
          if (m.containsKey('height') || m.containsKey('width')) {
            guessedType = ItemFieldType.dimension;
          } else if (m.containsKey('weight')) {
            guessedType = ItemFieldType.weight;
          } else if (m.containsKey('amount')) {
            guessedType = ItemFieldType.currency;
          }
        } else if (entry.value is num) {
          guessedType = ItemFieldType.number;
        }

        _fieldDefinitions.add(
          FieldDefinition(
            id: const Uuid().v4(),
            name: entry.key,
            type: guessedType,
            defaultValue: entry.value,
          ),
        );
      }
    } else {
      _selectedItemTypeId = 'generic';
      _selectedItemTypeName = 'Generic Item';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _syncWithLatestItemType(ItemType selectedType, {bool isManualSwitch = false}) {
    _selectedItemTypeId = selectedType.id;
    _selectedItemTypeName = selectedType.name;

    if (isManualSwitch) {
      // User explicitly changed type dropdown -> remove previous type fields and adopt new type's fields
      _fieldDefinitions.removeWhere(
        (fd) => _typeManagedFieldNames.contains(fd.name.toLowerCase()),
      );
      _fieldDefinitions.insertAll(0, selectedType.fields);
      for (final f in selectedType.fields) {
        if (!_fieldValues.containsKey(f.name) && f.defaultValue != null) {
          _fieldValues[f.name] = f.defaultValue;
        }
      }
    } else {
      // Synchronize definitions (e.g. edited fields in Settings) while preserving filled values
      for (final f in selectedType.fields) {
        final existingIdx = _fieldDefinitions.indexWhere(
          (fd) => fd.name.toLowerCase() == f.name.toLowerCase(),
        );
        if (existingIdx != -1) {
          _fieldDefinitions[existingIdx] = f;
        } else {
          _fieldDefinitions.add(f);
          if (!_fieldValues.containsKey(f.name) && f.defaultValue != null) {
            _fieldValues[f.name] = f.defaultValue;
          }
        }
      }
      if (selectedType.id != 'generic') {
        final currentTypeNames =
            selectedType.fields.map((f) => f.name.toLowerCase()).toSet();
        _fieldDefinitions.removeWhere(
          (fd) =>
              _typeManagedFieldNames.contains(fd.name.toLowerCase()) &&
              !currentTypeNames.contains(fd.name.toLowerCase()),
        );
      }
    }
    _typeManagedFieldNames.clear();
    _typeManagedFieldNames.addAll(
      selectedType.fields.map((f) => f.name.toLowerCase()),
    );
  }

  void _onItemTypeChanged(ItemType? selectedType) {
    if (selectedType == null) return;
    setState(() {
      _syncWithLatestItemType(selectedType, isManualSwitch: true);
    });
  }

  void _addAdHocField() async {
    final nameController = TextEditingController();
    ItemFieldType chosenType = ItemFieldType.text;
    final unitController = TextEditingController();

    final created = await showDialog<FieldDefinition>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Custom Field'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Field Name *',
                  hintText: 'e.g. Serial Number, Voltage, Color',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ItemFieldType>(
                initialValue: chosenType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: ItemFieldType.values.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t.displayName));
                }).toList(),
                onChanged: (t) {
                  if (t != null) {
                    setDialogState(() {
                      chosenType = t;
                      if (t == ItemFieldType.currency) unitController.text = 'AUD';
                      if (t == ItemFieldType.dimension) unitController.text = 'cm';
                      if (t == ItemFieldType.weight) unitController.text = 'kg';
                    });
                  }
                },
              ),
              if (chosenType != ItemFieldType.text && chosenType != ItemFieldType.date) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit / Currency Code (Optional)',
                    hintText: 'e.g. cm, kg, AUD, V',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop(
                  FieldDefinition(
                    id: const Uuid().v4(),
                    name: name,
                    type: chosenType,
                    unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
                  ),
                );
              },
              child: const Text('Add Field'),
            ),
          ],
        ),
      ),
    );

    if (created != null) {
      setState(() {
        _fieldDefinitions.add(created);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final item = Item(
      id: widget.itemToEdit?.id ?? const Uuid().v4(),
      libraryId: widget.libraryId,
      storageLocationId: widget.initialLocationId ?? widget.itemToEdit?.storageLocationId,
      itemTypeId: _selectedItemTypeId,
      itemTypeName: _selectedItemTypeName,
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      primaryImageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
      polygonPoints: widget.itemToEdit?.polygonPoints ?? [],
      customFields: _fieldValues,
      isTemporarilyRelocated: widget.itemToEdit?.isTemporarilyRelocated ?? false,
      temporaryLocationNote: widget.itemToEdit?.temporaryLocationNote,
      temporaryLocationId: widget.itemToEdit?.temporaryLocationId,
      status: widget.itemToEdit?.status ?? AppConstants.itemStatusStored,
      createdAt: widget.itemToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemToEdit != null;
    final itemTypesAsync = ref.watch(itemTypesForLibraryProvider(widget.libraryId));

    return AlertDialog(
      title: Text(isEditing ? 'Edit Item' : 'New Item'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Type Selector Bar
                itemTypesAsync.when(
                  data: (types) {
                    final allTypes = [ItemType.genericItem(widget.libraryId), ...types.where((t) => t.id != 'generic')];
                    final currentSelected = allTypes.firstWhere(
                      (t) => t.id == _selectedItemTypeId,
                      orElse: () => allTypes.first,
                    );

                    if (!_hasSyncedInitialType) {
                      _hasSyncedInitialType = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _syncWithLatestItemType(currentSelected);
                          });
                        }
                      });
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.category_outlined, size: 20, color: Color(0xFF818CF8)),
                          const SizedBox(width: 8),
                          const Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Expanded(
                            child: DropdownButton<ItemType>(
                              value: currentSelected,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E293B),
                              underline: const SizedBox(),
                              items: allTypes.map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text(t.name),
                                );
                              }).toList(),
                              onChanged: _onItemTypeChanged,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => const SizedBox(),
                ),
                const SizedBox(height: 14),

                // Name
                TextFormField(
                  controller: _nameController,
                  autofocus: !isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    hintText: 'e.g. 10mm Deep Socket, Dewalt Driver',
                    prefixIcon: Icon(Icons.inventory_2),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Specifications, notes, or storage tips',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 14),

                // Photo preview & attachment button
                Row(
                  children: [
                    AppImageView(
                      imageUrl: _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
                      width: 54,
                      height: 54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: Text(_imageUrlController.text.isNotEmpty ? 'Change Photo' : 'Attach Photo'),
                        onPressed: () async {
                          final picked = await ImagePickerBottomSheet.show(
                            context,
                            currentImageUrl: _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
                          );
                          if (picked != null) {
                            setState(() => _imageUrlController.text = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Typed Custom Fields Section
                Row(
                  children: [
                    const Icon(Icons.tune, size: 18, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    const Text(
                      'Attributes & Specifications',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Field'),
                      onPressed: _addAdHocField,
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                if (_fieldDefinitions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No custom fields attached yet. Choose an Item Type above or tap + Add Field.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  )
                else
                  for (int i = 0; i < _fieldDefinitions.length; i++) ...[
                    TypedFieldInputWidget(
                      field: _fieldDefinitions[i],
                      initialValue: _fieldValues[_fieldDefinitions[i].name],
                      onChanged: (val) {
                        setState(() {
                          _fieldValues[_fieldDefinitions[i].name] = val;
                        });
                      },
                      onRemove: () {
                        setState(() {
                          final removed = _fieldDefinitions.removeAt(i);
                          _fieldValues.remove(removed.name);
                        });
                      },
                    ),
                  ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Save Changes' : 'Create Item'),
        ),
      ],
    );
  }
}
