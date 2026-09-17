import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/item_list_model.dart';
import '../../models/item_model.dart';
import '../../state/repository_provider.dart';

class ContinuousScannerDialog extends ConsumerStatefulWidget {
  final String listId;
  final String libraryId;
  final ListDestinationType destinationType;
  final Set<String> listItemIds;
  final Future<void> Function(String itemId) onItemTicked;
  final Future<void> Function(String itemId) onItemAddedAndTicked;

  const ContinuousScannerDialog({
    super.key,
    required this.listId,
    required this.libraryId,
    required this.destinationType,
    required this.listItemIds,
    required this.onItemTicked,
    required this.onItemAddedAndTicked,
  });

  @override
  ConsumerState<ContinuousScannerDialog> createState() => _ContinuousScannerDialogState();
}

class _ContinuousScannerDialogState extends ConsumerState<ContinuousScannerDialog> {
  late final MobileScannerController _controller;
  final TextEditingController _manualTextController = TextEditingController();
  final FocusNode _manualFocusNode = FocusNode();

  bool _isProcessing = false;
  String? _lastScannedBarcode;
  DateTime? _lastScannedTime;

  String? _successBannerMessage;
  Timer? _bannerTimer;

  Item? _notOnListItem;

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
    _bannerTimer?.cancel();
    _controller.dispose();
    _manualTextController.dispose();
    _manualFocusNode.dispose();
    super.dispose();
  }

  void _showSuccessBanner(String message) {
    _bannerTimer?.cancel();
    setState(() {
      _successBannerMessage = message;
    });
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _successBannerMessage = null;
        });
      }
    });
  }

  Future<void> _handleBarcodeDetected(String rawBarcode) async {
    final code = rawBarcode.trim();
    if (code.isEmpty || _isProcessing || _notOnListItem != null) return;

    // Debounce duplicate scans within 2 seconds
    final now = DateTime.now();
    if (_lastScannedBarcode == code &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!) < const Duration(seconds: 2)) {
      return;
    }

    _lastScannedBarcode = code;
    _lastScannedTime = now;
    _isProcessing = true;

    try {
      final repo = ref.read(repositoryProvider);
      final allItems = await repo.getItems(widget.libraryId);
      final match = allItems.where((i) {
        final b = i.barcode?.trim();
        return b != null && b.toLowerCase() == code.toLowerCase();
      }).firstOrNull;

      if (!mounted) return;

      if (match == null) {
        HapticFeedback.heavyImpact();
        _showSuccessBanner('Unknown barcode: "$code"');
        _isProcessing = false;
        return;
      }

      // Found matching item
      if (widget.listItemIds.contains(match.id)) {
        // Item is on list -> Tick item!
        HapticFeedback.mediumImpact();
        await widget.onItemTicked(match.id);
        if (mounted) {
          _showSuccessBanner('${match.name} ticked');
        }
      } else {
        // Item is NOT on list -> Show prompt
        HapticFeedback.lightImpact();
        setState(() {
          _notOnListItem = match;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSuccessBanner('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _notOnListItem != null) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _handleBarcodeDetected(raw);
        break;
      }
    }
  }

  void _submitManual() {
    final text = _manualTextController.text.trim();
    if (text.isNotEmpty) {
      _manualTextController.clear();
      _handleBarcodeDetected(text);
    }
  }

  String get _actionButtonText {
    switch (widget.destinationType) {
      case ListDestinationType.lend:
        return 'Lend anyway';
      case ListDestinationType.storageLocation:
      case ListDestinationType.freeText:
        return 'Relocate anyway';
      case ListDestinationType.notRelocating:
        return 'Add to list anyway';
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
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Scanner (Continuous)',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Point at barcodes to collect items',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Done Scanning',
                  ),
                ],
              ),
            ),

            // Camera / Viewport Area with In-Scanner Popups
            Expanded(
              child: Stack(
                children: [
                  // Camera Scanner View
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (ctx, err) {
                      return Container(
                        color: isDark ? Colors.black87 : Colors.grey.shade200,
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_off_rounded, size: 48, color: colorScheme.error),
                            const SizedBox(height: 12),
                            const Text(
                              'Camera feed unavailable',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You can enter codes manually or use a USB scanner below.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.hintColor, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Guideline frame
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.8),
                          width: 2,
                        ),
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

                  // Torch button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: const BoxDecoration(
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

                  // SUCCESS POPUP / BANNER ("ITEM NAME ticked")
                  if (_successBannerMessage != null)
                    Positioned(
                      top: 16,
                      left: 20,
                      right: 20,
                      child: AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF065F46),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _successBannerMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // "NOT ON LIST" POPUP DIALOG OVERLAY
                  if (_notOnListItem != null)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black87,
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 40,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${_notOnListItem!.name} not on list',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This item is currently registered in your library but is not part of this collection list.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _notOnListItem = null;
                                          });
                                        },
                                        child: const Text('Oops, ignore that'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () async {
                                          final itemToAdd = _notOnListItem!;
                                          setState(() {
                                            _notOnListItem = null;
                                          });
                                          await widget.onItemAddedAndTicked(itemToAdd.id);
                                          if (mounted) {
                                            _showSuccessBanner('${itemToAdd.name} added & ticked');
                                          }
                                        },
                                        child: Text(_actionButtonText),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Manual Entry and Done Action
            Container(
              padding: const EdgeInsets.all(16),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualTextController,
                          focusNode: _manualFocusNode,
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Enter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Done Scanning & View List'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
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
