import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/tab_control.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController(text: '');
  final _emailController = TextEditingController(text: '');
  final _codeController = TextEditingController(text: '');
  bool _obscureCode = true;
  bool _acceptedTerms = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  int get _codeStrength {
    final len = _codeController.text.length;
    if (len == 0) return 0;
    if (len < 4) return 1;
    if (len < 8) return 2;
    return 3;
  }

  String get _codeStrengthLabel {
    switch (_codeStrength) {
      case 0:
        return '';
      case 1:
        return 'weak';
      case 2:
        return 'medium';
      default:
        return 'strong';
    }
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
            child: Form(
              key: _formKey,
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
                          selectedIndex: 0,
                          labels: const ['New game', 'Load game'],
                          onChanged: (i) {
                            if (i == 1) context.go(AppRoutes.login);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xl),
                  // Player status card
                  Container(
                    padding: const EdgeInsets.all(Spacing.lg),
                    decoration: BoxDecoration(
                      color: GlossaColors.creamPale,
                      borderRadius: BorderRadius.circular(Spacing.cardRadius),
                      border: Border.all(
                        color: GlossaColors.blueNavy,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const HeroAvatar(heroIndex: 0, level: 1, size: 50),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Player 1 is ready.',
                                style: GlossaTypography.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create your adventurer profile to begin learning.',
                                style: GlossaTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.xxl),
                  // Form fields
                  Text('Hero name', style: GlossaTypography.labelMedium),
                  const SizedBox(height: Spacing.sm),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Name your hero',
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter a hero name' : null,
                  ),
                  const SizedBox(height: Spacing.lg),
                  Text('Save-file email', style: GlossaTypography.labelMedium),
                  const SizedBox(height: Spacing.sm),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: Spacing.lg),
                  Text('Password', style: GlossaTypography.labelMedium),
                  const SizedBox(height: Spacing.sm),
                  TextFormField(
                    controller: _codeController,
                    obscureText: _obscureCode,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '8+ characters',
                      suffixIcon: GestureDetector(
                        onTap: () =>
                            setState(() => _obscureCode = !_obscureCode),
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
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Enter at least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: Spacing.sm),
                  // Strength bar
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: List.generate(4, (i) {
                            Color color;
                            if (i < _codeStrength) {
                              color = _codeStrength == 1
                                  ? GlossaColors.redAction
                                  : _codeStrength == 2
                                  ? GlossaColors.blueDeep
                                  : GlossaColors.successGreen;
                            } else {
                              color = GlossaColors.disabledGray;
                            }
                            return Expanded(
                              child: Container(
                                height: 6,
                                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Flexible(
                        child: Text(
                          'Code strength: $_codeStrengthLabel',
                          style: GlossaTypography.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xl),
                  // Consent
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptedTerms,
                        onChanged: (v) =>
                            setState(() => _acceptedTerms = v ?? false),
                      ),
                      Expanded(
                        child: Text(
                          'I accept the Quest Rules and Privacy Policy.',
                          style: GlossaTypography.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xl),
                  GlossaButton(
                    label: 'Start adventure',
                    loadingLabel: 'Creating account...',
                    onPressed: _acceptedTerms
                        ? () async {
                            if (!_formKey.currentState!.validate()) return;
                            try {
                              await ref
                                  .read(gameStateProvider.notifier)
                                  .signUp(
                                    name: _nameController.text.trim(),
                                    email: _emailController.text.trim(),
                                    password: _codeController.text,
                                  );
                              if (context.mounted) {
                                context.go(AppRoutes.characterSelect);
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error.toString()),
                                  ),
                                );
                              }
                            }
                          }
                        : null,
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
                  const SizedBox(height: Spacing.xl),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/login'),
                      child: RichText(
                        text: TextSpan(
                          style: GlossaTypography.bodyMedium,
                          children: [
                            const TextSpan(text: 'Have a save file? '),
                            TextSpan(
                              text: 'Load game',
                              style: GlossaTypography.labelMedium.copyWith(
                                color: GlossaColors.redAction,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Center(
                    child: Text(
                      'Next: pick a character and a language.',
                      style: GlossaTypography.bodySmall,
                    ),
                  ),
                  const SizedBox(height: Spacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
