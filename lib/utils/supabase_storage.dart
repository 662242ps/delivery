import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

const String kSupabaseBucket = 'avatars';

String _guessMime(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    default:
      return 'application/octet-stream';
  }
}

Future<String?> uploadImageToSupabase({
  required File file,
  required String path,
  String bucket = kSupabaseBucket,
}) async {
  final client = Supabase.instance.client;
  final storage = client.storage;
  final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
  final mime = _guessMime(cleanPath);

  try {
    final bytes = await file.readAsBytes();
    await storage.from(bucket).uploadBinary(
          cleanPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            cacheControl: '3600',
            contentType: mime,
          ),
        );
  } on StorageException {
    await storage.from(bucket).upload(
          cleanPath,
          file,
          fileOptions: FileOptions(
            upsert: true,
            cacheControl: '3600',
            contentType: mime,
          ),
        );
  }

  return storage.from(bucket).getPublicUrl(cleanPath);
}
