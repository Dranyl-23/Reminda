import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  static String _versionName = '1.0.0';
  static String _buildNumber = '13';
  static const String releaseType = 'Production Release';

  static Future<void> initialize() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) _versionName = info.version;
      if (info.buildNumber.isNotEmpty) _buildNumber = info.buildNumber;
    } catch (_) {}
  }

  static String get versionName => _versionName;
  static String get buildNumber => _buildNumber;
  static String get fullVersion => 'v$_versionName+$_buildNumber';
  static String get displayTag => 'v$_versionName+$_buildNumber ($releaseType)';
  static String get fullWithBuild => 'v$_versionName (Build $_buildNumber)';
}

