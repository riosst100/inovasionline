class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.minSupportedBuildNumber,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.apkUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) => AppUpdateInfo(
    version: json['version'] as String,
    buildNumber: json['build_number'] as int,
    minSupportedBuildNumber: json['min_supported_build_number'] as int,
    forceUpdate: json['force_update'] as bool,
    releaseNotes: json['release_notes'] as String? ?? '',
    apkUrl: json['apk_url'] as String?,
  );

  final String version;
  final int buildNumber;
  final int minSupportedBuildNumber;
  final bool forceUpdate;
  final String releaseNotes;
  final String? apkUrl;
}
