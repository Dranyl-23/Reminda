import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_version.dart';

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  bool geminiOnlineFallbackEnabled = true;
  String minRequiredAppVersion = '1.0.0+8';
  String latestAppVersion = '1.0.0+8';
  bool forceUpdateEnabled = false;
  String updateStoreUrl = 'https://github.com/Dranyl-23/Schedly/releases';
  bool maintenanceMode = false;
  String maintenanceMessage = '';

  final ValueNotifier<bool> updateRequiredNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> maintenanceModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> maintenanceMessageNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> geminiFallbackNotifier = ValueNotifier<bool>(true);

  StreamSubscription<DocumentSnapshot>? _subscription;

  static int parseBuildNumber(String version) {
    final trimmed = version.trim();
    if (trimmed.contains('+')) {
      final parts = trimmed.split('+');
      final build = int.tryParse(parts.last.trim());
      if (build != null) return build;
    }
    final directNum = int.tryParse(trimmed);
    if (directNum != null) return directNum;
    return 0;
  }

  /// Parses semver [major, minor, patch] from version string (ignoring +build)
  static List<int> parseSemver(String version) {
    final cleaned = version.split('+').first.replaceAll(RegExp(r'[^0-9.]'), '');
    final parts = cleaned.split('.');
    return parts.map((p) => int.tryParse(p) ?? 0).toList();
  }

  static bool isVersionOutdated({
    required String currentVersion,
    required String currentBuild,
    required String minRequiredVersion,
  }) {
    final minBuild = parseBuildNumber(minRequiredVersion);
    final curBuild = parseBuildNumber(currentBuild);

    // If both have explicit build numbers, check build number first
    if (minBuild > 0 && curBuild > 0) {
      if (curBuild < minBuild) return true;
      if (curBuild > minBuild) return false;
    }

    // Fallback or secondary: Semver compare
    final minParts = parseSemver(minRequiredVersion);
    final curParts = parseSemver(currentVersion);

    for (int i = 0; i < 3; i++) {
      final cur = i < curParts.length ? curParts[i] : 0;
      final min = i < minParts.length ? minParts[i] : 0;
      if (cur < min) return true;
      if (cur > min) return false;
    }

    return false;
  }

  bool get isUpdateRequired {
    if (!forceUpdateEnabled) return false;
    return isVersionOutdated(
      currentVersion: AppVersion.versionName,
      currentBuild: AppVersion.buildNumber,
      minRequiredVersion: minRequiredAppVersion,
    );
  }

  void startListening() {
    try {
      final firestore = FirebaseFirestore.instance;
      _subscription = firestore
          .collection('system_config')
          .doc('app_control')
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          geminiOnlineFallbackEnabled = data['geminiOnlineFallbackEnabled'] as bool? ?? true;
          minRequiredAppVersion = data['minRequiredAppVersion'] as String? ?? '1.0.0+8';
          latestAppVersion = data['latestAppVersion'] as String? ?? '1.0.0+8';
          forceUpdateEnabled = data['forceUpdateEnabled'] as bool? ?? false;
          updateStoreUrl = data['updateStoreUrl'] as String? ?? 'https://github.com/Dranyl-23/Schedly/releases';
          maintenanceMode = data['maintenanceMode'] as bool? ?? false;
          maintenanceMessage = data['maintenanceMessage'] as String? ?? '';

          updateRequiredNotifier.value = isUpdateRequired;
          maintenanceModeNotifier.value = maintenanceMode;
          maintenanceMessageNotifier.value = maintenanceMessage;
          geminiFallbackNotifier.value = geminiOnlineFallbackEnabled;

          debugPrint('RemoteConfigService: Sync updated (Force: $forceUpdateEnabled, Required: $isUpdateRequired, Min: $minRequiredAppVersion, Current: ${AppVersion.buildNumber}, Maintenance: $maintenanceMode, GeminiFallback: $geminiOnlineFallbackEnabled)');
        }
      }, onError: (err) {
        debugPrint('RemoteConfigService: Listener notice ($err)');
      });
    } catch (e) {
      debugPrint('RemoteConfigService: Init error ($e)');
    }
  }

  void dispose() {
    _subscription?.cancel();
    updateRequiredNotifier.dispose();
    maintenanceModeNotifier.dispose();
    maintenanceMessageNotifier.dispose();
    geminiFallbackNotifier.dispose();
  }
}

