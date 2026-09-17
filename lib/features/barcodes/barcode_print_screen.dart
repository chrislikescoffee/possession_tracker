import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/utils/barcode_utils.dart';
import '../../models/item_model.dart';
import '../../models/storage_location_model.dart';
import '../../state/item_state.dart';
import '../../state/library_state.dart';
import '../../state/repository_provider.dart';
import '../../state/storage_state.dart';

class BarcodePrintScreen extends ConsumerStatefulWidget {
  const BarcodePrintScreen({super.key});

  @override
  ConsumerState<BarcodePrintScreen> createState() => _BarcodePrintScreenState();
}

class _BarcodePrintScreenState extends ConsumerState<BarcodePrintScreen> {
  final Set<String> _selectedIds = {};
  bool _hasInitializedSelection = false;

  BarcodeFormatType _formatType = BarcodeFormatType.qrCode;
  LabelSize _labelSize = LabelSize.medium;
  bool _showName = true;
  bool _showBarcodeText = true;
  bool _showCutLines = true;

  @override
  Widget build(BuildContext context) {
    final selectedLib = ref.watch(selectedLibraryProvider).value;

    if (selectedLib == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Print Barcodes / QR Codes')),
        body: const Center(child: Text('No active library selected')),
      );
    }

    final locationsAsync = ref.watch(allStorageLocationsProvider);
    final itemsAsync = ref.watch(libraryItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Barcodes & QR Codes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Print & Cut Instructions',
            onPressed: () => _showInstructionsDialog(context),
          ),
        ],
      ),
      body: locationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error loading locations: $err')),
        data: (allLocations) {
          return itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('Error loading items: $err')),
            data: (allItems) {
              // Filter to locations & items that actually have barcodes
              final List<BarcodeLabelItem> labelItems = [];

              for (final loc in allLocations) {
                if (loc.barcode != null && loc.barcode!.trim().isNotEmpty) {
                  labelItems.add(
                    BarcodeLabelItem(
                      id: loc.id,
                      name: loc.name,
                      barcode: loc.barcode!.trim(),
                      barcodeType: loc.barcodeType,
                      isLocation: true,
                      barcodeGeneratedAt: loc.barcodeGeneratedAt,
                      barcodeLastPrintedAt: loc.barcodeLastPrintedAt,
                    ),
                  );
                }
              }

              for (final itm in allItems) {
                if (itm.barcode != null && itm.barcode!.trim().isNotEmpty) {
                  labelItems.add(
                    BarcodeLabelItem(
                      id: itm.id,
                      name: itm.name,
                      barcode: itm.barcode!.trim(),
                      barcodeType: itm.barcodeType,
                      isLocation: false,
                      barcodeGeneratedAt: itm.barcodeGeneratedAt,
                      barcodeLastPrintedAt: itm.barcodeLastPrintedAt,
                    ),
                  );
                }
              }

              // Initial selection: Default select newly generated codes that haven't been printed yet
              if (!_hasInitializedSelection) {
                _hasInitializedSelection = true;
                for (final item in labelItems) {
                  if (item.isNewlyGenerated) {
                    _selectedIds.add(item.id);
                  }
                }
              }

              final selectedList = labelItems.where((i) => _selectedIds.contains(i.id)).toList();

              final config = BarcodeLabelConfig(
                formatType: _formatType,
                labelSize: _labelSize,
                showName: _showName,
                showBarcodeText: _showBarcodeText,
                showCutLines: _showCutLines,
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;

                  if (isWide) {
                    return Row(
                      children: [
                        // Left Configuration & Selection panel
                        SizedBox(
                          width: 420,
                          child: _buildControlsAndList(labelItems, allLocations, allItems),
                        ),
                        const VerticalDivider(width: 1),
                        // Right PDF Preview panel
                        Expanded(
                          child: _buildPdfPreview(selectedList, config, allLocations, allItems),
                        ),
                      ],
                    );
                  } else {
                    // Narrow screen: Tabs or segmented layout
                    return DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            tabs: [
                              Tab(
                                icon: const Icon(Icons.checklist_rounded),
                                text: 'Select Labels (${selectedList.length})',
                              ),
                              const Tab(
                                icon: Icon(Icons.picture_as_pdf_rounded),
                                text: 'PDF Preview & Print',
                              ),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildControlsAndList(labelItems, allLocations, allItems),
                                _buildPdfPreview(selectedList, config, allLocations, allItems),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildControlsAndList(
    List<BarcodeLabelItem> allItems,
    List<StorageLocation> allLocations,
    List<Item> items,
  ) {
    final newlyGeneratedCount = allItems.where((i) => i.isNewlyGenerated).length;

    return Column(
      children: [
        // Controls Header
        ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.tune_rounded, color: Color(0xFF38BDF8)),
          title: const Text(
            'Label Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            '${_labelSize.name.toUpperCase()} • ${_formatType == BarcodeFormatType.qrCode ? "QR Code" : "1D Barcode"}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Code Type
                  const Text('Barcode Symbology', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SegmentedButton<BarcodeFormatType>(
                    segments: const [
                      ButtonSegment(
                        value: BarcodeFormatType.qrCode,
                        label: Text('QR Code'),
                        icon: Icon(Icons.qr_code_2),
                      ),
                      ButtonSegment(
                        value: BarcodeFormatType.code128,
                        label: Text('1D Barcode'),
                        icon: Icon(Icons.view_week_outlined),
                      ),
                    ],
                    selected: {_formatType},
                    onSelectionChanged: (set) => setState(() => _formatType = set.first),
                  ),
                  const SizedBox(height: 14),

                  // Label Size
                  const Text('Label Size (Physical Sheet)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SegmentedButton<LabelSize>(
                    segments: const [
                      ButtonSegment(
                        value: LabelSize.small,
                        label: Text('Small\n(38x21mm)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: LabelSize.medium,
                        label: Text('Medium\n(64x38mm)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: LabelSize.large,
                        label: Text('Large\n(99x57mm)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {_labelSize},
                    onSelectionChanged: (set) => setState(() => _labelSize = set.first),
                  ),
                  const SizedBox(height: 12),

                  // Toggles
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('Show Names'),
                        selected: _showName,
                        onSelected: (val) => setState(() => _showName = val),
                      ),
                      FilterChip(
                        label: const Text('Show Code Text'),
                        selected: _showBarcodeText,
                        onSelected: (val) => setState(() => _showBarcodeText = val),
                      ),
                      FilterChip(
                        label: const Text('Cut Lines'),
                        selected: _showCutLines,
                        onSelected: (val) => setState(() => _showCutLines = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),

        const Divider(height: 1),

        // Selection Action Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_selectedIds.length} of ${allItems.length} Selected',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                tooltip: 'Selection Options',
                onSelected: (val) {
                  setState(() {
                    if (val == 'all') {
                      _selectedIds.addAll(allItems.map((i) => i.id));
                    } else if (val == 'none') {
                      _selectedIds.clear();
                    } else if (val == 'unprinted') {
                      _selectedIds.clear();
                      _selectedIds.addAll(allItems.where((i) => i.isNewlyGenerated).map((i) => i.id));
                    }
                  });
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'unprinted',
                    child: Text('Select Unprinted ($newlyGeneratedCount)'),
                  ),
                  const PopupMenuItem(
                    value: 'all',
                    child: Text('Select All'),
                  ),
                  const PopupMenuItem(
                    value: 'none',
                    child: Text('Deselect All'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List of Known Barcodes
        Expanded(
          child: allItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 48, color: Theme.of(context).hintColor),
                        const SizedBox(height: 12),
                        const Text(
                          'No Barcodes or QR Codes Found',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Generate or scan codes when adding or editing items and storage areas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: allItems.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    final isSelected = _selectedIds.contains(item.id);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedIds.add(item.id);
                          } else {
                            _selectedIds.remove(item.id);
                          }
                        });
                      },
                      dense: true,
                      secondary: Icon(
                        item.isLocation ? Icons.folder_outlined : Icons.inventory_2_outlined,
                        color: item.isLocation ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                        size: 22,
                      ),
                      title: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.barcode,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (item.isNewlyGenerated)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                  ),
                                  child: const Text(
                                    'Unprinted',
                                    style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else if (item.barcodeLastPrintedAt != null)
                                Text(
                                  'Printed ${DateFormat.yMd().format(item.barcodeLastPrintedAt!)}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                )
                              else
                                const Text(
                                  'Scanned Code',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPdfPreview(
    List<BarcodeLabelItem> selectedList,
    BarcodeLabelConfig config,
    List<StorageLocation> allLocations,
    List<Item> allItems,
  ) {
    if (selectedList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 56, color: Color(0xFF64748B)),
            const SizedBox(height: 12),
            const Text(
              'No Labels Selected',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select one or more items/areas to generate a printable PDF.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Print Toolbar Action
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1E293B),
          child: Row(
            children: [
              Text(
                '${selectedList.length} Labels Ready for Print',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Mark Selected as Printed'),
                onPressed: () => _markSelectedAsPrinted(selectedList, allLocations, allItems),
              ),
            ],
          ),
        ),

        // Live PDF Preview Widget
        Expanded(
          child: PdfPreview(
            build: (format) => BarcodeUtils.generateLabelsPdf(
              items: selectedList,
              config: config,
            ),
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            actions: [
              PdfPreviewAction(
                icon: const Icon(Icons.done_all_rounded),
                onPressed: (ctx, fn, format) => _markSelectedAsPrinted(selectedList, allLocations, allItems),
              ),
            ],
            onPrinted: (ctx) {
              _markSelectedAsPrinted(selectedList, allLocations, allItems);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _markSelectedAsPrinted(
    List<BarcodeLabelItem> selectedList,
    List<StorageLocation> allLocations,
    List<Item> allItems,
  ) async {
    final now = DateTime.now();
    final repo = ref.read(repositoryProvider);
    final selectedIds = selectedList.map((e) => e.id).toSet();

    for (final loc in allLocations) {
      if (selectedIds.contains(loc.id)) {
        await repo.saveStorageLocation(loc.copyWith(barcodeLastPrintedAt: now));
      }
    }

    for (final itm in allItems) {
      if (selectedIds.contains(itm.id)) {
        await repo.saveItem(itm.copyWith(barcodeLastPrintedAt: now));
      }
    }

    ref.invalidate(allStorageLocationsProvider);
    ref.invalidate(libraryItemsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked ${selectedList.length} labels as printed at ${DateFormat.jm().format(now)}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _showInstructionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.print_rounded, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text('Printing & Label Instructions'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Label Sizes & Sheets',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              '• Small: 38 x 21.2mm (e.g. 65 per A4 sheet)\n'
              '• Medium: 63.5 x 38.1mm (e.g. 21 per A4 sheet)\n'
              '• Large: 99.1 x 57mm (e.g. 10 per A4 sheet)',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 10),
            Text(
              '2. Scissors & Cut Guidelines',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              'If printing onto regular paper or sticker sheets, leave "Cut Lines" enabled to guide your scissors cleanly along borders.',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 10),
            Text(
              '3. Symbology Choice',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              '• QR Codes: Best for phones and webcams, can be scanned from any angle.\n'
              '• 1D Barcodes: Ideal for traditional laser/CCD handheld scanner guns.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
