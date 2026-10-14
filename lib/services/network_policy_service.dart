import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/network_audit_log.dart';
import 'storage_service.dart';

enum ConnectionPurpose {
  updateCheck,
  manualUpdateCheck,
  updateDownload,
  modelSearch,
  modelDownload,
  webSearch,
  skillInstall,
  remoteInference,
  externalNavigation,
  fontDownload,
}

class NetworkPolicyResult {
  final bool allowed;
  final String? reason;

  const NetworkPolicyResult({required this.allowed, this.reason});
}

class NetworkPolicyService {
  static final NetworkPolicyService _instance =
      NetworkPolicyService._internal();

  /// Fresh, non-singleton instance for tests and subclasses.
  @visibleForTesting
  NetworkPolicyService.test();
  factory NetworkPolicyService() => _instance;
  NetworkPolicyService._internal();

  StorageService? _storageService;
  final List<NetworkAuditEntry> _auditLog = [];

  /// Loopback decisions are useful for the current session but are not
  /// persisted: they never leave the device and would otherwise drown out the
  /// meaningful entries (every local model request would write storage).
  final List<NetworkAuditEntry> _loopbackLog = [];
  final StreamController<List<NetworkAuditEntry>> _auditLogController =
      StreamController<List<NetworkAuditEntry>>.broadcast();

  Stream<List<NetworkAuditEntry>> get auditLogStream =>
      _auditLogController.stream;
  List<NetworkAuditEntry> get auditLog => _mergedLog();

  List<NetworkAuditEntry> _mergedLog() {
    final merged = [..._auditLog, ..._loopbackLog]
      ..sort((left, right) => right.timestamp.compareTo(left.timestamp));
    return List.unmodifiable(merged.take(100));
  }

  void init(StorageService storageService) {
    _storageService = storageService;
    _auditLog.clear();
    _loopbackLog.clear();
    final raw = storageService.getSetting(
      AppConstants.networkAuditLogKey,
      defaultValue: const [],
    );
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          _auditLog.add(
            NetworkAuditEntry.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          // Preserve valid audit records if one legacy entry is malformed.
        }
      }
    }
    _auditLog.sort((left, right) => right.timestamp.compareTo(left.timestamp));
    if (_auditLog.length > 100) {
      _auditLog.removeRange(100, _auditLog.length);
    }
  }

  /// True only for addresses that cannot leave this device: `localhost`
  /// (and `*.localhost`), the IPv4 127.0.0.0/8 block, and IPv6 `::1`.
  ///
  /// `0.0.0.0` is deliberately not loopback. It is the unspecified address, not
  /// a destination, and treating it as local would let a misconfigured or
  /// hostile endpoint bypass Strict Offline.
  bool isLoopback(Uri uri) {
    var host = uri.host.toLowerCase();
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    if (host == 'localhost' || host.endsWith('.localhost')) return true;
    final address = InternetAddress.tryParse(host);
    if (address == null || address.type == InternetAddressType.unix) {
      return false;
    }
    return address.isLoopback;
  }

  bool get isStrictOfflineMode {
    if (_storageService == null) return false;
    final val = _storageService!.getSetting(
      AppConstants.strictOfflineModeKey,
      defaultValue: false,
    );
    return val is bool ? val : false;
  }

  bool get isAutoUpdateCheckEnabled {
    if (_storageService == null) return false;
    final val = _storageService!.getSetting(
      AppConstants.autoUpdateCheckKey,
      defaultValue: false,
    );
    return val is bool ? val : false;
  }

  Future<void> setAutoUpdateCheckEnabled(bool enabled) async {
    final storage = _storageService;
    if (storage == null) {
      throw StateError('Network policy has not been initialized.');
    }
    await storage.saveSetting(AppConstants.autoUpdateCheckKey, enabled);
  }

  bool get isOnlineModelBrowsingEnabled {
    if (_storageService == null) return true;
    final val = _storageService!.getSetting(
      AppConstants.onlineModelBrowsingKey,
      defaultValue: true,
    );
    return val is bool ? val : true;
  }

  bool get isTavilySearchEnabled {
    if (_storageService == null) return true;
    final val = _storageService!.getSetting(
      AppConstants.tavilySearchEnabledKey,
      defaultValue: true,
    );
    return val is bool ? val : true;
  }

  bool get isGithubSkillsEnabled {
    if (_storageService == null) return true;
    final val = _storageService!.getSetting(
      AppConstants.githubSkillsEnabledKey,
      defaultValue: true,
    );
    return val is bool ? val : true;
  }

  NetworkPolicyResult evaluateConnection({
    required Uri uri,
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
  }) {
    final domain = uri.host.isEmpty ? uri.toString() : uri.host;
    final loopback = isLoopback(uri);

    if (loopback) {
      _logAudit(
        domain: domain,
        purpose: purpose.name,
        trigger: trigger,
        infoSent: infoSent,
        allowed: true,
        persist: false,
      );
      return const NetworkPolicyResult(allowed: true);
    }

    if (isStrictOfflineMode) {
      const reason = 'Blocked by Strict Offline Mode';
      _logAudit(
        domain: domain,
        purpose: purpose.name,
        trigger: trigger,
        infoSent: infoSent,
        allowed: false,
        blockReason: reason,
      );
      return const NetworkPolicyResult(allowed: false, reason: reason);
    }

    switch (purpose) {
      case ConnectionPurpose.updateCheck:
        if (!isAutoUpdateCheckEnabled) {
          const reason = 'Automatic update checks disabled';
          _logAudit(
            domain: domain,
            purpose: purpose.name,
            trigger: trigger,
            infoSent: infoSent,
            allowed: false,
            blockReason: reason,
          );
          return const NetworkPolicyResult(allowed: false, reason: reason);
        }
        break;

      case ConnectionPurpose.manualUpdateCheck:
      case ConnectionPurpose.updateDownload:
        // These are explicit user actions. Strict Offline Mode is still
        // enforced before this switch, but the background-update preference
        // must not block a user-initiated check or confirmed download.
        break;

      case ConnectionPurpose.modelSearch:
      case ConnectionPurpose.modelDownload:
        if (!isOnlineModelBrowsingEnabled) {
          const reason = 'Online model browsing disabled';
          _logAudit(
            domain: domain,
            purpose: purpose.name,
            trigger: trigger,
            infoSent: infoSent,
            allowed: false,
            blockReason: reason,
          );
          return const NetworkPolicyResult(allowed: false, reason: reason);
        }
        break;

      case ConnectionPurpose.webSearch:
        if (!isTavilySearchEnabled) {
          const reason = 'Tavily web search disabled';
          _logAudit(
            domain: domain,
            purpose: purpose.name,
            trigger: trigger,
            infoSent: infoSent,
            allowed: false,
            blockReason: reason,
          );
          return const NetworkPolicyResult(allowed: false, reason: reason);
        }
        break;

      case ConnectionPurpose.skillInstall:
        if (!isGithubSkillsEnabled) {
          const reason = 'GitHub skill installation disabled';
          _logAudit(
            domain: domain,
            purpose: purpose.name,
            trigger: trigger,
            infoSent: infoSent,
            allowed: false,
            blockReason: reason,
          );
          return const NetworkPolicyResult(allowed: false, reason: reason);
        }
        break;

      case ConnectionPurpose.fontDownload:
        const reason =
            'Runtime font downloading is disabled (fonts bundled locally)';
        _logAudit(
          domain: domain,
          purpose: purpose.name,
          trigger: trigger,
          infoSent: infoSent,
          allowed: false,
          blockReason: reason,
        );
        return const NetworkPolicyResult(allowed: false, reason: reason);

      case ConnectionPurpose.remoteInference:
      case ConnectionPurpose.externalNavigation:
        break;
    }

    _logAudit(
      domain: domain,
      purpose: purpose.name,
      trigger: trigger,
      infoSent: infoSent,
      allowed: true,
    );
    return const NetworkPolicyResult(allowed: true);
  }

  void _logAudit({
    required String domain,
    required String purpose,
    required String trigger,
    required String infoSent,
    required bool allowed,
    String? blockReason,
    bool persist = true,
  }) {
    final entry = NetworkAuditEntry(
      timestamp: DateTime.now(),
      domain: domain,
      purpose: purpose,
      trigger: trigger,
      infoSent: infoSent,
      allowed: allowed,
      blockReason: blockReason,
    );
    if (!persist) {
      _loopbackLog.insert(0, entry);
      if (_loopbackLog.length > 50) {
        _loopbackLog.removeLast();
      }
      _auditLogController.add(_mergedLog());
      return;
    }
    _auditLog.insert(0, entry);
    if (_auditLog.length > 100) {
      _auditLog.removeLast();
    }
    _auditLogController.add(_mergedLog());
    final storage = _storageService;
    if (storage != null) {
      unawaited(
        storage.saveSetting(
          AppConstants.networkAuditLogKey,
          _auditLog.map((item) => item.toJson()).toList(growable: false),
        ),
      );
    }
  }
}
