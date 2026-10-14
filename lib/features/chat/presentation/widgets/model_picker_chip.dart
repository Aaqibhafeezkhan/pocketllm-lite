import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/models_provider.dart';

/// The model control in the chat top bar.
///
/// One tappable chip that always shows the active model and opens a sheet to
/// change it. It replaces a narrow dropdown that truncated the name and shared
/// the bar with six icon buttons on a 360 dp screen.
class ModelPickerChip extends StatelessWidget {
  final List<UnifiedModel> models;
  final String selectedId;
  final String? activeLoadedId;
  final ValueChanged<String> onSelected;

  /// Opens model setup (store / import). Offered in the empty state and as a
  /// footer action in the sheet.
  final VoidCallback onGetModels;

  const ModelPickerChip({
    super.key,
    required this.models,
    required this.selectedId,
    required this.activeLoadedId,
    required this.onSelected,
    required this.onGetModels,
  });

  UnifiedModel? get _selected {
    for (final model in models) {
      if (model.id == selectedId) return model;
    }
    return models.isEmpty ? null : models.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = _selected;

    if (selected == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: Icon(Icons.add_rounded, size: 18, color: colors.primary),
          label: const Text('Set up a model'),
          tooltip: 'Download a model or connect a server',
          onPressed: onGetModels,
        ),
      );
    }

    final loaded = selected.id == activeLoadedId;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Model: ${selected.name}. Double tap to change model.',
        excludeSemantics: true,
        child: Material(
          color: colors.secondaryContainer,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              _openSheet(context);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.only(left: 14, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected.isLocal
                          ? Icons.smartphone_rounded
                          : Icons.cloud_outlined,
                      size: 18,
                      color: colors.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        selected.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                    ),
                    if (loaded) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: colors.onSecondaryContainer,
                      ),
                    ],
                    Icon(
                      Icons.expand_more_rounded,
                      color: colors.onSecondaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _ModelSheet(
        models: models,
        selectedId: _selected?.id,
        activeLoadedId: activeLoadedId,
        onSelected: (id) {
          Navigator.pop(sheetContext);
          onSelected(id);
        },
        onGetModels: () {
          Navigator.pop(sheetContext);
          onGetModels();
        },
      ),
    );
  }
}

class _ModelSheet extends StatelessWidget {
  final List<UnifiedModel> models;
  final String? selectedId;
  final String? activeLoadedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onGetModels;

  const _ModelSheet({
    required this.models,
    required this.selectedId,
    required this.activeLoadedId,
    required this.onSelected,
    required this.onGetModels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = models.where((m) => m.isLocal).toList();
    final remote = models.where((m) => !m.isLocal).toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Semantics(
                header: true,
                child:
                    Text('Choose a model', style: theme.textTheme.titleLarge),
              ),
            ),
            if (local.isNotEmpty) ...[
              _SectionLabel('On this device'),
              for (final model in local) _tile(context, model),
            ],
            if (remote.isNotEmpty) ...[
              _SectionLabel('Connected server'),
              for (final model in remote) _tile(context, model),
            ],
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Get more models'),
              subtitle: const Text('Download, import or connect a server'),
              onTap: onGetModels,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, UnifiedModel model) {
    final theme = Theme.of(context);
    final isSelected = model.id == selectedId;
    final loaded = model.id == activeLoadedId;
    final details = <String>[
      if (model.size > 0) _formatSize(model.size),
      model.backend,
      if (model.supportsVision) 'vision',
      if (loaded) 'in memory',
    ].join(' · ');
    return ListTile(
      selected: isSelected,
      leading: Icon(
        model.isLocal ? Icons.smartphone_rounded : Icons.cloud_outlined,
      ),
      title: Text(model.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(details, style: theme.textTheme.bodySmall),
      trailing: isSelected ? const Icon(Icons.check_rounded) : null,
      onTap: () => onSelected(model.id),
    );
  }

  static String _formatSize(int bytes) {
    const gib = 1024 * 1024 * 1024;
    const mib = 1024 * 1024;
    return bytes >= gib
        ? '${(bytes / gib).toStringAsFixed(1)} GB'
        : '${(bytes / mib).toStringAsFixed(0)} MB';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
