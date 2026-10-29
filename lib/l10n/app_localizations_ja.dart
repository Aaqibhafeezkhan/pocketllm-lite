// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'PocketLLM ライト';

  @override
  String get chatSettings => 'チャット設定';

  @override
  String get enableTools => 'ネイティブエージェントツール';

  @override
  String get enableRag => '知識ベース (RAG)';

  @override
  String get temperature => '温度';

  @override
  String get topP => 'トップP';

  @override
  String get systemPrompt => 'システムプロンプト';

  @override
  String get applyChanges => '変更を適用';

  @override
  String get cancel => 'キャンセル';

  @override
  String get deleteMessage => 'メッセージを削除';

  @override
  String get clearChat => '会話をクリア';

  @override
  String get settings => '設定';

  @override
  String get benchmarks => 'ベンチマーク';

  @override
  String get history => '履歴';

  @override
  String get chat => 'チャット';

  @override
  String get language => 'Language';

  @override
  String get languageSystemDefault => 'Device language';

  @override
  String get languageUnreviewed => 'Translation not yet reviewed';

  @override
  String get languageCoverageNote =>
      'Only part of the app is translated so far. Anything without a translation is shown in English.';

  @override
  String get modelSetupTitle => 'Get your first model';

  @override
  String get skillDetailsTitle => "スキルの詳細";

  @override
  String get skillNotFound => "スキルが見つかりません";

  @override
  String get skillDescription => "説明";

  @override
  String get skillSource => "ソース";

  @override
  String get skillActive => "有効・実行中";

  @override
  String get skillDisabled => "無効／一時停止";

  @override
  String get skillInstructions => "スキルの手順";
}
