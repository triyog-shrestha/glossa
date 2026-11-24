import '../models/course_models.dart';
import '../models/leaderboard_entry.dart';
import '../mock_data/mock_data.dart';

/// Interface for course/lesson data access.
abstract class CourseRepository {
  List<Lesson> getLessons();
  List<Exercise> getExercises(String lessonId);
}

class MockCourseRepository implements CourseRepository {
  @override
  List<Lesson> getLessons() => mockLessons;

  @override
  List<Exercise> getExercises(String lessonId) => exercisesForLesson(lessonId);
}

/// Interface for lesson progress tracking.
abstract class ProgressRepository {
  void recordAttempt(LessonAttempt attempt);
  LessonAttempt? getLastAttempt(String lessonId);
  int getTotalXp();
}

class MockProgressRepository implements ProgressRepository {
  final Map<String, LessonAttempt> _attempts = {};
  int _totalXp = 310;

  @override
  void recordAttempt(LessonAttempt attempt) {
    _attempts[attempt.lessonId] = attempt;
    _totalXp += attempt.xpEarned;
  }

  @override
  LessonAttempt? getLastAttempt(String lessonId) => _attempts[lessonId];

  @override
  int getTotalXp() => _totalXp;
}

/// Interface for leaderboard data.
abstract class LeaderboardRepository {
  List<LeaderboardEntry> getEntries(String filter);
}

class MockLeaderboardRepository implements LeaderboardRepository {
  @override
  List<LeaderboardEntry> getEntries(String filter) {
    switch (filter) {
      case 'alltime':
        return mockLeaderboardAllTime;
      default:
        return mockLeaderboardWeekly;
    }
  }
}

/// Interface for audio playback (demo only).
abstract class AudioRepository {
  Future<void> play(String id);
  Future<void> stop();
  bool get isPlaying;
}

class MockAudioRepository implements AudioRepository {
  bool _isPlaying = false;

  @override
  Future<void> play(String id) async {
    _isPlaying = true;
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
  }

  @override
  bool get isPlaying => _isPlaying;
}
