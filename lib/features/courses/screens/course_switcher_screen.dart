import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/glossa_card.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

class CourseSwitcherScreen extends ConsumerStatefulWidget {
  const CourseSwitcherScreen({super.key});

  @override
  ConsumerState<CourseSwitcherScreen> createState() =>
      _CourseSwitcherScreenState();
}

class _CourseSwitcherScreenState extends ConsumerState<CourseSwitcherScreen> {
  bool _switching = false;
  String? _switchingCourseId;

  Future<void> _selectCourse(Course course) async {
    if (!course.isPublished || _switching) return;
    setState(() {
      _switching = true;
      _switchingCourseId = course.id;
    });
    try {
      await ref.read(gameStateProvider.notifier).switchCourse(course.id);
      if (mounted) {
        context.go(AppRoutes.town);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _switching = false;
          _switchingCourseId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);
    final courses = gs.courses.where((c) => c.isPublished).toList();
    final activeCourseId = gs.user.activeCourseId;

    return Scaffold(
      backgroundColor: GlossaColors.creamBackground,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: Spacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.pagePadding,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.town);
                      }
                    },
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: GlossaColors.blueNavy,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Text('Select Course', style: GlossaTypography.displayMedium),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            Expanded(
              child: courses.isEmpty
                  ? const Center(
                      child: Text(
                        'No courses available yet',
                        style: GlossaTypography.bodyMedium,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.pagePadding,
                      ),
                      child: Column(
                        children: courses.map((course) {
                          final isActive = course.id == activeCourseId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: Spacing.md),
                            child: _CourseCard(
                              course: course,
                              isActive: isActive,
                              isSwitching:
                                  _switching && _switchingCourseId == course.id,
                              onTap: () => _selectCourse(course),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final bool isActive;
  final bool isSwitching;
  final VoidCallback onTap;

  const _CourseCard({
    required this.course,
    required this.isActive,
    required this.isSwitching,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: course.isPublished && !isSwitching ? onTap : null,
      child: GlossaCard(
        backgroundColor: course.isPublished
            ? (isActive ? GlossaColors.blueNavy : GlossaColors.white)
            : GlossaColors.creamPale,
        child: Row(
          children: [
            // Source language letter
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive
                    ? GlossaColors.yellowPrimary
                    : GlossaColors.creamPale,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GlossaColors.blueNavy, width: 2),
              ),
              child: Center(
                child: Text(
                  course.sourceLanguage.nameEnglish[0],
                  style: TextStyle(
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
                  Text(
                    course.name,
                    style: GlossaTypography.headlineSmall.copyWith(
                      color: course.isPublished
                          ? (isActive
                              ? GlossaColors.white
                              : GlossaColors.textDark)
                          : GlossaColors.textSubtle,
                    ),
                  ),
                  if (course.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      course.description!,
                      style: GlossaTypography.bodySmall.copyWith(
                        color: course.isPublished
                            ? (isActive
                                ? GlossaColors.white.withValues(alpha: 0.7)
                                : GlossaColors.textSubtle)
                            : GlossaColors.textSubtle,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            // Badge
            if (isSwitching)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: GlossaColors.successGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Active',
                  style: GlossaTypography.labelSmall.copyWith(
                    color: GlossaColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: GlossaColors.blueDeep,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Switch',
                  style: GlossaTypography.labelSmall.copyWith(
                    color: GlossaColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
