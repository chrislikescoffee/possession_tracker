import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/polygon_region.dart';
import '../../core/widgets/app_image_view.dart';
import '../../core/widgets/image_picker_bottom_sheet.dart';
import '../../models/storage_location_model.dart';

class LocationDialogResult {
  final StorageLocation? location;
  final List<NormalizedPoint>? polygonPoints;
  final int? colorHex;
  final bool useCroppedPhoto;
  final bool isDrawRequested;
  final String? draftName;
  final String? draftDescription;

  const LocationDialogResult({
    this.location,
    this.polygonPoints,
    this.colorHex,
    this.useCroppedPhoto = true,
    this.isDrawRequested = false,
    this.draftName,
    this.draftDescription,
  });
}

class AddEditLocationDialog extends StatefulWidget {
  final String libraryId;
  final String? parentId;
  final StorageLocation? locationToEdit;
  final bool allowDraw;
  final String? initialName;
  final String? initialDescription;
  final int? initialColorHex;
  final List<NormalizedPoint>? initialPolygonPoints;
  final bool initialUseCroppedPhoto;

  const AddEditLocationDialog({
    super.key,
    required this.libraryId,
    this.parentId,
    this.locationToEdit,
    this.allowDraw = false,
    this.initialName,
    this.initialDescription,
    this.initialColorHex,
    this.initialPolygonPoints,
    this.initialUseCroppedPhoto = true,
  });

  @override
  State<AddEditLocationDialog> createState() => _AddEditLocationDialogState();
}

class _AddEditLocationDialogState extends State<AddEditLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final _imageUrlController = TextEditingController();

  late int _selectedColorHex;
  late bool _useCroppedPhoto;
  List<NormalizedPoint>? _polygonPoints;

  static const List<int> _paletteColors = [
    0xFF06B6D4, // Cyan
    0xFF10B981, // Emerald
    0xFFF59E0B, // Amber
    0xFF6366F1, // Indigo
    0xFFA855F7, // Purple
    0xFFF43F5E, // Rose
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialName ?? widget.locationToEdit?.name ?? '',
    );
    _descController = TextEditingController(
      text: widget.initialDescription ?? widget.locationToEdit?.description ?? '',
    );
    _selectedColorHex = widget.initialColorHex ?? _paletteColors.first;
    _useCroppedPhoto = widget.initialUseCroppedPhoto;
    _polygonPoints = widget.initialPolygonPoints;

    if (widget.locationToEdit != null) {
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

  void _requestDraw() {
    Navigator.of(context).pop(
      LocationDialogResult(
        isDrawRequested: true,
        draftName: _nameController.text.trim(),
        draftDescription: _descController.text.trim(),
        colorHex: _selectedColorHex,
        useCroppedPhoto: _useCroppedPhoto,
        polygonPoints: _polygonPoints,
      ),
    );
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

    Navigator.of(context).pop(
      LocationDialogResult(
        location: location,
        polygonPoints: _polygonPoints,
        colorHex: _selectedColorHex,
        useCroppedPhoto: _useCroppedPhoto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.locationToEdit != null;
    final hasImage = _imageUrlController.text.trim().isNotEmpty;
    final hasDrawnPoints = _polygonPoints != null && _polygonPoints!.isNotEmpty;

    return AlertDialog(
      backgroundColor: const Color(0xFF131B2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF263352)),
      ),
      title: Text(
        isEditing ? 'Edit Storage Location' : 'New Storage Location',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Location Name *',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    hintText: 'e.g. Shelf A, Tool Box, Cabinet 2',
                    hintStyle: TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: Icon(Icons.folder_open, color: Color(0xFF38BDF8)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF263352)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                    ),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Description / Notes',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    hintText: 'e.g. Second drawer down, holds metric tools',
                    hintStyle: TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: Icon(Icons.notes, color: Color(0xFF94A3B8)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF263352)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Color Choice Palette
                const Text(
                  'Area Tag Color',
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
                        width: 30,
                        height: 30,
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
                const SizedBox(height: 18),

                // Drawing or Photo Configuration
                if (widget.allowDraw) ...[
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

                  // Draw Area Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                        foregroundColor: const Color(0xFF38BDF8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF06B6D4)),
                        ),
                      ),
                      icon: Icon(
                        hasDrawnPoints ? Icons.refresh : Icons.gesture,
                        size: 18,
                      ),
                      label: Text(
                        hasDrawnPoints ? 'Redraw Area Outline' : 'Draw Area on Photo',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _requestDraw,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Option: Use cropped area as sub-location photo
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF263352)),
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      title: const Text(
                        'Use cropped area as sub-location photo',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: const Text(
                        'Automatically crops the drawn bounding box as cover image',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                      activeColor: const Color(0xFF38BDF8),
                      value: _useCroppedPhoto,
                      onChanged: (val) =>
                          setState(() => _useCroppedPhoto = val ?? true),
                    ),
                  ),
                ] else ...[
                  // Standard standalone photo button for root locations
                  const Text(
                    'Location Photograph',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),

                  if (hasImage) ...[
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        AppImageView(
                          imageUrl: _imageUrlController.text,
                          height: 140,
                          width: double.infinity,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.black87,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close, size: 16, color: Colors.white),
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
                        hasImage ? 'Change Photo' : 'Take / Attach Photo',
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
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _submit,
          child: Text(isEditing ? 'Save Changes' : 'Create Location'),
        ),
      ],
    );
  }
}

