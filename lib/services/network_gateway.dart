import 'package:http/http.dart' as http;

import 'network_policy_service.dart';

class NetworkPolicyError implements Exception {
  final String message;
  const NetworkPolicyError(this.message);

  @override
  String toString() => message;
}

class NetworkGateway {
  final http.Client _client;
  final NetworkPolicyService _policy;

  NetworkGateway({http.Client? client, NetworkPolicyService? policy})
      : _client = client ?? http.Client(),
        _policy = policy ?? NetworkPolicyService();

  static const _maxRedirects = 5;

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  /// GET with per-hop policy evaluation. Redirects are followed here (never by
  /// the HTTP client) so a redirect cannot reach a host that the policy, or
  /// Strict Offline, would have blocked, and each hop is audited.
  Future<http.Response> get(
    Uri uri, {
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
    Map<String, String>? headers,
  }) async {
    var current = uri;
    var currentHeaders = headers == null ? null : Map.of(headers);
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      _requireAllowed(
        current,
        purpose,
        hop == 0 ? trigger : '${trigger}_redirect_$hop',
        infoSent,
      );
      final request = http.Request('GET', current)..followRedirects = false;
      if (currentHeaders != null) request.headers.addAll(currentHeaders);
      final response = await http.Response.fromStream(
        await _client.send(request),
      );
      if (!_isRedirect(response.statusCode)) return response;

      final location = response.headers['location'];
      if (location == null || location.trim().isEmpty) return response;
      final Uri target;
      try {
        target = current.resolve(location.trim());
      } on FormatException {
        throw const NetworkPolicyError('Invalid redirect location.');
      }
      final scheme = target.scheme.toLowerCase();
      if (scheme != 'https' &&
          !(scheme == 'http' && _policy.isLoopback(target))) {
        throw const NetworkPolicyError(
          'Refused a redirect to a non-HTTPS address.',
        );
      }
      if (currentHeaders != null &&
          target.host.toLowerCase() != current.host.toLowerCase()) {
        // Do not forward credentials to a different host.
        currentHeaders.removeWhere((key, _) {
          final name = key.toLowerCase();
          return name == 'authorization' || name == 'cookie';
        });
      }
      current = target;
    }
    throw const NetworkPolicyError('Too many redirects.');
  }

  Future<http.Response> post(
    Uri uri, {
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
    Map<String, String>? headers,
    Object? body,
  }) {
    _requireAllowed(uri, purpose, trigger, infoSent);
    return _client.post(uri, headers: headers, body: body);
  }

  Future<http.StreamedResponse> send(
    http.BaseRequest request, {
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
  }) {
    _requireAllowed(request.url, purpose, trigger, infoSent);
    return _client.send(request);
  }

  Future<http.Response> delete(
    Uri uri, {
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
    Map<String, String>? headers,
    Object? body,
  }) {
    _requireAllowed(uri, purpose, trigger, infoSent);
    return _client.delete(uri, headers: headers, body: body);
  }

  void _requireAllowed(
    Uri uri,
    ConnectionPurpose purpose,
    String trigger,
    String infoSent,
  ) {
    final result = _policy.evaluateConnection(
      uri: uri,
      purpose: purpose,
      trigger: trigger,
      infoSent: infoSent,
    );
    if (!result.allowed) {
      throw NetworkPolicyError(result.reason ?? 'Network request blocked.');
    }
  }

  void close() => _client.close();
}
