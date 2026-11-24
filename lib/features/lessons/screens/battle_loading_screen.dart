import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/motion/glossa_motion.dart';
import 'package:glossa_app/core/motion/motion_widgets.dart';
import 'package:glossa_app/core/widgets/greek_key_border.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/core/widgets/xp_tip_banner.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

class BattleLoadingScreen extends ConsumerStatefulWidget {
  const BattleLoadingScreen({super.key});

  @override
  ConsumerState<BattleLoadingScreen> createState() => _BattleLoadingScreenState();
}

class _BattleLoadingScreenState extends ConsumerState<BattleLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GlossaMotion.loadingDuration,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final activeLessonId = ref.read(gameStateProvider).activeLessonId;
      if (activeLessonId == null) {
        context.go(AppRoutes.town);
        return;
      }
      _controller.forward();
    });

    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        // Always route to the unified lesson runner which handles all exercise
        // types in sequence. The old per-type routes are kept for backwards
        // compatibility but are no longer used by the battle loading flow.
        context.go(AppRoutes.lessonRunner);
      }
    });
  }

  void _handleCancel() {
    _controller.stop();
    ref.read(gameStateProvider.notifier).resetLesson();
    context.go(AppRoutes.town);
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleCancel();
      },
      child: Scaffold(
      backgroundColor: GlossaColors.blueDarkest,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: MediaQuery.of(context).padding.top + Spacing.xxxl),
                    Text('Preparing for battle',
                        style: GlossaTypography.displayMediumOnDark),
                    const SizedBox(height: Spacing.md),
                    Text('Getting your gear ready...',
                        style: GlossaTypography.bodyMediumOnDark),
                    const Spacer(),
                    // VS Scene
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hero
                        Column(
                          children: [
                            HeroAvatar(
                              heroIndex: gs.user.heroIndex,
                              level: gs.user.level,
                              size: 90,
                              showBorder: false,
                              animateIdle: true,
                            ),
                            const SizedBox(height: Spacing.sm),
                            Text(gs.user.name,
                                style: GlossaTypography.labelMedium
                                    .copyWith(color: GlossaColors.white)),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 100,
                              child: GlossaProgressBar(
                                progress: 1.0,
                                fillColor: GlossaColors.redAction,
                                height: 6,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                          child: Text('VS',
                              style: GlossaTypography.displayLarge.copyWith(
                                  color: GlossaColors.yellowPrimary,
                                  fontSize: 32)),
                        ),
                        // Fog enemy
                        Column(
                          children: [
                            IdleBobbing(
                              offsetDistance: 3.5,
                              child: _FogEnemy(),
                            ),
                            const SizedBox(height: Spacing.sm),
                            Text('Forgetting Fog',
                                style: GlossaTypography.labelMedium
                                    .copyWith(color: GlossaColors.white)),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 100,
                              child: GlossaProgressBar(
                                progress: 1.0,
                                fillColor: GlossaColors.disabledGray,
                                height: 6,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SegmentedProgressBar(
                            progress: _controller.value,
                            filledColor: GlossaColors.yellowPrimary,
                            emptyColor: GlossaColors.disabledGray,
                          ),
                          const SizedBox(height: Spacing.md),
                          Text(
                            'Preparing... ${(_controller.value * 100).round()}%',
                            style: GlossaTypography.headlineLargeOnDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.xxl),
                    const XpTipBanner(
                      tip: 'Answer exercises accurately and conquer the lesson to earn rewards!',
                    ),
                    const SizedBox(height: Spacing.xxl),
                  ],
                ),
              ),
            ),
            const GreekKeyBorder(),
          ],
        ),
      ),
    ),
    );
  }
}

class _FogEnemy extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80, height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Body
          Positioned(
            bottom: 5,
            child: Container(
              width: 60, height: 50,
              decoration: BoxDecoration(
                color: GlossaColors.white,
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          // Top bumps
          Positioned(
            top: 5,
            left: 15,
            child: Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(
                color: GlossaColors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 15,
            child: Container(
              width: 35, height: 35,
              decoration: const BoxDecoration(
                color: GlossaColors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Eyes
          Positioned(
            top: 30,
            left: 25,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: GlossaColors.blueNavy,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: 25,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: GlossaColors.blueNavy,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
