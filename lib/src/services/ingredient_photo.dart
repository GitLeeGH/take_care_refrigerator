import 'local_expiry_reminders.dart';
import 'expiry_compatibility.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

String newIngredientUuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class IngredientPhotoDraft {
  IngredientPhotoDraft(this.bytes) {
    if (bytes.length > 5 * 1024 * 1024 || bytes.length < 8) {
      throw const FormatException('사진은 5MB 이하의 JPEG 또는 PNG여야 합니다.');
    }
    final png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (List.generate(8, (i) => bytes[i] == png[i]).every((v) => v)) {
      extension = 'png';
      mime = 'image/png';
    } else if (bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) {
      extension = 'jpg';
      mime = 'image/jpeg';
    } else {
      throw const FormatException('JPEG 또는 PNG 사진을 선택해 주세요.');
    }
  }
  final Uint8List bytes;
  late final String extension;
  late final String mime;
}

abstract interface class IngredientPhotoGateway {
  Future<void> upload(String path, IngredientPhotoDraft photo);
  Future<Map<String, dynamic>?> read(String id);
  Future<void> save(Map<String, dynamic> data, bool editing);
  Future<void> remove(String path);
}

class SupabaseIngredientPhotoGateway implements IngredientPhotoGateway {
  SupabaseIngredientPhotoGateway(this.client);
  final SupabaseClient client;
  @override
  Future<void> upload(String path, IngredientPhotoDraft photo) async {
    await client.storage
        .from('ingredient-photos')
        .uploadBinary(
          path,
          photo.bytes,
          fileOptions: FileOptions(contentType: photo.mime, upsert: false),
        );
  }

  @override
  Future<Map<String, dynamic>?> read(String id) => client
      .from('ingredients')
      .select()
      .eq('id', id)
      .eq('user_id', client.auth.currentUser!.id)
      .maybeSingle();
  @override
  Future<void> save(Map<String, dynamic> data, bool editing) async {
    validateLegacyExpiryWrite(data, editing: editing);
    if (editing) {
      await guardLocalExpiryInventoryMutation(data['user_id'] as String, () => client
          .from('ingredients')
          .update(data)
          .eq('id', data['id'])
          .eq('user_id', data['user_id'])
          .select('id')
          .single());
    } else {
      // Stable client ID makes a lost insert response safe to retry.
      await client
          .from('ingredients')
          .upsert(data, onConflict: 'id')
          .select('id')
          .single();
    }
  }

  @override
  Future<void> remove(String path) async {
    await client.storage.from('ingredient-photos').remove([path]);
  }
}

/// A retry keeps the exact same record and photo identity. Never remove a photo
/// after an uncertain database response: it might already be referenced.
class IngredientSaveOperation {
  IngredientSaveOperation({
    required this.gateway,
    required Map<String, dynamic> data,
    required this.editing,
    this.photo,
    this.oldPath,
    this.stillValid,
  }) : data = Map.of(data) {
    if (photo != null) {
      this.data['image_path'] =
          '${data['user_id']}/${data['id']}/${newIngredientUuid()}.${photo!.extension}';
    }
  }
  final IngredientPhotoGateway gateway;
  final Map<String, dynamic> data;
  final bool editing;
  final IngredientPhotoDraft? photo;
  final String? oldPath;
  final bool Function()? stillValid;
  bool _invalidated = false;
  void _checkSession() {
    if (_invalidated || !(stillValid?.call() ?? true)) {
      _invalidated = true;
      throw StateError('Save session changed');
    }
  }

  bool _uploaded = false;
  bool _writeAttempted = false;
  Future<bool>? _pending;
  Future<bool> save() =>
      _pending ??= _save().whenComplete(() => _pending = null);
  bool _matches(Map<String, dynamic>? row) =>
      row != null &&
      data.entries
          .where((e) => e.key != 'created_at')
          .every((e) => row[e.key] == e.value);
  Future<bool> _save() async {
    _checkSession();
    if (photo != null || data.containsKey('expiry_date')) {
      validateLegacyExpiryWrite(data, editing: editing);
    }

    if (_writeAttempted && _matches(await gateway.read(data['id']))) {
      return _cleanOldPhoto();
    }
    _checkSession();
    if (photo != null && !_uploaded) {
      try {
        await gateway.upload(data['image_path'], photo!);
        _uploaded = true;
      } catch (_) {
        // No DB write has started, so this newly allocated object cannot be
        // committed by this operation. Cleanup failure is safe and private.
        try {
          _checkSession();
          await gateway.remove(data['image_path']);
        } catch (_) {}
        rethrow;
      }
    }
    _checkSession();
    _writeAttempted = true;
    try {
      await gateway.save(data, editing);
    } catch (_) {
      _checkSession();
      if (!_matches(await gateway.read(data['id']))) rethrow;
    }
    return _cleanOldPhoto();
  }

  Future<bool> _cleanOldPhoto() async {
    _checkSession();
    if (oldPath != null && oldPath != data['image_path']) {
      try {
        await gateway.remove(oldPath!);
      } catch (_) {
        return false;
      }
    }
    return true;
  }
}
