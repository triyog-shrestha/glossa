import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/greek_key_border.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);
    final user = gs.user;

    final xpProgress = user.xpToNextLevel > 0
        ? (user.xp / user.xpToNextLevel).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: GlossaColors.creamBackground,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top),
            const GreekKeyBorder(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.pagePadding,
                  vertical: Spacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hero Profile', style: GlossaTypography.displayMedium),
                    const SizedBox(height: Spacing.lg),

                    // ─── Profile Header Card ──────────────────
                    Container(
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: GlossaColors.white,
                        borderRadius: BorderRadius.circular(Spacing.cardRadius),
                        border: Border.all(
                          color: GlossaColors.blueNavy,
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: GlossaColors.blueNavy,
                            offset: Offset(0, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              HeroAvatar(
                                heroIndex: user.heroIndex,
                                level: user.level,
                                size: 68,
                                animateIdle: true,
                              ),
                              const SizedBox(width: Spacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: GlossaTypography.headlineLarge,
                                    ),
                                    Text(
                                      'Lv ${user.level} ${user.heroClassName}',
                                      style: GlossaTypography.labelMedium
                                          .copyWith(
                                            color: GlossaColors.blueDeep,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: GlossaColors.creamPale,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: GlossaColors.blueNavy,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        user.languageScript.isNotEmpty
                                            ? '${user.languageScript} (${user.languageName})'
                                            : 'Nepal Bhasa (Newari)',
                                        style: GlossaTypography.labelSmall
                                            .copyWith(
                                              color: GlossaColors.blueNavy,
                                              fontSize: 10,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: GlossaColors.blueNavy,
                                ),
                                onPressed: () => context.push(
                                  '${AppRoutes.characterSelect}?mode=edit',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.md),
                          GlossaProgressBar(
                            progress: xpProgress,
                            fillColor: GlossaColors.redAction,
                            height: 10,
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${user.xp} / ${user.xpToNextLevel} XP to Level ${user.level + 1}',
                              style: GlossaTypography.bodySmall.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),

                    // ─── 3 Stats Row ─────────────────────────
                    Row(
                      children: [
                        _buildStatBox(
                          'Words Found',
                          '${user.wordsFound}',
                          '📚',
                        ),
                        const SizedBox(width: Spacing.sm),
                        _buildStatBox('Day Streak', '${user.streak}d', '🔥'),
                        const SizedBox(width: Spacing.sm),
                        _buildStatBox(
                          'Lessons',
                          '${user.lessonsCompleted}',
                          '⚔️',
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xl),

                    // ─── Settings & Navigation Links ──────────
                    Material(
                      color: GlossaColors.white,
                      borderRadius: BorderRadius.circular(Spacing.cardRadius),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            Spacing.cardRadius,
                          ),
                          border: Border.all(
                            color: GlossaColors.blueNavy,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.swap_horiz_rounded,
                                color: GlossaColors.blueNavy,
                              ),
                              title: Text(
                                'Switch Course',
                                style: GlossaTypography.labelMedium,
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => context.push(
                                AppRoutes.courseSwitcher,
                              ),
                            ),
                            const Divider(height: 1, thickness: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.language_rounded,
                                color: GlossaColors.blueNavy,
                              ),
                              title: Text(
                                'Change Target Language',
                                style: GlossaTypography.labelMedium,
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => context.push(
                                '${AppRoutes.languageSelect}?mode=edit',
                              ),
                            ),
                            const Divider(height: 1, thickness: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.switch_account_rounded,
                                color: GlossaColors.blueNavy,
                              ),
                              title: Text(
                                'Switch Hero Appearance',
                                style: GlossaTypography.labelMedium,
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => context.push(
                                '${AppRoutes.characterSelect}?mode=edit',
                              ),
                            ),
                            const Divider(height: 1, thickness: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.logout_rounded,
                                color: GlossaColors.redAction,
                              ),
                              title: Text(
                                _isLoggingOut ? 'Logging out...' : 'Log Out',
                                style: GlossaTypography.labelMedium.copyWith(
                                  color: GlossaColors.redAction,
                                ),
                              ),
                              trailing: _isLoggingOut
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: GlossaColors.redAction,
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right_rounded),
                              onTap: _isLoggingOut
                                  ? null
                                  : () async {
                                      setState(() => _isLoggingOut = true);
                                      try {
                                        await ref
                                            .read(gameStateProvider.notifier)
                                            .logOut();
                                        if (context.mounted) {
                                          context.go(AppRoutes.welcome);
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isLoggingOut = false);
                                        }
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, String icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.md,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: GlossaColors.white,
          borderRadius: BorderRadius.circular(Spacing.cardRadius),
          border: Border.all(color: GlossaColors.blueNavy, width: 2),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: GlossaTypography.headlineMedium.copyWith(
                color: GlossaColors.blueNavy,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: GlossaTypography.bodySmall.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
