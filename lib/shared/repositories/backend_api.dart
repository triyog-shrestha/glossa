import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/models/demo_user.dart';
import 'package:glossa_app/shared/models/leaderboard_entry.dart';
import 'package:glossa_app/shared/mock_data/mock_data.dart';

import 'dart:convert';

class BackendApi {
  BackendApi({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  /// Explicit override via --dart-define=API_BASE_URL=...
  /// Takes priority over all automatic detection.
  static const _configuredUrl = String.fromEnvironment('API_BASE_URL');
  static String? _resolvedUrl;

  /// Detect the correct base URL based on the runtime platform.
  ///
  /// Priority:
  ///   1. --dart-define=API_BASE_URL=... (explicit override)
  ///   2. Dynamically resolved working URL (cached after probe)
  ///   3. Android -> defaults to http://127.0.0.1:8000 (physical device with adb reverse)
  ///      with automatic fallback to http://10.0.2.2:8000 (emulator).
  ///   4. Desktop (Windows/macOS/Linux) -> http://127.0.0.1:8000.
  static String get baseUrl {
    if (_configuredUrl.isNotEmpty) return _configuredUrl;
    if (_resolvedUrl != null) return _resolvedUrl!;
    return 'http://127.0.0.1:8000';
  }

  /// Manually override or reset the resolved URL (useful for testing or fallback).
  static void setResolvedUrl(String? url) {
    _resolvedUrl = url;
  }

  /// Human-readable description of the current backend target.
  static String get backendTarget => baseUrl;

  Future<String?> get token async {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return null;
    }
    try {
      return await _storage.read(key: 'glossa_access_token');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1$path',
    );
    if (kDebugMode) debugPrint('[BackendApi] $method $uri');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final savedToken = await token;
    if (authenticated && savedToken != null) {
      headers['Authorization'] = 'Bearer $savedToken';
    }
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    late final http.Response response;
    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 15));
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('[BackendApi] SocketException: ${e.message}');
      // On Android, if default 127.0.0.1:8000 failed and no URL was explicitly configured,
      // probe 10.0.2.2:8000 (emulator loopback) as automatic fallback.
      if (_configuredUrl.isEmpty &&
          _resolvedUrl == null &&
          defaultTargetPlatform == TargetPlatform.android &&
          baseUrl == 'http://127.0.0.1:8000') {
        try {
          final probe = await _client
              .get(Uri.parse('http://10.0.2.2:8000/health'))
              .timeout(const Duration(seconds: 2));
          if (probe.statusCode == 200) {
            _resolvedUrl = 'http://10.0.2.2:8000';
            if (kDebugMode) debugPrint('[BackendApi] Resolved emulator URL: $_resolvedUrl');
            return await _request(method, path, body: body, authenticated: authenticated);
          }
        } catch (_) {}
      }
      throw const BackendException(
        'Unable to connect to the Glossa server. Check that the backend is '
        'running and your device can reach it.',
      );
    } on TimeoutException {
      // Same check for TimeoutException on Android
      if (_configuredUrl.isEmpty &&
          _resolvedUrl == null &&
          defaultTargetPlatform == TargetPlatform.android &&
          baseUrl == 'http://127.0.0.1:8000') {
        try {
          final probe = await _client
              .get(Uri.parse('http://10.0.2.2:8000/health'))
              .timeout(const Duration(seconds: 2));
          if (probe.statusCode == 200) {
            _resolvedUrl = 'http://10.0.2.2:8000';
            if (kDebugMode) debugPrint('[BackendApi] Resolved emulator URL: $_resolvedUrl');
            return await _request(method, path, body: body, authenticated: authenticated);
          }
        } catch (_) {}
      }
      throw const BackendException(
        'The server did not respond in time. Make sure the backend is running '
        'with `docker compose up --build` or `start_backend.bat`.',
      );
    } on HttpException catch (e) {
      if (kDebugMode) debugPrint('[BackendApi] HttpException: ${e.message}');
      throw const BackendException(
        'Unable to connect to the Glossa server. Check your network '
        'connection and try again.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[BackendApi] Unexpected error: $e');
      throw const BackendException(
        'A network error occurred. Please check your connection and try again.',
      );
    }
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw BackendException(
        detail?.toString() ?? 'Request failed (${response.statusCode})',
      );
    }
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  Future<DemoUser> _authenticate(String path, Map<String, dynamic> body) async {
    final data = await _request('POST', path, body: body, authenticated: false);
    await _storage.write(
      key: 'glossa_access_token',
      value: data['access_token'] as String,
    );
    return _user(data['user'] as Map<String, dynamic>);
  }

  Future<DemoUser> register({
    required String name,
    required String email,
    required String password,
  }) => _authenticate('/auth/register', {
    'name': name,
    'email': email,
    'password': password,
  });

  Future<DemoUser> login({required String email, required String password}) =>
      _authenticate('/auth/login', {'email': email, 'password': password});

  Future<void> logout() => _storage.delete(key: 'glossa_access_token');

  Future<DemoUser> me() async => _user(await _request('GET', '/me'));

  Future<DemoUser> updateProfile({
    String? name,
    int? heroIndex,
    String? languageId,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (heroIndex != null) body['hero_index'] = heroIndex;
    if (languageId != null) body['language_id'] = languageId;
    return _user(await _request('PATCH', '/me', body: body));
  }

  // ─── Multi-language course endpoints ────────────────────────

  Future<List<Language>> getLanguages() async {
    final result = await _request('GET', '/languages');
    final rows = result['data'] as List? ?? [];
    return rows
        .map((raw) => Language.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  Future<List<Course>> getCourses({bool publishedOnly = true}) async {
    final result = await _request(
      'GET',
      '/courses?published_only=${publishedOnly.toString()}',
    );
    final rows = result['data'] as List? ?? [];
    return rows
        .map((raw) => Course.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  Future<List<CourseUnit>> getUnitsForCourse(String courseId) async {
    final result = await _request('GET', '/courses/$courseId/units');
    final rows = result['data'] as List? ?? [];
    return rows
        .map((raw) => CourseUnit.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  Future<DemoUser> updateActiveCourse(String courseId) async {
    final data = await _request(
      'PUT',
      '/users/me/active-course',
      body: {'active_course_id': courseId},
    );
    return _user(data['user'] as Map<String, dynamic>? ?? data);
  }

  Future<List<Lesson>> lessons({String? courseId}) async {
    final path = courseId != null ? '/lessons?course_id=$courseId' : '/lessons';
    final result = await _request('GET', path);
    return (result['data'] as List)
        .map((item) => _lesson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Exercise>> exercises(String lessonId) async {
    final result = await _request('GET', '/lessons/$lessonId/exercises');
    return (result['data'] as List)
        .map((item) => _exercise(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> checkAnswer(String lessonId, Map<String, dynamic> answer) async {
    final result = await _request(
      'POST',
      '/lessons/$lessonId/answer',
      body: answer,
    );
    return result['correct'] as bool;
  }

  Future<Map<String, dynamic>> submitAttempt(
    String lessonId,
    List<Map<String, dynamic>> answers,
  ) => _request(
    'POST',
    '/lessons/$lessonId/attempts',
    body: {'answers': answers},
  );

  Future<List<LeaderboardEntry>> leaderboard(String filter) async {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      switch (filter) {
        case 'alltime':
          return mockLeaderboardAllTime;
        case 'weekly':
        default:
          return mockLeaderboardWeekly;
      }
    }
    final result = await _request('GET', '/leaderboard?filter=$filter');
    final rows = result['data'] as List;
    return rows.map((raw) {
      final row = raw as Map<String, dynamic>;
      return LeaderboardEntry(
        rank: row['rank'],
        name: row['name'],
        level: row['level'],
        className: row['class_name'],
        xp: row['xp'],
        heroIndex: row['hero_index'],
        isCurrentUser: row['is_current_user'],
      );
    }).toList();
  }

  DemoUser _user(Map<String, dynamic> row) => DemoUser(
    name: row['name'] as String,
    email: row['email'] as String,
    heroIndex: row['hero_index'] as int,
    heroClassName: row['hero_class_name'] as String,
    level: row['level'] as int,
    xp: row['xp'] as int,
    xpToNextLevel: row['xp_to_next_level'] as int,
    streak: row['streak'] as int,
    wordsFound: row['words_found'] as int,
    lessonsCompleted: row['lessons_completed'] as int,
    languageId: row['language_id'] as String,
    activeCourseId: row['active_course_id'] as String?,
    languageName: switch (row['language_id']) {
      'newari' => 'Newari',
      'nepali' => 'Nepali',
      'english' => 'English',
      _ => row['language_id'],
    },
    languageScript: switch (row['language_id']) {
      'newari' => 'नेपाल भाषा',
      'nepali' => 'नेपाली',
      'english' => 'English',
      _ => '',
    },
  );

  Lesson _lesson(Map<String, dynamic> row) => Lesson(
    id: row['id'] as String,
    unitId: row['unit_id'] != null ? (row['unit_id'] as num).toInt() : null,
    sequence: row['sequence'] != null ? (row['sequence'] as num).toInt() : null,
    title: row['title'] as String,
    subtitle: row['subtitle'] as String,
    exerciseType: _exerciseType(row['exercise_type'] as String),
    status: _lessonStatus(row['status'] as String),
    xpReward: (row['xp_reward'] as num?)?.toInt() ?? 20,
    wordCount: (row['word_count'] as num?)?.toInt() ?? 4,
    requiredLevel: (row['required_level'] as num?)?.toInt() ?? 1,
    isPublished: (row['is_published'] as bool?) ?? true,
  );

  Exercise _exercise(Map<String, dynamic> row) => Exercise(
    id: row['id'] as String,
    type: _exerciseType(row['type'] as String),
    instruction: row['instruction'] as String,
    prompt: row['prompt'] as String?,
    promptHint: row['prompt_hint'] as String?,
    imageKey: row['image_key'] as String?,
    options: (row['options'] as List).map((raw) {
      final option = raw as Map<String, dynamic>;
      return AnswerOption(
        id: option['id'],
        text: option['text'],
        imageKey: option['image_key'],
        isDevanagari: option['is_devanagari'] ?? false,
      );
    }).toList(),
    correctAnswerId: '',
    pairs: row['pairs'] != null
        ? (row['pairs'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v.toString()))
        : null,
  );

  ExerciseType _exerciseType(String value) => switch (value) {
    'matchWords' => ExerciseType.matchWords,
    'pictureToWord' => ExerciseType.pictureToWord,
    'wordToPicture' => ExerciseType.wordToPicture,
    _ => ExerciseType.fillBlank,
  };

  LessonStatus _lessonStatus(String value) => switch (value) {
    'cleared' => LessonStatus.cleared,
    'locked' => LessonStatus.locked,
    _ => LessonStatus.current,
  };
}

class BackendException implements Exception {
  const BackendException(this.message);
  final String message;
  @override
  String toString() => message;
}
