import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocketllm_lite/services/model_bundle_validator.dart';

void main() {
  late Directory root;
  const validator = ModelBundleValidator();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pocketllm_bundle_');
  });

  tearDown(() => root.delete(recursive: true));

  Future<File> write(String relative, List<int> bytes) async {
    final file = File(p.join(root.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  test('a Cactus bundle (config.txt + weights) is runnable', () async {
    await write('config.txt', 'precision=INT8\n'.codeUnits);
    await write('layer_0_attn_q.weights', [1, 2, 3]);
    await write('layer_0_attn_q.scale', [1]);
    await write('tokenizer.json', '{}'.codeUnits);

    final result = await validator.inspect(root);
    expect(result.format, LocalModelFormat.cactusBundle);
    expect(result.isRunnable, isTrue);
    expect(result.weightFileCount, 1);
  });

  test('macOS resource-fork junk never counts as model data', () async {
    await write('__MACOSX/._config.txt', [0, 5]);
    await write('._layer_0.weights', [0, 5, 22]);
    await write('.DS_Store', [0]);

    final result = await validator.inspect(root);
    expect(result.format, LocalModelFormat.empty);
    expect(result.isRunnable, isFalse);
  });

  test('junk beside real files is ignored, not mistaken for weights', () async {
    await write('config.txt', 'x=1\n'.codeUnits);
    await write('._layer_0.weights', [0, 5, 22]);

    final result = await validator.inspect(root);
    expect(result.isRunnable, isFalse,
        reason: 'only an AppleDouble file exists, so no weights are present');
    expect(result.problem, contains('.weights'));
  });

  test('a GGUF folder is identified and explained, not called corrupt',
      () async {
    await write('model.Q4_K_M.gguf', [0x47, 0x47, 0x55, 0x46, 3, 0, 0, 0]);

    final result = await validator.inspect(root);
    expect(result.format, LocalModelFormat.gguf);
    expect(result.isRunnable, isFalse);
    expect(result.problem, contains('Ollama'));
    expect(result.problem, contains('Cactus-format'));
  });

  test('an incomplete download (empty config or weights) is not runnable',
      () async {
    await write('config.txt', const []);
    await write('layer_0.weights', [1]);
    var result = await validator.inspect(root);
    expect(result.isRunnable, isFalse);
    expect(result.problem, contains('config.txt is empty'));

    await write('config.txt', 'a=1\n'.codeUnits);
    await write('layer_1.weights', const []);
    result = await validator.inspect(root);
    expect(result.isRunnable, isFalse);
    expect(result.problem, contains('layer_1.weights is empty'));
  });

  test('weights without config.txt are not a bundle', () async {
    await write('layer_0.weights', [1, 2]);
    final result = await validator.inspect(root);
    expect(result.isRunnable, isFalse);
    expect(result.problem, contains('config.txt is missing'));
  });

  test('a missing directory reports empty', () async {
    final result = await validator.inspect(Directory(p.join(root.path, 'no')));
    expect(result.format, LocalModelFormat.empty);
  });

  test('isArchiveJunk matches only archive artefacts', () {
    expect(ModelBundleValidator.isArchiveJunk('__MACOSX/a/._b'), isTrue);
    expect(ModelBundleValidator.isArchiveJunk('dir/._x.weights'), isTrue);
    expect(ModelBundleValidator.isArchiveJunk('layer_0.weights'), isFalse);
    expect(ModelBundleValidator.isArchiveJunk('config.txt'), isFalse);
  });
}
