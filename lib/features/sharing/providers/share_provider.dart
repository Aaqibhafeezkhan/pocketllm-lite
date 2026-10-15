import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router.dart';
import '../../../services/share_intake_service.dart';
import '../../../services/shared_content.dart';

final shareIntakeServiceProvider = Provider<ShareIntakeService>((ref) {
  final service = ShareIntakeService();
  ref.onDispose(service.dispose);
  return service;
});

/// The share currently waiting for the user's decision, or null.
final shareProvider = NotifierProvider<ShareNotifier, SharedContent?>(
  ShareNotifier.new,
);

class ShareNotifier extends Notifier<SharedContent?> {
  @override
  SharedContent? build() => null;

  /// Validates a platform payload. Returns true when something usable was
  /// received (the UI then shows it). Copies that were refused are deleted at
  /// once so unaccepted material is not left on disk.
  Future<bool> ingest(RawShare raw) async {
    final service = ref.read(shareIntakeServiceProvider);
    final inbox = await service.inboxPath();
    if (inbox == null) return false;

    await _discardCurrent();
    final content = SharedContentPolicy(inboxPath: inbox).validate(raw);

    final accepted = content.files.map((file) => file.file.path).toSet();
    await service.discard(
      raw.files
          .map((file) => file.path)
          .where((path) => path.isNotEmpty && !accepted.contains(path)),
    );

    if (content.isEmpty && content.rejected.isEmpty) return false;
    state = content;
    return true;
  }

  /// Deletes the copied files and forgets the share.
  Future<void> clear() async {
    await _discardCurrent();
    state = null;
  }

  Future<void> _discardCurrent() async {
    final current = state;
    if (current == null || current.files.isEmpty) return;
    await ref
        .read(shareIntakeServiceProvider)
        .discard(current.files.map((file) => file.file.path));
  }
}

/// Listens for shares that arrive while the app is open and opens the share
/// screen. Cold-start shares are picked up by the splash screen.
final shareCoordinatorProvider = Provider<void>((ref) {
  final service = ref.watch(shareIntakeServiceProvider);
  final subscription = service.incoming.listen((raw) async {
    final accepted = await ref.read(shareProvider.notifier).ingest(raw);
    if (accepted) ref.read(routerProvider).go('/share');
  });
  ref.onDispose(subscription.cancel);
});
