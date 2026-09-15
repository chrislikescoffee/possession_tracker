import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_image_view.dart';
import '../../core/widgets/image_picker_bottom_sheet.dart';
import '../../models/storage_location_model.dart';
import '../../state/repository_provider.dart';

class ReparentLocationDialog extends ConsumerStatefulWidget {
  final StorageLocation currentLocation;
  final List<StorageLocation> allLocations;

  const ReparentLocationDialog({
    super.key,
    required this.currentLocation,
    required this.allLocations,
  });

  @override
  ConsumerState<ReparentLocationDialog> createState() => _ReparentLocationDialogState();
}

class _ReparentLocationDialogState extends ConsumerState<ReparentLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _photoController = TextEditingController();

  bool _isCreatingNewParent = true;
  String? _selectedExistingParentId;
  final Set<String> _selectedSiblingIds = {};

  @override
  void initState() {
    super.initState();
    // Default checked is the current location
    _selectedSiblingIds.add(widget.currentLocation.id);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repo = ref.read(repositoryProvider);

    if (_isCreatingNewParent) {
      if (!_formKey.currentState!.validate()) return;

      final parentName = _nameController.text.trim();
      final parentDesc = _descController.text.trim().isEmpty ? null : _descController.text.trim();
      final photoUrl = _photoController.text.trim().isEmpty ? null : _photoController.text.trim();

      final createdParent = await repo.createParentAbove(
        childLocationIds: _selectedSiblingIds.toList(),
        libraryId: widget.currentLocation.libraryId,
        parentName: parentName,
        parentDescription: parentDesc,
        parentImageUrl: photoUrl,
      );

      if (mounted) {
        Navigator.of(context).pop(createdParent);
      }
    } else {
      if (_selectedExistingParentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a parent location')),
        );
        return;
      }

      await repo.reparentLocation(
        locationId: widget.currentLocation.id,
        newParentId: _selectedExistingParentId,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Other root locations that can be grouped together
    final otherRootLocations = widget.allLocations
        .where((l) => (l.parentId == null || l.parentId!.isEmpty) && l.id != widget.currentLocation.id)
        .toList();

    // Potential parents (cannot be self or children of self)
    final validParents = widget.allLocations
        .where((l) => l.id != widget.currentLocation.id && l.parentId != widget.currentLocation.id)
        .toList();

    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.drive_file_move_outlined, color: Color(0xFF6366F1)),
          SizedBox(width: 10),
          Text('Add Level Above (Re-parent)'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Move "${widget.currentLocation.name}" under a higher-level container (e.g. Property Address, Site, or Building).',
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),

              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Create New Parent Above'),
                    icon: Icon(Icons.add_circle_outline),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Move Under Existing'),
                    icon: Icon(Icons.folder_shared),
                  ),
                ],
                selected: {_isCreatingNewParent},
                onSelectionChanged: (val) => setState(() => _isCreatingNewParent = val.first),
              ),
              const SizedBox(height: 20),

              if (_isCreatingNewParent) ...[
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'New Overarching Level Name *',
                          hintText: 'e.g. 142 Smith St Farm, Main Homestead, Site A',
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'e.g. 5-acre rural property with workshops and stables',
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Optional Photo
                      if (_photoController.text.isNotEmpty) ...[
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            AppImageView(
                              imageUrl: _photoController.text,
                              height: 120,
                              width: double.infinity,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            IconButton(
                              icon: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black87,
                                child: Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                              onPressed: () => setState(() => _photoController.clear()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt, color: Color(0xFF06B6D4)),
                        label: Text(_photoController.text.isEmpty
                            ? 'Add Property Photo (Optional)'
                            : 'Change Photo'),
                        onPressed: () async {
                          final picked = await ImagePickerBottomSheet.show(context);
                          if (picked != null) {
                            setState(() => _photoController.text = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Sibling Multi-select
                      if (otherRootLocations.isNotEmpty) ...[
                        const Text(
                          'Also group these existing root locations under this new parent:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF182238),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF263352)),
                          ),
                          child: Column(
                            children: otherRootLocations.map((loc) {
                              final isChecked = _selectedSiblingIds.contains(loc.id);
                              return CheckboxListTile(
                                dense: true,
                                title: Text(loc.name),
                                value: isChecked,
                                activeColor: const Color(0xFF6366F1),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedSiblingIds.add(loc.id);
                                    } else {
                                      _selectedSiblingIds.remove(loc.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                // Move Under Existing
                if (validParents.isEmpty)
                  const Text('No other valid storage locations to move under.')
                else
                  DropdownButtonFormField<String>(
                    value: _selectedExistingParentId,
                    decoration: const InputDecoration(
                      labelText: 'Select New Parent Location *',
                      prefixIcon: Icon(Icons.folder_open),
                    ),
                    items: validParents.map((loc) {
                      return DropdownMenuItem(
                        value: loc.id,
                        child: Text(loc.name),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedExistingParentId = val),
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
          child: Text(_isCreatingNewParent ? 'Create Parent & Re-group' : 'Move Location'),
        ),
      ],
    );
  }
}
