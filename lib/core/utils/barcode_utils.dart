import 'dart:typed_data';
import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

enum BarcodeFormatType {
  qrCode,
  code128,
}

enum LabelSize {
  small, // ~38mm x 21mm (e.g. 65 per sheet / compact)
  medium, // ~63.5mm x 38.1mm (e.g. 21 per sheet / standard address)
  large, // ~99.1mm x 57mm (e.g. 10 per sheet / box label)
}

class BarcodeLabelConfig {
  final BarcodeFormatType formatType;
  final LabelSize labelSize;
  final bool showName;
  final bool showBarcodeText;
  final bool showCutLines;

  const BarcodeLabelConfig({
    this.formatType = BarcodeFormatType.qrCode,
    this.labelSize = LabelSize.medium,
    this.showName = true,
    this.showBarcodeText = true,
    this.showCutLines = true,
  });

  BarcodeLabelConfig copyWith({
    BarcodeFormatType? formatType,
    LabelSize? labelSize,
    bool? showName,
    bool? showBarcodeText,
    bool? showCutLines,
  }) {
    return BarcodeLabelConfig(
      formatType: formatType ?? this.formatType,
      labelSize: labelSize ?? this.labelSize,
      showName: showName ?? this.showName,
      showBarcodeText: showBarcodeText ?? this.showBarcodeText,
      showCutLines: showCutLines ?? this.showCutLines,
    );
  }
}

class BarcodeLabelItem {
  final String id;
  final String name;
  final String barcode;
  final String? barcodeType;
  final bool isLocation;
  final DateTime? barcodeGeneratedAt;
  final DateTime? barcodeLastPrintedAt;

  BarcodeLabelItem({
    required this.id,
    required this.name,
    required this.barcode,
    this.barcodeType,
    required this.isLocation,
    this.barcodeGeneratedAt,
    this.barcodeLastPrintedAt,
  });

  /// Logic: Default to selected if generated since last printed, or never printed
  bool get isNewlyGenerated {
    if (barcodeGeneratedAt == null) return false;
    if (barcodeLastPrintedAt == null) return true;
    return barcodeGeneratedAt!.isAfter(barcodeLastPrintedAt!);
  }
}

class BarcodeUtils {
  static const _uuid = Uuid();

  /// Generate a unique, human-readable barcode for a storage area
  static String generateLocationBarcode() {
    final short = _uuid.v4().substring(0, 8).toUpperCase();
    return 'PT-LOC-$short';
  }

  /// Generate a unique, human-readable barcode for an item
  static String generateItemBarcode() {
    final short = _uuid.v4().substring(0, 8).toUpperCase();
    return 'PT-ITM-$short';
  }

  /// Map format type enum to Barcode object from the barcode package
  static Barcode getBarcodeObject(BarcodeFormatType type) {
    switch (type) {
      case BarcodeFormatType.qrCode:
        return Barcode.qrCode();
      case BarcodeFormatType.code128:
        return Barcode.code128();
    }
  }

  /// Generate a print-ready PDF containing labels arranged in a grid with physical cut guides
  static Future<Uint8List> generateLabelsPdf({
    required List<BarcodeLabelItem> items,
    required BarcodeLabelConfig config,
  }) async {
    final doc = pw.Document();

    final barcodeObj = getBarcodeObject(config.formatType);

    // Physical dimensions according to label size (in mm converted to PDF points: 1 pt = 1/72 inch, 1 mm = 72/25.4 pt = 2.8346 pt)
    const mmToPt = 72.0 / 25.4;
    double labelWidthPt;
    double labelHeightPt;
    int columns;
    int rows;

    switch (config.labelSize) {
      case LabelSize.small:
        labelWidthPt = 38.0 * mmToPt;
        labelHeightPt = 21.2 * mmToPt;
        columns = 5;
        rows = 13;
        break;
      case LabelSize.medium:
        labelWidthPt = 63.5 * mmToPt;
        labelHeightPt = 38.1 * mmToPt;
        columns = 3;
        rows = 7;
        break;
      case LabelSize.large:
        labelWidthPt = 99.1 * mmToPt;
        labelHeightPt = 57.0 * mmToPt;
        columns = 2;
        rows = 5;
        break;
    }

    final labelsPerPage = columns * rows;
    final totalPages = (items.isEmpty) ? 1 : (items.length / labelsPerPage).ceil();

    for (var pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * labelsPerPage;
      final pageItems = items.skip(startIndex).take(labelsPerPage).toList();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: columns,
                    childAspectRatio: labelWidthPt / labelHeightPt,
                    children: List.generate(pageItems.length, (index) {
                      final item = pageItems[index];
                      return pw.Container(
                        decoration: pw.BoxDecoration(
                          border: config.showCutLines
                              ? pw.Border.all(
                                  color: PdfColors.grey400,
                                  width: 0.5,
                                  style: pw.BorderStyle.dashed,
                                )
                              : null,
                        ),
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            if (config.showName) ...[
                              pw.Text(
                                item.name,
                                style: pw.TextStyle(
                                  fontSize: config.labelSize == LabelSize.small ? 7 : 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: pw.TextOverflow.clip,
                              ),
                              pw.SizedBox(height: 2),
                            ],
                            pw.Expanded(
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                child: pw.BarcodeWidget(
                                  barcode: barcodeObj,
                                  data: item.barcode,
                                  drawText: false,
                                ),
                              ),
                            ),
                            if (config.showBarcodeText) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(
                                item.barcode,
                                style: pw.TextStyle(
                                  fontSize: config.labelSize == LabelSize.small ? 6 : 8,
                                  color: PdfColors.grey700,
                                ),
                                maxLines: 1,
                                overflow: pw.TextOverflow.clip,
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Possession Tracker - Printed Labels',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Page ${pageIndex + 1} of $totalPages',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return doc.save();
  }
}
