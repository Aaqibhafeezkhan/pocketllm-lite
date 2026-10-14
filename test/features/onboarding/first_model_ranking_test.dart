import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/model_browser/domain/model_store_model.dart';
import 'package:pocketllm_lite/features/onboarding/domain/first_model_ranking.dart';
import 'package:pocketllm_lite/services/device_spec_service.dart';
import 'package:pocketllm_lite/services/model_recommendation_engine.dart';

ModelStoreModel _model(
  String id,
  int sizeMb, {
  ModelStoreRuntime runtime = ModelStoreRuntime.onDevice,
  Set<String> capabilities = const {'Text'},
}) =>
    ModelStoreModel(
      id: id,
      name: id,
      runtime: runtime,
      sizeMb: sizeMb,
      downloadUrl: 'https://example.test/$id.zip',
      archiveFilename: '$id.zip',
      quantizationBits: 4,
      capabilities: capabilities,
      source: 'test',
    );

DeviceHardwareProfile _profile({
  double? total = 8,
  double? available = 4,
  double? storage = 50,
  String? thermal,
}) =>
    DeviceHardwareProfile(
      totalRamGB: total,
      availableRamGB: available,
      cpuArchitecture: 'arm64-v8a',
      cpuCores: 8,
      hasGpuAcceleration: null,
      availableStorageGB: storage,
      thermalState: thermal,
    );

void main() {
  final catalog = [
    _model('tiny', 300),
    _model('small', 700),
    _model('mid', 1500),
    _model('large', 2400),
    _model('huge', 9000),
    _model('embed', 200, capabilities: {'Embeddings'}),
    _model('whisper', 80, runtime: ModelStoreRuntime.speech),
  ];

  test('excludes embeddings, speech and models that cannot fit RAM', () {
    final options = rankFirstModels(
      catalog: catalog,
      profile: _profile(total: 4, available: 2, storage: 50),
      limit: 10,
    );
    final ids = options.map((o) => o.model.id).toList();
    expect(ids, ['tiny', 'small', 'mid']);
    expect(ids, isNot(contains('embed')));
    expect(ids, isNot(contains('whisper')));
    expect(ids, isNot(contains('huge')));
  });

  test('never reports a load-tested or recommended badge for a catalog entry',
      () {
    final options = rankFirstModels(
      catalog: catalog,
      profile: _profile(),
      limit: 10,
    );
    expect(options, isNotEmpty);
    for (final option in options) {
      expect(option.recommendation.loadTestedOnDevice, isFalse);
      expect(option.recommendation.badge, RecommendationBadge.experimental);
    }
  });

  test('requires twice the catalog size in free storage', () {
    final options = rankFirstModels(
      catalog: [_model('mid', 1500)],
      profile: _profile(storage: 2.5),
    );
    expect(options, isEmpty);
    final fitting = rankFirstModels(
      catalog: [_model('mid', 1500)],
      profile: _profile(storage: 3.2),
    );
    expect(fitting, hasLength(1));
  });

  test('unknown RAM yields experimental options, not a guess', () {
    final options = rankFirstModels(
      catalog: catalog,
      profile: _profile(total: null, available: null),
      limit: 10,
    );
    expect(options.map((o) => o.model.id), contains('huge'));
    expect(
      options.every(
        (o) => o.recommendation.badge == RecommendationBadge.experimental,
      ),
      isTrue,
    );
  });

  test('spreads three picks across the fitting range', () {
    final options = rankFirstModels(
      catalog: catalog,
      profile: _profile(total: 12, available: 8),
    );
    expect(options.map((o) => o.model.id), ['tiny', 'mid', 'large']);
  });

  test('an empty or fully non-fitting catalog yields no options', () {
    expect(
      rankFirstModels(catalog: const [], profile: _profile()),
      isEmpty,
    );
    expect(
      rankFirstModels(
        catalog: [_model('huge', 9000)],
        profile: _profile(total: 4, available: 1),
      ),
      isEmpty,
    );
  });
}
