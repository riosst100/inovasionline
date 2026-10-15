import 'package:flutter/foundation.dart';

class AccountBlockInfo {
  const AccountBlockInfo({this.reason, this.contactUrl});

  final String? reason;
  final String? contactUrl;
}

/// A single feature (chat / posts / purchase) the admin has banned the user
/// from. A new instance is published per rejected request so the UI re-shows.
class FeatureBanInfo {
  const FeatureBanInfo({required this.feature, this.reason, this.contactUrl});

  final String feature;
  final String? reason;
  final String? contactUrl;

  String get featureLabel => switch (feature) {
    'chat' => 'Chat',
    'posts' => 'Postingan',
    'purchase' => 'Pembelian',
    _ => feature,
  };
}

/// App-wide "this account is blocked" signal. Set when the backend reports it
/// (login/profile payload or a 403 `ACCOUNT_BLOCKED` on any request) and
/// cleared on logout or once the admin unblocks the account.
class AccountBlock {
  static final ValueNotifier<AccountBlockInfo?> notifier = ValueNotifier(null);

  /// Set when a request is rejected with 403 `FEATURE_BANNED`; the gate shows
  /// a dialog and clears it.
  static final ValueNotifier<FeatureBanInfo?> featureBan = ValueNotifier(null);
}
