// Real-device inference probe. Not part of the app and not a unit test.
//
// Downloads a catalog model through the app's own download service, loads it
// with the real Cactus runtime and streams tokens, printing one `PROBE {json}`
// line per measurement. Run on an arm64 device (or an emulator with ARM
// translation, which proves function but not speed):
//
//   flutter run --release -d DEVICE_ID --target-platform android-arm64 \
//     -t tool/device_inference_probe.dart
//   adb logcat -s flutter | grep PROBE
//
// Nothing is uploaded; the only network use is the model download itself.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
// ignore: implementation_imports
import 'package:cactus/src/services/context.dart';
import 'package:pocketllm_lite/services/audio_transcription_service.dart';
import 'package:pocketllm_lite/services/inference_service.dart';
import 'package:pocketllm_lite/services/local_inference_service.dart';
import 'package:pocketllm_lite/services/model_download_service.dart';

const _modelId =
    String.fromEnvironment('MODEL_ID', defaultValue: 'gemma3-270m');
const _modelName =
    String.fromEnvironment('MODEL_NAME', defaultValue: 'Gemma 3 270M');
const _modelSizeMb = int.fromEnvironment('MODEL_SIZE_MB', defaultValue: 172);
const _modelUrl = String.fromEnvironment(
  'MODEL_URL',
  defaultValue:
      'https://vlqqczxwyaodtcdmdmlw.supabase.co/storage/v1/object/public/cactus-models/gemma3-270m.zip',
);

void probe(String step, Map<String, Object?> data) {
  print('PROBE ${jsonEncode({'step': step, ...data})}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  final total = Stopwatch()..start();
  try {
    final downloads = ModelDownloadService();
    final downloadWatch = Stopwatch()..start();
    var lastLogged = -1;
    final installedPath = await downloads.downloadManagedBundle(
      modelId: _modelId,
      modelName: _modelName,
      url: _modelUrl,
      archiveFilename: '$_modelId.zip',
      catalogSizeMb: _modelSizeMb,
      onProgress: (progress, phase) {
        final percent = (progress.progress * 100).floor();
        if (percent ~/ 10 != lastLogged) {
          lastLogged = percent ~/ 10;
          probe('download_progress', {
            'percent': percent,
            'phase': phase,
            'mb': (progress.downloadedBytes / 1048576).round(),
          });
        }
      },
    );
    probe('download_done', {
      'path_basename': installedPath.split(RegExp(r'[\\/]')).last,
      'seconds': (downloadWatch.elapsedMilliseconds / 1000).toStringAsFixed(1),
    });

    if (_modelId.startsWith('whisper')) {
      // Speech bundle: verify installation detection and that the runtime can
      // create a context from it. Transcribing needs real speech audio, which
      // this probe does not synthesize.
      final installed = await AudioTranscriptionService().isModelInstalled();
      probe('whisper_installed', {'detected': installed});
      final watch = Stopwatch()..start();
      final context = await CactusContext.initContext(installedPath, 1024);
      probe('whisper_init_context', {
        'ok': context.$1 != null,
        'message': context.$2,
        'ms': watch.elapsedMilliseconds,
      });
      if (context.$1 != null) CactusContext.freeContext(context.$1!);
      probe('done',
          {'total_seconds': (total.elapsedMilliseconds / 1000).round()});
      return;
    }

    final runtime = LocalInferenceService(contextSize: 1024);
    final models = await runtime.listModels();
    probe('list_models', {
      'ids': models.map((m) => m.id).toList(),
      'contains_target': models.any((m) => m.id == _modelId),
    });

    final loadWatch = Stopwatch()..start();
    await runtime.loadModel(_modelId);
    probe('load_model', {'ms': loadWatch.elapsedMilliseconds});

    // 1) Full generation with first-token timing.
    final request = ChatRequest(
      modelId: _modelId,
      messages: const [
        ChatRequestMessage(role: 'user', content: 'Name three primary colors.'),
      ],
      temperature: 0.2,
      topP: 0.9,
      maxTokens: 48,
    );
    final genWatch = Stopwatch()..start();
    int? firstTokenMs;
    var chunks = 0;
    final text = StringBuffer();
    await for (final token in runtime.chatStream(request)) {
      firstTokenMs ??= genWatch.elapsedMilliseconds;
      chunks++;
      text.write(token.text);
    }
    final metrics = await runtime.getMetrics();
    probe('generate', {
      'first_token_ms': firstTokenMs,
      'total_ms': genWatch.elapsedMilliseconds,
      'chunks': chunks,
      'chars': text.length,
      'runtime_tokens_per_second': metrics.tokensPerSecond,
      'runtime_completion_tokens': metrics.completionTokens,
      'counts_estimated': metrics.tokenCountsEstimated,
      'non_empty': text.toString().trim().isNotEmpty,
      // The reply text is intentionally not logged.
    });

    // 2) Cancellation: stop after the first chunk, then generate again.
    final cancelWatch = Stopwatch()..start();
    final sub = runtime.chatStream(request).listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await sub.cancel();
    probe('cancel', {'ms_to_cancel': cancelWatch.elapsedMilliseconds});
    var recovered = 0;
    await for (final _ in runtime.chatStream(request)) {
      recovered++;
    }
    probe('after_cancel_generate', {'chunks': recovered});

    await runtime.unloadModel(_modelId);
    probe(
        'done', {'total_seconds': (total.elapsedMilliseconds / 1000).round()});
  } catch (error, stack) {
    probe('error', {
      'type': error.runtimeType.toString(),
      'message': error.toString(),
      'stack': stack.toString().split('\n').take(4).toList(),
    });
  }
}
