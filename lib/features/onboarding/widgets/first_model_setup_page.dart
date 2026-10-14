import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';
import '../../../providers/model_manager_provider.dart';
import '../../../services/device_spec_service.dart';
import '../../../services/model_recommendation_engine.dart';
import '../../../services/network_policy_service.dart';
import '../../model_browser/providers/model_store_provider.dart';
import '../domain/first_model_ranking.dart';

enum _Phase { idle, loading, options, downloading, installed, failed }

/// Onboarding step that takes a first-time user from "no model" to "ready to
/// chat" without leaving the flow: device-aware choices, a real download with
/// progress and cancel, and clear alternatives (own server, local file, later).
class FirstModelSetupPage extends ConsumerStatefulWidget {
  /// Finishes onboarding and opens [route] (a settings screen for the chosen
  /// alternative). Supplied by the onboarding screen.
  final void Function(String route) onFinishTo;

  const FirstModelSetupPage({super.key, required this.onFinishTo});

  @override
  ConsumerState<FirstModelSetupPage> createState() =>
      _FirstModelSetupPageState();
}

class _FirstModelSetupPageState extends ConsumerState<FirstModelSetupPage> {
  _Phase _phase = _Phase.idle;
  DeviceHardwareProfile? _profile;
  List<FirstModelOption> _options = const [];
  FirstModelOption? _active;
  ModelDownloadProgressView? _progress;
  String? _taskId;
  String? _message;
  String? _installedName;

  bool get _discoveryBlocked {
    final policy = NetworkPolicyService();
    return policy.isStrictOfflineMode || !policy.isOnlineModelBrowsingEnabled;
  }

  Future<void> _findModels() async {
    setState(() {
      _phase = _Phase.loading;
      _message = null;
    });
    try {
      final profile = await ref.read(deviceHardwareProfileProvider.future);
      final catalog = await ref.read(modelStoreServiceProvider).fetchCatalog();
      final options = rankFirstModels(catalog: catalog, profile: profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _options = options;
        _phase = _Phase.options;
        if (options.isEmpty) {
          _message = 'No catalog model fits the memory and storage measured '
              'on this device. You can still use your own server or import a '
              'GGUF file.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _message = 'The model catalog could not be loaded: $error';
      });
    }
  }

  Future<void> _download(FirstModelOption option) async {
    final model = option.model;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Download ${model.name}?'),
        content: Text(
          '${model.sizeMb} MB from the Cactus catalog, extracted into private '
          'app storage. Use Wi-Fi if you are on a metered connection.\n\n'
          'License: ${model.license ?? 'not supplied by catalog metadata'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _active = option;
      _phase = _Phase.downloading;
      _progress = null;
      _message = null;
    });
    try {
      await ref.read(modelDownloadServiceProvider).downloadManagedBundle(
            modelId: model.id,
            modelName: model.name,
            url: model.downloadUrl,
            archiveFilename: model.archiveFilename,
            catalogSizeMb: model.sizeMb,
            onTaskCreated: (id) => _taskId = id,
            onProgress: (progress, phase) {
              if (!mounted) return;
              setState(() {
                _progress = ModelDownloadProgressView(
                  fraction: progress.progress,
                  downloadedMb: progress.downloadedBytes / (1024 * 1024),
                  totalMb: progress.totalBytes / (1024 * 1024),
                  phase: phase,
                );
              });
            },
          );
      ref.invalidate(installedStoreModelIdsProvider);
      await ref.read(modelManagerProvider.notifier).scanLocalModels();
      await ref
          .read(storageServiceProvider)
          .saveSetting(AppConstants.defaultModelKey, model.id);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.installed;
        _installedName = model.name;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.options;
        _message = 'The download did not finish: $error. Nothing was '
            'installed; you can retry or pick another model.';
      });
    }
  }

  Future<void> _cancel() async {
    final id = _taskId;
    if (id != null) {
      await ref.read(modelDownloadServiceProvider).cancelManagedDownload(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Get your first model',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A model is the AI itself. Run one on this phone, or connect a '
            'server you control. You can change this any time.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _buildBody(context),
          const SizedBox(height: 16),
          if (_phase != _Phase.downloading && _phase != _Phase.installed)
            _AlternativeActions(onFinishTo: widget.onFinishTo),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    switch (_phase) {
      case _Phase.idle:
        if (_discoveryBlocked) {
          return _InfoCard(
            icon: Icons.cloud_off_rounded,
            title: 'Model discovery is off',
            body: 'Strict Offline Mode or the online model browsing switch is '
                'on, so the catalog will not be contacted. Go back one step to '
                'change that, or import a GGUF file or use your own server below.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(
              icon: Icons.memory_rounded,
              title: 'Find a model for this phone',
              body: 'PocketLLM checks your free memory and storage, then '
                  'lists catalog models that should fit. This contacts the '
                  'Cactus model catalog (no personal data is sent).',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _findModels,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Find models'),
            ),
          ],
        );
      case _Phase.loading:
        return const _LoadingCard(label: 'Checking your device and catalog…');
      case _Phase.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(
              icon: Icons.error_outline_rounded,
              title: 'Could not load models',
              body: _message ?? 'Unknown error.',
              tone: colors.errorContainer,
              toneOn: colors.onErrorContainer,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _findModels,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        );
      case _Phase.options:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_profile != null) _DeviceSummary(profile: _profile!),
            if (_message != null) ...[
              const SizedBox(height: 8),
              _InfoCard(
                icon: Icons.info_outline_rounded,
                title: 'Heads up',
                body: _message!,
              ),
            ],
            const SizedBox(height: 8),
            for (final option in _options)
              _ModelOptionTile(option: option, onDownload: _download),
          ],
        );
      case _Phase.downloading:
        final progress = _progress;
        final fraction =
            progress != null && progress.totalMb > 0 ? progress.fraction : null;
        return Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Downloading ${_active?.model.name ?? 'model'}',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: fraction),
                const SizedBox(height: 8),
                Text(
                  progress == null
                      ? 'Starting…'
                      : '${progress.phase} · '
                          '${progress.downloadedMb.toStringAsFixed(0)} of '
                          '${progress.totalMb.toStringAsFixed(0)} MB',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _cancel,
                  child: const Text('Cancel download'),
                ),
              ],
            ),
          ),
        );
      case _Phase.installed:
        return _InfoCard(
          icon: Icons.check_circle_rounded,
          title: '${_installedName ?? 'Model'} is ready',
          body: 'It is installed and set as your default. Tap Get Started to '
              'open chat. The first reply loads the model and can take a '
              'moment.',
          tone: colors.primaryContainer,
          toneOn: colors.onPrimaryContainer,
        );
    }
  }
}

/// Immutable view of download progress for the UI.
class ModelDownloadProgressView {
  final double fraction;
  final double downloadedMb;
  final double totalMb;
  final String phase;

  const ModelDownloadProgressView({
    required this.fraction,
    required this.downloadedMb,
    required this.totalMb,
    required this.phase,
  });
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color? tone;
  final Color? toneOn;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.tone,
    this.toneOn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = toneOn ?? colors.onSurface;
    return Card.filled(
      color: tone ?? colors.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: foreground)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: foreground)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String label;
  const _LoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _DeviceSummary extends StatelessWidget {
  final DeviceHardwareProfile profile;
  const _DeviceSummary({required this.profile});

  @override
  Widget build(BuildContext context) {
    String gib(double? value) =>
        value == null ? 'unknown' : '${value.toStringAsFixed(1)} GB';
    return Text(
      'This device: ${gib(profile.totalRamGB)} RAM '
      '(${gib(profile.availableRamGB)} free), '
      '${gib(profile.availableStorageGB)} storage free.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _ModelOptionTile extends StatelessWidget {
  final FirstModelOption option;
  final Future<void> Function(FirstModelOption option) onDownload;

  const _ModelOptionTile({required this.option, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final model = option.model;
    final capabilities = model.capabilities.join(', ');
    return Card.outlined(
      margin: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: ListTile(
          title: Text(model.name),
          subtitle: Text(
            '${model.sizeMb} MB · $capabilities · '
            '${option.recommendation.badge.label}, not yet load-tested on '
            'this device',
          ),
          trailing: IconButton.filledTonal(
            tooltip: 'Download ${model.name}',
            onPressed: () => onDownload(option),
            icon: const Icon(Icons.download_rounded),
          ),
          titleTextStyle: theme.textTheme.titleSmall,
        ),
      ),
    );
  }
}

class _AlternativeActions extends StatelessWidget {
  final void Function(String route) onFinishTo;
  const _AlternativeActions({required this.onFinishTo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Other ways to start',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.dns_rounded),
          title: const Text('Use my own Ollama or compatible server'),
          subtitle: const Text('Set the address in Privacy and network'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onFinishTo('/settings/privacy-network'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_open_rounded),
          title: const Text('Import a GGUF file I already have'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onFinishTo('/settings/local-models'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_rounded),
          title: const Text('Decide later'),
          subtitle: const Text('Chat will guide you when you need a model'),
          onTap: () => onFinishTo('/chat'),
        ),
      ],
    );
  }
}
