import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Owns an extracted model file for Interpreter.fromFile. File-backed model
/// loading avoids the native buffer allocated by tflite_flutter.fromBuffer.
/// Windows retains the path until interpreter close; Android can unlink it
/// after mapping while the native interpreter retains the mapped pages.
class ModelAssetFile {
  ModelAssetFile._(this.directory, this.file);
  final Directory directory;
  final File file;
  Future<void>? _deleting;

  static Future<ModelAssetFile> create(
    String asset, {
    AssetBundle? bundle,
    Future<Directory> Function()? cacheDirectory,
  }) async {
    final data = await (bundle ?? rootBundle).load(asset);
    final cache = await (cacheDirectory ?? getTemporaryDirectory)();
    final directory = await cache.createTemp('money_model_');
    final file = File('${directory.path}/model.tflite');
    final owned = ModelAssetFile._(directory, file);
    try {
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      return owned;
    } catch (_) {
      await owned.delete();
      rethrow;
    }
  }

  // POSIX mappings remain valid after unlink. Avoid abandoned cache files if
  // Android later kills the app without running Dart dispose callbacks.
  Future<void> releaseMappedPath() async {
    if (Platform.isAndroid || Platform.isLinux) await delete();
  }

  Future<void> delete() => _deleting ??= _delete();

  Future<void> _delete() async {
    if (await file.exists()) await file.delete();
    // Only the exact file and directory created above are removed.
    if (await directory.exists()) await directory.delete();
  }
}
