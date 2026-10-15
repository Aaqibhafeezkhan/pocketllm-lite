import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/core/localization/app_locale.dart';
import 'package:pocketllm_lite/core/localization/language_picker.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/l10n/app_localizations.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

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

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text('settings=${l10n.settings}'),
        Text('language=${l10n.language}'),
        Text('note=${l10n.languageCoverageNote}'),
      ],
    );
  }
}

Widget _app({required Locale? locale, required Widget child}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  group('locale parsing', () {
    test('known codes map to locales; system and unknown follow the device',
        () {
      expect(localeFromCode('es'), const Locale('es'));
      expect(localeFromCode('zh'), const Locale('zh'));
      expect(localeFromCode('system'), isNull);
      expect(localeFromCode(null), isNull);
      expect(localeFromCode('xx'), isNull);
    });

    test('every language has a resource file and English is reviewed', () {
      final supported = AppLocalizations.supportedLocales
          .map((locale) => locale.languageCode)
          .toSet();
      for (final language in supportedAppLanguages) {
        expect(supported, contains(language.code), reason: language.code);
      }
      expect(
        supportedAppLanguages.where((l) => l.reviewed).map((l) => l.code),
        ['en'],
        reason: 'only reviewed languages may be presented as polished',
      );
    });
  });

  group('rendering', () {
    testWidgets('a translated message changes with the locale', (tester) async {
      await tester.pumpWidget(
        _app(locale: const Locale('es'), child: const _Probe()),
      );
      expect(find.text('settings=Ajustes'), findsOneWidget);
    });

    testWidgets('a key without a translation falls back to English',
        (tester) async {
      await tester.pumpWidget(
        _app(locale: const Locale('es'), child: const _Probe()),
      );
      // `language` has no Spanish entry yet: it must show the English text.
      expect(find.text('language=Language'), findsOneWidget);
    });

    testWidgets('an unsupported device locale resolves to English',
        (tester) async {
      await tester.pumpWidget(
        _app(locale: const Locale('fr'), child: const _Probe()),
      );
      expect(find.text('settings=Settings'), findsOneWidget);
    });
  });

  group('language picker', () {
    Future<(_MemoryStorage, ProviderContainer)> pump(
      WidgetTester tester, {
      String? saved,
    }) async {
      final storage = _MemoryStorage();
      if (saved != null) storage.values[AppConstants.appLocaleKey] = saved;
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              locale: ref.watch(appLocaleProvider),
              localizationsDelegates: const [
                ...AppLocalizations.localizationsDelegates,
                GlobalMaterialLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: LanguageSettingsTile()),
            ),
          ),
        ),
      );
      await tester.pump();
      return (storage, container);
    }

    testWidgets('selecting a language switches the UI and persists it',
        (tester) async {
      final (storage, container) = await pump(tester);
      expect(find.text('Device language'), findsOneWidget);

      await tester.tap(find.byType(LanguageSettingsTile));
      await tester.pumpAndSettle();
      expect(find.text('Translation not yet reviewed'), findsWidgets);
      await tester.tap(find.text('Español'));
      await tester.pumpAndSettle();

      expect(container.read(appLocaleProvider), const Locale('es'));
      expect(storage.values[AppConstants.appLocaleKey], 'es');
    });

    testWidgets('a saved language is restored and device default is selectable',
        (tester) async {
      final (storage, container) = await pump(tester, saved: 'ja');
      expect(container.read(appLocaleProvider), const Locale('ja'));
      expect(find.text('日本語'), findsOneWidget);

      await tester.tap(find.byType(LanguageSettingsTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Device language').last);
      await tester.pumpAndSettle();

      expect(container.read(appLocaleProvider), isNull);
      expect(storage.values[AppConstants.appLocaleKey], 'system');
    });
  });
}
