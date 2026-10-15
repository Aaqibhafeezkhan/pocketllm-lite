import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Signing material in a public repository is a permanent leak. This test
/// fails when a keystore, signing properties file or private key is tracked.
///
/// History already contains `upload-keystore.jks` (see docs/RELEASE_SIGNING.md);
/// that key must be treated as compromised. This guard only prevents new
/// leaks and requires the `git` executable, so it is skipped without it.
void main() {
  test('no keystore, signing properties or private key is tracked', () async {
    final ProcessResult result;
    try {
      result = await Process.run('git', ['ls-files']);
    } on ProcessException {
      markTestSkipped('git is not available');
      return;
    }
    if (result.exitCode != 0) {
      markTestSkipped('not a git checkout');
      return;
    }
    final forbidden = RegExp(
      r'(\.jks|\.keystore|\.p12|\.pfx|\.pem)$|(^|/)key\.properties(\..*)?$',
      caseSensitive: false,
    );
    final offenders = (result.stdout as String)
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && forbidden.hasMatch(line))
        .toList();
    expect(
      offenders,
      isEmpty,
      reason: 'Untrack these files and rotate any key they contain: $offenders',
    );
  });
}
