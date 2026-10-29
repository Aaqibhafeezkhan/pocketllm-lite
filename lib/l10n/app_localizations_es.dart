// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'PocketLLM Lite';

  @override
  String get chatSettings => 'Ajustes de Chat';

  @override
  String get enableTools => 'Herramientas de Agente Nativas';

  @override
  String get enableRag => 'Base de Conocimiento (RAG)';

  @override
  String get temperature => 'Temperatura';

  @override
  String get topP => 'Top P';

  @override
  String get systemPrompt => 'Fórmula del Sistema';

  @override
  String get applyChanges => 'Aplicar Cambios';

  @override
  String get cancel => 'Cancelar';

  @override
  String get deleteMessage => 'Eliminar Mensaje';

  @override
  String get clearChat => 'Limpiar Conversación';

  @override
  String get settings => 'Ajustes';

  @override
  String get benchmarks => 'Rendimiento';

  @override
  String get history => 'Historial';

  @override
  String get chat => 'Chat';

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
  String get skillDetailsTitle => "Detalles de la habilidad";

  @override
  String get skillNotFound => "Habilidad no encontrada";

  @override
  String get skillDescription => "Descripción";

  @override
  String get skillSource => "Fuente";

  @override
  String get skillActive => "Activa y en ejecución";

  @override
  String get skillDisabled => "Desactivada / en pausa";

  @override
  String get skillInstructions => "Instrucciones de la habilidad";
}
