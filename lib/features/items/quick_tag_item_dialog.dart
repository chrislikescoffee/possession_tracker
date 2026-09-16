import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_image_view.dart';
import '../../models/item_model.dart';
import '../../models/polygon_region.dart';

class QuickTagItemDialog extends StatefulWidget {
  final String libraryId;
  final String storageLocationId;
  final List<NormalizedPoint> points;
  final String? croppedImageUrl;
  final List<Item> unlinkedItems;

  const QuickTagItemDialog({
    super.key,
    required this.libraryId,
    required this.storageLocationId,
    required this.points,
    this.croppedImageUrl,
    this.unlinkedItems = const [],
  });

  @override
  State<QuickTagItemDialog> createState() => _QuickTagItemDialogState();
}

class _QuickTagItemDialogState extends State<QuickTagItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _brandController = TextEditingController();
  final _sizeController = TextEditingController();
  bool _showExtraFields = false;
  bool _isAssigningExisting = false;
  String? _selectedExistingId;

  @override
  void initState() {
    super.initState();
    if (widget.unlinkedItems.isNotEmpty) {
      _selectedExistingId = widget.unlinkedItems.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _brandController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  void _submit({required bool continueIdentifying}) {
    if (_isAssigningExisting && _selectedExistingId != null) {
      final match = widget.unlinkedItems.firstWhere(
        (i) => i.id == _selectedExistingId,
        orElse: () => widget.unlinkedItems.first,
      );
      Navigator.of(context).pop({
        'item': match,
        'isExisting': true,
        'continue': continueIdentifying,
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final customFields = <String, dynamic>{};
    if (_brandController.text.trim().isNotEmpty) {
      customFields['Brand'] = _brandController.text.trim();
    }
    if (_sizeController.text.trim().isNotEmpty) {
      customFields['Size'] = _sizeController.text.trim();
    }

    final newItem = Item(
      id: const Uuid().v4(),
      libraryId: widget.libraryId,
      storageLocationId: widget.storageLocationId,
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      primaryImageUrl: widget.croppedImageUrl,
      polygonPoints: widget.points,
      customFields: customFields,
      status: AppConstants.itemStatusStored,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop({
      'item': newItem,
      'isExisting': false,
      'continue': continueIdentifying,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.crop_free, color: Color(0xFF10B981)),
          SizedBox(width: 10),
          Text('Identify Item'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cropped Thumbnail Preview
                if (widget.croppedImageUrl != null) ...[
                  Row(
                    children: [
                      AppImageView(
                        imageUrl: widget.croppedImageUrl,
                        width: 72,
                        height: 72,
                        borderRadius: BorderRadius.circular(10),
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Auto-Cropped Thumbnail',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Captured from the polygon region on the container photo.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Segmented switcher if unlinked items exist
                if (widget.unlinkedItems.isNotEmpty) ...[
                  SegmentedButton<bool>(
                    segments: [
                      const ButtonSegment<bool>(
                        value: false,
                        label: Text('Create New'),
                        icon: Icon(Icons.add),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Link Existing (${widget.unlinkedItems.length})'),
                        icon: const Icon(Icons.link),
                      ),
                    ],
                    selected: {_isAssigningExisting},
                    onSelectionChanged: (val) {
                      setState(() {
                        _isAssigningExisting = val.first;
                        if (_isAssigningExisting && widget.unlinkedItems.isNotEmpty) {
                          _selectedExistingId ??= widget.unlinkedItems.first.id;
                          final match = widget.unlinkedItems.firstWhere(
                            (i) => i.id == _selectedExistingId,
                            orElse: () => widget.unlinkedItems.first,
                          );
                          _nameController.text = match.name;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                if (_isAssigningExisting && widget.unlinkedItems.isNotEmpty) ...[
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
                        _nameController.text = match.name;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Item Name *',
                      hintText: 'e.g. 12mm Metric Socket, Wire Strippers',
                      prefixIcon: Icon(Icons.inventory_2),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description / Notes (Optional)',
                    hintText: 'e.g. Chrome vanadium, top right slot',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 12),

                if (!_showExtraFields)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Brand or Size fields'),
                    onPressed: () => setState(() => _showExtraFields = true),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _brandController,
                          decoration: const InputDecoration(
                            labelText: 'Brand',
                            hintText: 'e.g. DeWalt',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _sizeController,
                          decoration: const InputDecoration(
                            labelText: 'Size',
                            hintText: 'e.g. 12mm',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
          ),
          onPressed: () => _submit(continueIdentifying: false),
          child: const Text('Tag Item'),
        ),
      ],
    );
  }
}
