import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/motion/glossa_motion.dart';
import 'package:glossa_app/core/motion/motion_widgets.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/core/widgets/simple_illustration.dart';
import 'package:glossa_app/core/widgets/xp_tip_banner.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

/// Unified lesson runner that handles mixed exercise types in sequence.
///
/// Replaces the four separate exercise screens with a single screen that
/// iterates through all exercises in a lesson, rendering each one according
/// to its [ExerciseType]. Answers are accumulated in GameState and submitted
/// as a complete attempt when all exercises are done.
class LessonRunnerScreen extends ConsumerStatefulWidget {
  const LessonRunnerScreen({super.key});

  @override
  ConsumerState<LessonRunnerScreen> createState() =>
      _LessonRunnerScreenState();
}

class _LessonRunnerScreenState extends ConsumerState<LessonRunnerScreen> {
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    // Ensure exercises are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gs = ref.read(gameStateProvider);
      if (gs.exercises.isEmpty && gs.activeLessonId != null) {
        // Exercises not loaded yet — go back to town
        if (mounted) context.go(AppRoutes.town);
      }
    });
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave lesson?'),
        content: const Text('Your progress in this lesson will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(gameStateProvider.notifier).resetLesson();
              context.go(AppRoutes.town);
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _onExerciseComplete() async {
    final gs = ref.read(gameStateProvider);
    final isLastExercise =
        gs.currentExerciseIndex >= gs.exercises.length - 1;

    if (isLastExercise) {
      // All exercises done — submit the complete attempt
      if (_completing) return;
      setState(() => _completing = true);
      try {
        await ref.read(gameStateProvider.notifier).completeLesson();
        if (mounted) {
          context.go(AppRoutes.levelUp);
        }
      } catch (error) {
        if (mounted) {
          setState(() => _completing = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    } else {
      // Advance to the next exercise
      ref.read(gameStateProvider.notifier).nextExercise();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);

    if (gs.exercises.isEmpty) {
      return Scaffold(
        backgroundColor: GlossaColors.creamBackground,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No exercises found for this lesson.'),
                const SizedBox(height: Spacing.md),
                GlossaButton(
                  label: 'Back to Town',
                  onPressed: () => context.go(AppRoutes.town),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentExercise = gs.exercises[gs.currentExerciseIndex];
    final progress =
        (gs.currentExerciseIndex + 1) / gs.exercises.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showLeaveDialog();
      },
      child: Scaffold(
        backgroundColor: GlossaColors.creamBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.pagePadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Spacing.md),
                _buildHeader(gs, progress),
                const SizedBox(height: Spacing.xl),
                // Render the current exercise based on its type
                Expanded(
                  child: _buildExerciseContent(currentExercise, gs),
                ),
                // Bottom submit/continue area
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xl),
                  child: _buildBottomArea(currentExercise),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GameState gs, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _showLeaveDialog,
              child: const Icon(
                Icons.close_rounded,
                color: GlossaColors.blueNavy,
                size: 28,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(child: LessonProgressBar(progress: progress)),
            const SizedBox(width: Spacing.sm),
            HeroAvatar(
              heroIndex: gs.user.heroIndex,
              level: gs.user.level,
              size: 40,
              animateIdle: true,
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'Exercise ${gs.currentExerciseIndex + 1} of ${gs.exercises.length}',
          style: GlossaTypography.bodySmall,
        ),
      ],
    );
  }

  Widget _buildExerciseContent(Exercise exercise, GameState gs) {
    switch (exercise.type) {
      case ExerciseType.matchWords:
        return _MatchWordsContent(
          exercise: exercise,
          onComplete: _onExerciseComplete,
        );
      case ExerciseType.fillBlank:
        return _FillBlankContent(
          exercise: exercise,
          onComplete: _onExerciseComplete,
        );
      case ExerciseType.pictureToWord:
        return _PictureToWordContent(
          exercise: exercise,
          onComplete: _onExerciseComplete,
        );
      case ExerciseType.wordToPicture:
        return _WordToPictureContent(
          exercise: exercise,
          onComplete: _onExerciseComplete,
        );
    }
  }

  Widget _buildBottomArea(Exercise exercise) {
    if (_completing) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    // The exercise content widgets handle their own submit buttons
    // This is just a spacer/placeholder for types that don't need a bottom button
    return const SizedBox.shrink();
  }
}

// ═══════════════════════════════════════════════════════════════
// Exercise content widgets
// ═══════════════════════════════════════════════════════════════

// ─── Match Words ───────────────────────────────────────────────

class MatchWordsRandomizer {
  /// Randomizes both columns independently and guarantees that NO correct pair
  /// appears automatically aligned horizontally in the same row.
  static ({List<AnswerOption> devanagari, List<AnswerOption> english}) randomize({
    required List<AnswerOption> options,
    Map<String, String>? pairs,
    Random? random,
  }) {
    final rand = random ?? Random();
    final devItems = options.where((o) => o.isDevanagari).toList();
    final engItems = options.where((o) => !o.isDevanagari).toList();

    bool isPair(String devId, String engId) {
      if (pairs != null && pairs.containsKey(devId)) {
        return pairs[devId] == engId;
      }
      final devNum = devId.split('_d').last;
      final engNum = engId.split('_e').last;
      if (devNum.isNotEmpty && devNum == engNum && RegExp(r'^\d+$').hasMatch(devNum)) {
        return true;
      }
      final dIdx = devItems.indexWhere((o) => o.id == devId);
      final eIdx = engItems.indexWhere((o) => o.id == engId);
      return dIdx != -1 && dIdx == eIdx;
    }

    final shuffledDev = List<AnswerOption>.from(devItems)..shuffle(rand);
    var shuffledEng = List<AnswerOption>.from(engItems)..shuffle(rand);

    if (shuffledDev.length > 1 && shuffledEng.length == shuffledDev.length) {
      bool hasAlignment(List<AnswerOption> devList, List<AnswerOption> engList) {
        for (int i = 0; i < devList.length; i++) {
          if (isPair(devList[i].id, engList[i].id)) return true;
        }
        return false;
      }

      int attempts = 0;
      while (hasAlignment(shuffledDev, shuffledEng) && attempts < 20) {
        for (int i = 0; i < shuffledDev.length; i++) {
          if (isPair(shuffledDev[i].id, shuffledEng[i].id)) {
            final nextIdx = (i + 1) % shuffledDev.length;
            final temp = shuffledEng[i];
            shuffledEng[i] = shuffledEng[nextIdx];
            shuffledEng[nextIdx] = temp;
          }
        }
        attempts++;
      }

      if (hasAlignment(shuffledDev, shuffledEng)) {
        for (int shift = 1; shift < shuffledDev.length; shift++) {
          final candidate = <AnswerOption>[];
          for (int i = 0; i < shuffledDev.length; i++) {
            candidate.add(shuffledEng[(i + shift) % shuffledDev.length]);
          }
          if (!hasAlignment(shuffledDev, candidate)) {
            shuffledEng = candidate;
            break;
          }
        }
      }
    }

    return (devanagari: shuffledDev, english: shuffledEng);
  }
}

class _MatchWordsContent extends ConsumerStatefulWidget {
  final Exercise exercise;
  final VoidCallback onComplete;

  const _MatchWordsContent({
    required this.exercise,
    required this.onComplete,
  });

  @override
  ConsumerState<_MatchWordsContent> createState() => _MatchWordsContentState();
}

class _MatchWordsContentState extends ConsumerState<_MatchWordsContent> {
  late final List<AnswerOption> _devanagariItems;
  late final List<AnswerOption> _shuffledEnglishItems;
  String? _selectedDevanagariId;
  String? _selectedEnglishId;
  final Set<String> _matchedIds = {};
  String? _wrongFlashId;

  Exercise get exercise => widget.exercise;
  VoidCallback get onComplete => widget.onComplete;

  @override
  void initState() {
    super.initState();
    final randomized = MatchWordsRandomizer.randomize(
      options: exercise.options,
      pairs: exercise.pairs,
    );
    _devanagariItems = randomized.devanagari;
    _shuffledEnglishItems = randomized.english;
  }

  void _onTapDevanagari(String id) {
    if (_matchedIds.contains(id)) return;
    setState(() {
      _selectedDevanagariId = id;
      _wrongFlashId = null;
    });
    _tryMatch();
  }

  void _onTapEnglish(String id) {
    if (_matchedIds.contains(id)) return;
    setState(() {
      _selectedEnglishId = id;
      _wrongFlashId = null;
    });
    _tryMatch();
  }

  Future<void> _tryMatch() async {
    if (_selectedDevanagariId == null || _selectedEnglishId == null) return;
    final devId = _selectedDevanagariId!;
    final engId = _selectedEnglishId!;

    bool correct;
    try {
      correct = await ref.read(gameStateProvider.notifier).checkAnswer(
        exercise.id,
        selectedPairs: {devId: engId},
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }

    if (correct) {
      setState(() {
        _matchedIds.add(devId);
        _matchedIds.add(engId);
      });
      _selectedDevanagariId = null;
      _selectedEnglishId = null;

      // Check if all pairs are matched
      if (_matchedIds.length == _devanagariItems.length * 2) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) onComplete();
      }
    } else {
      setState(() => _wrongFlashId = engId);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _wrongFlashId = null;
          _selectedDevanagariId = null;
          _selectedEnglishId = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Match the words', style: GlossaTypography.headlineLarge),
          const SizedBox(height: Spacing.md),
          Text(
            '${_matchedIds.length ~/ 2} / ${_devanagariItems.length} matched',
            style: GlossaTypography.bodySmall,
          ),
          const SizedBox(height: Spacing.lg),
          // Match grid: Devanagari (left) and shuffled English (right)
          for (int i = 0; i < _devanagariItems.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: _MatchChip(
                      text: _devanagariItems[i].text,
                      isDevanagari: true,
                      isMatched: _matchedIds.contains(_devanagariItems[i].id),
                      isSelected: _selectedDevanagariId == _devanagariItems[i].id,
                      isWrong: false,
                      onTap: () => _onTapDevanagari(_devanagariItems[i].id),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: _MatchChip(
                      text: _shuffledEnglishItems[i].text,
                      isDevanagari: false,
                      isMatched:
                          _matchedIds.contains(_shuffledEnglishItems[i].id),
                      isSelected:
                          _selectedEnglishId == _shuffledEnglishItems[i].id,
                      isWrong: _wrongFlashId == _shuffledEnglishItems[i].id,
                      onTap: () => _onTapEnglish(_shuffledEnglishItems[i].id),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Spacing.lg),
          const XpTipBanner(
            tip: 'Match words faster to earn streak bonuses!',
          ),
          // Submit button when all matched
          if (_matchedIds.length == _devanagariItems.length * 2) ...[
            const SizedBox(height: Spacing.lg),
            GlossaButton(
              label: 'Continue',
              loadingLabel: 'Saving progress...',
              style: GlossaButtonStyle.dark,
              onPressed: onComplete,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Fill Blank ───────────────────────────────────────────────

class _FillBlankContent extends ConsumerStatefulWidget {
  final Exercise exercise;
  final VoidCallback onComplete;

  const _FillBlankContent({
    required this.exercise,
    required this.onComplete,
  });

  @override
  ConsumerState<_FillBlankContent> createState() => _FillBlankContentState();
}

class _FillBlankContentState extends ConsumerState<_FillBlankContent> {
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();
  String? _selectedOptionId;
  bool? _isCorrect;
  bool _submitted = false;
  bool _isChecking = false;

  Exercise get exercise => widget.exercise;
  VoidCallback get onComplete => widget.onComplete;

  void _selectOption(String id) {
    if (_submitted || _isChecking) return;
    setState(() {
      _selectedOptionId = id;
      _isCorrect = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedOptionId == null || _isChecking) return;
    setState(() => _isChecking = true);

    bool correct;
    try {
      correct = await ref.read(gameStateProvider.notifier).checkAnswer(
        exercise.id,
        selectedOptionId: _selectedOptionId,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }

    if (!mounted) return;
    setState(() {
      _submitted = true;
      _isCorrect = correct;
    });

    if (!correct) {
      _shakeKey.currentState?.shake();
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _selectedOptionId = null;
          _isCorrect = null;
          _submitted = false;
        });
      });
    } else {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) onComplete();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.instruction, style: GlossaTypography.headlineLarge),
          const SizedBox(height: Spacing.lg),
          // Sentence card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: GlossaColors.creamPale,
              borderRadius: BorderRadius.circular(Spacing.cardRadius),
              border: Border.all(color: GlossaColors.blueNavy, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  exercise.prompt ?? '',
                  style: GlossaTypography.devanagariMedium
                      .copyWith(fontSize: 28),
                ),
                if (exercise.promptHint != null) ...[
                  const SizedBox(height: Spacing.sm),
                  Text(exercise.promptHint!, style: GlossaTypography.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          Text(exercise.instruction, style: GlossaTypography.headlineSmall),
          const SizedBox(height: Spacing.md),
          ShakeWidget(
            key: _shakeKey,
            child: Wrap(
              spacing: Spacing.md,
              runSpacing: Spacing.md,
              children: exercise.options.map((opt) {
                final isSelected = _selectedOptionId == opt.id;
                final isCorrectOpt =
                    _submitted && isSelected && _isCorrect == true;
                final isWrongSelection =
                    _submitted && isSelected && _isCorrect == false;

                Color bg = GlossaColors.white;
                Color border = GlossaColors.blueNavy;
                if (isCorrectOpt && _submitted) {
                  bg = GlossaColors.successGreen.withValues(alpha: 0.25);
                  border = GlossaColors.successGreen;
                } else if (isWrongSelection) {
                  bg = GlossaColors.redAction.withValues(alpha: 0.15);
                  border = GlossaColors.redAction;
                } else if (isSelected) {
                  bg = GlossaColors.yellowPrimary.withValues(alpha: 0.6);
                }

                return GestureDetector(
                  onTap: () => _selectOption(opt.id),
                  child: AnimatedContainer(
                    duration: GlossaMotion.selection,
                    curve: GlossaMotion.snappy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(Spacing.cardRadius),
                      border: Border.all(color: border, width: 2.5),
                    ),
                    child: Text(
                      opt.text,
                      style: opt.isDevanagari
                          ? GlossaTypography.devanagariSmall
                          : GlossaTypography.headlineSmall,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: Spacing.xl),
          GlossaButton(
            label: 'Submit answer',
            loadingLabel: 'Checking answer...',
            style: GlossaButtonStyle.primary,
            onPressed: _selectedOptionId != null && !_submitted && !_isChecking
                ? _submit
                : null,
          ),
        ],
      ),
    );
  }
}

// ─── Picture to Word ───────────────────────────────────────────

class _PictureToWordContent extends ConsumerStatefulWidget {
  final Exercise exercise;
  final VoidCallback onComplete;

  const _PictureToWordContent({
    required this.exercise,
    required this.onComplete,
  });

  @override
  ConsumerState<_PictureToWordContent> createState() =>
      _PictureToWordContentState();
}

class _PictureToWordContentState extends ConsumerState<_PictureToWordContent> {
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();
  String? _selectedOptionId;
  bool? _isCorrect;
  bool _submitted = false;
  bool _isChecking = false;

  Exercise get exercise => widget.exercise;
  VoidCallback get onComplete => widget.onComplete;

  void _selectOption(String id) {
    if (_submitted || _isChecking) return;
    setState(() {
      _selectedOptionId = id;
      _isCorrect = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedOptionId == null || _isChecking) return;
    setState(() => _isChecking = true);
    bool correct;
    try {
      correct = await ref.read(gameStateProvider.notifier).checkAnswer(
        exercise.id,
        selectedOptionId: _selectedOptionId,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
    if (!mounted) return;
    setState(() {
      _submitted = true;
      _isCorrect = correct;
    });

    if (!correct) {
      _shakeKey.currentState?.shake();
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _selectedOptionId = null;
          _isCorrect = null;
          _submitted = false;
        });
      });
    } else {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) onComplete();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Name the picture', style: GlossaTypography.headlineLarge),
          const SizedBox(height: Spacing.lg),
          Center(
            child: Container(
              width: 200,
              height: 180,
              decoration: BoxDecoration(
                color: GlossaColors.yellowPrimary.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(Spacing.cardRadius),
                border: Border.all(color: GlossaColors.blueNavy, width: 2.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SimpleIllustration(
                    imageKey: exercise.imageKey ?? 'bowl',
                    size: 100,
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    exercise.prompt ?? 'What is this called?',
                    style: GlossaTypography.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          ShakeWidget(
            key: _shakeKey,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: Spacing.md,
              mainAxisSpacing: Spacing.md,
              childAspectRatio: 2.5,
              physics: const NeverScrollableScrollPhysics(),
              children: exercise.options.map((opt) {
                final isSelected = _selectedOptionId == opt.id;
                final isCorrectOpt =
                    _submitted && isSelected && _isCorrect == true;
                final isWrongSelection =
                    _submitted && isSelected && _isCorrect == false;

                Color bg = GlossaColors.white;
                Color border = GlossaColors.blueNavy;
                if (isCorrectOpt && _submitted) {
                  bg = GlossaColors.successGreen.withValues(alpha: 0.25);
                  border = GlossaColors.successGreen;
                } else if (isWrongSelection) {
                  bg = GlossaColors.redAction.withValues(alpha: 0.15);
                  border = GlossaColors.redAction;
                } else if (isSelected) {
                  bg = GlossaColors.yellowPrimary.withValues(alpha: 0.6);
                }

                return GestureDetector(
                  onTap: () => _selectOption(opt.id),
                  child: AnimatedContainer(
                    duration: GlossaMotion.selection,
                    curve: GlossaMotion.snappy,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(Spacing.cardRadius),
                      border: Border.all(color: border, width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        opt.text,
                        style: opt.isDevanagari
                            ? GlossaTypography.devanagariSmall
                            : GlossaTypography.headlineSmall,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: Spacing.xl),
          GlossaButton(
            label: 'Submit answer',
            loadingLabel: 'Checking answer...',
            style: GlossaButtonStyle.primary,
            onPressed:
                _selectedOptionId != null && !_submitted && !_isChecking ? _submit : null,
          ),
        ],
      ),
    );
  }
}

// ─── Word to Picture ───────────────────────────────────────────

class _WordToPictureContent extends ConsumerStatefulWidget {
  final Exercise exercise;
  final VoidCallback onComplete;

  const _WordToPictureContent({
    required this.exercise,
    required this.onComplete,
  });

  @override
  ConsumerState<_WordToPictureContent> createState() =>
      _WordToPictureContentState();
}

class _WordToPictureContentState extends ConsumerState<_WordToPictureContent> {
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();
  String? _selectedOptionId;
  bool? _isCorrect;
  bool _submitted = false;
  bool _isChecking = false;

  Exercise get exercise => widget.exercise;
  VoidCallback get onComplete => widget.onComplete;

  void _selectOption(String id) {
    if (_submitted || _isChecking) return;
    setState(() {
      _selectedOptionId = id;
      _isCorrect = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedOptionId == null || _isChecking) return;
    setState(() => _isChecking = true);
    bool correct;
    try {
      correct = await ref.read(gameStateProvider.notifier).checkAnswer(
        exercise.id,
        selectedOptionId: _selectedOptionId,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
    if (!mounted) return;
    setState(() {
      _submitted = true;
      _isCorrect = correct;
    });

    if (!correct) {
      _shakeKey.currentState?.shake();
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _selectedOptionId = null;
          _isCorrect = null;
          _submitted = false;
        });
      });
    } else {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) onComplete();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pick the picture', style: GlossaTypography.headlineLarge),
        const SizedBox(height: Spacing.lg),
        // Word prompt card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spacing.xl),
          decoration: BoxDecoration(
            color: GlossaColors.blueNavy,
            borderRadius: BorderRadius.circular(Spacing.cardRadius),
          ),
          child: Center(
            child: Text(
              exercise.prompt ?? '?',
              style: GlossaTypography.devanagariLarge
                  .copyWith(color: GlossaColors.yellowPrimary),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xxl),
        Expanded(
          child: ShakeWidget(
            key: _shakeKey,
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: Spacing.md,
              mainAxisSpacing: Spacing.md,
              childAspectRatio: 1.0,
              physics: const NeverScrollableScrollPhysics(),
              children: exercise.options.map((opt) {
                final isSelected = _selectedOptionId == opt.id;
                final isCorrectOpt =
                    _submitted && isSelected && _isCorrect == true;
                final isWrongSelection =
                    _submitted && isSelected && _isCorrect == false;

                Color bg = GlossaColors.white;
                Color border = GlossaColors.blueNavy;
                if (isCorrectOpt && _submitted) {
                  bg = GlossaColors.successGreen.withValues(alpha: 0.25);
                  border = GlossaColors.successGreen;
                } else if (isWrongSelection) {
                  bg = GlossaColors.redAction.withValues(alpha: 0.15);
                  border = GlossaColors.redAction;
                } else if (isSelected) {
                  bg = GlossaColors.yellowPrimary.withValues(alpha: 0.6);
                }

                return GestureDetector(
                  onTap: () => _selectOption(opt.id),
                  child: AnimatedContainer(
                    duration: GlossaMotion.selection,
                    curve: GlossaMotion.snappy,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(Spacing.cardRadius),
                      border: Border.all(color: border, width: 2.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SimpleIllustration(
                          imageKey: opt.imageKey ?? 'house',
                          size: 60,
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(opt.text, style: GlossaTypography.labelMedium),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        GlossaButton(
          label: 'Submit answer',
          loadingLabel: 'Checking answer...',
          style: GlossaButtonStyle.primary,
          onPressed:
              _selectedOptionId != null && !_submitted && !_isChecking ? _submit : null,
        ),
      ],
    );
  }
}

// ─── Shared match chip widget ─────────────────────────────────

class _MatchChip extends StatelessWidget {
  final String text;
  final bool isDevanagari;
  final bool isMatched;
  final bool isSelected;
  final bool isWrong;
  final VoidCallback onTap;

  const _MatchChip({
    required this.text,
    required this.isDevanagari,
    required this.isMatched,
    required this.isSelected,
    required this.isWrong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    if (isMatched) {
      bgColor = GlossaColors.successGreen.withValues(alpha: 0.2);
      borderColor = GlossaColors.successGreen;
    } else if (isWrong) {
      bgColor = GlossaColors.redAction.withValues(alpha: 0.15);
      borderColor = GlossaColors.redAction;
    } else if (isSelected) {
      bgColor = GlossaColors.yellowPrimary.withValues(alpha: 0.6);
      borderColor = GlossaColors.blueNavy;
    } else {
      bgColor = GlossaColors.white;
      borderColor = GlossaColors.blueNavy;
    }

    Widget chipContent = AnimatedContainer(
      duration: GlossaMotion.selection,
      curve: GlossaMotion.snappy,
      height: 56,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
        border: Border.all(color: borderColor, width: 2.5),
      ),
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: GlossaMotion.selection,
          style: isDevanagari
              ? GlossaTypography.devanagariSmall
                  .copyWith(color: GlossaColors.textDark)
              : GlossaTypography.headlineSmall
                  .copyWith(color: GlossaColors.textDark),
          child: Text(text),
        ),
      ),
    );

    if (isWrong) {
      chipContent = ShakeWidget(deltaX: 6.0, child: chipContent);
    }

    return GestureDetector(
      onTap: isMatched ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: GlossaMotion.selection,
        opacity: isMatched ? 0.75 : 1.0,
        child: chipContent,
      ),
    );
  }
}
