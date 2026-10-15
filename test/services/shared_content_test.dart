import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocketllm_lite/services/shared_content.dart';

void main() {
  final inbox = p.join('tmp', 'cache', 'shared_inbox');
  final policy = SharedContentPolicy(inboxPath: inbox);
  String inboxFile(String name) => p.join(inbox, 'abc', name);

  RawSharedFile file(
    String name, {
    String? mime,
    int size = 1024,
    String? path,
    String? error,
  }) =>
      RawSharedFile(
        path: path ?? inboxFile(name),
        name: name,
        mimeType: mime,
        sizeBytes: size,
        error: error,
      );

  group('text and links', () {
    test('plain text is accepted and its links are extracted', () {
      final content = policy.validate(const RawShare(
        text: 'Read this: https://example.com/a?b=1, and (http://x.test/y).',
      ));
      expect(content.hasText, isTrue);
      expect(content.links, ['https://example.com/a?b=1', 'http://x.test/y']);
      expect(content.isLinkOnly, isFalse);
    });

    test('a link-only share is recognised', () {
      final content =
          policy.validate(const RawShare(text: 'https://example.com/post'));
      expect(content.isLinkOnly, isTrue);
    });

    test('only http and https are surfaced as links', () {
      final links = SharedContentPolicy.extractLinks(
        'javascript:alert(1) file:///etc/passwd content://x ftp://h/f '
        'https://ok.example/path',
      );
      expect(links, ['https://ok.example/path']);
    });

    test('oversized text is rejected with a reason', () {
      final content = policy.validate(
        RawShare(text: 'a' * (SharedContentPolicy.maxTextChars + 1)),
      );
      expect(content.hasText, isFalse);
      expect(content.rejected.single.reason, contains('200 KB'));
    });
  });

  group('files', () {
    test('PDF, TXT, Markdown and CSV are accepted by type', () {
      final content = policy.validate(RawShare(files: [
        file('a.pdf', mime: 'application/pdf'),
        file('b.txt', mime: 'text/plain'),
        file('c.md', mime: 'text/markdown'),
        file('d.csv', mime: 'text/csv'),
      ]));
      expect(content.files.map((f) => f.kind), [
        SharedFileKind.pdf,
        SharedFileKind.text,
        SharedFileKind.text,
        SharedFileKind.text,
      ]);
      expect(content.rejected, isEmpty);
    });

    test('a generic MIME type falls back to a safe text extension', () {
      final ok = policy.validate(RawShare(
        files: [file('notes.md', mime: 'application/octet-stream')],
      ));
      expect(ok.files, hasLength(1));
      final bad = policy.validate(RawShare(
        files: [file('payload.apk', mime: 'application/octet-stream')],
      ));
      expect(bad.files, isEmpty);
      expect(bad.rejected.single.reason, contains('Unsupported type'));
    });

    test('executables, archives and images are refused', () {
      for (final name in ['x.exe', 'y.zip', 'z.png', 'w.docx', 'v.js']) {
        final content = policy.validate(RawShare(files: [file(name)]));
        expect(content.files, isEmpty, reason: name);
        expect(content.rejected, hasLength(1), reason: name);
      }
    });

    test('empty and oversized files are refused', () {
      final content = policy.validate(RawShare(files: [
        file('empty.txt', mime: 'text/plain', size: 0),
        file(
          'big.pdf',
          mime: 'application/pdf',
          size: SharedContentPolicy.maxFileBytes + 1,
        ),
      ]));
      expect(content.files, isEmpty);
      expect(content.rejected.map((r) => r.reason),
          [contains('empty'), contains('25 MB')]);
    });

    test('a path outside the share inbox is never accepted', () {
      final content = policy.validate(RawShare(files: [
        file('leak.txt',
            mime: 'text/plain', path: '/data/data/app/databases/secret.db'),
        file('trav.txt',
            mime: 'text/plain', path: p.join(inbox, '..', 'other', 'x.txt')),
      ]));
      expect(content.files, isEmpty);
      expect(content.rejected, hasLength(2));
      expect(content.rejected.first.reason, contains('share inbox'));
    });

    test('errors reported by the platform layer are surfaced', () {
      final content = policy.validate(RawShare(files: [
        file('bad.txt', error: 'The sending app denied access.'),
      ]));
      expect(content.rejected.single.reason, 'The sending app denied access.');
    });

    test('at most five files are used and the rest is reported', () {
      final content = policy.validate(RawShare(files: [
        for (var i = 0; i < 7; i++) file('f$i.txt', mime: 'text/plain'),
      ]));
      expect(content.files, hasLength(SharedContentPolicy.maxFiles));
      expect(content.rejected.single.reason, contains('first 5'));
    });
  });

  test('RawShare parses the platform payload', () {
    final raw = RawShare.fromMap({
      'text': 'hello',
      'subject': 'S',
      'files': [
        {
          'path': '/x/a.txt',
          'name': 'a.txt',
          'mimeType': 'text/plain',
          'sizeBytes': 5
        },
        'not-a-map',
      ],
    });
    expect(raw.text, 'hello');
    expect(raw.files.single.name, 'a.txt');
    expect(raw.files.single.sizeBytes, 5);
  });
}
