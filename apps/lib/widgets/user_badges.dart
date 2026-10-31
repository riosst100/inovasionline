import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Blue check of users with the admin-granted verified badge.
const verifiedBadgeColor = Color(0xFF1D9BF0);

/// A user's name followed by their badges: the verified check and an "Admin Tiwulandu" pill for a user
/// appointed to look after a region. Used on posts, comments and chat messages.
class UserNameWithBadges extends StatelessWidget {
  const UserNameWithBadges({
    super.key,
    required this.name,
    this.verified = false,
    this.adminBadge,
    this.style,
  });

  final String name;
  final bool verified;
  final String? adminBadge;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final fontSize = style?.fontSize ?? 14;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(name, overflow: TextOverflow.ellipsis, style: style),
        ),
        if (verified) ...[
          const SizedBox(width: 3),
          Icon(Icons.verified, size: fontSize + 2, color: verifiedBadgeColor),
        ],
        if (adminBadge != null) ...[
          const SizedBox(width: 5),
          Flexible(child: AdminBadge(label: adminBadge!)),
        ],
      ],
    );
  }
}

class AdminBadge extends StatelessWidget {
  const AdminBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined, size: 11, color: AppColors.primary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
