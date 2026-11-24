import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/greek_key_border.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/shared/models/leaderboard_entry.dart';
import 'package:glossa_app/shared/mock_data/mock_data.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  int _selectedTabIndex = 0;
  late Future<List<LeaderboardEntry>> _entries;

  static const _filters = ['weekly', 'alltime'];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  List<LeaderboardEntry> _mockForFilter(String filter) {
    switch (filter) {
      case 'alltime':
        return mockLeaderboardAllTime;
      case 'weekly':
      default:
        return mockLeaderboardWeekly;
    }
  }

  void _loadEntries() {
    _entries = ref
        .read(backendApiProvider)
        .leaderboard(_filters[_selectedTabIndex])
        .catchError((_) => _mockForFilter(_filters[_selectedTabIndex]));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LeaderboardEntry>>(
      future: _entries,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <LeaderboardEntry>[];
        final topThree = entries.take(3).toList();
        final remaining = entries.skip(3).toList();
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Could not load leaderboard: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          backgroundColor: GlossaColors.creamBackground,
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top),
                const GreekKeyBorder(),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.pagePadding,
                            vertical: Spacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Leaderboard',
                                style: GlossaTypography.displayMedium,
                              ),
                              const SizedBox(height: Spacing.md),
                              _buildFilterTabs(),
                              const SizedBox(height: Spacing.xl),
                              if (topThree.isNotEmpty) _buildPodium(topThree),
                              const SizedBox(height: Spacing.xl),
                              Text(
                                'Top Adventurers',
                                style: GlossaTypography.headlineSmall,
                              ),
                              const SizedBox(height: Spacing.sm),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.pagePadding,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final entry = remaining[index];
                            return _buildLeaderboardTile(entry);
                          }, childCount: remaining.length),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: Spacing.xxl),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterTabs() {
    final tabs = ['This week', 'All time'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GlossaColors.white,
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
        border: Border.all(color: GlossaColors.blueNavy, width: 2),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = _selectedTabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedTabIndex = i;
                _loadEntries();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? GlossaColors.blueNavy
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Spacing.cardRadius - 4),
                ),
                child: Center(
                  child: Text(
                    tabs[i],
                    style: GlossaTypography.labelSmall.copyWith(
                      color: isSelected
                          ? GlossaColors.white
                          : GlossaColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> topThree) {
    // 2nd on left, 1st in center, 3rd on right
    LeaderboardEntry? first = topThree.isNotEmpty ? topThree[0] : null;
    LeaderboardEntry? second = topThree.length > 1 ? topThree[1] : null;
    LeaderboardEntry? third = topThree.length > 2 ? topThree[2] : null;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: GlossaColors.creamPale,
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
        border: Border.all(color: GlossaColors.blueNavy, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null) _buildPodiumPillar(second, 2, 110),
          if (first != null) _buildPodiumPillar(first, 1, 140),
          if (third != null) _buildPodiumPillar(third, 3, 90),
        ],
      ),
    );
  }

  Widget _buildPodiumPillar(LeaderboardEntry entry, int rank, double height) {
    Color medalColor;
    switch (rank) {
      case 1:
        medalColor = const Color(0xFFFFD700);
        break;
      case 2:
        medalColor = const Color(0xFFC0C0C0);
        break;
      case 3:
      default:
        medalColor = const Color(0xFFCD7F32);
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            HeroAvatar(
              heroIndex: entry.heroIndex,
              level: entry.level,
              size: rank == 1 ? 56 : 46,
            ),
            Positioned(
              top: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: medalColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GlossaColors.blueNavy, width: 1.5),
                ),
                child: Text(
                  '#$rank',
                  style: GlossaTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w900,
                    color: GlossaColors.blueNavy,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          entry.name,
          style: GlossaTypography.labelMedium.copyWith(fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${entry.xp} XP',
          style: GlossaTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: GlossaColors.blueDeep,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Container(
          width: 72,
          height: height,
          decoration: BoxDecoration(
            color: rank == 1 ? GlossaColors.yellowPrimary : GlossaColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: GlossaColors.blueNavy, width: 2),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: GlossaTypography.headlineLarge.copyWith(
                color: GlossaColors.blueNavy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTile(LeaderboardEntry entry) {
    final isMe = entry.isCurrentUser;

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? GlossaColors.yellowPrimary : GlossaColors.white,
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
        border: Border.all(
          color: GlossaColors.blueNavy,
          width: isMe ? 2.5 : 1.5,
        ),
        boxShadow: isMe
            ? [
                const BoxShadow(
                  color: GlossaColors.blueNavy,
                  offset: Offset(0, 2),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${entry.rank}',
              style: GlossaTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: GlossaColors.textDark,
              ),
            ),
          ),
          HeroAvatar(heroIndex: entry.heroIndex, level: entry.level, size: 38),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.name,
                      style: GlossaTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: Spacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: GlossaColors.redAction,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'YOU',
                          style: GlossaTypography.labelSmall.copyWith(
                            color: GlossaColors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Lv ${entry.level} ${entry.className}',
                  style: GlossaTypography.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${entry.xp} XP',
            style: GlossaTypography.labelMedium.copyWith(
              color: GlossaColors.blueDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
