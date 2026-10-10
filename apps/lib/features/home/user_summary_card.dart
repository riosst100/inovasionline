import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';

/// Dummy membership/points/voucher placeholders until the backend
/// exposes real loyalty data for [User].
class _LoyaltySummary {
  const _LoyaltySummary({
    required this.membershipLabel,
    required this.points,
    required this.voucherCount,
  });

  final String membershipLabel;
  final int points;
  final int voucherCount;
}

const _dummyLoyalty = _LoyaltySummary(
  membershipLabel: 'Bronze',
  points: 0,
  voucherCount: 0,
);

class UserSummaryCard extends ConsumerWidget {
  const UserSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isLoggedIn =
        authState.status == AuthStatus.authenticated && user != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: InkWell(
        onTap: () => context.push(isLoggedIn ? '/account' : '/account/login'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.foreground.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surface,
                    backgroundImage: isLoggedIn && user.avatarUrl != null
                        ? CachedNetworkImageProvider(user.avatarUrl!)
                        : null,
                    child: !isLoggedIn || user.avatarUrl == null
                        ? const Icon(
                            Icons.person_outline,
                            size: 18,
                            color: AppColors.mutedForeground,
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLoggedIn ? user.name : 'Login / Daftar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isLoggedIn) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.workspace_premium_outlined,
                                  size: 12,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Member ${_dummyLoyalty.membershipLabel}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if (isLoggedIn)
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: Icons.stars_outlined,
                        label: 'Poin',
                        value: '${_dummyLoyalty.points}',
                      ),
                    ),
                    Container(width: 1, height: 28, color: AppColors.border),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Voucher',
                        value: '${_dummyLoyalty.voucherCount}',
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    const Icon(
                      Icons.card_giftcard_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Masuk untuk mendapatkan voucher dan poin',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
