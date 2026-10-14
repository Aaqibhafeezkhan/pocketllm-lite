import '../../../services/device_spec_service.dart';
import '../../../services/model_recommendation_engine.dart';
import '../../model_browser/domain/model_store_model.dart';

/// One candidate shown on the onboarding "first model" step.
class FirstModelOption {
  final ModelStoreModel model;
  final ModelRecommendationResult recommendation;

  /// False when free storage is known and cannot hold the download plus its
  /// extraction (the download service requires twice the catalog size).
  final bool fitsStorage;

  const FirstModelOption({
    required this.model,
    required this.recommendation,
    required this.fitsStorage,
  });

  bool get isSelectable =>
      fitsStorage &&
      recommendation.badge != RecommendationBadge.highMemoryRisk &&
      recommendation.badge != RecommendationBadge.unsupported;
}

/// Picks up to [limit] on-device chat models worth offering a first-time user.
///
/// Only measured facts are used: catalog size, measured free RAM and storage.
/// Nothing about quality or speed is claimed, and an unmeasured device yields
/// "Experimental" badges rather than a guess. Models that cannot fit are kept
/// out of the primary list entirely.
List<FirstModelOption> rankFirstModels({
  required List<ModelStoreModel> catalog,
  required DeviceHardwareProfile profile,
  ModelRecommendationEngine engine = const ModelRecommendationEngine(),
  int limit = 3,
}) {
  final candidates = catalog
      .where((model) =>
          model.runtime == ModelStoreRuntime.onDevice &&
          !model.isEmbedding &&
          model.sizeMb > 0)
      .toList()
    ..sort((left, right) => left.sizeMb.compareTo(right.sizeMb));

  final freeStorageGB = profile.availableStorageGB;
  final options = <FirstModelOption>[];
  for (final model in candidates) {
    final fileSizeGB = model.sizeMb / 1024;
    final fitsStorage =
        freeStorageGB == null || freeStorageGB >= fileSizeGB * 2;
    final recommendation = engine.evaluateFileSize(
      profile: profile,
      fileSizeGB: fileSizeGB,
    );
    final option = FirstModelOption(
      model: model,
      recommendation: recommendation,
      fitsStorage: fitsStorage,
    );
    if (option.isSelectable) options.add(option);
  }
  if (options.length <= limit) return options;

  // Spread the choice across the fitting range: smallest (quickest start),
  // a middle option, and the largest that still fits.
  final picked = <FirstModelOption>[options.first];
  if (limit >= 3) picked.add(options[options.length ~/ 2]);
  picked.add(options.last);
  return picked.toSet().toList()
    ..sort((left, right) => left.model.sizeMb.compareTo(right.model.sizeMb));
}
