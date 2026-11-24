import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/motion/glossa_motion.dart';
import 'package:glossa_app/core/widgets/greek_key_border.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/logo_widget.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/core/widgets/xp_tip_banner.dart';

class TownLoadingScreen extends StatefulWidget {
  const TownLoadingScreen({super.key});

  @override
  State<TownLoadingScreen> createState() => _TownLoadingScreenState();
}

class _TownLoadingScreenState extends State<TownLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GlossaMotion.loadingDuration,
    )..forward();
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) context.go(AppRoutes.town);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _controller.stop();
          context.go(AppRoutes.town);
        }
      },
      child: Scaffold(
      backgroundColor: GlossaColors.blueDeep,
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
                    SizedBox(height: MediaQuery.of(context).padding.top + Spacing.lg),
                    const GlossaAppIcon(size: 44),
                    const SizedBox(height: Spacing.lg),
                    Text('Entering Town',
                        style: GlossaTypography.displayMediumOnDark),
                    const SizedBox(height: Spacing.xs),
                    Text('Gathering your lessons...',
                        style: GlossaTypography.bodyMediumOnDark),
                    // Cloud shapes
                    const SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        Container(
                          width: 70, height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 60, height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Town scene
                    SizedBox(
                      height: 120,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _SimpleHouse(roofColor: GlossaColors.redAction),
                          const SizedBox(width: Spacing.xl),
                          const HeroAvatar(
                            heroIndex: 0,
                            level: 3,
                            size: 70,
                            showBorder: false,
                            animateIdle: true,
                          ),
                          const SizedBox(width: Spacing.xl),
                          _SimpleHouse(roofColor: GlossaColors.yellowPrimary),
                        ],
                      ),
                    ),
                    // Yellow ground
                    Container(
                      height: 6,
                      color: GlossaColors.yellowPrimary,
                    ),
                    const SizedBox(height: Spacing.xxl),
                    // Progress
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SegmentedProgressBar(
                            progress: _controller.value,
                            filledColor: GlossaColors.redAction,
                            emptyColor: GlossaColors.disabledGray,
                          ),
                          const SizedBox(height: Spacing.md),
                          Text(
                            'Loading town... ${(_controller.value * 100).round()}%',
                            style: GlossaTypography.headlineLargeOnDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.xxl),
                    const XpTipBanner(
                      tip: 'Complete lessons and keep your daily streak alive to earn bonus XP.',
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

class _SimpleHouse extends StatelessWidget {
  final Color roofColor;
  const _SimpleHouse({required this.roofColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 80,
      child: Column(
        children: [
          // Roof
          CustomPaint(
            size: const Size(60, 25),
            painter: _RoofPainter(roofColor),
          ),
          // Body
          Container(
            width: 50,
            height: 45,
            decoration: BoxDecoration(
              color: GlossaColors.creamBackground,
              border: Border.all(color: GlossaColors.blueNavy, width: 2),
            ),
            child: Center(
              child: Container(
                width: 16, height: 24,
                color: GlossaColors.blueDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoofPainter extends CustomPainter {
  final Color color;
  _RoofPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = GlossaColors.blueNavy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
