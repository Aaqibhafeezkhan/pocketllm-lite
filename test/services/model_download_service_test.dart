import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pocketllm_lite/services/model_download_service.dart';
import 'package:pocketllm_lite/services/network_policy_service.dart';
import 'package:pocketllm_lite/services/model_storage_service.dart';

void main() {
  test('restarts safely when a resumed bundle receives HTTP 200', () async {
    final root = await Directory.systemTemp.createTemp('pocketllm_download_');
    addTearDown(() => root.delete(recursive: true));
    final archive = Archive()
      ..addFile(ArchiveFile('fixture/model.gguf', 8, const [
        0x47,
        0x47,
        0x55,
        0x46,
        1,
        2,
        3,
        4,
      ]));
    final bundle = ZipEncoder().encode(archive);
    final adapter = _RangeIgnoringAdapter(bundle);
    final dio = Dio()..httpClientAdapter = adapter;
    final storage = _FakeStorage(root);
    final models = await storage.getModelDirectory();
    final partial = File(
      path.join(models.path, '.downloads', 'fixture.zip.part'),
    );
    await partial.parent.create(recursive: true);
    await partial.writeAsBytes(bundle.take(7).toList());

    final installed = await ModelDownloadService(
      dio: dio,
      storage: storage,
    ).downloadManagedBundle(
      modelId: 'fixture',
      modelName: 'Fixture',
      url: 'https://example.test/fixture.zip',
      archiveFilename: 'fixture.zip',
      catalogSizeMb: 1,
    );

    expect(adapter.rangedGets, 1);
    expect(adapter.fullGets, 1);
    expect(await partial.exists(), isFalse);
    expect(
      await storage.isValidGGUFFile(
        path.join(installed, 'model.gguf'),
      ),
      isTrue,
    );
  });

  group('redirects', () {
    late Directory root;
    late _FakeStorage storage;
    late List<int> bundle;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('pocketllm_redirect_');
      storage = _FakeStorage(root);
      final archive = Archive()
        ..addFile(ArchiveFile('fixture/model.gguf', 8, const [
          0x47, 0x47, 0x55, 0x46, 1, 2, 3, 4, //
        ]));
      bundle = ZipEncoder().encode(archive);
    });

    tearDown(() => root.delete(recursive: true));

    test('follows an HTTPS redirect and evaluates every hop', () async {
      final adapter = _RedirectingAdapter(
        bundle,
        redirects: {
          'https://example.test/fixture.zip': 'https://cdn.example.test/blob/1',
        },
      );
      final policy = _RecordingPolicy();
      final installed = await ModelDownloadService(
        dio: Dio()..httpClientAdapter = adapter,
        networkPolicy: policy,
        storage: storage,
      ).downloadManagedBundle(
        modelId: 'fixture',
        modelName: 'Fixture',
        url: 'https://example.test/fixture.zip',
        archiveFilename: 'fixture.zip',
        catalogSizeMb: 1,
      );

      expect(await File(path.join(installed, 'model.gguf')).exists(), isTrue);
      expect(policy.hosts, contains('example.test'));
      expect(policy.hosts, contains('cdn.example.test'),
          reason: 'the CDN hop must be evaluated by network policy');
    });

    test('a redirect blocked by policy never reaches the network', () async {
      final adapter = _RedirectingAdapter(
        bundle,
        redirects: {
          'https://example.test/fixture.zip':
              'https://tracker.example.test/blob',
        },
      );
      final policy = _RecordingPolicy(blockedHosts: {'tracker.example.test'});

      await expectLater(
        ModelDownloadService(
          dio: Dio()..httpClientAdapter = adapter,
          networkPolicy: policy,
          storage: storage,
        ).downloadManagedBundle(
          modelId: 'fixture',
          modelName: 'Fixture',
          url: 'https://example.test/fixture.zip',
          archiveFilename: 'fixture.zip',
          catalogSizeMb: 1,
        ),
        throwsA(anything),
      );
      expect(adapter.requestedHosts, isNot(contains('tracker.example.test')));
    });

    test('refuses an HTTPS to HTTP downgrade', () async {
      final adapter = _RedirectingAdapter(
        bundle,
        redirects: {
          'https://example.test/fixture.zip': 'http://cdn.example.test/blob',
        },
      );
      await expectLater(
        ModelDownloadService(
          dio: Dio()..httpClientAdapter = adapter,
          networkPolicy: _RecordingPolicy(),
          storage: storage,
        ).downloadManagedBundle(
          modelId: 'fixture',
          modelName: 'Fixture',
          url: 'https://example.test/fixture.zip',
          archiveFilename: 'fixture.zip',
          catalogSizeMb: 1,
        ),
        throwsA(anything),
      );
      expect(adapter.requestedHosts, isNot(contains('cdn.example.test')));
    });

    test('stops after too many redirects', () async {
      final adapter = _RedirectingAdapter(bundle, loopForever: true);
      await expectLater(
        ModelDownloadService(
          dio: Dio()..httpClientAdapter = adapter,
          networkPolicy: _RecordingPolicy(),
          storage: storage,
        ).downloadManagedBundle(
          modelId: 'fixture',
          modelName: 'Fixture',
          url: 'https://example.test/fixture.zip',
          archiveFilename: 'fixture.zip',
          catalogSizeMb: 1,
        ),
        throwsA(anything),
      );
      expect(adapter.requestCount, lessThan(20));
    });
  });
}

class _FakeStorage extends ModelStorageService {
  final Directory root;

  _FakeStorage(this.root);

  @override
  Future<Directory> getModelDirectory() async {
    final directory = Directory(path.join(root.path, 'models'));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<int> getAvailableDiskSpace() async => 4 * 1024 * 1024 * 1024;
}

class _RangeIgnoringAdapter implements HttpClientAdapter {
  final List<int> bundle;
  int rangedGets = 0;
  int fullGets = 0;

  _RangeIgnoringAdapter(this.bundle);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final headers = {
      'accept-ranges': ['bytes'],
      'etag': ['"fixture-v1"'],
      Headers.contentLengthHeader: ['${bundle.length}'],
    };
    if (options.method == 'HEAD') {
      return ResponseBody.fromBytes(const [], 200, headers: headers);
    }
    if (options.headers.keys.any((key) => key.toLowerCase() == 'range')) {
      rangedGets++;
      // Intentionally ignore Range and return the complete body with 200.
    } else {
      fullGets++;
    }
    return ResponseBody.fromBytes(bundle, 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

class _RecordingPolicy extends NetworkPolicyService {
  final Set<String> blockedHosts;
  final List<String> hosts = [];

  _RecordingPolicy({this.blockedHosts = const {}}) : super.test();

  @override
  NetworkPolicyResult evaluateConnection({
    required Uri uri,
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
  }) {
    hosts.add(uri.host);
    if (blockedHosts.contains(uri.host)) {
      return const NetworkPolicyResult(allowed: false, reason: 'blocked');
    }
    return const NetworkPolicyResult(allowed: true);
  }
}

class _RedirectingAdapter implements HttpClientAdapter {
  final List<int> bundle;
  final Map<String, String> redirects;
  final bool loopForever;
  final List<String> requestedHosts = [];
  int requestCount = 0;

  _RedirectingAdapter(
    this.bundle, {
    this.redirects = const {},
    this.loopForever = false,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    requestedHosts.add(options.uri.host);
    if (loopForever) {
      return ResponseBody.fromBytes(const [], 302,
          headers: {
            'location': ['https://example.test/loop/$requestCount'],
          });
    }
    final target = redirects[options.uri.toString()];
    if (target != null) {
      return ResponseBody.fromBytes(const [], 302,
          headers: {
            'location': [target],
          });
    }
    return ResponseBody.fromBytes(bundle, 200, headers: {
      'content-length': ['${bundle.length}'],
      'etag': ['"fixture"'],
    });
  }

  @override
  void close({bool force = false}) {}
}
