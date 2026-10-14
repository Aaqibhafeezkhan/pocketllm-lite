import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/model_browser/domain/model_store_model.dart';
import 'package:pocketllm_lite/features/onboarding/widgets/first_model_setup_page.dart';
import 'package:pocketllm_lite/providers/model_manager_provider.dart';
import 'package:pocketllm_lite/services/device_spec_service.dart';
import 'package:pocketllm_lite/services/model_download_service.dart';
import 'package:pocketllm_lite/services/model_store_service.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

ModelStoreModel _model(String id, int sizeMb) => ModelStoreModel(
      id: id,
      name: 'Model $id',
      runtime: ModelStoreRuntime.onDevice,
      sizeMb: sizeMb,
      downloadUrl: 'https://example.test/$id.zip',
      archiveFilename: '$id.zip',
      quantizationBits: 4,
      capabilities: const {'Text'},
      source: 'test',
      license: 'Apache-2.0',
    );

class _FakeStore extends ModelStoreService {
  final List<ModelStoreModel>? catalog;
  int calls = 0;
  _FakeStore(this.catalog);

  @override
  Future<List<ModelStoreModel>> fetchCatalog() async {
    calls++;
    if (catalog == null) throw StateError('catalog offline');
    return catalog!;
  }
}

class _FakeDownloads extends ModelDownloadService {
  final Completer<void> release = Completer<void>();
  String? downloaded;
  bool cancelled = false;

  @override
  Future<String> downloadManagedBundle({
    required String modelId,
    required String modelName,
    required String url,
    required String archiveFilename,
    required int catalogSizeMb,
    void Function(ModelDownloadProgress progress, String phase)? onProgress,
    void Function(String taskId)? onTaskCreated,
  }) async {
    onTaskCreated?.call('task-1');
    onProgress?.call(
      const ModelDownloadProgress(
        progress: 0.5,
        networkSpeed: 5,
        timeRemaining: Duration(seconds: 3),
        totalBytes: 600 * 1024 * 1024,
        downloadedBytes: 300 * 1024 * 1024,
      ),
      'Downloading bundle',
    );
    await release.future;
    if (cancelled) throw StateError('cancelled');
    downloaded = modelId;
    return '/models/$modelId';
  }

  @override
  Future<void> cancelManagedDownload(String taskId) async {
    cancelled = true;
    if (!release.isCompleted) release.complete();
  }
}

class _MemoryStorage extends StorageService {
  final Map<String, dynamic> values = {};

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) =>
      values[key] ?? defaultValue;

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    values[key] = value;
  }
}

class _NoopModelManager extends ModelManagerNotifier {
  int scans = 0;

  @override
  Future<void> scanLocalModels() async {
    scans++;
  }
}

const _profile = DeviceHardwareProfile(
  totalRamGB: 8,
  availableRamGB: 4,
  cpuArchitecture: 'arm64-v8a',
  cpuCores: 8,
  hasGpuAcceleration: null,
  availableStorageGB: 40,
  thermalState: null,
);

Future<void> _pump(
  WidgetTester tester, {
  required ModelStoreService store,
  required ModelDownloadService downloads,
  required _MemoryStorage storage,
  required void Function(String route) onFinishTo,
  double textScale = 1,
  _NoopModelManager? manager,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        modelStoreServiceProvider.overrideWithValue(store),
        modelDownloadServiceProvider.overrideWithValue(downloads),
        storageServiceProvider.overrideWithValue(storage),
        deviceHardwareProfileProvider.overrideWith((ref) async => _profile),
        modelManagerProvider.overrideWith(() => manager ?? _NoopModelManager()),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 640),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: FirstModelSetupPage(onFinishTo: onFinishTo),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('lists device-aware options only after the user asks',
      (tester) async {
    final store = _FakeStore([
      _model('tiny', 300),
      _model('mid', 1200),
      _model('huge', 9000),
    ]);
    await _pump(
      tester,
      store: store,
      downloads: _FakeDownloads(),
      storage: _MemoryStorage(),
      onFinishTo: (_) {},
    );

    // No catalog request before the explicit action.
    expect(store.calls, 0);
    expect(find.text('Find models'), findsOneWidget);

    await tester.tap(find.text('Find models'));
    await tester.pumpAndSettle();

    expect(store.calls, 1);
    expect(find.text('Model tiny'), findsOneWidget);
    expect(find.text('Model mid'), findsOneWidget);
    expect(find.text('Model huge'), findsNothing,
        reason: 'a model larger than available RAM must not be offered');
    expect(find.textContaining('This device: 8.0 GB RAM'), findsOneWidget);
    expect(find.textContaining('not yet load-tested'), findsWidgets);
  });

  testWidgets('a catalog failure is shown honestly and can be retried',
      (tester) async {
    await _pump(
      tester,
      store: _FakeStore(null),
      downloads: _FakeDownloads(),
      storage: _MemoryStorage(),
      onFinishTo: (_) {},
    );
    await tester.tap(find.text('Find models'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load models'), findsOneWidget);
    expect(find.textContaining('catalog offline'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    // Alternatives stay available while the catalog is down.
    expect(find.text('Decide later'), findsOneWidget);
  });

  testWidgets('download shows progress, installs and sets the default model',
      (tester) async {
    final downloads = _FakeDownloads();
    final storage = _MemoryStorage();
    final manager = _NoopModelManager();
    await _pump(
      tester,
      store: _FakeStore([_model('tiny', 600)]),
      downloads: downloads,
      storage: storage,
      onFinishTo: (_) {},
      manager: manager,
    );
    final scansBefore = manager.scans;
    await tester.tap(find.text('Find models'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download Model tiny'));
    await tester.pumpAndSettle();
    expect(find.text('Download Model tiny?'), findsOneWidget);
    await tester.tap(find.text('Download'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Downloading Model tiny'), findsOneWidget);
    expect(find.textContaining('300 of 600 MB'), findsOneWidget);
    expect(find.text('Cancel download'), findsOneWidget);

    downloads.release.complete();
    await tester.pumpAndSettle();

    expect(find.text('Model tiny is ready'), findsOneWidget);
    expect(downloads.downloaded, 'tiny');
    expect(storage.values[AppConstants.defaultModelKey], 'tiny');
    expect(manager.scans - scansBefore, greaterThanOrEqualTo(1),
        reason: 'installed models must be rescanned after the install');
  });

  testWidgets('cancelling returns to the list with nothing installed',
      (tester) async {
    final downloads = _FakeDownloads();
    final storage = _MemoryStorage();
    await _pump(
      tester,
      store: _FakeStore([_model('tiny', 600)]),
      downloads: downloads,
      storage: storage,
      onFinishTo: (_) {},
    );
    await tester.tap(find.text('Find models'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download Model tiny'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Cancel download'));
    await tester.pumpAndSettle();

    expect(find.text('Model tiny is ready'), findsNothing);
    expect(find.textContaining('did not finish'), findsOneWidget);
    expect(storage.values.containsKey(AppConstants.defaultModelKey), isFalse);
    expect(downloads.cancelled, isTrue);
  });

  testWidgets('alternative paths report their route', (tester) async {
    final routes = <String>[];
    await _pump(
      tester,
      store: _FakeStore(const []),
      downloads: _FakeDownloads(),
      storage: _MemoryStorage(),
      onFinishTo: routes.add,
    );
    await tester.tap(find.text('Use my own Ollama or compatible server'));
    await tester.tap(find.text('Import a GGUF file I already have'));
    await tester.tap(find.text('Decide later'));
    expect(routes, [
      '/settings/privacy-network',
      '/settings/local-models',
      '/chat',
    ]);
  });

  testWidgets('fits 360 x 640 at 130% text scale without overflow',
      (tester) async {
    await _pump(
      tester,
      store: _FakeStore([_model('tiny', 300), _model('mid', 1200)]),
      downloads: _FakeDownloads(),
      storage: _MemoryStorage(),
      onFinishTo: (_) {},
      textScale: 1.3,
    );
    await tester.tap(find.text('Find models'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Model tiny'), findsOneWidget);
  });
}
