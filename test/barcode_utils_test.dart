import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:possession_tracker/core/utils/barcode_utils.dart';
import 'package:possession_tracker/models/item_model.dart';
import 'package:possession_tracker/models/storage_location_model.dart';

void main() {
  group('BarcodeUtils Code Generation Tests', () {
    test('generateLocationBarcode generates valid format PT-LOC-XXXXXXXX', () {
      final code1 = BarcodeUtils.generateLocationBarcode();
      final code2 = BarcodeUtils.generateLocationBarcode();

      expect(code1.startsWith('PT-LOC-'), isTrue);
      expect(code2.startsWith('PT-LOC-'), isTrue);
      expect(code1, isNot(equals(code2)));
      expect(code1.length, 15); // 'PT-LOC-' (7) + 8 chars = 15
    });

    test('generateItemBarcode generates valid format PT-ITM-XXXXXXXX', () {
      final code1 = BarcodeUtils.generateItemBarcode();
      final code2 = BarcodeUtils.generateItemBarcode();

      expect(code1.startsWith('PT-ITM-'), isTrue);
      expect(code2.startsWith('PT-ITM-'), isTrue);
      expect(code1, isNot(equals(code2)));
      expect(code1.length, 15); // 'PT-ITM-' (7) + 8 chars = 15
    });
  });

  group('BarcodeLabelItem Pre-selection Logic Tests', () {
    test('Newly generated code never printed should be selected', () {
      final item = BarcodeLabelItem(
        id: '1',
        name: 'Drawer 1',
        barcode: 'PT-LOC-ABCD1234',
        isLocation: true,
        barcodeGeneratedAt: DateTime.now(),
        barcodeLastPrintedAt: null,
      );

      expect(item.isNewlyGenerated, isTrue);
    });

    test('Code generated after last print should be selected', () {
      final now = DateTime.now();
      final item = BarcodeLabelItem(
        id: '2',
        name: 'Drill Set',
        barcode: 'PT-ITM-12345678',
        isLocation: false,
        barcodeGeneratedAt: now,
        barcodeLastPrintedAt: now.subtract(const Duration(days: 1)),
      );

      expect(item.isNewlyGenerated, isTrue);
    });

    test('Already printed code should NOT be newly generated', () {
      final now = DateTime.now();
      final item = BarcodeLabelItem(
        id: '3',
        name: 'Drill Set',
        barcode: 'PT-ITM-12345678',
        isLocation: false,
        barcodeGeneratedAt: now.subtract(const Duration(days: 2)),
        barcodeLastPrintedAt: now.subtract(const Duration(days: 1)),
      );

      expect(item.isNewlyGenerated, isFalse);
    });

    test('Scanned commercial barcode (null generatedAt) should NOT be newly generated', () {
      final item = BarcodeLabelItem(
        id: '4',
        name: 'Retail Item',
        barcode: '9312345678901',
        isLocation: false,
        barcodeGeneratedAt: null,
        barcodeLastPrintedAt: null,
      );

      expect(item.isNewlyGenerated, isFalse);
    });
  });

  group('Barcode PDF Generation Tests', () {
    test('generateLabelsPdf generates valid PDF bytes for QR Codes', () async {
      final items = [
        BarcodeLabelItem(
          id: '1',
          name: 'Main Shelf A',
          barcode: 'PT-LOC-AAAA1111',
          isLocation: true,
          barcodeGeneratedAt: DateTime.now(),
        ),
        BarcodeLabelItem(
          id: '2',
          name: 'Impact Driver',
          barcode: 'PT-ITM-BBBB2222',
          isLocation: false,
          barcodeGeneratedAt: DateTime.now(),
        ),
      ];

      const config = BarcodeLabelConfig(
        formatType: BarcodeFormatType.qrCode,
        labelSize: LabelSize.medium,
        showCutLines: true,
      );

      final pdfBytes = await BarcodeUtils.generateLabelsPdf(items: items, config: config);
      expect(pdfBytes.isNotEmpty, isTrue);
      // Verify PDF header magic bytes "%PDF"
      final header = utf8.decode(pdfBytes.take(4).toList());
      expect(header, '%PDF');
    });

    test('generateLabelsPdf generates valid PDF bytes for Code128 across all sizes', () async {
      final items = [
        BarcodeLabelItem(
          id: '1',
          name: 'Cabinet 3',
          barcode: 'PT-LOC-CCCC3333',
          isLocation: true,
        ),
      ];

      for (final size in LabelSize.values) {
        final config = BarcodeLabelConfig(
          formatType: BarcodeFormatType.code128,
          labelSize: size,
          showCutLines: true,
        );

        final pdfBytes = await BarcodeUtils.generateLabelsPdf(items: items, config: config);
        expect(pdfBytes.isNotEmpty, isTrue);
        final header = utf8.decode(pdfBytes.take(4).toList());
        expect(header, '%PDF');
      }
    });
  });

  group('StorageLocation & Item Barcode Model Serialization Tests', () {
    test('StorageLocation serializes and deserializes barcode fields', () {
      final now = DateTime.now();
      final loc = StorageLocation(
        id: 'loc-test',
        libraryId: 'lib-1',
        name: 'Parts Bin',
        barcode: 'PT-LOC-ABCD1234',
        barcodeType: 'qr',
        barcodeGeneratedAt: now,
        barcodeLastPrintedAt: now,
        createdAt: now,
      );

      final json = loc.toJson();
      expect(json['barcode'], 'PT-LOC-ABCD1234');
      expect(json['barcode_type'], 'qr');
      expect(json['barcode_generated_at'], isNotNull);
      expect(json['barcode_last_printed_at'], isNotNull);

      final restored = StorageLocation.fromJson(json);
      expect(restored.barcode, 'PT-LOC-ABCD1234');
      expect(restored.barcodeType, 'qr');
      expect(restored.hasBarcode, isTrue);
      expect(restored.barcodeGeneratedAt?.toIso8601String(), now.toIso8601String());
      expect(restored.barcodeLastPrintedAt?.toIso8601String(), now.toIso8601String());
    });

    test('Item serializes and deserializes barcode fields', () {
      final now = DateTime.now();
      final item = Item(
        id: 'itm-test',
        libraryId: 'lib-1',
        name: 'Cordless Saw',
        barcode: 'PT-ITM-WXYZ9876',
        barcodeType: 'scanned',
        barcodeGeneratedAt: null,
        barcodeLastPrintedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final json = item.toJson();
      expect(json['barcode'], 'PT-ITM-WXYZ9876');
      expect(json['barcode_type'], 'scanned');
      expect(json['barcode_generated_at'], isNull);
      expect(json['barcode_last_printed_at'], isNotNull);

      final restored = Item.fromJson(json);
      expect(restored.barcode, 'PT-ITM-WXYZ9876');
      expect(restored.barcodeType, 'scanned');
      expect(restored.hasBarcode, isTrue);
      expect(restored.barcodeGeneratedAt, isNull);
      expect(restored.barcodeLastPrintedAt?.toIso8601String(), now.toIso8601String());
    });
  });
}
