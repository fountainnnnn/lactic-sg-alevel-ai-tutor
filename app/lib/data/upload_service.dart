import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Picks a photo and uploads it to the private `uploads` bucket under the
/// signed-in user's own `{uid}/` prefix. The path it returns is exactly what the
/// `chat` Edge Function expects as `image_path` (it OCRs the image server-side).
///
/// Storage RLS only lets a user write under their own prefix, so this requires a
/// signed-in user — callers gate on that before invoking.
class UploadService {
  final ImagePicker _picker = ImagePicker();

  /// Opens the picker. Returns the chosen file's bytes (for an instant preview)
  /// or null if the user cancelled.
  Future<XFile?> pick(ImageSource source) =>
      _picker.pickImage(source: source, maxWidth: 2000, imageQuality: 85);

  /// Uploads [bytes] for [file] and returns the storage path.
  /// Throws [StateError] if no user is signed in.
  Future<String> upload(XFile file, Uint8List bytes) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw StateError('sign in required');
    final isPng = file.name.toLowerCase().endsWith('.png');
    final ext = isPng ? 'png' : 'jpg';
    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await Supabase.instance.client.storage.from('uploads').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
              contentType: isPng ? 'image/png' : 'image/jpeg', upsert: false),
        );
    return path;
  }
}
