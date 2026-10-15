import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/compatibility_report.dart';

CompatibilityReport _report({
  bool estimated = false,
  double? totalRam = 8,
  String? quant = 'Q4_K_M',
}) =>
    CompatibilityReport(
      generatedAtUtc: DateTime.utc(2026, 10, 15, 12),
      appVersion: '1.0.39',
      androidRelease: '14',
      cpuArchitecture: 'arm64-v8a',
      cpuCores: 8,
      totalRamGB: totalRam,
      availableRamGB: 4.2,
      freeStorageGB: 31.5,
      thermalState: 'none',
      modelName: 'Example 1B',
      quantization: quant,
      backend: 'cactus',
      promptType: 'Quick Test',
      timeToFirstTokenMs: 640,
      tokensPerSecond: 12.34,
      totalTokens: 128,
      totalTimeMs: 10400,
      tokenCountsEstimated: estimated,
    );

void main() {
  test('markdown states measured facts and the privacy boundary', () {
    final text = _report().toMarkdown();
    expect(text, contains('**App version:** 1.0.39'));
    expect(text, contains('arm64-v8a, 8 cores'));
    expect(text, contains('8.00 GiB total, 4.20 GiB available'));
    expect(text, contains('Example 1B (Q4_K_M)'));
    expect(text, contains('12.3 tokens/s'));
    expect(text, contains('128 tokens (runtime-measured)'));
    expect(text, contains('no prompts, outputs or personal identifiers'));
  });

  test('estimated counts and missing measurements are labelled honestly', () {
    final text =
        _report(estimated: true, totalRam: null, quant: null).toMarkdown();
    expect(text, contains('128 tokens (estimated from text length)'));
    expect(text, contains('not measured total'));
    expect(text, isNot(contains('()')));
  });

  test('json export is an allow-list with no content or identifiers', () {
    final json = jsonDecode(_report().toJsonString()) as Map<String, dynamic>;
    expect(json['schemaVersion'], CompatibilityReport.schemaVersion);
    expect(json.keys.toSet(), {
      'schemaVersion',
      'generatedAtUtc',
      'appVersion',
      'androidRelease',
      'device',
      'model',
      'run',
    });
    final flat = jsonEncode(json).toLowerCase();
    for (final forbidden in ['prompt"', 'response', 'serial', 'imei', 'path']) {
      expect(flat, isNot(contains(forbidden)), reason: forbidden);
    }
    expect((json['device'] as Map).keys.toSet(), {
      'cpuArchitecture',
      'cpuCores',
      'totalRamGB',
      'availableRamGB',
      'freeStorageGB',
      'thermalState',
    });
  });
}
