import 'dart:convert';

/// A device/model compatibility report the user can paste into a GitHub issue.
///
/// Privacy contract: this object is built from an explicit allow-list of
/// facts. It never contains prompts, model output, chat content, file paths,
/// device names, serial numbers or any account identifier, and nothing is sent
/// anywhere. The user copies the text and decides whether to share it.
class CompatibilityReport {
  final DateTime generatedAtUtc;
  final String appVersion;
  final String? androidRelease;
  final String cpuArchitecture;
  final int cpuCores;
  final double? totalRamGB;
  final double? availableRamGB;
  final double? freeStorageGB;
  final String? thermalState;
  final String modelName;
  final String? quantization;
  final String backend;
  final String promptType;
  final int timeToFirstTokenMs;
  final double tokensPerSecond;
  final int totalTokens;
  final int totalTimeMs;
  final bool tokenCountsEstimated;

  const CompatibilityReport({
    required this.generatedAtUtc,
    required this.appVersion,
    this.androidRelease,
    required this.cpuArchitecture,
    required this.cpuCores,
    this.totalRamGB,
    this.availableRamGB,
    this.freeStorageGB,
    this.thermalState,
    required this.modelName,
    this.quantization,
    required this.backend,
    required this.promptType,
    required this.timeToFirstTokenMs,
    required this.tokensPerSecond,
    required this.totalTokens,
    required this.totalTimeMs,
    required this.tokenCountsEstimated,
  });

  static const schemaVersion = 1;

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'generatedAtUtc': generatedAtUtc.toIso8601String(),
        'appVersion': appVersion,
        'androidRelease': androidRelease,
        'device': {
          'cpuArchitecture': cpuArchitecture,
          'cpuCores': cpuCores,
          'totalRamGB': totalRamGB,
          'availableRamGB': availableRamGB,
          'freeStorageGB': freeStorageGB,
          'thermalState': thermalState,
        },
        'model': {
          'name': modelName,
          'quantization': quantization,
          'backend': backend,
        },
        'run': {
          'promptType': promptType,
          'timeToFirstTokenMs': timeToFirstTokenMs,
          'tokensPerSecond': tokensPerSecond,
          'totalTokens': totalTokens,
          'totalTimeMs': totalTimeMs,
          'tokenCountsEstimated': tokenCountsEstimated,
        },
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Markdown for a GitHub issue. Unmeasured values say so explicitly.
  String toMarkdown() {
    String gib(double? value) =>
        value == null ? 'not measured' : '${value.toStringAsFixed(2)} GiB';
    final tokens = tokenCountsEstimated
        ? '$totalTokens tokens (estimated from text length)'
        : '$totalTokens tokens (runtime-measured)';
    return '''
### PocketLLM Lite compatibility report

- **App version:** $appVersion
- **Android:** ${androidRelease ?? 'not recorded'}
- **CPU:** $cpuArchitecture, $cpuCores cores
- **RAM:** ${gib(totalRamGB)} total, ${gib(availableRamGB)} available at test time
- **Free storage:** ${gib(freeStorageGB)}
- **Thermal state:** ${thermalState ?? 'not available'}

**Model:** $modelName${quantization == null ? '' : ' ($quantization)'}
**Backend:** $backend

**Result ($promptType):**
- Time to first token: $timeToFirstTokenMs ms
- Output speed: ${tokensPerSecond.toStringAsFixed(1)} tokens/s
- $tokens in ${(totalTimeMs / 1000).toStringAsFixed(2)} s

_Generated on-device ${generatedAtUtc.toIso8601String()}. Contains no prompts, outputs or personal identifiers. Speed figures are from one run and are not a benchmark._
''';
  }
}
