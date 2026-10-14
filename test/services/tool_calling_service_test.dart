import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketllm_lite/services/app_secret_service.dart';
import 'package:pocketllm_lite/services/network_gateway.dart';
import 'package:pocketllm_lite/services/network_policy_service.dart';
import 'package:pocketllm_lite/services/device_tool_action_service.dart';
import 'package:pocketllm_lite/services/tool_calling_service.dart';

class _RecordingDeviceActions implements DeviceToolActionService {
  String? clipboard;
  Map<String, dynamic>? note;
  DateTime? reminderTime;
  Uri? openedUrl;
  String? emailRecipient;

  @override
  Future<void> copyToClipboard(String text) async => clipboard = text;

  @override
  Future<Map<String, dynamic>> createNote(
    String title,
    String content,
  ) async {
    return note = {'id': 'note-1', 'title': title, 'content': content};
  }

  @override
  Future<void> openEmailDraft({
    required String recipient,
    required String subject,
    required String body,
  }) async {
    emailRecipient = recipient;
  }

  @override
  Future<void> openWebUrl(Uri uri) async => openedUrl = uri;

  @override
  Future<int> scheduleReminder(
    String title,
    String body,
    DateTime when,
  ) async {
    reminderTime = when;
    return 42;
  }
}

void main() {
  _webSearchSecurityTests();
  final service = ToolCallingService();

  test('parses canonical JSON tool calls and validates strict arguments', () {
    final call = service.parseToolCall(
      '{"tool":"calculator","arguments":{"expression":"(2 + 3) * 4"}}',
    );
    expect(call?['name'], 'calculator');
    final tool = service.getTool('calculator')!;
    expect(
        service.validateArguments(tool, {'expression': '(2 + 3) * 4'}), isNull);
    expect(service.validateArguments(tool, {'expression': 20}),
        contains('string'));
    expect(
      service.validateArguments(tool, {'expression': '2', 'shell': 'rm'}),
      contains('Unsupported'),
    );
  });

  test('calculator handler uses safe precedence-aware evaluation', () async {
    final tool = service.getTool('calculator')!;
    expect(await tool.handler({'expression': '(2 + 3) * -4'}), contains('-20'));
    expect(
      () => tool.handler({'expression': '1 / 0'}),
      throwsA(
          predicate((error) => error.toString().contains('Division by zero'))),
    );
  });

  test('parses multiple tool calls and rejects invalid execution', () async {
    final calls = service.parseToolCalls(
      '{"tool":"calculator","arguments":{"expression":"2+2"}}\n'
      '{"tool":"calculator","arguments":{"expression":4}}',
    );
    expect(calls, hasLength(2));
    final invalid = await service.execute(calls.last);
    expect(invalid.success, isFalse);
    expect(invalid.error, contains('must be a string'));
  });

  test('tolerates non-string call ids from model output', () {
    final calls = service.parseToolCalls(
      '{"id":7,"tool":"calculator","arguments":{"expression":"2+2"}}',
    );
    expect(calls, hasLength(1));
    expect(calls.single.name, 'calculator');
    expect(calls.single.id, isNotEmpty);
  });

  test('legacy XML adapter parses JSON arguments in either quote style', () {
    final single = service.parseToolCalls(
      "<tool_call name=\"calculator\" args='{\"expression\":\"2+2\"}' />",
    );
    expect(single, hasLength(1));
    expect(single.single.name, 'calculator');
    expect(single.single.arguments['expression'], '2+2');

    final escaped = service.parseToolCalls(
      '<tool_call name="calculator" args="{&quot;expression&quot;:&quot;3+3&quot;}" />',
    );
    expect(escaped, hasLength(1));
    expect(escaped.single.arguments['expression'], '3+3');
  });

  test('does not expose canned knowledge search', () {
    expect(service.getTool('knowledge_search'), isNull);
  });

  test('system information is local and contains measured platform fields',
      () async {
    final tool = service.getTool('system_info')!;
    expect(tool.requiresNetwork, isFalse);
    final output = await tool.handler(const {});
    expect(output, contains('cpuArchitecture'));
    expect(output, contains('cpuCores'));
    expect(output, isNot(contains('PocketLLM Native Core')));
  });

  test('side-effect tools require confirmation and execute real adapters',
      () async {
    final actions = _RecordingDeviceActions();
    final tools = ToolCallingService(deviceActions: actions);
    const call = ParsedToolCall(
      id: 'note-call',
      name: 'notes',
      arguments: {'title': 'Release', 'content': 'Verify signing'},
    );

    final denied = await tools.execute(call);
    expect(denied.success, isFalse);
    expect(actions.note, isNull);

    final approved = await tools.execute(
      call,
      confirm: (tool, call) async => true,
    );
    expect(approved.success, isTrue);
    expect(actions.note?['content'], 'Verify signing');
    expect(tools.getTool('notes')?.filesystemScope, contains('write'));
  });

  test('reminders require offset-aware ISO time', () async {
    final actions = _RecordingDeviceActions();
    final tools = ToolCallingService(deviceActions: actions);
    const call = ParsedToolCall(
      id: 'reminder-call',
      name: 'reminders',
      arguments: {
        'title': 'Check build',
        'body': 'Inspect the artifact',
        'scheduled_at': '2030-01-02T03:04:05',
      },
    );
    final result = await tools.execute(
      call,
      confirm: (tool, call) async => true,
    );
    expect(result.success, isFalse);
    expect(result.error, contains('explicit UTC offset'));
    expect(actions.reminderTime, isNull);
  });
}

class _FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> values;
  const _FakeSecureStorage(this.values);

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];
}

class _OfflinePolicy extends NetworkPolicyService {
  final bool strict;
  _OfflinePolicy({required this.strict}) : super.test();

  @override
  bool get isStrictOfflineMode => strict;

  @override
  NetworkPolicyResult evaluateConnection({
    required Uri uri,
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
  }) =>
      strict
          ? const NetworkPolicyResult(
              allowed: false, reason: 'Blocked by Strict Offline Mode')
          : const NetworkPolicyResult(allowed: true);
}

void _webSearchSecurityTests() {
  group('web_search is an explicit, confirmed network action', () {
    late List<http.Request> sent;
    late ToolCallingService Function({required bool strict}) build;

    setUp(() {
      sent = [];
      build = ({required bool strict}) {
        final policy = _OfflinePolicy(strict: strict);
        return ToolCallingService(
          networkPolicy: policy,
          secrets: const AppSecretService(
            storage: _FakeSecureStorage({'tavily_api_key_v1': 'test-key'}),
          ),
          network: NetworkGateway(
            policy: policy,
            client: MockClient((request) async {
              sent.add(request);
              return http.Response(
                jsonEncode({
                  'results': [
                    {'title': 'T', 'url': 'https://t.example', 'content': 'C'}
                  ],
                }),
                200,
              );
            }),
          ),
        );
      };
    });

    ParsedToolCall search(String query) => ParsedToolCall(
          id: 'search-1',
          name: 'web_search',
          arguments: {'query': query},
        );

    test('is classified as a medium-risk network tool needing confirmation',
        () {
      final tool = build(strict: false).getTool('web_search')!;
      expect(tool.requiresNetwork, isTrue);
      expect(tool.requiresConfirmation, isTrue);
      expect(tool.riskLevel, ToolRiskLevel.medium);
      expect(tool.networkHost, 'api.tavily.com');
      expect(tool.dataSent, contains('api.tavily.com'));
    });

    test('sends nothing when the user denies or no confirmer exists', () async {
      final tools = build(strict: false);
      final noConfirmer = await tools.execute(search('private notes'));
      expect(noConfirmer.success, isFalse);
      final denied = await tools.execute(
        search('private notes'),
        confirm: (tool, call) async => false,
      );
      expect(denied.success, isFalse);
      expect(sent, isEmpty);
    });

    test('Strict Offline refuses before prompting and sends nothing', () async {
      var prompted = false;
      final result = await build(strict: true).execute(
        search('anything'),
        confirm: (tool, call) async {
          prompted = true;
          return true;
        },
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Strict Offline'));
      expect(prompted, isFalse);
      expect(sent, isEmpty);
    });

    test('rejects oversized queries used to smuggle document text', () async {
      final result = await build(strict: false).execute(
        search('x' * 401),
        confirm: (tool, call) async => true,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('longer than 400'));
      expect(sent, isEmpty);
    });

    test('rejects extra injected arguments', () async {
      final result = await build(strict: false).execute(
        const ParsedToolCall(
          id: 'inj',
          name: 'web_search',
          arguments: {'query': 'ok', 'url': 'https://evil.example/exfil'},
        ),
        confirm: (tool, call) async => true,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Unsupported argument'));
      expect(sent, isEmpty);
    });

    test('a confirmed search sends only the query to the Tavily endpoint',
        () async {
      final result = await build(strict: false).execute(
        search('flutter release notes'),
        confirm: (tool, call) async {
          expect(call.arguments['query'], 'flutter release notes');
          return true;
        },
      );
      expect(result.success, isTrue, reason: result.error);
      expect(sent, hasLength(1));
      expect(sent.single.url.host, 'api.tavily.com');
      final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
      expect(body['query'], 'flutter release notes');
      expect(body.keys, containsAll(['api_key', 'query']));
    });
  });
}
