import 'dart:io';

import 'package:path/path.dart' as p;

/// What a model folder on disk actually contains.
enum LocalModelFormat {
  /// A Cactus-native bundle: `config.txt` plus `*.weights` tensors. This is the
  /// only format the bundled Cactus runtime can load, and it is what the
  /// Cactus model catalog (including Whisper) serves.
  cactusBundle,

  /// One or more `.gguf` files. The bundled Cactus runtime has no GGUF loader
  /// (its native library contains no GGUF code path), so these cannot run
  /// on-device in this build. They remain usable through Ollama or any
  /// OpenAI-compatible server.
  gguf,

  /// No model files at all.
  empty,

  /// Files are present but match neither format, or a bundle is incomplete.
  unrecognized,
}

class ModelBundleInspection {
  final LocalModelFormat format;
  final int weightFileCount;
  final int ggufFileCount;
  final int totalBytes;

  /// Human-readable reason when [isRunnable] is false.
  final String? problem;

  const ModelBundleInspection({
    required this.format,
    this.weightFileCount = 0,
    this.ggufFileCount = 0,
    this.totalBytes = 0,
    this.problem,
  });

  bool get isRunnable => format == LocalModelFormat.cactusBundle;
}

/// Decides, from facts on disk, whether a folder is a model the on-device
/// runtime can load. Replaces earlier GGUF-only checks that rejected every
/// catalog bundle after it had been downloaded.
class ModelBundleValidator {
  const ModelBundleValidator();

  /// Archive artefacts that are not model data: macOS resource forks
  /// (`__MACOSX/` and `._name` AppleDouble files) and hidden files.
  static bool isArchiveJunk(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/').where((s) => s.isNotEmpty);
    return segments.any(
      (segment) =>
          segment == '__MACOSX' ||
          segment.startsWith('._') ||
          segment == '.DS_Store',
    );
  }

  Future<ModelBundleInspection> inspect(Directory directory) async {
    if (!await directory.exists()) {
      return const ModelBundleInspection(
        format: LocalModelFormat.empty,
        problem: 'The model folder does not exist.',
      );
    }
    final files = <File>[];
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: directory.path);
      if (isArchiveJunk(relative)) continue;
      files.add(entity);
    }
    if (files.isEmpty) {
      return const ModelBundleInspection(
        format: LocalModelFormat.empty,
        problem: 'The model folder is empty.',
      );
    }

    var total = 0;
    final weights = <File>[];
    final gguf = <File>[];
    File? config;
    for (final file in files) {
      final name = p.basename(file.path).toLowerCase();
      final length = await file.length();
      total += length;
      if (name == 'config.txt' && p.dirname(file.path) == directory.path) {
        config = file;
      } else if (name.endsWith('.weights')) {
        weights.add(file);
      } else if (name.endsWith('.gguf')) {
        gguf.add(file);
      }
    }

    if (config != null && weights.isNotEmpty) {
      if (await config.length() == 0) {
        return ModelBundleInspection(
          format: LocalModelFormat.unrecognized,
          weightFileCount: weights.length,
          totalBytes: total,
          problem: 'config.txt is empty; the download is incomplete.',
        );
      }
      for (final weight in weights) {
        if (await weight.length() == 0) {
          return ModelBundleInspection(
            format: LocalModelFormat.unrecognized,
            weightFileCount: weights.length,
            totalBytes: total,
            problem: '${p.basename(weight.path)} is empty; the download is '
                'incomplete.',
          );
        }
      }
      return ModelBundleInspection(
        format: LocalModelFormat.cactusBundle,
        weightFileCount: weights.length,
        ggufFileCount: gguf.length,
        totalBytes: total,
      );
    }

    if (gguf.isNotEmpty) {
      return ModelBundleInspection(
        format: LocalModelFormat.gguf,
        ggufFileCount: gguf.length,
        totalBytes: total,
        problem: 'This is a GGUF model. The on-device runtime in this build '
            'only loads Cactus-format bundles from the Model Store. Use it '
            'through Ollama or an OpenAI-compatible server instead.',
      );
    }

    return ModelBundleInspection(
      format: LocalModelFormat.unrecognized,
      weightFileCount: weights.length,
      totalBytes: total,
      problem: config == null
          ? 'config.txt is missing, so this is not a Cactus model bundle.'
          : 'No .weights files were found next to config.txt.',
    );
  }
}
