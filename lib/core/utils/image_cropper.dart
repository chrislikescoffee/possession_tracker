import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import '../../models/polygon_region.dart';

class ImageCropperUtils {
  /// Crops the area defined by [points] from [sourceImageUrl] and returns a Base64 data URL (`data:image/png;base64,...`).
  /// Works with both Base64 data URLs and network URLs (`http://`, `https://`).
  /// A slight [paddingPercent] (default 4%) is added around the bounding box for context.
  static Future<String?> cropRegionFromImage({
    required String? sourceImageUrl,
    required List<NormalizedPoint> points,
    double paddingPercent = 0.04,
  }) async {
    if (sourceImageUrl == null || sourceImageUrl.trim().isEmpty || points.length < 3) {
      return null;
    }

    try {
      // 1. Get raw image bytes
      Uint8List bytes;
      final trimmed = sourceImageUrl.trim();
      if (trimmed.startsWith('data:image/') || trimmed.contains(';base64,')) {
        final commaIdx = trimmed.indexOf(',');
        final base64Str = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
        bytes = base64Decode(base64Str);
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final resp = await http.get(Uri.parse(trimmed));
        if (resp.statusCode != 200) return null;
        bytes = resp.bodyBytes;
      } else {
        return null;
      }

      // 2. Decode into ui.Image
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      final imgWidth = image.width.toDouble();
      final imgHeight = image.height.toDouble();

      if (imgWidth <= 0 || imgHeight <= 0) return null;

      // 3. Compute normalized bounding box
      double minX = 1.0;
      double maxX = 0.0;
      double minY = 1.0;
      double maxY = 0.0;

      for (final pt in points) {
        minX = math.min(minX, pt.x);
        maxX = math.max(maxX, pt.x);
        minY = math.min(minY, pt.y);
        maxY = math.max(maxY, pt.y);
      }

      final boxWidth = maxX - minX;
      final boxHeight = maxY - minY;

      // Add safety padding
      final padX = boxWidth * paddingPercent;
      final padY = boxHeight * paddingPercent;

      final cropLeft = ((minX - padX) * imgWidth).clamp(0.0, imgWidth - 1);
      final cropTop = ((minY - padY) * imgHeight).clamp(0.0, imgHeight - 1);
      final cropRight = ((maxX + padX) * imgWidth).clamp(1.0, imgWidth);
      final cropBottom = ((maxY + padY) * imgHeight).clamp(1.0, imgHeight);

      final cropWidth = (cropRight - cropLeft).clamp(10.0, imgWidth);
      final cropHeight = (cropBottom - cropTop).clamp(10.0, imgHeight);

      // 4. Render cropped region to a new Canvas
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final srcRect = Rect.fromLTWH(cropLeft, cropTop, cropWidth, cropHeight);
      final dstRect = Rect.fromLTWH(0, 0, cropWidth, cropHeight);

      canvas.drawImageRect(
        image,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.medium,
      );

      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(cropWidth.toInt(), cropHeight.toInt());
      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final croppedBase64 = base64Encode(byteData.buffer.asUint8List());
      return 'data:image/png;base64,$croppedBase64';
    } catch (_) {
      return null;
    }
  }
}
