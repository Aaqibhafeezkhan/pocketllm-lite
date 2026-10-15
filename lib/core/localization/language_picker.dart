import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'app_locale.dart';

/// Settings row that shows the current language and opens a chooser.
class LanguageSettingsTile extends ConsumerWidget {
  const LanguageSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(appLocaleProvider);
    final current = locale == null
        ? l10n.languageSystemDefault
        : supportedAppLanguages
            .firstWhere(
              (language) => language.code == locale.languageCode,
              orElse: () => supportedAppLanguages.first,
            )
            .nativeName;
    return ListTile(
      leading: Icon(Icons.language_rounded,
          color: Theme.of(context).colorScheme.primary),
      title: Text(l10n.language),
      subtitle: Text(current),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showLanguageSheet(context, ref),
    );
  }
}

Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = ref.watch(appLocaleProvider);
    void choose(Locale? next) {
      ref.read(appLocaleProvider.notifier).setLocale(next);
      Navigator.pop(context);
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: RadioGroup<String>(
          groupValue: locale?.languageCode ?? 'system',
          onChanged: (value) => choose(localeFromCode(value)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Semantics(
                  header: true,
                  child: Text(l10n.language, style: theme.textTheme.titleLarge),
                ),
              ),
              RadioListTile<String>(
                value: 'system',
                title: Text(l10n.languageSystemDefault),
              ),
              for (final language in supportedAppLanguages)
                RadioListTile<String>(
                  value: language.code,
                  title: Text(language.nativeName),
                  subtitle:
                      language.reviewed ? null : Text(l10n.languageUnreviewed),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  l10n.languageCoverageNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
