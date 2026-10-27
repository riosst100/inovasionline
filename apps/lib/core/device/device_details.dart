import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Device facts sent once per launch with the presence heartbeat, for
/// security on the backend (one phone behind many accounts, emulators).
/// The IP address is not collected here: the backend reads it from the request.
class DeviceDetails {
  DeviceDetails._();

  /// Null when the platform is unsupported or the lookup fails.
  static Future<Map<String, dynamic>?> collect() async {
    try {
      if (Platform.isAndroid) return await _android();
      if (Platform.isIOS) return await _ios();
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> _android() async {
    final info = await DeviceInfoPlugin().androidInfo;
    // Android ID: per device and app signing key, survives a reinstall.
    final androidId = await const AndroidId().getId().catchError((_) => null);
    return {
      'id': androidId,
      'name': info.name.isEmpty ? null : info.name,
      'brand': info.brand,
      'model': '${info.manufacturer} ${info.model}',
      'os_version': 'Android ${info.version.release} (SDK ${info.version.sdkInt})',
      'is_emulator': !info.isPhysicalDevice,
      'details': {
        ..._common(),
        'device': info.device,
        'product': info.product,
        'hardware': info.hardware,
        'fingerprint': info.fingerprint,
        // "test-keys" means a custom or rooted build.
        'build_tags': info.tags,
        'security_patch': info.version.securityPatch,
        'abis': info.supportedAbis,
        'ram_mb': info.physicalRamSize,
      },
    };
  }

  static Future<Map<String, dynamic>> _ios() async {
    final info = await DeviceInfoPlugin().iosInfo;
    return {
      'id': info.identifierForVendor,
      'name': info.name,
      'brand': 'Apple',
      'model': info.utsname.machine,
      'os_version': '${info.systemName} ${info.systemVersion}',
      'is_emulator': !info.isPhysicalDevice,
      'details': {..._common(), 'model_name': info.modelName},
    };
  }

  static Map<String, dynamic> _common() => {
    'locale': Platform.localeName,
    'timezone': DateTime.now().timeZoneName,
    'utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
  };
}
