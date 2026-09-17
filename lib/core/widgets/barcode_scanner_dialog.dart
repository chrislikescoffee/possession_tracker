import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerDialog extends StatefulWidget {
  final String title;

  const BarcodeScannerDialog({
    super.key,
    this.title = 'Scan Barcode or QR Code',
  });

  /// Static helper to launch the dialog and return the scanned/entered code
  static Future<String?> show(BuildContext context, {String title = 'Scan Barcode or QR Code'}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BarcodeScannerDialog(title: title),
    );
  }

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  late final MobileScannerController _controller;
  final TextEditingController _manualTextController = TextEditingController();
  final FocusNode _manualFocusNode = FocusNode();
  bool _hasDetected = false;
  final bool _cameraError = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualTextController.dispose();
    _manualFocusNode.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _hasDetected = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(rawValue.trim());
        break;
      }
    }
  }

  void _submitManual() {
    final text = _manualTextController.text.trim();
    if (text.isNotEmpty) {
      Navigator.of(context).pop(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Camera Scanner Viewport
            Flexible(
              child: Stack(
                children: [
                  if (!_cameraError)
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) {
                        return Container(
                          color: isDark ? Colors.black87 : Colors.grey.shade200,
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_off_rounded, size: 48, color: colorScheme.error),
                              const SizedBox(height: 12),
                              Text(
                                'Camera not available',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'You can still use manual entry or a USB scanner below.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  // Scanner overlay guideline
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.8), width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Container(
                            width: 180,
                            height: 2,
                            color: colorScheme.primary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Flashlight toggle overlay
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                        tooltip: 'Toggle Flash',
                        onPressed: () => _controller.toggleTorch(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Manual Entry / USB Barcode reader input
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualTextController,
                          focusNode: _manualFocusNode,
                          autofocus: false,
                          decoration: InputDecoration(
                            hintText: 'Or enter / scan code manually...',
                            prefixIcon: const Icon(Icons.keyboard_alt_outlined, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onSubmitted: (_) => _submitManual(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _submitManual,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Use Code'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
