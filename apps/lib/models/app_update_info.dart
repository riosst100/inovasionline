class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.apkUrl,
  });

  /// Reads release.json as written by scripts/publish-apk.sh (`version`,
  /// `buildNumber`, `filename`). `minSupportedBuildNumber` and `releaseNotes`
  /// are optional (the script does not write them yet): builds below the
  /// minimum get an update they cannot dismiss.
  factory AppUpdateInfo.fromReleaseJson(
    Map<String, dynamic> json, {
    required String baseUrl,
    required int currentBuildNumber,
  }) {
    final minSupported = (json['minSupportedBuildNumber'] as num?)?.toInt() ?? 0;
    return AppUpdateInfo(
      version: json['version'] as String,
      buildNumber: (json['buildNumber'] as num).toInt(),
      forceUpdate: currentBuildNumber < minSupported,
      releaseNotes: json['releaseNotes'] as String? ?? '',
      apkUrl: '$baseUrl/${json['filename'] as String}',
    );
  }

  final String version;
  final int buildNumber;
  final bool forceUpdate;
  final String releaseNotes;
  final String apkUrl;
}
