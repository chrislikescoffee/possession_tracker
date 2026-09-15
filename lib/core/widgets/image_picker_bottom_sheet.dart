import 'package:flutter/material.dart';
import '../services/image_service.dart';

class ImagePickerBottomSheet extends StatefulWidget {
  final String? currentImageUrl;

  const ImagePickerBottomSheet({super.key, this.currentImageUrl});

  static Future<String?> show(BuildContext context, {String? currentImageUrl}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ImagePickerBottomSheet(currentImageUrl: currentImageUrl),
    );
  }

  @override
  State<ImagePickerBottomSheet> createState() => _ImagePickerBottomSheetState();
}

class _ImagePickerBottomSheetState extends State<ImagePickerBottomSheet> {
  bool _isProcessing = false;
  bool _showUrlInput = false;
  final _urlController = TextEditingController();

  final List<Map<String, String>> _samplePhotos = [
    {
      'label': 'Garage / Workshop',
      'url': 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'label': 'Workbench / Desk',
      'url': 'https://images.unsplash.com/photo-1530124566582-a618bc2615dc?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'label': 'Tool Chest / Drawer',
      'url': 'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'label': 'Organizer Box / Bin',
      'url': 'https://images.unsplash.com/photo-1581244277943-fe4a9c777189?auto=format&fit=crop&w=1200&q=80',
    },
  ];

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleCamera() async {
    setState(() => _isProcessing = true);
    final result = await ImageService.captureFromCamera();
    if (mounted) {
      setState(() => _isProcessing = false);
      if (result != null) {
        Navigator.of(context).pop(result);
      }
    }
  }

  Future<void> _handleGallery() async {
    setState(() => _isProcessing = true);
    final result = await ImageService.pickFromGallery();
    if (mounted) {
      setState(() => _isProcessing = false);
      if (result != null) {
        Navigator.of(context).pop(result);
      }
    }
  }

  void _submitUrl() {
    final text = _urlController.text.trim();
    if (text.isNotEmpty) {
      Navigator.of(context).pop(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF131B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF818CF8)),
              ),
              const SizedBox(width: 12),
              const Text(
                'Add Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_isProcessing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Action Options
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: const Color(0xFF1E293B),
            leading: const Icon(Icons.camera_alt, color: Color(0xFF06B6D4), size: 24),
            title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Capture using device camera with auto WebP/JPEG compression',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            onTap: _isProcessing ? null : _handleCamera,
          ),
          const SizedBox(height: 10),

          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: const Color(0xFF1E293B),
            leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF10B981), size: 24),
            title: const Text('Choose from Photo Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Select an existing photo from your device',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            onTap: _isProcessing ? null : _handleGallery,
          ),
          const SizedBox(height: 10),

          if (!_showUrlInput)
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFF1E293B),
              leading: const Icon(Icons.link, color: Color(0xFF818CF8), size: 24),
              title: const Text('Enter Web Photo URL', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => setState(() => _showUrlInput = true),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'https://...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submitUrl,
                    child: const Text('Use'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Sample template photos
          const Text(
            'Quick Sample Photos:',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _samplePhotos.map((p) {
              return ActionChip(
                avatar: const Icon(Icons.photo_size_select_actual_outlined, size: 14),
                label: Text(p['label']!, style: const TextStyle(fontSize: 11)),
                onPressed: () => Navigator.of(context).pop(p['url']),
              );
            }).toList(),
          ),

          if (widget.currentImageUrl != null && widget.currentImageUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF263352)),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Remove Current Photo', style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.of(context).pop(''),
            ),
          ],
        ],
      ),
    );
  }
}
