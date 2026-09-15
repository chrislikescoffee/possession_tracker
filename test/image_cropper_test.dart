import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:possession_tracker/core/utils/image_cropper.dart';
import 'package:possession_tracker/models/polygon_region.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCropperUtils Tests', () {
    test('Returns null gracefully for empty or invalid image URLs', () async {
      final res1 = await ImageCropperUtils.cropRegionFromImage(
        sourceImageUrl: null,
        points: [
          const NormalizedPoint(x: 0.1, y: 0.1),
          const NormalizedPoint(x: 0.5, y: 0.1),
          const NormalizedPoint(x: 0.5, y: 0.5),
        ],
      );
      expect(res1, isNull);

      final res2 = await ImageCropperUtils.cropRegionFromImage(
        sourceImageUrl: '',
        points: [],
      );
      expect(res2, isNull);
    });

    test('Successfully crops region from a base64 encoded image', () async {
      // Create a small 200x200 dummy test image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 200, 200),
        Paint()..color = const Color(0xFF6366F1),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 200);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final base64String = base64Encode(byteData!.buffer.asUint8List());
      final dataUrl = 'data:image/png;base64,$base64String';

      // Crop a 50% square in the middle
      final cropped = await ImageCropperUtils.cropRegionFromImage(
        sourceImageUrl: dataUrl,
        points: const [
          NormalizedPoint(x: 0.25, y: 0.25),
          NormalizedPoint(x: 0.75, y: 0.25),
          NormalizedPoint(x: 0.75, y: 0.75),
          NormalizedPoint(x: 0.25, y: 0.75),
        ],
      );

      expect(cropped, isNotNull);
      expect(cropped!.startsWith('data:image/png;base64,'), isTrue);
    });
  });
}
