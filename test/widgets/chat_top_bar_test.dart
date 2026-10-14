import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/widgets/m3_app_bar.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/models_provider.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/chat_overflow_menu.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/model_picker_chip.dart';

UnifiedModel _model(String id, String name,
        {bool local = true, int size = 0}) =>
    UnifiedModel(
      id: id,
      name: name,
      isLocal: local,
      size: size,
      backend: local ? 'cactus' : 'ollama',
    );

Future<void> _pumpBar(
  WidgetTester tester, {
  required List<UnifiedModel> models,
  String selected = 'a',
  String? loaded,
  double textScale = 1,
  ValueChanged<String>? onSelected,
  VoidCallback? onGetModels,
  ValueChanged<ChatMenuAction>? onMenu,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          appBar: M3AppBar(
            title: '',
            automaticallyImplyLeading: false,
            titleWidget: ModelPickerChip(
              models: models,
              selectedId: selected,
              activeLoadedId: loaded,
              onSelected: onSelected ?? (_) {},
              onGetModels: onGetModels ?? () {},
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded),
                tooltip: 'History',
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: 'New chat',
                onPressed: () {},
              ),
              ChatOverflowMenu(
                modelLoaded: loaded != null,
                onSelected: onMenu ?? (_) {},
              ),
            ],
          ),
          body: const SizedBox.expand(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const longName = 'Qwen3 4B Instruct Q4_K_M with a very long catalog name';

  testWidgets('long model name fits beside three actions at 360 dp',
      (tester) async {
    await _pumpBar(tester, models: [_model('a', longName)]);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Qwen3 4B'), findsOneWidget);
    expect(find.byTooltip('History'), findsOneWidget);
    expect(find.byTooltip('New chat'), findsOneWidget);
    expect(find.byTooltip('More options'), findsOneWidget);
    // Chip is a comfortable touch target.
    final size = tester.getSize(find.byType(ModelPickerChip));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('fits at 130% and 200% text scale', (tester) async {
    for (final scale in [1.3, 2.0]) {
      await _pumpBar(
        tester,
        models: [_model('a', longName)],
        textScale: scale,
      );
      expect(tester.takeException(), isNull, reason: 'scale $scale');
    }
  });

  testWidgets('sheet groups models and reports the selection', (tester) async {
    String? picked;
    await _pumpBar(
      tester,
      models: [
        _model('a', 'Local small', size: 600 * 1024 * 1024),
        _model('b', 'Remote big', local: false),
      ],
      loaded: 'a',
      onSelected: (id) => picked = id,
    );
    await tester.tap(find.text('Local small').first);
    await tester.pumpAndSettle();

    expect(find.text('Choose a model'), findsOneWidget);
    expect(find.text('On this device'), findsOneWidget);
    expect(find.text('Connected server'), findsOneWidget);
    expect(find.textContaining('in memory'), findsOneWidget);
    expect(find.text('Get more models'), findsOneWidget);

    await tester.tap(find.text('Remote big'));
    await tester.pumpAndSettle();
    expect(picked, 'b');
  });

  testWidgets('empty list offers setup instead of a dead dropdown',
      (tester) async {
    var setup = 0;
    await _pumpBar(tester, models: const [], onGetModels: () => setup++);
    expect(find.text('Set up a model'), findsOneWidget);
    await tester.tap(find.text('Set up a model'));
    expect(setup, 1);
  });

  testWidgets('overflow menu exposes secondary actions; unload only if loaded',
      (tester) async {
    final actions = <ChatMenuAction>[];
    await _pumpBar(
      tester,
      models: [_model('a', 'Local')],
      onMenu: actions.add,
    );
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Chat settings'), findsOneWidget);
    expect(find.text('Media in this chat'), findsOneWidget);
    expect(find.text('App settings'), findsOneWidget);
    expect(find.text('Unload model from memory'), findsNothing);
    await tester.tap(find.text('Chat settings'));
    await tester.pumpAndSettle();
    expect(actions, [ChatMenuAction.chatSettings]);

    await _pumpBar(tester, models: [_model('a', 'Local')], loaded: 'a');
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Unload model from memory'), findsOneWidget);
  });
}
