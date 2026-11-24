import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/motion/glossa_motion.dart';
import 'package:glossa_app/core/widgets/greek_key_border.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  void _navigateNext() {
    if (!mounted) return;
    final isAuthenticated = ref.read(gameStateProvider).isAuthenticated;
    if (isAuthenticated) {
      context.go(AppRoutes.town);
    } else {
      context.go(AppRoutes.welcome);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GlossaMotion.loadingDuration,
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateNext();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    _controller.stop();
    _navigateNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlossaColors.blueDeep,
      body: GestureDetector(
        onTap: _skip,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),
                    const HeroAvatar(
                      heroIndex: 0,
                      level: 1,
                      size: 80,
                      showBorder: false,
                      animateIdle: true,
                    ),
                    const SizedBox(height: Spacing.sm),
                    // Shadow oval
                    Container(
                      width: 60,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Spacer(flex: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.pagePadding),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Loading your realm...',
                          style: GlossaTypography.displayMediumOnDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.pagePadding),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Preparing your language adventure.',
                          style: GlossaTypography.bodyMediumOnDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xxxl),
                  ],
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
