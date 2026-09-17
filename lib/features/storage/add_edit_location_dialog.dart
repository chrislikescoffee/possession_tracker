import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/barcode_utils.dart';
import '../../core/widgets/barcode_scanner_dialog.dart';
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
  final String? draftBarcode;
  final String? draftBarcodeType;
  final DateTime? draftBarcodeGeneratedAt;

  const LocationDialogResult({
    this.location,
    this.polygonPoints,
    this.colorHex,
    this.useCroppedPhoto = true,
    this.isDrawRequested = false,
    this.draftName,
    this.draftDescription,
    this.draftBarcode,
    this.draftBarcodeType,
    this.draftBarcodeGeneratedAt,
  });
}

class AddEditLocationDialog extends StatefulWidget {
  final String libraryId;
  final String? parentId;
  final StorageLocation? locationToEdit;
  final bool allowDraw;
  final String? initialName;
  final String? initialDescription;
  final String? initialBarcode;
  final String? initialBarcodeType;
  final DateTime? initialBarcodeGeneratedAt;
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
    this.initialBarcode,
    this.initialBarcodeType,
    this.initialBarcodeGeneratedAt,
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
  late final TextEditingController _barcodeController;
  final _imageUrlController = TextEditingController();

  String? _barcodeType;
  DateTime? _barcodeGeneratedAt;
  DateTime? _barcodeLastPrintedAt;
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
    _barcodeController = TextEditingController(
      text: widget.initialBarcode ?? widget.locationToEdit?.barcode ?? '',
    );
    _barcodeType = widget.initialBarcodeType ?? widget.locationToEdit?.barcodeType;
    _barcodeGeneratedAt = widget.initialBarcodeGeneratedAt ?? widget.locationToEdit?.barcodeGeneratedAt;
    _barcodeLastPrintedAt = widget.locationToEdit?.barcodeLastPrintedAt;

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
    _barcodeController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _requestDraw() {
    Navigator.of(context).pop(
      LocationDialogResult(
        isDrawRequested: true,
        draftName: _nameController.text.trim(),
        draftDescription: _descController.text.trim(),
        draftBarcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        draftBarcodeType: _barcodeType,
        draftBarcodeGeneratedAt: _barcodeGeneratedAt,
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
      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      barcodeType: _barcodeType,
      barcodeGeneratedAt: _barcodeGeneratedAt,
      barcodeLastPrintedAt: _barcodeLastPrintedAt,
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

    final theme = Theme.of(context);
    final dialogBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerColor;
    final primaryColor = theme.colorScheme.primary;

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      title: Text(
        isEditing ? 'Edit Storage Location' : 'New Storage Location',
        style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
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
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Location Name *',
                    hintText: 'e.g. Shelf A, Tool Box, Cabinet 2',
                    prefixIcon: Icon(Icons.folder_open, color: primaryColor),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Description / Notes',
                    hintText: 'e.g. Second drawer down, holds metric tools',
                    prefixIcon: Icon(Icons.notes, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
                const SizedBox(height: 16),

                // Color Choice Palette
                Text(
                  'Area Tag Color',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
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

                // Barcode / QR Code Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.qr_code_2_rounded, size: 20, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Barcode / QR Code',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          if (_barcodeController.text.isNotEmpty)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                                foregroundColor: const Color(0xFFF43F5E),
                              ),
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              label: const Text('Remove', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                setState(() {
                                  _barcodeController.clear();
                                  _barcodeType = null;
                                  _barcodeGeneratedAt = null;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_barcodeController.text.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: BarcodeWidget(
                                barcode: Barcode.qrCode(),
                                data: _barcodeController.text,
                                width: 64,
                                height: 64,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _barcodeController.text,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _barcodeGeneratedAt != null
                                        ? 'Generated code (Ready to print)'
                                        : 'Scanned / Custom code',
                                    style: TextStyle(
                                      color: _barcodeGeneratedAt != null
                                          ? primaryColor
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                side: BorderSide(color: primaryColor),
                                foregroundColor: primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                              label: const Text('Scan Code', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final scanned = await BarcodeScannerDialog.show(context, title: 'Scan Area Code');
                                if (scanned != null && scanned.isNotEmpty) {
                                  setState(() {
                                    _barcodeController.text = scanned;
                                    _barcodeType = 'scanned';
                                    _barcodeGeneratedAt = null;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                backgroundColor: primaryColor.withValues(alpha: 0.15),
                                foregroundColor: primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                              label: const Text('Generate QR Code', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                setState(() {
                                  _barcodeController.text = BarcodeUtils.generateLocationBarcode();
                                  _barcodeType = 'qr';
                                  _barcodeGeneratedAt = DateTime.now();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                            icon: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
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
                        backgroundColor: primaryColor.withValues(alpha: 0.2),
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: primaryColor),
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
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      title: Text(
                        'Use cropped area as sub-location photo',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Automatically crops the drawn bounding box as cover image',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                      activeColor: primaryColor,
                      value: _useCroppedPhoto,
                      onChanged: (val) =>
                          setState(() => _useCroppedPhoto = val ?? true),
                    ),
                  ),
                ] else ...[
                  // Standard standalone photo button for root locations
                  Text(
                    'Location Photograph',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
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
                        side: BorderSide(color: primaryColor),
                      ),
                      icon: Icon(Icons.camera_alt, color: primaryColor),
                      label: Text(
                        hasImage ? 'Change Photo' : 'Take / Attach Photo',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
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
          child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: theme.colorScheme.onPrimary,
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

