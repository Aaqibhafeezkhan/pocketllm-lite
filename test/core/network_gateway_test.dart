import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketllm_lite/services/network_gateway.dart';
import 'package:pocketllm_lite/services/network_policy_service.dart';

void main() {
  test('blocked policy fails before the HTTP client is invoked', () async {
    var invoked = false;
    final gateway = NetworkGateway(
      client: MockClient((_) async {
        invoked = true;
        return http.Response('unexpected', 200);
      }),
    );

    expect(
      () => gateway.get(
        Uri.parse('https://fonts.googleapis.com/css'),
        purpose: ConnectionPurpose.fontDownload,
        trigger: 'test',
        infoSent: 'font name',
      ),
      throwsA(isA<NetworkPolicyError>()),
    );
    expect(invoked, isFalse);
  });

  group('redirects', () {
    test('every hop is evaluated and a blocked hop is never requested',
        () async {
      final requested = <String>[];
      final policy = _HostPolicy(blocked: {'tracker.example'});
      final gateway = NetworkGateway(
        policy: policy,
        client: MockClient((request) async {
          requested.add(request.url.host);
          if (request.url.host == 'api.example') {
            return http.Response('', 302,
                headers: {'location': 'https://tracker.example/x'});
          }
          return http.Response('ok', 200);
        }),
      );

      await expectLater(
        gateway.get(
          Uri.parse('https://api.example/data'),
          purpose: ConnectionPurpose.modelSearch,
          trigger: 'test',
          infoSent: 'query',
        ),
        throwsA(isA<NetworkPolicyError>()),
      );
      expect(requested, ['api.example']);
      expect(policy.hosts, ['api.example', 'tracker.example']);
    });

    test('follows an allowed redirect and drops credentials cross-host',
        () async {
      http.BaseRequest? last;
      final gateway = NetworkGateway(
        policy: _HostPolicy(),
        client: MockClient((request) async {
          last = request;
          if (request.url.host == 'api.example') {
            return http.Response('', 307,
                headers: {'location': 'https://cdn.example/file'});
          }
          return http.Response('payload', 200);
        }),
      );

      final response = await gateway.get(
        Uri.parse('https://api.example/data'),
        purpose: ConnectionPurpose.modelSearch,
        trigger: 'test',
        infoSent: 'query',
        headers: {'Authorization': 'Bearer secret', 'Accept': 'text/plain'},
      );
      expect(response.body, 'payload');
      expect(last!.url.host, 'cdn.example');
      expect(last!.headers.containsKey('Authorization'), isFalse);
      expect(last!.headers['Accept'], 'text/plain');
    });

    test('refuses a downgrade to plain HTTP', () async {
      final gateway = NetworkGateway(
        policy: _HostPolicy(),
        client: MockClient((request) async => http.Response('', 302,
            headers: {'location': 'http://cdn.example/file'})),
      );
      await expectLater(
        gateway.get(
          Uri.parse('https://api.example/data'),
          purpose: ConnectionPurpose.modelSearch,
          trigger: 'test',
          infoSent: 'query',
        ),
        throwsA(isA<NetworkPolicyError>()),
      );
    });
  });
}

class _HostPolicy extends NetworkPolicyService {
  final Set<String> blocked;
  final List<String> hosts = [];

  _HostPolicy({this.blocked = const {}}) : super.test();

  @override
  NetworkPolicyResult evaluateConnection({
    required Uri uri,
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
  }) {
    hosts.add(uri.host);
    return blocked.contains(uri.host)
        ? const NetworkPolicyResult(allowed: false, reason: 'blocked')
        : const NetworkPolicyResult(allowed: true);
  }
}
