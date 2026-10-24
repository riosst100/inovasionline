import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/storage/install_id.dart';
import 'contact_service.dart';

/// Reads the phone book and keeps the backend's copy of it current, for
/// post, chat and product suggestions. Optional: nothing in the app depends on it,
/// so every failure is swallowed.
///
/// Access is asked only from the card on the Postingan tab
/// (ContactConnectCard); after that the phone book is re-synced quietly on
/// launch. Works for guests too: rows are keyed by [InstallId] and the backend links
/// them to the account once this install signs in ([claim]).
class ContactSync {
  ContactSync(this._service);

  final ContactService _service;

  static const _storage = FlutterSecureStorage();
  static const _dismissedKey = 'contacts_card_dismissed';
  static const _fingerprintKey = 'contacts_fingerprint';
  static const _syncedAtKey = 'contacts_synced_at';

  /// An unchanged phone book is still re-sent after this long, so the
  /// backend's copy recovers from anything lost on its side.
  static const _resyncAfter = Duration(days: 7);

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<bool> isGranted() async =>
      isSupported && await FlutterContacts.permissions.has(PermissionType.read);

  /// Whether to show the "connect contacts" card: access not allowed yet and
  /// the user has not closed the card.
  Future<bool> shouldOffer() async {
    if (!isSupported) return false;
    if (await _storage.read(key: _dismissedKey) != null) return false;
    return !await isGranted();
  }

  /// Shows the system dialog, or opens Settings once the OS no longer shows
  /// it. Uploads right away when allowed.
  Future<bool> request() async {
    final current = await FlutterContacts.permissions.check(PermissionType.read);
    if (current == PermissionStatus.permanentlyDenied ||
        current == PermissionStatus.restricted) {
      await FlutterContacts.permissions.openSettings();
      return false;
    }
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    final granted = status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
    if (granted) unawaited(sync(force: true));
    return granted;
  }

  /// The user closed the card; it is not offered again.
  Future<void> dismiss() => _storage.write(key: _dismissedKey, value: '1');

  /// Uploads the phone book if access is allowed and it changed since the
  /// last upload (or that upload is older than [_resyncAfter]).
  Future<void> sync({bool force = false}) async {
    try {
      if (!await isGranted()) return;
      final contacts = await _readPhoneBook();
      final fingerprint = Object.hashAll(
        contacts.map((c) => '${c.phone}|${c.name}'),
      ).toString();

      if (!force && fingerprint == await _storage.read(key: _fingerprintKey)) {
        final syncedAt = DateTime.tryParse(
          await _storage.read(key: _syncedAtKey) ?? '',
        );
        if (syncedAt != null &&
            DateTime.now().difference(syncedAt) < _resyncAfter) {
          return;
        }
      }

      await _service.sync(await InstallId.read(), contacts);
      await _storage.write(key: _fingerprintKey, value: fingerprint);
      await _storage.write(
        key: _syncedAtKey,
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      developer.log('Failed to sync contacts: $e', name: 'contacts');
    }
  }

  /// Right after sign-in: links contacts uploaded from this install (e.g. as
  /// a guest) to the account. Skipped when nothing was ever uploaded.
  Future<void> claim() async {
    try {
      if (!isSupported || await _storage.read(key: _fingerprintKey) == null) {
        return;
      }
      await _service.sync(await InstallId.read(), const []);
    } catch (e) {
      developer.log('Failed to claim contacts: $e', name: 'contacts');
    }
  }

  /// One entry per number, sorted so the fingerprint ignores read order.
  Future<List<PhoneContact>> _readPhoneBook() async {
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    final byPhone = <String, PhoneContact>{};
    for (final contact in contacts) {
      final name = contact.displayName?.trim();
      for (final phone in contact.phones) {
        final number = (phone.normalizedNumber ?? phone.number).trim();
        if (number.isEmpty) continue;
        byPhone.putIfAbsent(
          number,
          () => PhoneContact(
            name: name == null || name.isEmpty ? null : name,
            phone: number,
          ),
        );
      }
    }
    return byPhone.values.toList()..sort((a, b) => a.phone.compareTo(b.phone));
  }
}
