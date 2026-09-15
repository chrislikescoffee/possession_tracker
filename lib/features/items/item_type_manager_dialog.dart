import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/field_definition_model.dart';
import '../../models/item_type_model.dart';
import '../../state/item_type_state.dart';
import '../../state/repository_provider.dart';

class ItemTypeManagerDialog extends ConsumerStatefulWidget {
  final String libraryId;
  final ItemType? initialItemType;

  const ItemTypeManagerDialog({
    super.key,
    required this.libraryId,
    this.initialItemType,
  });

  @override
  ConsumerState<ItemTypeManagerDialog> createState() => _ItemTypeManagerDialogState();
}

class _ItemTypeManagerDialogState extends ConsumerState<ItemTypeManagerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedIcon = 'inventory_2';

  final List<FieldDefinition> _fields = [];

  // Icon options
  final List<MapEntry<String, IconData>> _iconOptions = const [
    MapEntry('inventory_2', Icons.inventory_2),
    MapEntry('build', Icons.build),
    MapEntry('palette', Icons.palette),
    MapEntry('terrain', Icons.terrain),
    MapEntry('home', Icons.home),
    MapEntry('kitchen', Icons.kitchen),
    MapEntry('sports', Icons.sports_tennis),
    MapEntry('devices', Icons.devices),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialItemType != null) {
      _nameController.text = widget.initialItemType!.name;
      _descController.text = widget.initialItemType!.description ?? '';
      _selectedIcon = widget.initialItemType!.icon ?? 'inventory_2';
      _fields.addAll(widget.initialItemType!.fields);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _addNewFieldDialog() async {
    final fieldNameController = TextEditingController();
    final unitController = TextEditingController();
    ItemFieldType selectedType = ItemFieldType.text;

    final createdField = await showDialog<FieldDefinition>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Field Definition'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fieldNameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Field Name *',
                  hintText: 'e.g. Price, Voltage, Dimensions, Weight',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ItemFieldType>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Field Type'),
                items: ItemFieldType.values.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text(t.displayName),
                  );
                }).toList(),
                onChanged: (t) {
                  if (t != null) {
                    setDialogState(() {
                      selectedType = t;
                      if (t == ItemFieldType.currency && unitController.text.isEmpty) {
                        unitController.text = 'AUD';
                      } else if (t == ItemFieldType.dimension && unitController.text.isEmpty) {
                        unitController.text = 'cm';
                      } else if (t == ItemFieldType.weight && unitController.text.isEmpty) {
                        unitController.text = 'kg';
                      }
                    });
                  }
                },
              ),
              if (selectedType != ItemFieldType.date && selectedType != ItemFieldType.text) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit / Currency (Optional)',
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
                final name = fieldNameController.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop(
                  FieldDefinition(
                    id: const Uuid().v4(),
                    name: name,
                    type: selectedType,
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

    if (createdField != null) {
      setState(() {
        _fields.add(createdField);
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(repositoryProvider);
    final itemType = ItemType(
      id: widget.initialItemType?.id ?? const Uuid().v4(),
      libraryId: widget.libraryId,
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      icon: _selectedIcon,
      fields: _fields,
      createdAt: widget.initialItemType?.createdAt ?? DateTime.now(),
    );

    final saved = await repo.saveItemType(itemType);
    ref.invalidate(itemTypesProvider);
    ref.invalidate(itemTypesForLibraryProvider);
    if (mounted) {
      Navigator.of(context).pop(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialItemType != null;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.category_outlined, color: Color(0xFF818CF8), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      isEditing ? 'Edit Item Type' : 'Create New Item Type',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name & Icon Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Type Name *',
                          hintText: 'e.g. Power Tool, Pottery Item, Camping Gear',
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Please enter a type name' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedIcon,
                      dropdownColor: const Color(0xFF1E293B),
                      underline: const SizedBox(),
                      items: _iconOptions.map((opt) {
                        return DropdownMenuItem(
                          value: opt.key,
                          child: Icon(opt.value, color: const Color(0xFF818CF8)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedIcon = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Short description of items in this category',
                  ),
                ),
                const SizedBox(height: 20),

                // Field Definitions Section
                Row(
                  children: [
                    const Icon(Icons.list_alt, size: 18, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    const Text(
                      'Defined Fields Schema',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Field'),
                      onPressed: _addNewFieldDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_fields.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Center(
                      child: Text(
                        'No specialized fields defined yet.\nClick Add Field to attach typed attributes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _fields.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final f = _fields[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              f.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                f.type.displayName,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF818CF8)),
                              ),
                            ),
                            if (f.unit != null) ...[
                              const SizedBox(width: 6),
                              Text('(${f.unit})',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              onPressed: () {
                                setState(() => _fields.removeAt(index));
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _submit,
                      child: Text(isEditing ? 'Save Item Type' : 'Create Item Type'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
