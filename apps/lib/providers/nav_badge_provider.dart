import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

/// Promo tag on the "Belanja Online" tab. Admin (Pengaturan → Badge Menu) sets the
/// text, on/off and schedule; the styling lives in the app.
class NavBadge {
  const NavBadge({required this.label});

  factory NavBadge.fromJson(Map<String, dynamic> json) =>
      NavBadge(label: json['label'] as String);

  final String label;
}

/// Null when no badge should show. Refreshed when the app resumes (see ActiveOrderBar).
final navBadgeProvider = FutureProvider<NavBadge?>((ref) async {
  final response = await ref.watch(apiClientProvider).dio.get('/nav-badge');
  final data = response.data['data'];
  return data is Map<String, dynamic> ? NavBadge.fromJson(data) : null;
});
