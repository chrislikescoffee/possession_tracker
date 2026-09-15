import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/item_model.dart';
import '../../models/polygon_region.dart';
import '../../models/storage_location_model.dart';

class PolygonEditorSheet extends StatefulWidget {
  final List<NormalizedPoint> points;
  final String? initialLabel;
  final int? initialColorHex;
  final List<StorageLocation> unlinkedLocations;
  final List<Item> unlinkedItems;

  const PolygonEditorSheet({
    super.key,
    required this.points,
    this.initialLabel,
    this.initialColorHex,
    this.unlinkedLocations = const [],
    this.unlinkedItems = const [],
  });

  @override
  State<PolygonEditorSheet> createState() => _PolygonEditorSheetState();
}

class _PolygonEditorSheetState extends State<PolygonEditorSheet> {
  final _labelController = TextEditingController();
  String _linkType = 'location'; // 'location' or 'item'
  int _selectedColor = 0xFF6366F1;
  bool _useCroppedAsDefault = true;

  bool _isAssigningExisting = false;
  String? _selectedExistingId;

  final List<int> _colorPalette = const [
    0xFF6366F1, // Indigo
    0xFF06B6D4, // Cyan
    0xFF10B981, // Emerald
    0xFFF59E0B, // Amber
    0xFFF43F5E, // Rose
    0xFF8B5CF6, // Purple
  ];

  @override
  void initState() {
    super.initState();
    _labelController.text = widget.initialLabel ?? '';
    _selectedColor = widget.initialColorHex ?? _colorPalette.first;

    // If unlinked locations exist and no initial label, default to linking existing
    if (widget.unlinkedLocations.isNotEmpty &&
        (widget.initialLabel == null || widget.initialLabel!.isEmpty)) {
      _isAssigningExisting = true;
      _selectedExistingId = widget.unlinkedLocations.first.id;
      _labelController.text = widget.unlinkedLocations.first.name;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _submit() {
    String label = _labelController.text.trim();
    String? targetLocId;
    String? targetItemId;

    if (_isAssigningExisting && _selectedExistingId != null) {
      if (_linkType == 'location') {
        targetLocId = _selectedExistingId;
        final loc = widget.unlinkedLocations.firstWhere(
          (l) => l.id == _selectedExistingId,
          orElse: () => widget.unlinkedLocations.first,
        );
        if (label.isEmpty) label = loc.name;
      } else {
        targetItemId = _selectedExistingId;
        final it = widget.unlinkedItems.firstWhere(
          (i) => i.id == _selectedExistingId,
          orElse: () => widget.unlinkedItems.first,
        );
        if (label.isEmpty) label = it.name;
      }
    }

    if (label.isEmpty) return;

    final newRegion = PolygonRegion(
      id: const Uuid().v4(),
      label: label,
      points: widget.points,
      colorHex: _selectedColor,
      targetLocationId: targetLocId,
      targetItemId: targetItemId,
    );

    Navigator.of(context).pop({
      'region': newRegion,
      'linkType': _linkType,
      'isAssigningExisting': _isAssigningExisting,
      'existingId': _selectedExistingId,
      'selectedExistingLocationId':
          (_linkType == 'location' && _isAssigningExisting) ? _selectedExistingId : null,
      'selectedExistingItemId':
          (_linkType == 'item' && _isAssigningExisting) ? _selectedExistingId : null,
      'useCroppedAsDefault': _useCroppedAsDefault,
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasUnlinkedLocations = widget.unlinkedLocations.isNotEmpty;
    final hasUnlinkedItems = widget.unlinkedItems.isNotEmpty;
    final canAssignExisting = (_linkType == 'location' && hasUnlinkedLocations) ||
        (_linkType == 'item' && hasUnlinkedItems);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF131B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(_selectedColor).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.crop_square, color: Color(_selectedColor)),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Map Polygon Region',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Link Type Selection
            const Text(
              'Link Region To',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Sub-Storage Area'),
                    avatar: const Icon(Icons.folder_open, size: 18),
                    selected: _linkType == 'location',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _linkType = 'location';
                          _selectedExistingId = widget.unlinkedLocations.isNotEmpty
                              ? widget.unlinkedLocations.first.id
                              : null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Specific Item'),
                    avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                    selected: _linkType == 'item',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _linkType = 'item';
                          _selectedExistingId = widget.unlinkedItems.isNotEmpty
                              ? widget.unlinkedItems.first.id
                              : null;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mode: Create New vs Assign to Existing Unlinked
            if (canAssignExisting) ...[
              SegmentedButton<bool>(
                segments: [
                  const ButtonSegment<bool>(
                    value: false,
                    label: Text('Create New'),
                    icon: Icon(Icons.add),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(
                      _linkType == 'location'
                          ? 'Assign to Unlinked Area (${widget.unlinkedLocations.length})'
                          : 'Assign to Unlinked Item (${widget.unlinkedItems.length})',
                    ),
                    icon: const Icon(Icons.link),
                  ),
                ],
                selected: {_isAssigningExisting},
                onSelectionChanged: (val) {
                  setState(() {
                    _isAssigningExisting = val.first;
                    if (_isAssigningExisting) {
                      if (_linkType == 'location' && widget.unlinkedLocations.isNotEmpty) {
                        _selectedExistingId = widget.unlinkedLocations.first.id;
                        _labelController.text = widget.unlinkedLocations.first.name;
                      } else if (_linkType == 'item' && widget.unlinkedItems.isNotEmpty) {
                        _selectedExistingId = widget.unlinkedItems.first.id;
                        _labelController.text = widget.unlinkedItems.first.name;
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            if (_isAssigningExisting && canAssignExisting) ...[
              if (_linkType == 'location')
                DropdownButtonFormField<String>(
                  initialValue: _selectedExistingId,
                  decoration: const InputDecoration(
                    labelText: 'Select Existing Unlinked Sub-Area',
                    prefixIcon: Icon(Icons.folder_open),
                  ),
                  items: widget.unlinkedLocations.map((loc) {
                    return DropdownMenuItem(
                      value: loc.id,
                      child: Text(loc.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedExistingId = val;
                      final match = widget.unlinkedLocations.firstWhere(
                        (l) => l.id == val,
                        orElse: () => widget.unlinkedLocations.first,
                      );
                      _labelController.text = match.name;
                    });
                  },
                )
              else
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedExistingId,
                  decoration: const InputDecoration(
                    labelText: 'Select Existing Unlinked Item',
                    prefixIcon: Icon(Icons.inventory_2),
                  ),
                  items: widget.unlinkedItems.map((it) {
                    final isStoredHere = it.storageLocationId != null && it.storageLocationId!.isNotEmpty;
                    return DropdownMenuItem(
                      value: it.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              it.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isStoredHere
                                  ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isStoredHere
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFFFBBF24),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              isStoredHere ? 'In this area' : 'Unallocated',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isStoredHere
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedExistingId = val;
                      final match = widget.unlinkedItems.firstWhere(
                        (i) => i.id == val,
                        orElse: () => widget.unlinkedItems.first,
                      );
                      _labelController.text = match.name;
                    });
                  },
                ),
            ] else ...[
              TextField(
                controller: _labelController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _linkType == 'location' ? 'Sub-Area Name' : 'Item Name',
                  hintText: _linkType == 'location' ? 'e.g. Socket Drawer' : 'e.g. 10mm Wrench',
                  prefixIcon: const Icon(Icons.label_outline),
                ),
              ),
            ],
            const SizedBox(height: 18),

            // Color Selector
            const Text(
              'Accent Color',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 10),
            Row(
              children: _colorPalette.map((c) {
                final isSelected = _selectedColor == c;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _linkType == 'location'
                    ? 'Use cropped area as sub-location photo'
                    : 'Use cropped area as item photo',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Automatically crops this polygon as the default photo for the newly created entity.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              value: _useCroppedAsDefault,
              activeThumbColor: const Color(0xFF10B981),
              onChanged: (val) => setState(() => _useCroppedAsDefault = val),
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
                  child: Text(_isAssigningExisting ? 'Link to Area' : 'Save & Link'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
