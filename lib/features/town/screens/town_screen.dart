import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/glossa_card.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/models/course_models.dart';

class TownScreen extends ConsumerStatefulWidget {
  const TownScreen({super.key});

  @override
  ConsumerState<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends ConsumerState<TownScreen> {
  bool _isExpanded = false;
  bool _isStartingLesson = false;

  Future<void> _startLesson(Lesson lesson) async {
    if (_isStartingLesson) return;
    if (lesson.status == LessonStatus.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complete the previous lesson to unlock "${lesson.title}".',
          ),
        ),
      );
      return;
    }
    setState(() => _isStartingLesson = true);
    try {
      await ref.read(gameStateProvider.notifier).startLesson(lesson.id);
      if (mounted) {
        context.go(AppRoutes.battleLoading);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingLesson = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);
    final user = gs.user;
    final lessons = gs.lessons;
    final units = gs.units;

    // Group lessons by unitId
    final lessonsByUnit = <int, List<Lesson>>{};
    for (final lesson in lessons) {
      if (lesson.unitId != null) {
        lessonsByUnit.putIfAbsent(lesson.unitId!, () => []).add(lesson);
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.pagePadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Spacing.lg),
                    // Player header with course switcher button
                    Row(
                      children: [
                        HeroAvatar(
                          heroIndex: user.heroIndex,
                          level: user.level,
                          size: 50,
                          animateIdle: true,
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lv ${user.level} ${user.heroClassName}',
                                style: GlossaTypography.bodySmall,
                              ),
                              Text(
                                'Ready, ${user.name}?',
                                style: GlossaTypography.headlineLarge,
                              ),
                            ],
                          ),
                        ),
                        // Course switcher button
                        IconButton(
                          icon: const Icon(
                            Icons.swap_horiz_rounded,
                            color: GlossaColors.blueNavy,
                            size: 28,
                          ),
                          onPressed: () =>
                              context.push(AppRoutes.courseSwitcher),
                          tooltip: 'Switch course',
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    GlossaProgressBar(
                      progress: user.xp / user.xpToNextLevel,
                      fillColor: GlossaColors.redAction,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Row(
                      children: [
                        Text(
                          '${user.xp} / ${user.xpToNextLevel} XP',
                          style: GlossaTypography.bodySmall,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: GlossaColors.streakGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '🔥 ${user.streak} day streak',
                            style: GlossaTypography.labelSmall.copyWith(
                              color: GlossaColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xl),
                    // Dynamic unit sections
                    if (units.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(Spacing.xl),
                        decoration: BoxDecoration(
                          color: GlossaColors.creamPale,
                          borderRadius:
                              BorderRadius.circular(Spacing.cardRadius),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.school_rounded,
                                size: 48, color: GlossaColors.textSubtle),
                            const SizedBox(height: Spacing.md),
                            Text(
                              'No lessons available yet.\nSwitch to a course or check back soon!',
                              style: GlossaTypography.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: Spacing.md),
                            GlossaButton(
                              label: 'Browse Courses',
                              onPressed: () =>
                                  context.push(AppRoutes.courseSwitcher),
                            ),
                          ],
                        ),
                      )
                    else
                      ...units.map((unit) {
                        final unitLessons = lessonsByUnit[unit.id] ?? [];
                        if (unitLessons.isEmpty) return const SizedBox.shrink();
                        final displayLessons = _isExpanded
                            ? unitLessons
                            : unitLessons.take(3).toList();
                        return _UnitSection(
                          unit: unit,
                          clearedInUnit: unitLessons
                              .where((l) =>
                                  l.status == LessonStatus.cleared)
                              .length,
                          totalInUnit: unitLessons.length,
                          lessons: displayLessons,
                          onStart: _startLesson,
                        );
                      }),
                    // Expand/collapse button
                    if (lessons.isNotEmpty)
                      Center(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _isExpanded = !_isExpanded),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: GlossaColors.yellowPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: GlossaColors.blueNavy,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: GlossaColors.textDark,
                            ),
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
}

class _LessonPathItem extends StatelessWidget {
  final Lesson lesson;
  final bool isLast;
  final VoidCallback? onStart;

  const _LessonPathItem({
    required this.lesson,
    required this.isLast,
    this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Path node
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: lesson.status == LessonStatus.current
                          ? GlossaColors.redAction
                          : GlossaColors.blueNavy,
                      width: 2,
                    ),
                  ),
                  child: Center(child: _nodeContent),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: GlossaColors.blueNavy.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          // Lesson card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Spacing.lg),
              child: GlossaCard(
                backgroundColor: lesson.status == LessonStatus.locked
                    ? GlossaColors.creamPale
                    : GlossaColors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.title,
                            style: GlossaTypography.headlineSmall.copyWith(
                              color: lesson.status == LessonStatus.locked
                                  ? GlossaColors.textSubtle
                                  : GlossaColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lesson.subtitle,
                            style: GlossaTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _statusBadge,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _nodeColor {
    switch (lesson.status) {
      case LessonStatus.cleared:
        return GlossaColors.successGreen;
      case LessonStatus.current:
        return GlossaColors.white;
      case LessonStatus.locked:
        return GlossaColors.creamPale;
    }
  }

  Widget get _nodeContent {
    switch (lesson.status) {
      case LessonStatus.cleared:
        return const Icon(Icons.check, color: GlossaColors.white, size: 20);
      case LessonStatus.current:
        return Text(
          'GO',
          style: GlossaTypography.labelSmall.copyWith(
            color: GlossaColors.redAction,
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
        );
      case LessonStatus.locked:
        return Text(
          'Lv ${lesson.requiredLevel}',
          style: GlossaTypography.labelSmall.copyWith(fontSize: 9),
        );
    }
  }

  Widget get _statusBadge {
    switch (lesson.status) {
      case LessonStatus.cleared:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GlossaColors.blueNavy, width: 1.5),
          ),
          child: Text(
            'Cleared',
            style: GlossaTypography.labelSmall.copyWith(
              color: GlossaColors.textDark,
            ),
          ),
        );
      case LessonStatus.current:
        return GestureDetector(
          onTap: onStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: GlossaColors.redAction,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Go!',
              style: GlossaTypography.labelSmall.copyWith(
                color: GlossaColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      case LessonStatus.locked:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GlossaColors.disabledGray, width: 1.5),
          ),
          child: Text(
            'Lv ${lesson.requiredLevel}',
            style: GlossaTypography.labelSmall,
          ),
        );
    }
  }
}

/// A section for a unit, showing the unit header and its lessons.
class _UnitSection extends StatelessWidget {
  final CourseUnit unit;
  final int clearedInUnit;
  final int totalInUnit;
  final List<Lesson> lessons;
  final Future<void> Function(Lesson) onStart;

  const _UnitSection({
    required this.unit,
    required this.clearedInUnit,
    required this.totalInUnit,
    required this.lessons,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unit header with progress
        Row(
          children: [
            Expanded(
              child: Text(
                unit.title,
                style: GlossaTypography.headlineMedium,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GlossaColors.blueNavy, width: 1.5),
              ),
              child: Text(
                '$clearedInUnit / $totalInUnit cleared',
                style: GlossaTypography.labelSmall.copyWith(
                  color: GlossaColors.textDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        GlossaProgressBar(
          progress: totalInUnit > 0 ? clearedInUnit / totalInUnit : 0,
          fillColor: clearedInUnit == totalInUnit
              ? GlossaColors.successGreen
              : GlossaColors.redAction,
        ),
        const SizedBox(height: Spacing.xl),
        // Lesson path items
        ...lessons.asMap().entries.map((entry) {
          final i = entry.key;
          final lesson = entry.value;
          final isLast = i == lessons.length - 1;
          return _LessonPathItem(
            lesson: lesson,
            isLast: isLast,
            onStart: lesson.status == LessonStatus.current
                ? () => onStart(lesson)
                : null,
          );
        }),
      ],
    );
  }
}
