import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../services/model_bundle_validator.dart';
import '../../../services/model_storage_service.dart';
import '../domain/model_store_model.dart';

final modelStoreCatalogProvider = FutureProvider<List<ModelStoreModel>>((ref) {
  return ref.watch(modelStoreServiceProvider).fetchCatalog();
});

final installedStoreModelIdsProvider = FutureProvider<Set<String>>((ref) async {
  final root = await ModelStorageService.instance.getModelDirectory();
  final ids = <String>{};
  await for (final entity in root.list(followLinks: false)) {
    if (entity is! Directory ||
        entity.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .last
            .startsWith(
              '.',
            )) {
      continue;
    }
    final valid =
        (await const ModelBundleValidator().inspect(entity)).isRunnable;
    if (valid) {
      ids.add(entity.uri.pathSegments.where((e) => e.isNotEmpty).last);
    }
  }
  return ids;
});
