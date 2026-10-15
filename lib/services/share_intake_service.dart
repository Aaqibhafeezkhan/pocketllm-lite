import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'shared_content.dart';

/// Bridge to the Android share-intent handler (`ShareIntentHandler.kt`).
///
/// The platform layer copies shared files into a private cache inbox and hands
/// over only plain data. This class never touches another app's storage.
class ShareIntakeService {
  static const _channelName = 'pocketllm_lite/share';

  final MethodChannel _channel;
  final StreamController<RawShare> _incoming =
      StreamController<RawShare>.broadcast();

  ShareIntakeService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_onCall);
  }

  /// Shares that arrive while the app is already running.
  Stream<RawShare> get incoming => _incoming.stream;

  /// The share that launched the app, if any. Returns it once.
  Future<RawShare?> takeInitialShare() async {
    try {
      final map =
          await _channel.invokeMapMethod<Object?, Object?>('getInitialShare');
      return map == null ? null : RawShare.fromMap(map);
    } on MissingPluginException {
      return null; // not Android, or a test without the channel
    } on PlatformException catch (error) {
      debugPrint('Share intake failed: ${error.message}');
      return null;
    }
  }

  /// The inbox directory the platform layer copies shared files into.
  Future<String?> inboxPath() async {
    try {
      return await _channel.invokeMethod<String>('inboxPath');
    } on MissingPluginException {
      return null;
    }
  }

  /// Deletes shared copies. Only paths inside the inbox are removed.
  Future<void> discard(Iterable<String> paths) async {
    final list = paths.where((path) => path.isNotEmpty).toList();
    if (list.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('discard', {'paths': list});
    } on MissingPluginException {
      // Nothing to clean up outside Android.
    }
  }

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'onShare' && call.arguments is Map) {
      _incoming.add(RawShare.fromMap(call.arguments as Map<Object?, Object?>));
    }
    return null;
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _incoming.close();
  }
}
