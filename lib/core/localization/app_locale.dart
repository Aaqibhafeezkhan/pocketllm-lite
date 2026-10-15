import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../providers.dart';

/// A language the app can display.
class AppLanguage {
  final String code;

  /// Name in its own language, so a user can find it whatever the UI language.
  final String nativeName;

  /// True only when a native speaker has reviewed the translation. Machine or
  /// unreviewed text must not be presented as polished localization.
  final bool reviewed;

  const AppLanguage(this.code, this.nativeName, {this.reviewed = false});

  Locale get locale => Locale(code);
}

/// The languages with a resource file in `lib/l10n`. English is the template
/// and the fallback for every missing message.
const supportedAppLanguages = <AppLanguage>[
  AppLanguage('en', 'English', reviewed: true),
  AppLanguage('es', 'Español'),
  AppLanguage('hi', 'हिन्दी'),
  AppLanguage('ja', '日本語'),
  AppLanguage('ko', '한국어'),
  AppLanguage('zh', '中文'),
];

/// Parses a stored language code. `null`, `system` and unknown codes mean
/// "follow the device", which resolves to English when unsupported.
Locale? localeFromCode(String? code) {
  if (code == null || code == 'system') return null;
  for (final language in supportedAppLanguages) {
    if (language.code == code) return language.locale;
  }
  return null;
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale?>(
  AppLocaleNotifier.new,
);

class AppLocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final storage = ref.watch(storageServiceProvider);
    final saved = storage.getSetting(AppConstants.appLocaleKey);
    return localeFromCode(saved is String ? saved : null);
  }

  /// Sets the display language, or follows the device when [locale] is null.
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    await ref.read(storageServiceProvider).saveSetting(
          AppConstants.appLocaleKey,
          locale?.languageCode ?? 'system',
        );
  }
}
