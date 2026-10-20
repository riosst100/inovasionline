import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_address.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

/// The signed-in user's saved delivery addresses, most recently added or used
/// first. Reloads when a different user signs in; invalidate after a change.
final userAddressesProvider = FutureProvider<List<UserAddress>>((ref) async {
  final userId = ref.watch(authProvider.select((s) => s.user?.id));
  if (userId == null) return const [];
  return ref.watch(userAddressServiceProvider).list();
});
