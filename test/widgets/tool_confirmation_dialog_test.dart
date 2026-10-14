import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/presentation/dialogs/tool_confirmation_dialog.dart';
import 'package:pocketllm_lite/services/tool_calling_service.dart';

ToolDefinition _searchTool() => ToolDefinition(
      name: 'web_search',
      description: 'Search the web',
      parameters: const {'type': 'object', 'properties': {}},
      handler: (_) async => '',
      requiresNetwork: true,
      requiresConfirmation: true,
      riskLevel: ToolRiskLevel.medium,
      networkHost: 'api.tavily.com',
      dataSent: 'The search query below is sent to api.tavily.com.',
    );

Future<bool?> _open(
  WidgetTester tester, {
  required ToolDefinition tool,
  required ParsedToolCall call,
  double textScale = 1,
}) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async =>
                    result = await ToolConfirmationDialog.show(
                  context,
                  tool: tool,
                  call: call,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  const call = ParsedToolCall(
    id: 'c1',
    name: 'web_search',
    arguments: {'query': 'flutter 3.41 release notes'},
  );

  testWidgets('shows destination, data sent and the exact arguments',
      (tester) async {
    await _open(tester, tool: _searchTool(), call: call);

    expect(find.text('Allow web_search?'), findsOneWidget);
    expect(find.textContaining('api.tavily.com'), findsOneWidget);
    expect(
      find.byKey(const Key('tool-confirmation-arguments')),
      findsOneWidget,
    );
    expect(find.textContaining('flutter 3.41 release notes'), findsWidgets);
    expect(find.text('Deny'), findsOneWidget);
    expect(find.text('Allow once'), findsOneWidget);
  });

  testWidgets('Deny resolves false and Allow once resolves true',
      (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => answer = await ToolConfirmationDialog.show(
                context,
                tool: _searchTool(),
                call: call,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deny'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow once'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('fits a 360 x 640 screen at 130% text scale', (tester) async {
    await _open(tester, tool: _searchTool(), call: call, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('Allow once'), findsOneWidget);
  });
}
