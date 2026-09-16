import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../models/polygon_region.dart';
import '../../core/widgets/app_image_view.dart';
import '../../core/widgets/image_picker_bottom_sheet.dart';
import '../../models/field_definition_model.dart';
import '../../models/item_model.dart';
import '../../models/item_type_model.dart';
import '../../state/item_type_state.dart';
import 'typed_field_input_widget.dart';

class ItemDialogResult {
  final Item? item;
  final List<NormalizedPoint>? polygonPoints;
  final int? colorHex;
  final bool isDrawRequested;
  final String? draftName;
  final String? draftDescription;
  final String? draftItemTypeId;

  const ItemDialogResult({
    this.item,
    this.polygonPoints,
    this.colorHex,
    this.isDrawRequested = false,
    this.draftName,
    this.draftDescription,
    this.draftItemTypeId,
  });
}

class AddEditItemDialog extends ConsumerStatefulWidget {
  final String libraryId;
  final String? initialLocationId;
  final Item? itemToEdit;
  final bool allowDraw;
  final String? initialName;
  final String? initialDescription;
  final String? initialItemTypeId;
  final int? initialColorHex;
  final List<NormalizedPoint>? initialPolygonPoints;

  const AddEditItemDialog({
    super.key,
    required this.libraryId,
    this.initialLocationId,
    this.itemToEdit,
    this.allowDraw = false,
    this.initialName,
    this.initialDescription,
    this.initialItemTypeId,
    this.initialColorHex,
    this.initialPolygonPoints,
  });

  @override
  ConsumerState<AddEditItemDialog> createState() => _AddEditItemDialogState();
}

class _AddEditItemDialogState extends ConsumerState<AddEditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final _imageUrlController = TextEditingController();

  String? _selectedItemTypeId;
  String? _selectedItemTypeName;
  late int _selectedColorHex;
  List<NormalizedPoint>? _polygonPoints;

  static const List<int> _paletteColors = [
    0xFF10B981, // Emerald
    0xFF06B6D4, // Cyan
    0xFFF59E0B, // Amber
    0xFF6366F1, // Indigo
    0xFFA855F7, // Purple
    0xFFF43F5E, // Rose
  ];

  // Active field definitions (from item type or ad-hoc)
  final List<FieldDefinition> _fieldDefinitions = [];
  final Map<String, dynamic> _fieldValues = {};
  final Set<String> _typeManagedFieldNames = {};
  bool _hasSyncedInitialType = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialName ?? widget.itemToEdit?.name ?? '',
    );
    _descController = TextEditingController(
      text: widget.initialDescription ?? widget.itemToEdit?.description ?? '',
    );
    _selectedItemTypeId = widget.initialItemTypeId ?? widget.itemToEdit?.itemTypeId ?? 'generic';
    _selectedColorHex = widget.initialColorHex ?? _paletteColors.first;
    _polygonPoints = widget.initialPolygonPoints ?? widget.itemToEdit?.polygonPoints;

    if (widget.itemToEdit != null) {
      final it = widget.itemToEdit!;
      _imageUrlController.text = it.primaryImageUrl ?? '';
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

  void _requestDraw() {
    Navigator.of(context).pop(
      ItemDialogResult(
        isDrawRequested: true,
        draftName: _nameController.text.trim(),
        draftDescription: _descController.text.trim(),
        draftItemTypeId: _selectedItemTypeId,
        colorHex: _selectedColorHex,
        polygonPoints: _polygonPoints,
      ),
    );
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
      polygonPoints: _polygonPoints ?? widget.itemToEdit?.polygonPoints ?? [],
      customFields: _fieldValues,
      isTemporarilyRelocated: widget.itemToEdit?.isTemporarilyRelocated ?? false,
      temporaryLocationNote: widget.itemToEdit?.temporaryLocationNote,
      temporaryLocationId: widget.itemToEdit?.temporaryLocationId,
      status: widget.itemToEdit?.status ?? AppConstants.itemStatusStored,
      createdAt: widget.itemToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (widget.allowDraw) {
      Navigator.of(context).pop(
        ItemDialogResult(
          item: item,
          polygonPoints: _polygonPoints,
          colorHex: _selectedColorHex,
        ),
      );
    } else {
      Navigator.of(context).pop(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemToEdit != null;
    final itemTypesAsync = ref.watch(itemTypesForLibraryProvider(widget.libraryId));
    final hasDrawnPoints = _polygonPoints != null && _polygonPoints!.isNotEmpty;

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

                // Drawing Configuration (When opened inside a storage area canvas)
                if (widget.allowDraw) ...[
                  // Color Choice Palette
                  const Text(
                    'Item Tag Color',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _paletteColors.map((hex) {
                      final isSelected = _selectedColorHex == hex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColorHex = hex),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Color(hex).withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  if (hasDrawnPoints) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Polygon outline attached (${_polygonPoints!.length} points)',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                            tooltip: 'Clear Polygon',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _polygonPoints = null),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Draw Item Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                        foregroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF10B981)),
                        ),
                      ),
                      icon: Icon(
                        hasDrawnPoints ? Icons.refresh : Icons.gesture,
                        size: 18,
                      ),
                      label: Text(
                        hasDrawnPoints ? 'Redraw Item Outline' : 'Draw Item on Photo',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _requestDraw,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

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
