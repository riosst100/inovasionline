import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';

/// Guards a page that needs an account. Signed out, it shows a "Masuk" prompt and the page itself
/// is never built, so it cannot call the API and fail with "Unauthenticated". As soon as the user
/// signs in (the login page pops back here) the page is built and loads normally.
class AuthRequired extends ConsumerWidget {
  const AuthRequired({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String message;
  final IconData icon;

  /// Builds the real page; only called while signed in.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authProvider.select((s) => s.status));

    if (status == AuthStatus.authenticated) return builder(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: status == AuthStatus.unknown
          // The session is still being restored.
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 56, color: AppColors.mutedForeground),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.mutedForeground),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.push('/account/login'),
                      child: const Text('Masuk'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
