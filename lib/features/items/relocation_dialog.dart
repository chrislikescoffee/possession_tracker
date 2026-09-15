import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/item_model.dart';
import '../../models/storage_location_model.dart';
import '../../state/repository_provider.dart';

class RelocationDialog extends ConsumerStatefulWidget {
  final Item item;

  const RelocationDialog({super.key, required this.item});

  @override
  ConsumerState<RelocationDialog> createState() => _RelocationDialogState();
}

class _RelocationDialogState extends ConsumerState<RelocationDialog> {
  bool _isTemporary = true;
  final _tempNoteController = TextEditingController();
  String? _selectedLocationId;
  List<StorageLocation> _availableLocations = [];
  bool _isLoadingLocations = true;

  @override
  void initState() {
    super.initState();
    _isTemporary = widget.item.isTemporarilyRelocated || true;
    _tempNoteController.text = widget.item.temporaryLocationNote ?? '';
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final repo = ref.read(repositoryProvider);
    // Flatten all locations in library
    final roots = await repo.getStorageLocations(widget.item.libraryId);
    final all = <StorageLocation>[];
    for (final r in roots) {
      all.add(r);
      final children = await repo.getStorageLocations(widget.item.libraryId, parentId: r.id);
      all.addAll(children);
    }
    if (mounted) {
      setState(() {
        _availableLocations = all;
        _isLoadingLocations = false;
        _selectedLocationId = widget.item.storageLocationId;
      });
    }
  }

  @override
  void dispose() {
    _tempNoteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isTemporary) {
      final note = _tempNoteController.text.trim();
      if (note.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please describe where the item is temporarily located.')),
        );
        return;
      }
      Navigator.of(context).pop({
        'isTemporary': true,
        'note': note,
      });
    } else {
      if (_selectedLocationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select the new permanent storage location.')),
        );
        return;
      }
      Navigator.of(context).pop({
        'isTemporary': false,
        'newLocationId': _selectedLocationId,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.alt_route, color: Color(0xFF6366F1)),
          const SizedBox(width: 8),
          const Text('Relocate Item'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Relocating: ${widget.item.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 16),

              // Toggle between Temporary and Permanent
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Temporary Move'),
                    icon: Icon(Icons.access_time),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Permanent Move'),
                    icon: Icon(Icons.drive_file_move_outlined),
                  ),
                ],
                selected: {_isTemporary},
                onSelectionChanged: (val) => setState(() => _isTemporary = val.first),
              ),
              const SizedBox(height: 20),

              if (_isTemporary) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The canonical home location remains saved. The item will show as temporarily displaced.',
                          style: TextStyle(fontSize: 12, color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _tempNoteController,
                  autofocus: true,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Temporary Location / Note *',
                    hintText: 'e.g. In the car boot, Took to work, On dining table',
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Quick suggestions:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    'In car trunk',
                    'Took to job site',
                    'On workbench',
                    'In backpack',
                  ].map((s) {
                    return ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _tempNoteController.text = s),
                    );
                  }).toList(),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Color(0xFF818CF8)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Permanently reassigns the primary storage container for this item.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF818CF8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoadingLocations)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    value: _selectedLocationId,
                    decoration: const InputDecoration(
                      labelText: 'New Primary Storage Location *',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                    items: _availableLocations.map((loc) {
                      return DropdownMenuItem(
                        value: loc.id,
                        child: Text(loc.name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedLocationId = val),
                  ),
              ],
            ],
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
          child: const Text('Confirm Relocation'),
        ),
      ],
    );
  }
}
