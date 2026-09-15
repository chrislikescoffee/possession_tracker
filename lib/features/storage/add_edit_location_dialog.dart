import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/widgets/app_image_view.dart';
import '../../core/widgets/image_picker_bottom_sheet.dart';
import '../../models/storage_location_model.dart';

class AddEditLocationDialog extends StatefulWidget {
  final String libraryId;
  final String? parentId;
  final StorageLocation? locationToEdit;

  const AddEditLocationDialog({
    super.key,
    required this.libraryId,
    this.parentId,
    this.locationToEdit,
  });

  @override
  State<AddEditLocationDialog> createState() => _AddEditLocationDialogState();
}

class _AddEditLocationDialogState extends State<AddEditLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _imageUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.locationToEdit != null) {
      _nameController.text = widget.locationToEdit!.name;
      _descController.text = widget.locationToEdit!.description ?? '';
      _imageUrlController.text = widget.locationToEdit!.imageUrl ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final location = StorageLocation(
      id: widget.locationToEdit?.id ?? const Uuid().v4(),
      libraryId: widget.libraryId,
      parentId: widget.parentId ?? widget.locationToEdit?.parentId,
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
      regions: widget.locationToEdit?.regions ?? [],
      createdAt: widget.locationToEdit?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(location);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.locationToEdit != null;
    final hasImage = _imageUrlController.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Storage Location' : 'New Storage Location'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Location Name *',
                    hintText: 'e.g. Garage, Tool Bench, Drawer 1, Box A',
                    prefixIcon: Icon(Icons.folder_open),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description / Notes',
                    hintText: 'e.g. Second drawer down, holds metric tools',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 18),

                // Camera & Photograph Selector
                const Text(
                  'Location Photograph',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (hasImage) ...[
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      AppImageView(
                        imageUrl: _imageUrlController.text,
                        height: 150,
                        width: double.infinity,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.black87,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, size: 18, color: Colors.white),
                            onPressed: () => setState(() => _imageUrlController.clear()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF06B6D4)),
                    ),
                    icon: const Icon(Icons.camera_alt, color: Color(0xFF06B6D4)),
                    label: Text(
                      hasImage ? 'Change Photo (Camera / Gallery)' : 'Take Photo with Camera / Gallery',
                      style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w600),
                    ),
                    onPressed: () async {
                      final picked = await ImagePickerBottomSheet.show(
                        context,
                        currentImageUrl: _imageUrlController.text,
                      );
                      if (picked != null) {
                        setState(() => _imageUrlController.text = picked);
                      }
                    },
                  ),
                ),
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
          child: Text(isEditing ? 'Save Changes' : 'Create Location'),
        ),
      ],
    );
  }
}
