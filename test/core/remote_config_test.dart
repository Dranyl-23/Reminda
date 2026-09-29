import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_scanner/core/config/remote_config_service.dart';

void main() {
  group('RemoteConfigService - Build Number Parsing', () {
    test('extracts build number from version with plus sign', () {
      expect(RemoteConfigService.parseBuildNumber('1.0.0+14'), equals(14));
      expect(RemoteConfigService.parseBuildNumber('1.0.0+16'), equals(16));
      expect(RemoteConfigService.parseBuildNumber('2.5.1+105'), equals(105));
    });

    test('extracts build number from direct integer string', () {
      expect(RemoteConfigService.parseBuildNumber('15'), equals(15));
      expect(RemoteConfigService.parseBuildNumber('42'), equals(42));
    });

    test('returns 0 for versions without build number or invalid strings', () {
      expect(RemoteConfigService.parseBuildNumber('1.0.0'), equals(0));
      expect(RemoteConfigService.parseBuildNumber('unknown'), equals(0));
      expect(RemoteConfigService.parseBuildNumber(''), equals(0));
    });
  });

  group('RemoteConfigService - Semantic Version Parsing', () {
    test('parses standard semver triples', () {
      expect(RemoteConfigService.parseSemver('1.0.0'), equals([1, 0, 0]));
      expect(RemoteConfigService.parseSemver('2.14.3'), equals([2, 14, 3]));
      expect(RemoteConfigService.parseSemver('v1.2.0'), equals([1, 2, 0]));
    });

    test('parses semver with build metadata stripped', () {
      expect(RemoteConfigService.parseSemver('1.0.0+15'), equals([1, 0, 0]));
      expect(RemoteConfigService.parseSemver('2.0.1+99'), equals([2, 0, 1]));
    });
  });

  group('RemoteConfigService - Version Comparison (isVersionOutdated)', () {
    test('build 15 is not outdated when min required is build 14', () {
      final outdated = RemoteConfigService.isVersionOutdated(
        currentVersion: '1.0.0',
        currentBuild: '15',
        minRequiredVersion: '1.0.0+14',
      );
      expect(outdated, isFalse);
    });

    test('build 15 is not outdated when min required is build 15', () {
      final outdated = RemoteConfigService.isVersionOutdated(
        currentVersion: '1.0.0',
        currentBuild: '15',
        minRequiredVersion: '1.0.0+15',
      );
      expect(outdated, isFalse);
    });

    test('build 15 is outdated when min required is build 16', () {
      final outdated = RemoteConfigService.isVersionOutdated(
        currentVersion: '1.0.0',
        currentBuild: '15',
        minRequiredVersion: '1.0.0+16',
      );
      expect(outdated, isTrue);
    });

    test('outdated when minor version is higher', () {
      final outdated = RemoteConfigService.isVersionOutdated(
        currentVersion: '1.0.0',
        currentBuild: '15',
        minRequiredVersion: '1.1.0',
      );
      expect(outdated, isTrue);
    });

    test('not outdated when current version has higher semver', () {
      final outdated = RemoteConfigService.isVersionOutdated(
        currentVersion: '2.0.0',
        currentBuild: '1',
        minRequiredVersion: '1.9.9',
      );
      expect(outdated, isFalse);
    });
  });

  group('RemoteConfigService - Reactive Notifiers', () {
    test('notifiers initialize with default values', () {
      final service = RemoteConfigService.instance;
      expect(service.updateRequiredNotifier.value, isA<bool>());
      expect(service.maintenanceModeNotifier.value, isA<bool>());
      expect(service.maintenanceMessageNotifier.value, isA<String>());
      expect(service.geminiFallbackNotifier.value, isA<bool>());
    });

    test('maintenanceModeNotifier updates correctly', () {
      final service = RemoteConfigService.instance;
      service.maintenanceModeNotifier.value = true;
      expect(service.maintenanceModeNotifier.value, isTrue);

      service.maintenanceModeNotifier.value = false;
      expect(service.maintenanceModeNotifier.value, isFalse);
    });
  });
}
