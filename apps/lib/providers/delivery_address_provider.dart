import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/nearest_address.dart';
import '../widgets/address_picker.dart';
import '../services/location_service.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

/// Why the GPS default address could not be set, so the header can say so
/// instead of silently showing nothing.
enum LocationFailure {
  /// No position: location services off, no fix in time, or permission lost.
  noFix,

  /// GPS is switched off.
  serviceOff,

  /// Position found, but outside the service area.
  outOfArea,

  /// Position found, but the lookup request failed (network / server).
  lookupFailed,
}

final locationFailureProvider = StateProvider<LocationFailure?>((ref) => null);

/// Header text for a failed lookup, or null when there is nothing to report.
String? locationFailureLabel(LocationFailure? failure) => switch (failure) {
      LocationFailure.noFix => 'Lokasi tidak terdeteksi',
      LocationFailure.serviceOff => 'GPS belum aktif',
      LocationFailure.outOfArea => 'Lokasi di luar area layanan',
      LocationFailure.lookupFailed => 'Gagal menentukan lokasi',
      null => null,
    };

LocationFailure failureFor(Object error) =>
    isOutOfAreaError(error) ? LocationFailure.outOfArea : LocationFailure.lookupFailed;

/// True for the API's 422 "outside the service area" answer.
bool isOutOfAreaError(Object error) =>
    error is DioException && error.response?.statusCode == 422;

/// Delivery address for guests. Accounts keep theirs server side; a guest has
/// nowhere to save one, so the GPS-derived default lives on the device.
final guestAddressProvider =
    StateNotifierProvider<GuestAddressNotifier, NearestAddress?>(
  (ref) => GuestAddressNotifier(ref),
);

class GuestAddressNotifier extends StateNotifier<NearestAddress?> {
  GuestAddressNotifier(this._ref) : super(null) {
    ready = _load();
  }

  static const _key = 'guest_delivery_address';

  final Ref _ref;
  final _storage = const FlutterSecureStorage();

  /// Completes once the saved address (if any) has been read from storage.
  late final Future<void> ready;

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return;
      state = NearestAddress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
  }

  /// Saves an address the guest picked by hand (province .. village).
  Future<void> setManual(AddressSelection selection) => set(
        NearestAddress(
          provinceCode: selection.province!.code,
          cityCode: selection.city!.code,
          districtCode: selection.district!.code,
          villageCode: selection.village!.code,
          label: [selection.village!, selection.district!, selection.city!]
              .map((r) => _titleCase(r.name))
              .join(', '),
        ),
      );

  Future<void> set(NearestAddress address) async {
    state = address;
    await _storage.write(key: _key, value: jsonEncode(address.toJson()));
  }

  static String _titleCase(String value) => value
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// Fills the address from the current location when none is saved yet.
  /// Returns true when an address is set afterwards. Silent on failure.
  Future<bool> setDefaultFromLocation() async {
    if (state != null) return true;

    final result = await LocationService.currentPosition();
    final position = result.position;
    if (position == null) {
      _ref.read(locationFailureProvider.notifier).state = result.serviceDisabled
          ? LocationFailure.serviceOff
          : LocationFailure.noFix;
      return false;
    }

    try {
      final address = await _ref.read(regionServiceProvider).nearest(
            latitude: position.latitude,
            longitude: position.longitude,
          );
      state = address;
      _ref.read(locationFailureProvider.notifier).state = null;
      await _storage.write(key: _key, value: jsonEncode(address.toJson()));
      return true;
    } catch (e) {
      _ref.read(locationFailureProvider.notifier).state = failureFor(e);
      return false;
    }
  }
}

/// The active delivery address, from the account when signed in and from the
/// device otherwise. Null while none is set.
final deliveryAddressProvider = Provider<NearestAddress?>((ref) {
  final auth = ref.watch(authProvider);
  final user = auth.user;
  if (auth.status != AuthStatus.authenticated || user == null) {
    return ref.watch(guestAddressProvider);
  }
  if (!user.hasAddress ||
      user.provinceCode == null ||
      user.cityCode == null ||
      user.districtCode == null ||
      user.villageCode == null) {
    return null;
  }
  return NearestAddress(
    provinceCode: user.provinceCode!,
    cityCode: user.cityCode!,
    districtCode: user.districtCode!,
    villageCode: user.villageCode!,
    label: user.addressLabel ?? '',
  );
});

/// Every saved delivery address. Only one can be stored today; the address
/// picker already lists them so more can be added later.
final savedDeliveryAddressesProvider = Provider<List<NearestAddress>>((ref) {
  final current = ref.watch(deliveryAddressProvider);
  return [?current];
});

final deliveryAddressActionsProvider = Provider<DeliveryAddressActions>(
  (ref) => DeliveryAddressActions(ref),
);

typedef LocateResult = ({NearestAddress? address, LocationFailure? failure});

class DeliveryAddressActions {
  DeliveryAddressActions(this._ref);

  static const _maxLocateAttempts = 3;

  final Ref _ref;

  /// Nearest served village to where the device is now. Never prompts and
  /// never saves anything.
  Future<LocateResult> locate() async {
    final result = await LocationService.currentPosition();
    final position = result.position;
    if (position == null) {
      return (
        address: null,
        failure: result.serviceDisabled
            ? LocationFailure.serviceOff
            : LocationFailure.noFix,
      );
    }
    try {
      final address = await _ref.read(regionServiceProvider).nearest(
            latitude: position.latitude,
            longitude: position.longitude,
          );
      return (address: address, failure: null);
    } catch (e) {
      return (address: null, failure: failureFor(e));
    }
  }

  /// Makes [address] the delivery address (account or device). Returns
  /// whether it was saved.
  Future<bool> apply(NearestAddress address) async {
    final auth = _ref.read(authProvider);
    final bool saved;
    if (auth.status == AuthStatus.authenticated && auth.user != null) {
      saved = await _ref.read(authProvider.notifier).updateAddress(
            provinceCode: address.provinceCode,
            cityCode: address.cityCode,
            districtCode: address.districtCode,
            villageCode: address.villageCode,
          );
    } else {
      await _ref.read(guestAddressProvider.notifier).set(address);
      saved = true;
    }
    if (saved) _ref.read(locationFailureProvider.notifier).state = null;
    return saved;
  }

  /// "Use my location": asks for location permission and GPS when needed,
  /// locates again and saves the result. Returns null on success, otherwise a
  /// message for the user.
  Future<String?> useMyLocation() async {
    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.locationWhenInUse.request();
    }
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return 'Izinkan akses lokasi di Pengaturan, lalu coba lagi.';
    }
    if (!status.isGranted) {
      return 'Izin lokasi dibutuhkan untuk memakai lokasi kamu.';
    }

    if (!await LocationService.requestEnableService()) {
      return 'Nyalakan GPS untuk memakai lokasi kamu.';
    }

    // A GPS that was only just switched on can take a moment to get a fix.
    LocateResult result = (address: null, failure: LocationFailure.noFix);
    for (var attempt = 0; attempt < _maxLocateAttempts; attempt++) {
      result = await locate();
      if (result.failure != LocationFailure.noFix) break;
    }

    final address = result.address;
    if (address == null) {
      return switch (result.failure) {
        LocationFailure.outOfArea => 'Lokasi kamu di luar area layanan.',
        LocationFailure.serviceOff => 'Nyalakan GPS untuk memakai lokasi kamu.',
        LocationFailure.noFix => 'Lokasi kamu belum terdeteksi, coba lagi.',
        _ => 'Gagal menentukan lokasi, coba lagi.',
      };
    }

    if (!await apply(address)) {
      return _ref.read(authProvider).error ?? 'Gagal menyimpan alamat.';
    }
    return null;
  }
}
