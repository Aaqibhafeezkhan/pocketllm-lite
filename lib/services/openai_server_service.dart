import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'generation_pipeline.dart';
import 'inference_service.dart';

/// Configuration for the embedded OpenAI-compatible server.
///
/// Security model (see `SECURITY.md`):
/// * Every request needs the bearer key.
/// * By default the server binds loopback only (IPv4 and, when available,
///   IPv6) and accepts only loopback `Host` names, which defeats DNS
///   rebinding from a web page.
/// * Browsers are refused unless their exact `Origin` is allow-listed.
/// * There is no TLS. LAN mode is for a network you trust and exposes the
///   server (and your key in transit) to that network.
class OpenAiServerConfig {
  final bool enabled;
  final int port;
  final String? apiKey;
  final bool localhostOnly;
  final int maxConcurrentRequests;

  /// Exact browser origins (for example `http://localhost:5173`) that may call
  /// the API. Requests carrying any other `Origin` are rejected with 403.
  /// Non-browser clients send no `Origin` and are unaffected.
  final Set<String> allowedOrigins;

  /// Extra `Host` header names accepted in LAN mode (for example a LAN
  /// hostname). IP literals are accepted in LAN mode without listing.
  final Set<String> allowedHosts;

  /// Longest silence allowed while generating (idle timeout for streaming,
  /// total time for non-streaming).
  final Duration requestTimeout;

  /// Longest time allowed to receive a request body.
  final Duration bodyTimeout;

  const OpenAiServerConfig({
    this.enabled = false,
    this.port = 8080,
    this.apiKey,
    this.localhostOnly = true,
    this.maxConcurrentRequests = 2,
    this.allowedOrigins = const {},
    this.allowedHosts = const {},
    this.requestTimeout = const Duration(minutes: 5),
    this.bodyTimeout = const Duration(seconds: 30),
  });
}

/// Parses a user-entered, comma/space separated list of browser origins.
///
/// Only `scheme://host[:port]` origins are accepted, with no path, query or
/// wildcard, so an allow-list entry always means exactly one origin.
/// Throws [FormatException] naming the first invalid entry.
Set<String> parseAllowedOrigins(String input) {
  final origins = <String>{};
  for (final raw in input.split(RegExp(r'[,\s]+'))) {
    final entry = raw.trim();
    if (entry.isEmpty) continue;
    final uri = Uri.tryParse(entry);
    final valid = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        !entry.contains('*') &&
        uri.path.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.userInfo.isEmpty;
    if (!valid) {
      throw FormatException('Not a valid origin: $entry');
    }
    origins.add(
      '${uri.scheme}://${uri.host.toLowerCase()}${uri.hasPort ? ':${uri.port}' : ''}',
    );
  }
  return origins;
}

class _PayloadTooLarge implements Exception {
  const _PayloadTooLarge();
}

class _HttpFailure implements Exception {
  final int status;
  final String message;
  const _HttpFailure(this.status, this.message);
}

class OpenAiServerLog {
  final DateTime timestamp;
  final String clientIp;
  final String path;
  final int statusCode;
  const OpenAiServerLog(
      this.timestamp, this.clientIp, this.path, this.statusCode);
}

class OpenAiServerService {
  static const _keyStorageName = 'openai_server_api_key_v1';
  static const _maxBodyBytes = 4 * 1024 * 1024;
  static const _loopbackHostNames = {'localhost', '127.0.0.1', '::1'};

  final GenerationPipeline _pipeline;
  final Future<List<LLMModel>> Function() _listModels;
  final Future<List<double>> Function(String text, String modelId) _embed;
  final FlutterSecureStorage _secureStorage;
  final List<HttpServer> _servers = [];
  OpenAiServerConfig _config = const OpenAiServerConfig();
  String? _activeApiKey;
  final List<OpenAiServerLog> _logs = [];
  int _activeRequests = 0;
  final Map<String, List<DateTime>> _requestTimes = {};

  OpenAiServerService({
    required GenerationPipeline pipeline,
    required Future<List<LLMModel>> Function() listModels,
    required Future<List<double>> Function(String text, String modelId) embed,
    FlutterSecureStorage? secureStorage,
  })  : _pipeline = pipeline,
        _listModels = listModels,
        _embed = embed,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  bool get isRunning => _servers.isNotEmpty;
  OpenAiServerConfig get config => _config;
  String? get activeApiKey => _activeApiKey;
  List<OpenAiServerLog> get logs => List.unmodifiable(_logs);
  int? get boundPort => _servers.isEmpty ? null : _servers.first.port;

  /// True when the loopback IPv6 listener (`[::1]`) is also running, so
  /// clients that resolve `localhost` to `::1` can connect.
  bool get listensOnIpv6 => _servers.any(
        (server) => server.address.type == InternetAddressType.IPv6,
      );

  Future<bool> startServer(OpenAiServerConfig config) async {
    await stopServer();
    if (config.port < 0 || config.port > 65535) {
      throw ArgumentError.value(config.port, 'port', 'must be 0 to 65535');
    }
    if (config.maxConcurrentRequests < 1) {
      throw ArgumentError.value(
        config.maxConcurrentRequests,
        'maxConcurrentRequests',
        'must be at least 1',
      );
    }
    _config = config;
    if (!config.enabled) return false;
    if (config.apiKey?.trim().isNotEmpty == true) {
      _activeApiKey = config.apiKey!.trim();
    } else {
      _activeApiKey = await _secureStorage.read(key: _keyStorageName);
      if (_activeApiKey == null || _activeApiKey!.isEmpty) {
        _activeApiKey = _generateApiKey();
        await _secureStorage.write(key: _keyStorageName, value: _activeApiKey);
      }
    }
    final primary = await HttpServer.bind(
      config.localhostOnly
          ? InternetAddress.loopbackIPv4
          : InternetAddress.anyIPv4,
      config.port,
    );
    _servers.add(primary);
    primary.listen(_handleRequest);
    if (config.localhostOnly) {
      // Best effort: `localhost` may resolve to ::1 first. IPv6 may be
      // unavailable on a device; that must not stop the IPv4 listener.
      try {
        final v6 = await HttpServer.bind(
          InternetAddress.loopbackIPv6,
          primary.port,
          v6Only: true,
        );
        _servers.add(v6);
        v6.listen(_handleRequest);
      } on SocketException {
        // IPv4 loopback only.
      }
    }
    return true;
  }

  Future<void> stopServer() async {
    final servers = List<HttpServer>.of(_servers);
    _servers.clear();
    for (final server in servers) {
      await server.close(force: true);
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    var status = HttpStatus.internalServerError;
    var acquiredSlot = false;
    try {
      request.response.headers.contentType = ContentType.json;

      // 1. DNS-rebinding defence: the Host header must be one we expect.
      if (!_isAllowedHost(request.headers.value(HttpHeaders.hostHeader))) {
        status = HttpStatus.forbidden;
        await _json(request.response, status, {
          'error': {'message': 'Host not allowed'}
        });
        return;
      }

      // 2. Cross-origin browser requests need an allow-listed origin.
      final origin = request.headers.value('origin');
      final originAllowed =
          origin != null && _config.allowedOrigins.contains(origin);
      if (origin != null && !originAllowed) {
        status = HttpStatus.forbidden;
        await _json(request.response, status, {
          'error': {'message': 'Origin not allowed'}
        });
        return;
      }
      if (originAllowed) {
        final headers = request.response.headers;
        headers.set('Access-Control-Allow-Origin', origin);
        headers.set('Vary', 'Origin');
      }
      if (request.method == 'OPTIONS') {
        if (!originAllowed) {
          status = HttpStatus.forbidden;
          await _json(request.response, status, {
            'error': {'message': 'Origin not allowed'}
          });
          return;
        }
        final headers = request.response.headers;
        headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        headers.set(
            'Access-Control-Allow-Headers', 'authorization, content-type');
        headers.set('Access-Control-Max-Age', '600');
        status = HttpStatus.noContent;
        request.response.statusCode = status;
        await request.response.close();
        return;
      }

      // 3. Rate limit every client, authenticated or not, so a key cannot be
      //    brute-forced at wire speed.
      final clientIp =
          request.connectionInfo?.remoteAddress.address ?? 'unknown';
      if (!_withinRateLimit(clientIp)) {
        status = HttpStatus.tooManyRequests;
        await _json(request.response, status, {
          'error': {'message': 'Rate limit exceeded. Try again shortly.'}
        });
        return;
      }

      // 4. Authenticate.
      if (!_isAuthorized(
          request.headers.value(HttpHeaders.authorizationHeader))) {
        status = HttpStatus.unauthorized;
        request.response.headers.set('WWW-Authenticate', 'Bearer');
        await _json(request.response, status, {
          'error': {'message': 'Unauthorized'}
        });
        return;
      }

      final needsGenerationSlot = request.method == 'POST' &&
          (request.uri.path == '/v1/chat/completions' ||
              request.uri.path == '/v1/embeddings');
      if (needsGenerationSlot &&
          _activeRequests >= _config.maxConcurrentRequests) {
        status = HttpStatus.tooManyRequests;
        await _json(request.response, status, {
          'error': {
            'message': 'Local runtime is busy. Retry after the active request.'
          }
        });
        return;
      }
      if (needsGenerationSlot) {
        _activeRequests++;
        acquiredSlot = true;
      }
      if (request.method == 'GET' && request.uri.path == '/v1/models') {
        final models = await _listModels();
        status = HttpStatus.ok;
        await _json(request.response, status, {
          'object': 'list',
          'data': models
              .map((model) => {
                    'id': model.id,
                    'object': 'model',
                    'owned_by': model.backend.name,
                  })
              .toList(growable: false),
        });
      } else if (request.method == 'POST' &&
          request.uri.path == '/v1/chat/completions') {
        status = await _chat(request);
      } else if (request.method == 'POST' &&
          request.uri.path == '/v1/embeddings') {
        status = await _embeddings(request);
      } else {
        status = HttpStatus.notFound;
        await _json(request.response, status, {
          'error': {'message': 'Endpoint not found'}
        });
      }
    } on _PayloadTooLarge {
      status = HttpStatus.requestEntityTooLarge;
      await _tryJson(request.response, status, 'Request too large');
    } on _HttpFailure catch (failure) {
      status = failure.status;
      await _tryJson(request.response, status, failure.message);
    } on FormatException catch (error) {
      status = HttpStatus.badRequest;
      await _tryJson(request.response, status, error.message);
    } on TypeError {
      status = HttpStatus.badRequest;
      await _tryJson(request.response, status, 'Malformed request body');
    } catch (error) {
      status = HttpStatus.internalServerError;
      await _tryJson(request.response, status, error.toString());
    } finally {
      if (acquiredSlot) _activeRequests--;
      _log(request, status);
    }
  }

  Future<int> _chat(HttpRequest request) async {
    final body = await _body(request);
    final model = body['model'] as String?;
    final rawMessages = body['messages'] as List?;
    if (model == null || rawMessages == null || rawMessages.isEmpty) {
      throw const FormatException('model and messages are required');
    }
    final messages = rawMessages.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final role = map['role'];
      final content = map['content'];
      if (role is! String ||
          !{'system', 'user', 'assistant', 'tool'}.contains(role) ||
          content is! String) {
        throw const FormatException(
          'Each message requires a valid role and string content.',
        );
      }
      return ChatRequestMessage(
        role: role,
        content: content,
      );
    }).toList(growable: false);
    final maxTokens = (body['max_tokens'] as num?)?.toInt() ?? 512;
    final generation = ChatRequest(
      modelId: model,
      messages: messages,
      temperature: (body['temperature'] as num?)?.toDouble() ?? 0.7,
      topP: (body['top_p'] as num?)?.toDouble() ?? 0.9,
      maxTokens: maxTokens,
    );
    final created = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final id = 'chatcmpl-${DateTime.now().microsecondsSinceEpoch}';
    if (body['stream'] == true) {
      final cancellation = GenerationCancellationToken();
      unawaited(
        request.response.done.catchError((_) {
          cancellation.cancel();
        }),
      );
      request.response.headers.contentType =
          ContentType('text', 'event-stream', charset: 'utf-8');
      request.response.headers.set('Cache-Control', 'no-cache');
      var failed = false;
      try {
        final source = _withIdleTimeout(
          _pipeline.stream(
            generation,
            options: GenerationOptions(cancellationToken: cancellation),
          ),
          _config.requestTimeout,
          onTimeout: cancellation.cancel,
        );
        await for (final token in source) {
          request.response.write('data: ${jsonEncode({
                'id': id,
                'object': 'chat.completion.chunk',
                'created': created,
                'model': model,
                'choices': [
                  {
                    'index': 0,
                    'delta': {'content': token.text},
                    'finish_reason': null
                  }
                ],
              })}\n\n');
          await request.response.flush();
        }
      } catch (error) {
        failed = true;
        // Headers are already sent, so report the failure in-band and still
        // terminate the stream instead of leaving the client hanging.
        if (!cancellation.isCancelled || error is TimeoutException) {
          request.response.write('data: ${jsonEncode({
                'error': {
                  'message': error.toString(),
                  'type': error is TimeoutException
                      ? 'timeout'
                      : 'generation_error',
                },
              })}\n\n');
        }
      }
      if (!failed) {
        // A streamed response carries no measured token count, so the server
        // cannot tell a natural stop from a token-cap stop. It reports "stop"
        // rather than guess.
        request.response.write('data: ${jsonEncode({
              'id': id,
              'object': 'chat.completion.chunk',
              'created': created,
              'model': model,
              'choices': [
                {'index': 0, 'delta': {}, 'finish_reason': 'stop'}
              ],
            })}\n\n');
      }
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
      return failed ? HttpStatus.internalServerError : HttpStatus.ok;
    }
    final GenerationResult result;
    try {
      result =
          await _pipeline.complete(generation).timeout(_config.requestTimeout);
    } on TimeoutException {
      throw const _HttpFailure(
        HttpStatus.gatewayTimeout,
        'Generation timed out.',
      );
    }
    // "length" only when the runtime measured (not estimated) that it emitted
    // exactly the requested number of tokens.
    final metrics = result.metrics;
    final hitTokenCap = !metrics.tokenCountsEstimated &&
        maxTokens > 0 &&
        metrics.completionTokens >= maxTokens;
    await _json(request.response, HttpStatus.ok, {
      'id': id,
      'object': 'chat.completion',
      'created': created,
      'model': model,
      'choices': [
        {
          'index': 0,
          'message': {'role': 'assistant', 'content': result.text},
          'finish_reason': hitTokenCap ? 'length' : 'stop',
        }
      ],
      'usage': {
        'prompt_tokens': metrics.promptTokens,
        'completion_tokens': metrics.completionTokens,
        'total_tokens': metrics.promptTokens + metrics.completionTokens,
      },
    });
    return HttpStatus.ok;
  }

  Future<int> _embeddings(HttpRequest request) async {
    final body = await _body(request);
    final model = body['model'] as String?;
    final input = body['input'];
    if (model == null || (input is! String && input is! List)) {
      throw const FormatException(
          'model and string or list input are required');
    }
    final texts = input is String ? [input] : input.cast<String>();
    final data = <Map<String, dynamic>>[];
    for (var index = 0; index < texts.length; index++) {
      data.add({
        'object': 'embedding',
        'index': index,
        'embedding': await _embed(texts[index], model),
      });
    }
    await _json(request.response, HttpStatus.ok, {
      'object': 'list',
      'model': model,
      'data': data,
    });
    return HttpStatus.ok;
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    if (request.contentLength > _maxBodyBytes) throw const _PayloadTooLarge();
    final bytes = BytesBuilder(copy: false);
    final done = Completer<void>();
    final subscription = request.listen(
      (chunk) {
        if (done.isCompleted) return;
        bytes.add(chunk);
        if (bytes.length > _maxBodyBytes) {
          done.completeError(const _PayloadTooLarge());
        }
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (Object error) {
        if (!done.isCompleted) done.completeError(error);
      },
      cancelOnError: true,
    );
    // A timer rather than Stream.timeout: cancelling an HttpRequest body
    // subscription destroys the connection, and the 408 could not be sent.
    final timer = Timer(_config.bodyTimeout, () {
      if (!done.isCompleted) {
        done.completeError(const _HttpFailure(
          HttpStatus.requestTimeout,
          'Timed out waiting for the request body.',
        ));
      }
    });
    try {
      await done.future;
    } catch (_) {
      subscription.pause();
      rethrow;
    } finally {
      timer.cancel();
    }
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(bytes.takeBytes())) as Map,
    );
  }

  /// Re-emits [source] but fails with a [TimeoutException] when it stays
  /// silent for [limit]. Unlike `Stream.timeout`, it never waits for the
  /// source to acknowledge cancellation: a runtime stuck inside a native call
  /// cannot be cancelled, and the client must still get an answer.
  Stream<ChatToken> _withIdleTimeout(
    Stream<ChatToken> source,
    Duration limit, {
    required void Function() onTimeout,
  }) {
    final controller = StreamController<ChatToken>();
    Timer? idle;
    StreamSubscription<ChatToken>? subscription;

    void arm() {
      idle?.cancel();
      idle = Timer(limit, () {
        if (controller.isClosed) return;
        onTimeout();
        controller.addError(
          TimeoutException('Generation produced no output in time.'),
        );
        unawaited(controller.close());
        // Do not await: a stuck generator may never finish cancelling.
        unawaited(subscription?.cancel());
      });
    }

    controller.onListen = () {
      arm();
      subscription = source.listen(
        (token) {
          arm();
          if (!controller.isClosed) controller.add(token);
        },
        onError: (Object error, StackTrace stack) {
          if (!controller.isClosed) controller.addError(error, stack);
        },
        onDone: () {
          idle?.cancel();
          if (!controller.isClosed) unawaited(controller.close());
        },
      );
    };
    controller.onCancel = () {
      idle?.cancel();
      unawaited(subscription?.cancel());
    };
    return controller.stream;
  }

  /// Accepts loopback names always; in LAN mode also IP literals and any
  /// explicitly allow-listed names. Anything else (a rebinding attacker's own
  /// hostname) is refused even if it resolves to this device.
  bool _isAllowedHost(String? header) {
    if (header == null || header.trim().isEmpty) {
      // HTTP/1.0 clients may omit Host. They cannot be a browser rebinding
      // attack, and they still need the bearer key.
      return true;
    }
    var host = header.trim().toLowerCase();
    if (host.startsWith('[')) {
      final end = host.indexOf(']');
      if (end < 0) return false;
      host = host.substring(1, end);
    } else {
      final colon = host.lastIndexOf(':');
      // A single colon separates a port. More than one means a bare IPv6.
      if (colon >= 0 && host.indexOf(':') == colon) {
        host = host.substring(0, colon);
      }
    }
    if (_loopbackHostNames.contains(host) || host.endsWith('.localhost')) {
      return true;
    }
    if (_config.allowedHosts.map((h) => h.toLowerCase()).contains(host)) {
      return true;
    }
    if (!_config.localhostOnly && InternetAddress.tryParse(host) != null) {
      return true;
    }
    return false;
  }

  bool _isAuthorized(String? header) {
    final key = _activeApiKey;
    if (key == null || header == null) return false;
    final expected = utf8.encode('Bearer $key');
    final actual = utf8.encode(header);
    // Compare every byte so response timing does not reveal a key prefix.
    var diff = expected.length ^ actual.length;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected[i] ^ (i < actual.length ? actual[i] : 0);
    }
    return diff == 0;
  }

  Future<void> _tryJson(
    HttpResponse response,
    int status,
    String message,
  ) async {
    try {
      await _json(response, status, {
        'error': {'message': message}
      });
    } on StateError {
      // Headers were already sent or the client closed the connection.
    } on HttpException {
      // The client went away before the error body was written.
    }
  }

  Future<void> _json(HttpResponse response, int status, Object body) async {
    response.statusCode = status;
    response.write(jsonEncode(body));
    await response.close();
  }

  void _log(HttpRequest request, int status) {
    _logs.insert(
      0,
      OpenAiServerLog(
        DateTime.now(),
        request.connectionInfo?.remoteAddress.address ?? 'unknown',
        request.uri.path,
        status,
      ),
    );
    if (_logs.length > 100) _logs.removeLast();
  }

  String _generateApiKey() {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    return 'pk-pllm-${base64UrlEncode(bytes).replaceAll('=', '')}';
  }

  bool _withinRateLimit(String clientIp) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: 1));
    // Drop idle clients so a scan from many addresses cannot grow the map.
    _requestTimes.removeWhere(
      (_, times) => times.isEmpty || times.last.isBefore(cutoff),
    );
    final times = _requestTimes.putIfAbsent(clientIp, () => []);
    times.removeWhere((time) => time.isBefore(cutoff));
    if (times.length >= 60) return false;
    times.add(now);
    return true;
  }
}
