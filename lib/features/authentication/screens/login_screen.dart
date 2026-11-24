import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/tab_control.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _obscureCode = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.welcome);
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Spacing.sm),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: GlossaColors.blueNavy,
                        size: 28,
                      ),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(AppRoutes.welcome);
                        }
                      },
                    ),
                    const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: GlossaTabControl(
                        selectedIndex: 1,
                        labels: const ['New game', 'Load game'],
                        onChanged: (i) {
                          if (i == 0) context.go(AppRoutes.signup);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.xl),
                // Quest Resume Header Card
                Container(
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: GlossaColors.creamPale,
                    borderRadius: BorderRadius.circular(Spacing.cardRadius),
                    border: Border.all(color: GlossaColors.blueNavy, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: GlossaColors.yellowPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: GlossaColors.blueNavy, width: 2),
                        ),
                        child: const Icon(
                          Icons.vpn_key_rounded,
                          color: GlossaColors.blueNavy,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resume Quest',
                              style: GlossaTypography.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sign in to restore your save file and continue your adventure.',
                              style: GlossaTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.xxl),
                Text('Save-file email', style: GlossaTypography.labelMedium),
                const SizedBox(height: Spacing.sm),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: Spacing.lg),
                Text('Password', style: GlossaTypography.labelMedium),
                const SizedBox(height: Spacing.sm),
                TextFormField(
                  controller: _codeController,
                  obscureText: _obscureCode,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscureCode = !_obscureCode),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          _obscureCode ? 'Show' : 'Hide',
                          style: GlossaTypography.labelMedium.copyWith(
                            color: GlossaColors.blueDeep,
                          ),
                        ),
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minHeight: 0,
                      minWidth: 0,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      color: GlossaColors.blueDeep,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: Text(
                        'Your session is saved securely on this device.',
                        style: GlossaTypography.bodySmall,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Lost your code?'),
                            content: const Text(
                              'Password reset is not available yet. Please contact support if you cannot access your account.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text(
                        'Lost your code?',
                        style: GlossaTypography.labelMedium.copyWith(
                          color: GlossaColors.blueDeep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.xl),
                GlossaButton(
                  label: 'Load game',
                  loadingLabel: 'Loading save file...',
                  onPressed: () async {
                    try {
                      await ref
                          .read(gameStateProvider.notifier)
                          .logIn(
                            email: _emailController.text.trim(),
                            password: _codeController.text,
                          );
                      if (context.mounted) context.go(AppRoutes.town);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: Spacing.lg),
                Center(child: Text('or', style: GlossaTypography.bodyMedium)),
                const SizedBox(height: Spacing.lg),
                GlossaButton(
                  label: 'Link with Google',
                  loadingLabel: 'Connecting to Google...',
                  style: GlossaButtonStyle.secondary,
                  onPressed: () async {
                    await Future.delayed(const Duration(milliseconds: 600));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Google login will be available with Firebase integration.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: Spacing.xxl),
                Center(
                  child: GestureDetector(
                    onTap: () => context.go(AppRoutes.signup),
                    child: RichText(
                      text: TextSpan(
                        style: GlossaTypography.bodyMedium,
                        children: [
                          const TextSpan(text: 'New here? '),
                          TextSpan(
                            text: 'Start a new game',
                            style: GlossaTypography.labelMedium.copyWith(
                              color: GlossaColors.blueDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
