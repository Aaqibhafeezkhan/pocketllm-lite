import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pocketllm_lite/features/chat/presentation/providers/models_provider.dart';
import 'package:pocketllm_lite/features/sharing/presentation/share_receiver_screen.dart';
import 'package:pocketllm_lite/features/sharing/providers/share_provider.dart';
import 'package:pocketllm_lite/services/shared_content.dart';

class _FixedShare extends ShareNotifier {
  final SharedContent? initial;
  _FixedShare(this.initial);

  @override
  SharedContent? build() => initial;

  @override
  Future<void> clear() async => state = null;
}

Widget _app(SharedContent? content, {List<UnifiedModel> models = const []}) {
  final router = GoRouter(
    initialLocation: '/share',
    routes: [
      GoRoute(
        path: '/share',
        builder: (context, state) => const ShareReceiverScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const Scaffold(body: Text('chat-screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      shareProvider.overrideWith(() => _FixedShare(content)),
      unifiedModelsProvider.overrideWith((ref) async => models),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareReceiverScreen', () {
    testWidgets('shows a preview and the three actions for shared text',
        (tester) async {
      await tester.pumpWidget(_app(
        const SharedContent(
          text: 'Quarterly numbers look strong.',
          subject: 'Weekly update',
        ),
      ));
      await tester.pump();

      expect(find.text('Weekly update'), findsOneWidget);
      expect(find.text('Quarterly numbers look strong.'), findsOneWidget);
      expect(find.byKey(const Key('share-summarize')), findsOneWidget);
      expect(find.byKey(const Key('share-ask')), findsOneWidget);
      expect(find.byKey(const Key('share-save')), findsOneWidget);
    });

    testWidgets('a link-only share explains that nothing is fetched',
        (tester) async {
      await tester.pumpWidget(_app(
        const SharedContent(
          text: 'https://example.com/post',
          links: ['https://example.com/post'],
        ),
      ));
      await tester.pump();

      expect(find.textContaining('does not open web pages'), findsOneWidget);
      final save =
          tester.widget<OutlinedButton>(find.byKey(const Key('share-save')));
      expect(save.onPressed, isNull);
    });

    testWidgets('rejected items are listed with their reason', (tester) async {
      await tester.pumpWidget(_app(
        const SharedContent(
          text: 'note',
          rejected: [
            RejectedSharedItem('virus.apk', 'Unsupported type.'),
          ],
        ),
      ));
      await tester.pump();

      expect(find.text('Not used'), findsOneWidget);
      expect(find.textContaining('virus.apk'), findsOneWidget);
      expect(find.textContaining('Unsupported type.'), findsOneWidget);
    });

    testWidgets('an empty share says there is nothing to read', (tester) async {
      await tester.pumpWidget(_app(const SharedContent()));
      await tester.pump();
      expect(find.textContaining('nothing PocketLLM can read'), findsOneWidget);
      expect(find.byKey(const Key('share-summarize')), findsNothing);
    });

    testWidgets('asking without a question is refused locally', (tester) async {
      await tester.pumpWidget(_app(const SharedContent(text: 'hello')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('share-ask')));
      await tester.pump();
      expect(find.byKey(const Key('share-error')), findsOneWidget);
      expect(find.text('Type a question first.'), findsOneWidget);
    });

    testWidgets('with no model ready the user is sent to set one up',
        (tester) async {
      await tester.pumpWidget(_app(const SharedContent(text: 'hello')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('share-summarize')));
      // The progress spinner animates forever, so settle manually.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('No model ready'), findsOneWidget);
      expect(find.text('Set up a model'), findsOneWidget);
      // Nothing was sent anywhere, and the share is still waiting.
      expect(find.text('chat-screen'), findsNothing);
      await tester.tap(find.text('Not now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('share-summarize')), findsOneWidget);
    });

    testWidgets('file previews show the name and size', (tester) async {
      final file = File(p.join('cache', 'shared_inbox', 'a', 'report.txt'));

      await tester.pumpWidget(_app(
        SharedContent(files: [
          AcceptedSharedFile(
            file: file,
            name: 'report.txt',
            kind: SharedFileKind.text,
            sizeBytes: 2048,
          ),
        ]),
      ));
      await tester.pump();

      expect(find.text('report.txt'), findsOneWidget);
      expect(find.text('2 KB'), findsOneWidget);
    });
  });

  group('ShareNotifier', () {
    const channel = MethodChannel('pocketllm_lite/share');
    late List<String> discarded;
    late String inbox;

    setUp(() {
      discarded = [];
      inbox = p.join('cache', 'shared_inbox');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'inboxPath') return inbox;
        if (call.method == 'discard') {
          discarded.addAll(
            ((call.arguments as Map)['paths'] as List).cast<String>(),
          );
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('refused copies are deleted immediately and good ones kept', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final good = p.join(inbox, 'a', 'ok.txt');
      final bad = p.join(inbox, 'b', 'tool.exe');
      final accepted = await container.read(shareProvider.notifier).ingest(
            RawShare(
              text: 'see attached',
              files: [
                RawSharedFile(
                  path: good,
                  name: 'ok.txt',
                  mimeType: 'text/plain',
                  sizeBytes: 12,
                ),
                RawSharedFile(
                  path: bad,
                  name: 'tool.exe',
                  mimeType: 'application/octet-stream',
                  sizeBytes: 12,
                ),
              ],
            ),
          );

      expect(accepted, isTrue);
      final content = container.read(shareProvider)!;
      expect(content.files.map((f) => f.name), ['ok.txt']);
      expect(content.rejected.map((r) => r.name), ['tool.exe']);
      expect(discarded, [bad]);

      await container.read(shareProvider.notifier).clear();
      expect(container.read(shareProvider), isNull);
      expect(discarded, contains(good));
    });

    test('an empty payload is not shown to the user', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final accepted =
          await container.read(shareProvider.notifier).ingest(const RawShare());
      expect(accepted, isFalse);
      expect(container.read(shareProvider), isNull);
    });
  });
}
