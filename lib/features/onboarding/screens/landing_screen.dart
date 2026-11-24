import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/motion/glossa_motion.dart';
import 'package:glossa_app/core/motion/motion_widgets.dart';
import 'package:glossa_app/core/widgets/greek_key_border.dart';
import 'package:glossa_app/core/widgets/logo_widget.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  Timer? _autoNav;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );

    _scaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: GlossaMotion.enter,
      ),
    );

    _entranceController.forward();

    _autoNav = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) context.go(AppRoutes.splash);
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _autoNav?.cancel();
    super.dispose();
  }

  void _skip() {
    _autoNav?.cancel();
    context.go(AppRoutes.splash);
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
              const GreekKeyBorder(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: Spacing.xxl),
                          // Large Devanagari greeting
                          Text(
                            'भाय्',
                            style: GlossaTypography.devanagariLarge.copyWith(
                              fontSize: 72,
                              color: GlossaColors.yellowPrimary,
                            ),
                          ),
                          const SizedBox(height: Spacing.lg),
                          // Logo with floating tokens
                          SizedBox(
                            height: 260,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const GlossaLogo(size: 180),
                                // Floating Devanagari tokens with idle bobbing
                                _FloatingToken('न', left: 20, top: 30, offset: 4.0),
                                _FloatingToken('म', right: 20, top: 10,
                                    bgColor: GlossaColors.redAction, offset: 3.0),
                                _FloatingToken('थ', left: 15, bottom: 30, offset: 5.0),
                                _FloatingToken('ल', right: 15, bottom: 10, offset: 3.5),
                              ],
                            ),
                          ),
                          const SizedBox(height: Spacing.xxl),
                          // Title
                          Text(
                            'Glossa',
                            style: GlossaTypography.displayLargeOnDark.copyWith(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            'Play. Learn. Master.',
                            style: GlossaTypography.bodyLargeOnDark,
                          ),
                          const SizedBox(height: Spacing.xxl),
                          Text(
                            'NEPALI  ·  NEWARI',
                            style: GlossaTypography.labelSmall.copyWith(
                              color: GlossaColors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: Spacing.xxl),
                        ],
                      ),
                    ),
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

class _FloatingToken extends Positioned {
  _FloatingToken(
    String letter, {
    super.left,
    super.right,
    super.top,
    super.bottom,
    Color bgColor = GlossaColors.yellowPrimary,
    double offset = 3.0,
  }) : super(
          child: IdleBobbing(
            offsetDistance: offset,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GlossaColors.blueNavy, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(0, 3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  letter,
                  style: const TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: GlossaColors.blueNavy,
                  ),
                ),
              ),
            ),
          ),
        );
}
