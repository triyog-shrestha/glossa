import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/greek_key_border.dart';
import 'package:glossa_app/core/widgets/logo_widget.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlossaColors.blueDeep,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const GreekKeyBorder(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Spacing.lg),
                    // Logo + decorative Devanagari
                    SizedBox(
                      height: 180,
                      child: Stack(
                        children: [
                          // Large faded Devanagari text
                          Positioned(
                            right: -20,
                            top: 0,
                            child: Text(
                              'भार',
                              style: TextStyle(
                                fontFamily: 'NotoSansDevanagari',
                                fontSize: 140,
                                fontWeight: FontWeight.w700,
                                color: GlossaColors.yellowPrimary.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 0,
                            top: 16,
                            child: GlossaAppIcon(size: 48),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    Text(
                      'Master the\nlanguages of\nNepal.',
                      style: GlossaTypography.displayLargeOnDark.copyWith(
                        fontSize: 36,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      'Explore game-inspired quests, complete exercises, and unlock knowledge.',
                      style: GlossaTypography.bodyMediumOnDark,
                    ),
                    const SizedBox(height: Spacing.xxl),
                    GlossaButton(
                      label: 'New Game',
                      style: GlossaButtonStyle.primary,
                      onPressed: () => context.go(AppRoutes.signup),
                    ),
                    const SizedBox(height: Spacing.lg),
                    GlossaButton(
                      label: 'Continue (load save)',
                      style: GlossaButtonStyle.secondary,
                      onPressed: () => context.go(AppRoutes.login),
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
}
