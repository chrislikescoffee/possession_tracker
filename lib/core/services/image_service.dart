import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  static final ImagePicker _picker = ImagePicker();
  static const _uuid = Uuid();

  /// Bucket name for private photo storage
  static const String privateBucketName = 'storage_photos';

  /// Process photo bytes: uploads to private Supabase bucket if authenticated,
  /// otherwise returns an offline-compatible Base64 data URL.
  static Future<String> processPhotoBytes(Uint8List bytes) async {
    try {
      if (Supabase.instance.isInitialized) {
        final client = Supabase.instance.client;
        final currentUser = client.auth.currentUser;

        if (currentUser != null) {
          // Strictly conform to RLS policy: storage_photos/{user_id}/{uuid}.jpg
          final fileName = '${_uuid.v4()}.jpg';
          final storagePath = '${currentUser.id}/$fileName';

          await client.storage.from(privateBucketName).uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

          // Generate a secure temporary signed URL (valid for 30 days)
          final signedUrl = await client.storage
              .from(privateBucketName)
              .createSignedUrl(storagePath, 60 * 60 * 24 * 30);

          return signedUrl;
        }
      }
    } catch (e) {
      debugPrint('Private cloud storage upload failed ($e). Falling back to local offline Base64.');
    }

    // Offline or unauthenticated fallback: Base64 data URL
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  /// Uploads raw bytes directly to the private storage bucket for a given user
  static Future<String?> uploadRawBytesToStorage({
    required Uint8List bytes,
    required String userId,
  }) async {
    try {
      if (Supabase.instance.isInitialized) {
        final client = Supabase.instance.client;
        final fileName = '${_uuid.v4()}.jpg';
        final storagePath = '$userId/$fileName';

        await client.storage.from(privateBucketName).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

        final signedUrl = await client.storage
            .from(privateBucketName)
            .createSignedUrl(storagePath, 60 * 60 * 24 * 30);

        return signedUrl;
      }
    } catch (e) {
      debugPrint('Upload to storage failed: $e');
    }
    return null;
  }

  /// Captures a photo using the device camera.
  static Future<String?> captureFromCamera({
    double maxWidth = 1280,
    double maxHeight = 1280,
    int imageQuality = 80,
  }) async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        requestFullMetadata: false,
      );

      if (xfile == null) return null;

      final bytes = await xfile.readAsBytes();
      return await processPhotoBytes(bytes);
    } catch (e) {
      debugPrint('Camera capture error: $e');
      return null;
    }
  }

  /// Picks a photo from the device photo gallery / file picker.
  static Future<String?> pickFromGallery({
    double maxWidth = 1280,
    double maxHeight = 1280,
    int imageQuality = 80,
  }) async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (xfile == null) return null;

      final bytes = await xfile.readAsBytes();
      return await processPhotoBytes(bytes);
    } catch (e) {
      debugPrint('Gallery pick error: $e');
      return null;
    }
  }
}
