import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/mock_data/mock_data.dart';
import 'package:glossa_app/shared/models/hero_choice.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  final bool isEditing;

  const LanguageSelectionScreen({super.key, this.isEditing = false});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    final userLang = ref.read(gameStateProvider).user.languageId;
    _selectedId = userLang.isNotEmpty ? userLang : 'nepali';
  }

  void _handleBack() {
    if (widget.isEditing) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.profile);
      }
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.characterSelect);
      }
    }
  }

  Future<void> _handleSave() async {
    final lang = languageChoices.firstWhere((l) => l.id == _selectedId);
    try {
      await ref
          .read(gameStateProvider.notifier)
          .selectLanguage(lang.id, lang.nameEnglish, lang.nameNative);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }

    if (!mounted) return;
    if (widget.isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Target language changed to ${lang.nameEnglish}!'),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.profile);
      }
    } else {
      context.go(AppRoutes.townLoading);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Spacing.sm),
                // Top bar with Back button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: GlossaColors.blueNavy,
                        size: 28,
                      ),
                      onPressed: _handleBack,
                    ),
                    if (widget.isEditing)
                      TextButton(
                        onPressed: _handleBack,
                        child: Text(
                          'Cancel',
                          style: GlossaTypography.labelMedium.copyWith(
                            color: GlossaColors.textSubtle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  widget.isEditing
                      ? 'Change target\nlanguage'
                      : 'Choose your\nlanguage',
                  style: GlossaTypography.displayMedium,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  widget.isEditing
                      ? 'Switch the dialect you are exploring. Your progress is saved.'
                      : 'Which tongue echoes in your home? More languages will unlock as your quest continues.',
                  style: GlossaTypography.bodyMedium,
                ),
                const SizedBox(height: Spacing.xxl),
                // Language cards
                ...languageChoices.map((lang) {
                  final isSelected = _selectedId == lang.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.md),
                    child: _LanguageCard(
                      language: lang,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedId = lang.id),
                    ),
                  );
                }),
                const SizedBox(height: Spacing.xl),
                // Hero note
                Row(
                  children: [
                    HeroAvatar(
                      heroIndex: gameState.user.heroIndex,
                      level: gameState.user.level,
                      size: 36,
                      animateIdle: true,
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Text(
                        'Your hero journeys in the language of home.',
                        style: GlossaTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.xxl),
                GlossaButton(
                  label: widget.isEditing ? 'Save language' : 'Begin quest',
                  loadingLabel: widget.isEditing ? 'Saving language...' : 'Starting quest...',
                  onPressed: _handleSave,
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

class _LanguageCard extends StatelessWidget {
  final LanguageChoice language;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected ? GlossaColors.blueNavy : GlossaColors.white,
          borderRadius: BorderRadius.circular(Spacing.cardRadius),
          border: Border.all(
            color: GlossaColors.blueNavy,
            width: Spacing.borderWidth,
          ),
        ),
        child: Row(
          children: [
            // Letter circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? GlossaColors.yellowPrimary
                    : GlossaColors.creamPale,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? GlossaColors.yellowPrimary
                      : GlossaColors.blueNavy,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  language.letterSymbol,
                  style: TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: GlossaColors.blueNavy,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        language.nameEnglish,
                        style: GlossaTypography.headlineSmall.copyWith(
                          color: isSelected
                              ? GlossaColors.white
                              : GlossaColors.textDark,
                        ),
                      ),
                      if (language.isStarter) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: GlossaColors.yellowPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Starter',
                            style: GlossaTypography.labelSmall.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: GlossaColors.blueNavy,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    language.nameNative,
                    style: TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 14,
                      color: isSelected
                          ? GlossaColors.white.withValues(alpha: 0.8)
                          : GlossaColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: GlossaColors.yellowPrimary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
