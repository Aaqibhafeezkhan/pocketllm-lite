import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pocketllm_lite/main.dart' as app;

/// Drives the real application (real storage, router and widgets) from a fresh
/// install. Run on a device or emulator:
///
///   adb shell pm clear com.pocketllm.pocketllm_lite   # fresh state
///   flutter test integration_test/app_flow_test.dart -d DEVICE_ID
///
/// No model is installed and no server is reachable, which is exactly the
/// first-launch situation these assertions describe.
/// When set (`--dart-define=SCREENSHOT_PAUSE_MS=3000`) the test announces each
/// checkpoint on stdout and waits, so an external `adb screencap` loop can
/// capture a real frame of that state. Normal runs do not pause.
const _pauseMs = int.fromEnvironment('SCREENSHOT_PAUSE_MS');

Future<void> _checkpoint(WidgetTester tester, String name) async {
  if (_pauseMs <= 0) return;
  // ignore: avoid_print
  print('CHECKPOINT $name');
  await tester.pump();
  await Future<void>.delayed(const Duration(milliseconds: _pauseMs));
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
    String? reason,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for ${reason ?? finder.toString()}');
  }

  testWidgets(
    'fresh launch: onboarding reaches model setup, then chat guides setup',
    (tester) async {
      app.main();

      // 1. Welcome page.
      await pumpUntil(tester, find.text('Welcome to PocketLLM'));
      await _checkpoint(tester, 'onboarding-welcome');

      // 2. Walk the pages with the real Next button.
      await tester.tap(find.text('Next'));
      await pumpUntil(tester, find.text('Setup & Chat'));
      await tester.tap(find.text('Next'));
      await pumpUntil(tester, find.text('Privacy & Connection Controls'));
      await tester.tap(find.text('Next'));

      // 3. The new model-setup step, with real alternatives.
      await pumpUntil(tester, find.text('Get your first model'));
      await _checkpoint(tester, 'onboarding-first-model');
      expect(find.text('Find models'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Decide later'), findsOneWidget);
      expect(
          find.text('Use my own Ollama or compatible server'), findsOneWidget);
      // Nothing was downloaded or listed before the user asked.
      expect(find.byIcon(Icons.download_rounded), findsNothing);

      // 4. Skipping lands in chat, where setup stays one tap away.
      await tester.ensureVisible(find.text('Decide later'));
      await tester.tap(find.text('Decide later'));
      await pumpUntil(
        tester,
        find.text('Set up a model'),
        timeout: const Duration(seconds: 45),
        reason: 'the empty-state model chip in the chat top bar',
      );

      await _checkpoint(tester, 'chat-no-model');
      // 5. The top bar is the compact three-action layout.
      expect(find.byTooltip('History'), findsOneWidget);
      expect(find.byTooltip('New chat'), findsOneWidget);
      expect(find.byTooltip('More options'), findsOneWidget);
      await tester.tap(find.byTooltip('More options'));
      await pumpUntil(tester, find.text('Chat settings'));
      await _checkpoint(tester, 'chat-overflow-menu');
      expect(find.text('App settings'), findsOneWidget);
      await tester.tapAt(const Offset(5, 300)); // dismiss menu
      await tester.pump(const Duration(milliseconds: 300));

      // 6. The empty chat explains what to do, without implying Ollama only.
      expect(
          find.textContaining('Download an on-device model'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
