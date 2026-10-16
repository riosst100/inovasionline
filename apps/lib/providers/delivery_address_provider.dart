import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/nearest_address.dart';
import '../widgets/address_picker.dart';
import '../services/location_service.dart';
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
  Future<void> setManual(AddressSelection selection) async {
    final address = NearestAddress(
      provinceCode: selection.province!.code,
      cityCode: selection.city!.code,
      districtCode: selection.district!.code,
      villageCode: selection.village!.code,
      label: [selection.village!, selection.district!, selection.city!]
          .map((r) => _titleCase(r.name))
          .join(', '),
    );
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
