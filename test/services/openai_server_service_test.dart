import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketllm_lite/services/generation_pipeline.dart';
import 'package:pocketllm_lite/services/inference_service.dart';
import 'package:pocketllm_lite/services/openai_server_service.dart';

class _ServerInference implements InferenceService {
  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    yield const ChatToken(text: 'pipeline ');
    yield const ChatToken(text: 'answer');
  }

  @override
  Future<InferenceMetrics> getMetrics() async =>
      const InferenceMetrics(promptTokens: 3, completionTokens: 2);
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<LLMModel>> listModels() async => const [];
  @override
  Future<void> loadModel(String modelId,
      {ProgressCallback? onProgress}) async {}
  @override
  Future<void> unloadModel(String modelId) async {}
  @override
  Future<List<double>> generateEmbeddings(String text, String modelId) async =>
      const [0.25, 0.75];
}

class _BlockingInference extends _ServerInference {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    if (!started.isCompleted) started.complete();
    await release.future;
    yield const ChatToken(text: 'finished');
  }
}

class _FailingInference extends _ServerInference {
  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    yield const ChatToken(text: 'partial');
    throw StateError('runtime crashed');
  }
}

class _CappedInference extends _ServerInference {
  final bool estimated;
  _CappedInference({this.estimated = false});

  @override
  Future<InferenceMetrics> getMetrics() async => InferenceMetrics(
        promptTokens: 3,
        completionTokens: 16,
        tokenCountsEstimated: estimated,
      );
}

class _SilentInference extends _ServerInference {
  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    yield const ChatToken(text: 'first');
    await Completer<void>().future; // never completes
  }
}

void main() {
  late OpenAiServerService server;
  late Uri baseUri;
  const key = 'test-server-key';

  setUp(() async {
    final inference = _ServerInference();
    server = OpenAiServerService(
      pipeline: GenerationPipeline(resolveInference: (_) async => inference),
      listModels: () async => const [
        LLMModel(
          id: 'local-test',
          name: 'Local Test',
          backend: InferenceBackend.local,
          sizeBytes: 1,
          isDownloaded: true,
        ),
      ],
      embed: inference.generateEmbeddings,
    );
    await server.startServer(
      const OpenAiServerConfig(enabled: true, port: 0, apiKey: key),
    );
    baseUri = Uri.parse('http://127.0.0.1:${server.boundPort}');
  });

  tearDown(() => server.stopServer());

  test('rejects unauthenticated requests and lists actual models', () async {
    final rejected = await http.get(baseUri.resolve('/v1/models'));
    expect(rejected.statusCode, 401);

    final accepted = await http.get(
      baseUri.resolve('/v1/models'),
      headers: {'Authorization': 'Bearer $key'},
    );
    expect(accepted.statusCode, 200);
    expect(jsonDecode(accepted.body)['data'][0]['id'], 'local-test');
  });

  test('chat completions and embeddings execute real injected runtimes',
      () async {
    final completion = await http.post(
      baseUri.resolve('/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'local-test',
        'messages': [
          {'role': 'user', 'content': 'hello'}
        ],
      }),
    );
    expect(completion.statusCode, 200);
    expect(jsonDecode(completion.body)['choices'][0]['message']['content'],
        'pipeline answer');

    final embedding = await http.post(
      baseUri.resolve('/v1/embeddings'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'model': 'local-test', 'input': 'hello'}),
    );
    expect(embedding.statusCode, 200);
    expect(jsonDecode(embedding.body)['data'][0]['embedding'], [0.25, 0.75]);
  });

  test('streaming emits SSE chunks and a done marker', () async {
    final response = await http.post(
      baseUri.resolve('/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'local-test',
        'stream': true,
        'messages': [
          {'role': 'user', 'content': 'hello'}
        ],
      }),
    );
    expect(response.headers['content-type'], contains('text/event-stream'));
    expect(response.body, contains('pipeline '));
    expect(response.body, contains('data: [DONE]'));
    expect(response.body, contains('"finish_reason":"stop"'));
    expect(
      response.body.indexOf('"finish_reason":"stop"'),
      lessThan(response.body.indexOf('data: [DONE]')),
    );
  });

  test('rejects malformed roles and concurrent generation beyond the limit',
      () async {
    final malformed = await http.post(
      baseUri.resolve('/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'local-test',
        'messages': [
          {'role': 'root', 'content': 'hello'}
        ],
      }),
    );
    expect(malformed.statusCode, 400);

    await server.stopServer();
    final inference = _BlockingInference();
    server = OpenAiServerService(
      pipeline: GenerationPipeline(resolveInference: (_) async => inference),
      listModels: () async => const [],
      embed: inference.generateEmbeddings,
    );
    await server.startServer(
      const OpenAiServerConfig(
        enabled: true,
        port: 0,
        apiKey: key,
        maxConcurrentRequests: 1,
      ),
    );
    baseUri = Uri.parse('http://127.0.0.1:${server.boundPort}');
    final first = http.post(
      baseUri.resolve('/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'local-test',
        'messages': [
          {'role': 'user', 'content': 'first'}
        ],
      }),
    );
    await inference.started.future;
    final second = await http.post(
      baseUri.resolve('/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'local-test',
        'messages': [
          {'role': 'user', 'content': 'second'}
        ],
      }),
    );
    expect(second.statusCode, 429);
    inference.release.complete();
    expect((await first).statusCode, 200);
  });

  test('a runtime failure mid-stream terminates the SSE response', () async {
    await server.stopServer();
    final inference = _FailingInference();
    server = OpenAiServerService(
      pipeline: GenerationPipeline(resolveInference: (_) async => inference),
      listModels: () async => const [],
      embed: inference.generateEmbeddings,
    );
    await server.startServer(
      const OpenAiServerConfig(enabled: true, port: 0, apiKey: key),
    );
    baseUri = Uri.parse('http://127.0.0.1:${server.boundPort}');

    final response = await http
        .post(
          baseUri.resolve('/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'local-test',
            'stream': true,
            'messages': [
              {'role': 'user', 'content': 'hello'}
            ],
          }),
        )
        .timeout(const Duration(seconds: 5));

    expect(response.body, contains('partial'));
    expect(response.body, contains('"error"'));
    expect(response.body, isNot(contains('"finish_reason":"stop"')));
    expect(response.body, contains('data: [DONE]'));
  });

  test('rejects request bodies over the size limit with 413', () async {
    final oversized = 'x' * (4 * 1024 * 1024 + 1024);
    final response = await http.post(
      baseUri.resolve('/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'local-test',
        'messages': [
          {'role': 'user', 'content': oversized}
        ],
      }),
    );
    expect(response.statusCode, 413);
  });

  group('network hardening', () {
    Future<HttpClientResponse> raw(
      String method,
      Uri uri, {
      Map<String, String> headers = const {},
      String? hostHeader,
      String? body,
    }) async {
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final request = await client.openUrl(method, uri);
      headers.forEach(request.headers.set);
      if (hostHeader != null) request.headers.host = hostHeader;
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(body);
      }
      return request.close();
    }

    Future<void> restart(OpenAiServerConfig config,
        {_ServerInference? with_}) async {
      await server.stopServer();
      final inference = with_ ?? _ServerInference();
      server = OpenAiServerService(
        pipeline: GenerationPipeline(resolveInference: (_) async => inference),
        listModels: () async => const [],
        embed: inference.generateEmbeddings,
      );
      await server.startServer(config);
      baseUri = Uri.parse('http://127.0.0.1:${server.boundPort}');
    }

    test('rejects a rebinding Host header even with a valid key', () async {
      final response = await raw(
        'GET',
        baseUri.resolve('/v1/models'),
        headers: {'Authorization': 'Bearer $key'},
        hostHeader: 'evil.example',
      );
      expect(response.statusCode, 403);
    });

    test('accepts loopback Host names', () async {
      for (final host in ['localhost', '127.0.0.1']) {
        final response = await raw(
          'GET',
          baseUri.resolve('/v1/models'),
          headers: {'Authorization': 'Bearer $key'},
          hostHeader: host,
        );
        expect(response.statusCode, 200, reason: host);
      }
    });

    test('refuses browser origins that are not allow-listed', () async {
      final response = await raw(
        'POST',
        baseUri.resolve('/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $key',
          'Origin': 'https://evil.example',
        },
        body: jsonEncode({
          'model': 'local-test',
          'messages': [
            {'role': 'user', 'content': 'hi'}
          ],
        }),
      );
      expect(response.statusCode, 403);
      expect(
        response.headers.value('access-control-allow-origin'),
        isNull,
      );
    });

    test('allow-listed origin gets CORS headers and a preflight answer',
        () async {
      await restart(const OpenAiServerConfig(
        enabled: true,
        port: 0,
        apiKey: key,
        allowedOrigins: {'http://localhost:5173'},
      ));
      final preflight = await raw(
        'OPTIONS',
        baseUri.resolve('/v1/chat/completions'),
        headers: {
          'Origin': 'http://localhost:5173',
          'Access-Control-Request-Method': 'POST',
        },
      );
      expect(preflight.statusCode, 204);
      expect(
        preflight.headers.value('access-control-allow-origin'),
        'http://localhost:5173',
      );
      expect(
        preflight.headers.value('access-control-allow-headers'),
        contains('authorization'),
      );

      final other = await raw(
        'OPTIONS',
        baseUri.resolve('/v1/chat/completions'),
        headers: {'Origin': 'http://localhost:9999'},
      );
      expect(other.statusCode, 403);

      final authed = await raw(
        'GET',
        baseUri.resolve('/v1/models'),
        headers: {
          'Authorization': 'Bearer $key',
          'Origin': 'http://localhost:5173',
        },
      );
      expect(authed.statusCode, 200);
      expect(
        authed.headers.value('access-control-allow-origin'),
        'http://localhost:5173',
      );
    });

    test('authentication failures advertise Bearer and never run inference',
        () async {
      final wrong = await raw(
        'GET',
        baseUri.resolve('/v1/models'),
        headers: {'Authorization': 'Bearer nope'},
      );
      expect(wrong.statusCode, 401);
      expect(wrong.headers.value('www-authenticate'), 'Bearer');
      final missing =
          await raw('POST', baseUri.resolve('/v1/chat/completions'));
      expect(missing.statusCode, 401);
    });

    test('unauthenticated floods are rate limited', () async {
      final statuses = <int>[];
      for (var i = 0; i < 65; i++) {
        final response = await raw('GET', baseUri.resolve('/v1/models'));
        statuses.add(response.statusCode);
        await response.drain<void>();
      }
      expect(statuses.take(60).every((code) => code == 401), isTrue);
      expect(statuses.skip(60), contains(429));
    });

    test('malformed JSON and non-object bodies return 400', () async {
      for (final body in ['{not json', '[1,2,3]', '"text"']) {
        final response = await raw(
          'POST',
          baseUri.resolve('/v1/chat/completions'),
          headers: {'Authorization': 'Bearer $key'},
          body: body,
        );
        expect(response.statusCode, 400, reason: body);
        await response.drain<void>();
      }
    });

    test('a stalled request body times out with 408', () async {
      await restart(const OpenAiServerConfig(
        enabled: true,
        port: 0,
        apiKey: key,
        bodyTimeout: Duration(milliseconds: 300),
      ));
      final socket = await Socket.connect('127.0.0.1', server.boundPort!);
      addTearDown(socket.destroy);
      socket.write('POST /v1/chat/completions HTTP/1.1\r\n'
          'Host: 127.0.0.1\r\n'
          'Authorization: Bearer $key\r\n'
          'Content-Type: application/json\r\n'
          'Content-Length: 500\r\n\r\n{"model":');
      final reply =
          await utf8.decodeStream(socket).timeout(const Duration(seconds: 5));
      expect(reply, startsWith('HTTP/1.1 408'));
    });

    test('a silent runtime ends the stream with a timeout error', () async {
      await restart(
        const OpenAiServerConfig(
          enabled: true,
          port: 0,
          apiKey: key,
          requestTimeout: Duration(milliseconds: 300),
        ),
        with_: _SilentInference(),
      );
      final response = await http
          .post(
            baseUri.resolve('/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'local-test',
              'stream': true,
              'messages': [
                {'role': 'user', 'content': 'hi'}
              ],
            }),
          )
          .timeout(const Duration(seconds: 5));
      expect(response.body, contains('first'));
      expect(response.body, contains('"type":"timeout"'));
      expect(response.body, contains('data: [DONE]'));
    });

    test('non-streaming generation timeout maps to 504', () async {
      await restart(
        const OpenAiServerConfig(
          enabled: true,
          port: 0,
          apiKey: key,
          requestTimeout: Duration(milliseconds: 300),
        ),
        with_: _SilentInference(),
      );
      final response = await http
          .post(
            baseUri.resolve('/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'local-test',
              'messages': [
                {'role': 'user', 'content': 'hi'}
              ],
            }),
          )
          .timeout(const Duration(seconds: 5));
      expect(response.statusCode, 504);
    });

    test('finish_reason is length only for a measured token-cap stop',
        () async {
      Future<String> reasonFor(_ServerInference inference) async {
        await restart(
          const OpenAiServerConfig(enabled: true, port: 0, apiKey: key),
          with_: inference,
        );
        final response = await http.post(
          baseUri.resolve('/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'local-test',
            'max_tokens': 16,
            'messages': [
              {'role': 'user', 'content': 'hi'}
            ],
          }),
        );
        return jsonDecode(response.body)['choices'][0]['finish_reason']
            as String;
      }

      expect(await reasonFor(_CappedInference()), 'length');
      expect(await reasonFor(_CappedInference(estimated: true)), 'stop');
      expect(await reasonFor(_ServerInference()), 'stop');
    });

    test('IPv6 loopback is served when the platform supports it', () async {
      if (!server.listensOnIpv6) {
        markTestSkipped('IPv6 loopback unavailable on this host');
        return;
      }
      final response = await raw(
        'GET',
        Uri.parse('http://[::1]:${server.boundPort}/v1/models'),
        headers: {'Authorization': 'Bearer $key'},
      );
      expect(response.statusCode, 200);
    });
  });

  group('parseAllowedOrigins', () {
    test('normalizes valid origins and ignores blanks', () {
      expect(
        parseAllowedOrigins('http://LocalHost:5173, https://app.example ,'),
        {'http://localhost:5173', 'https://app.example'},
      );
      expect(parseAllowedOrigins('   '), isEmpty);
    });

    test('rejects wildcards, paths, credentials and non-http schemes', () {
      for (final bad in [
        '*',
        'https://*.example.com',
        'https://example.com/app',
        'https://user:pw@example.com',
        'ftp://example.com',
        'localhost:5173',
        'https://example.com?x=1',
      ]) {
        expect(
          () => parseAllowedOrigins(bad),
          throwsA(isA<FormatException>()),
          reason: bad,
        );
      }
    });
  });
}
