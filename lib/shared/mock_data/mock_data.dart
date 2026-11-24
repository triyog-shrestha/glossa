import '../models/demo_user.dart';
import '../models/hero_choice.dart';
import '../models/course_models.dart';
import '../models/leaderboard_entry.dart';

// ─── Seed user ──────────────────────────────────────────────
const DemoUser seedUser = DemoUser(
  name: 'LeBron',
  email: 'lebron@example.com',
  heroIndex: 0,
  heroClassName: 'Speaker',
  level: 4,
  xp: 310,
  xpToNextLevel: 500,
  streak: 5,
  wordsFound: 24,
  lessonsCompleted: 1,
  languageId: 'newari',
  languageName: 'Newari',
  languageScript: 'नेपाल भाषा',
);

// ─── Hero choices ───────────────────────────────────────────
const List<HeroChoice> heroChoices = [
  HeroChoice(index: 0, label: 'Boy', description: 'A brave young traveler.'),
  HeroChoice(index: 1, label: 'Girl', description: 'A courageous explorer.'),
];

// ─── Language choices ───────────────────────────────────────
const List<LanguageChoice> languageChoices = [
  LanguageChoice(
    id: 'nepali',
    nameNative: 'नेपाली',
    nameEnglish: 'Nepali',
    letterSymbol: 'ने',
    subtitle: 'Primary course',
    isStarter: true,
  ),
  LanguageChoice(
    id: 'english',
    nameNative: 'English',
    nameEnglish: 'English',
    letterSymbol: 'En',
    subtitle: 'Learn English',
  ),
  LanguageChoice(
    id: 'newari',
    nameNative: 'नेपाल भाषा',
    nameEnglish: 'Newari',
    letterSymbol: 'भा',
    subtitle: 'Heritage language',
  ),
];

// ─── Lessons ────────────────────────────────────────────────
List<Lesson> get mockLessons => [
  const Lesson(
    id: 'lesson_1',
    title: 'Rice and Bread',
    subtitle: 'Match · 4 words',
    exerciseType: ExerciseType.matchWords,
    status: LessonStatus.cleared,
    xpReward: 20,
    wordCount: 4,
    requiredLevel: 1,
  ),
  const Lesson(
    id: 'lesson_2',
    title: 'Around the House',
    subtitle: 'Fill in the blank · +20 XP',
    exerciseType: ExerciseType.fillBlank,
    status: LessonStatus.current,
    xpReward: 20,
    wordCount: 4,
    requiredLevel: 3,
  ),
  const Lesson(
    id: 'lesson_3',
    title: 'Fruits and Veggies',
    subtitle: 'Picture to word',
    exerciseType: ExerciseType.pictureToWord,
    status: LessonStatus.locked,
    xpReward: 20,
    wordCount: 4,
    requiredLevel: 4,
  ),
  const Lesson(
    id: 'lesson_4',
    title: "Grandma's Kitchen",
    subtitle: 'Word to picture',
    exerciseType: ExerciseType.wordToPicture,
    status: LessonStatus.locked,
    xpReward: 20,
    wordCount: 4,
    requiredLevel: 5,
  ),
  const Lesson(
    id: 'lesson_5',
    title: 'Family at Home',
    subtitle: 'Audio lesson',
    exerciseType: ExerciseType.matchWords,
    status: LessonStatus.locked,
    xpReward: 25,
    wordCount: 5,
    requiredLevel: 6,
  ),
  const Lesson(
    id: 'lesson_6',
    title: 'Festival Feast',
    subtitle: 'Speak and record',
    exerciseType: ExerciseType.fillBlank,
    status: LessonStatus.locked,
    xpReward: 30,
    wordCount: 6,
    requiredLevel: 7,
  ),
];

// ─── Exercises ──────────────────────────────────────────────
/// Match words exercise for "Rice and Bread"
List<Exercise> get matchWordsExercises => [
  const Exercise(
    id: 'mw_1',
    type: ExerciseType.matchWords,
    instruction: 'Match the words',
    options: [
      AnswerOption(id: 'mw_d1', text: 'माँ', isDevanagari: true),
      AnswerOption(id: 'mw_e1', text: 'Mother'),
      AnswerOption(id: 'mw_d2', text: 'ल', isDevanagari: true),
      AnswerOption(id: 'mw_e2', text: 'House'),
      AnswerOption(id: 'mw_d3', text: 'छें', isDevanagari: true),
      AnswerOption(id: 'mw_e3', text: 'Water'),
      AnswerOption(id: 'mw_d4', text: 'बजि', isDevanagari: true),
      AnswerOption(id: 'mw_e4', text: 'Beaten rice'),
    ],
    correctAnswerId: '', // Matching pairs; handled by lesson logic
  ),
];

/// Match pairs mapping for the word matching exercise
const Map<String, String> matchPairs = {
  'mw_d1': 'mw_e1', // माँ → Mother
  'mw_d2': 'mw_e2', // ल → House
  'mw_d3': 'mw_e3', // छें → Water
  'mw_d4': 'mw_e4', // बजि → Beaten rice
};

/// Fill in the blank exercise for "Around the House"
List<Exercise> get fillBlankExercises => [
  const Exercise(
    id: 'fb_1',
    type: ExerciseType.fillBlank,
    instruction: 'Fill in the blank',
    prompt: 'दौ ___',
    promptHint: 'Yogurt and beaten rice',
    options: [
      AnswerOption(id: 'fb_a', text: 'बजि', isDevanagari: true),
      AnswerOption(id: 'fb_b', text: 'ल', isDevanagari: true),
      AnswerOption(id: 'fb_c', text: 'छें', isDevanagari: true),
    ],
    correctAnswerId: 'fb_a',
  ),
  const Exercise(
    id: 'fb_2',
    type: ExerciseType.fillBlank,
    instruction: 'Fill in the blank',
    prompt: '___ खा',
    promptHint: 'Eating at home',
    options: [
      AnswerOption(id: 'fb2_a', text: 'ल', isDevanagari: true),
      AnswerOption(id: 'fb2_b', text: 'माँ', isDevanagari: true),
      AnswerOption(id: 'fb2_c', text: 'छें', isDevanagari: true),
    ],
    correctAnswerId: 'fb2_a',
  ),
];

/// Picture to word exercise for "Fruits and Veggies"
List<Exercise> get pictureToWordExercises => [
  const Exercise(
    id: 'ptw_1',
    type: ExerciseType.pictureToWord,
    instruction: 'Name the picture',
    prompt: 'What is this called?',
    imageKey: 'bowl',
    options: [
      AnswerOption(id: 'ptw_a', text: 'बजि', isDevanagari: true),
      AnswerOption(id: 'ptw_b', text: 'छें', isDevanagari: true),
      AnswerOption(id: 'ptw_c', text: 'ल', isDevanagari: true),
      AnswerOption(id: 'ptw_d', text: 'माँ', isDevanagari: true),
    ],
    correctAnswerId: 'ptw_a',
  ),
];

/// Word to picture exercise for "Grandma's Kitchen"
List<Exercise> get wordToPictureExercises => [
  const Exercise(
    id: 'wtp_1',
    type: ExerciseType.wordToPicture,
    instruction: 'Pick the picture',
    prompt: 'Which picture is this?',
    options: [
      AnswerOption(id: 'wtp_a', text: 'House', imageKey: 'house'),
      AnswerOption(id: 'wtp_b', text: 'Water', imageKey: 'droplet'),
      AnswerOption(id: 'wtp_c', text: 'Bowl', imageKey: 'bowl'),
      AnswerOption(id: 'wtp_d', text: 'Person', imageKey: 'person'),
    ],
    correctAnswerId: 'wtp_a',
  ),
];

/// Get exercises for a given lesson.
List<Exercise> exercisesForLesson(String lessonId) {
  switch (lessonId) {
    case 'lesson_1':
      return matchWordsExercises;
    case 'lesson_2':
      return fillBlankExercises;
    case 'lesson_3':
      return pictureToWordExercises;
    case 'lesson_4':
      return wordToPictureExercises;
    default:
      return fillBlankExercises; // Fallback for locked lessons
  }
}

// ─── Mock leaderboard ───────────────────────────────────────
List<LeaderboardEntry> get mockLeaderboardWeekly => [
  const LeaderboardEntry(rank: 1, name: 'Sabin', level: 8, className: 'Master', xp: 2140, heroIndex: 0),
  const LeaderboardEntry(rank: 2, name: 'Nima', level: 7, className: 'Guardian', xp: 1980, heroIndex: 1),
  const LeaderboardEntry(rank: 3, name: 'Rina', level: 7, className: 'Guardian', xp: 1850, heroIndex: 1),
  const LeaderboardEntry(rank: 4, name: 'Anju', level: 7, className: 'Guardian', xp: 1320, heroIndex: 1),
  const LeaderboardEntry(rank: 5, name: 'Dorje', level: 6, className: 'Speaker', xp: 1090, heroIndex: 0),
  const LeaderboardEntry(rank: 6, name: 'LeBron', level: 4, className: 'Speaker', xp: 640, heroIndex: 0, isCurrentUser: true),
  const LeaderboardEntry(rank: 7, name: 'Pema', level: 4, className: 'Speaker', xp: 590, heroIndex: 1),
  const LeaderboardEntry(rank: 8, name: 'Karma', level: 2, className: 'Traveler', xp: 410, heroIndex: 0),
];

List<LeaderboardEntry> get mockLeaderboardAllTime => [
  const LeaderboardEntry(rank: 1, name: 'Sabin', level: 10, className: 'Master', xp: 8540, heroIndex: 0),
  const LeaderboardEntry(rank: 2, name: 'Nima', level: 9, className: 'Master', xp: 7200, heroIndex: 1),
  const LeaderboardEntry(rank: 3, name: 'Rina', level: 8, className: 'Master', xp: 6350, heroIndex: 1),
  const LeaderboardEntry(rank: 4, name: 'Anju', level: 7, className: 'Guardian', xp: 4800, heroIndex: 1),
  const LeaderboardEntry(rank: 5, name: 'Dorje', level: 6, className: 'Speaker', xp: 3200, heroIndex: 0),
  const LeaderboardEntry(rank: 6, name: 'LeBron', level: 4, className: 'Speaker', xp: 640, heroIndex: 0, isCurrentUser: true),
  const LeaderboardEntry(rank: 7, name: 'Pema', level: 4, className: 'Speaker', xp: 590, heroIndex: 1),
  const LeaderboardEntry(rank: 8, name: 'Karma', level: 2, className: 'Traveler', xp: 410, heroIndex: 0),
];

/// Word of the day
const Map<String, String> wordOfTheDay = {
  'devanagari': 'छें',
  'english': 'House',
};

/// Words learned as chips shown on completion
const List<String> learnedWords = ['माँ', 'ल', 'छें', 'बजि'];
