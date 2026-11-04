import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/model_asset_file.dart';

class TestBundle extends CachingAssetBundle {
  TestBundle(this.data);
  final ByteData data;
  @override
  Future<ByteData> load(String key) async => data;
}

void main() {
  test(
      'Model extraction respects ByteData offsets and deletes only its owned file',
      () async {
    final root = await Directory.systemTemp.createTemp('money_model_test_');
    addTearDown(() => root.delete());
    final raw = Uint8List.fromList([99, 1, 2, 3, 88]);
    final model = await ModelAssetFile.create(
      'fixture.tflite',
      bundle: TestBundle(ByteData.sublistView(raw, 1, 4)),
      cacheDirectory: () async => root,
    );
    expect(await model.file.readAsBytes(), [1, 2, 3]);
    expect(model.file.path.startsWith(root.path), isTrue);
    await model.delete();
    await model.delete();
    expect(await model.file.exists(), isFalse);
    expect(await model.directory.exists(), isFalse);
    expect(await root.list().toList(), isEmpty);
  });

  test('Concurrent model instances own different paths', () async {
    final root = await Directory.systemTemp.createTemp('money_model_test_');
    addTearDown(() => root.delete());
    final bundle = TestBundle(ByteData.sublistView(Uint8List.fromList([1, 2])));
    final first = await ModelAssetFile.create('model',
        bundle: bundle, cacheDirectory: () async => root);
    final second = await ModelAssetFile.create('model',
        bundle: bundle, cacheDirectory: () async => root);
    expect(first.file.path, isNot(second.file.path));
    await first.delete();
    expect(await second.file.readAsBytes(), [1, 2]);
    await second.delete();
  });
}
