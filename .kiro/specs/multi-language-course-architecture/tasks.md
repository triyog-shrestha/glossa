# Implementation Plan: Multi-Language Course Architecture

## Overview

This plan transforms Glossa from a single-direction learner into a multi-language course platform. The implementation order is strictly: database schema changes, Alembic migration, backend models and API, Flutter models, state management, UI components, then tests. All test tasks are **mandatory** unless explicitly noted otherwise. No test tasks may be skipped.

Key constraints applied throughout:
- Cascade deletes on lessons and exercises are NOT used in production paths. Lessons and exercises are protected from accidental deletion.
- Unknown legacy language_id values are NOT defaulted to new_en. They are set to NULL with a logged warning.
- Migration validation runs on a disposable Docker database before touching any persistent data.
- A mandatory data preservation checkpoint must pass before Flutter implementation begins.
- The 7 existing lessons are assigned to the legacy unit as an unverified temporary placeholder only.

## Tasks

- [ ] 1. Create database models for new tables
  - [ ] 1.1 Create Language SQLAlchemy model
    - Define Language model with fields: id (String PK), name_english, name_native, script, is_active (Boolean default True)
    - Add relationships to Course for source and target directions using explicit foreign_keys
    - _Requirements: 1.1, 13.2_

  - [ ] 1.2 Create Course SQLAlchemy model
    - Define Course model with fields: id (String PK), source_language_id (FK to languages.id), target_language_id (FK to languages.id), name, description (nullable), is_published (Boolean default False), created_at
    - Add relationships to Language (source and target) and to Unit
    - Add UniqueConstraint on (source_language_id, target_language_id)
    - Do NOT add ondelete=CASCADE on the course foreign key from Unit; deletion is administrative only
    - _Requirements: 1.2, 1.4, 40.1_

  - [ ] 1.3 Create Unit SQLAlchemy model
    - Define Unit model with fields: id (Integer PK auto-increment), course_id (FK to courses.id, indexed), sequence (Integer), title, description (nullable)
    - Add relationship to Course and to Lesson
    - Add UniqueConstraint on (course_id, sequence)
    - Do NOT add ondelete=CASCADE on the unit foreign key from Lesson; lessons are protected
    - _Requirements: 1.3, 1.5, 1.6, 39.1_

  - [ ] 1.4 Update Lesson SQLAlchemy model
    - Add unit_id (Integer, ForeignKey to units.id, nullable=True initially, indexed)
    - Add sequence (Integer, nullable=True initially)
    - Add is_published (Boolean, default False)
    - Add relationship to Unit
    - Add UniqueConstraint on (unit_id, sequence)
    - Preserve all existing fields and relationships
    - Confirm that no CASCADE DELETE is set on this foreign key
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.7_

  - [ ] 1.5 Update User SQLAlchemy model
    - Add active_course_id (String, nullable ForeignKey to courses.id, indexed)
    - Add relationship to Course
    - Preserve existing language_id field unchanged
    - Preserve all existing fields
    - _Requirements: 3.1, 3.2, 3.3, 38.1_

- [ ] 2. Create Alembic migration script
  - [ ] 2.1 Generate migration file
    - Run: alembic revision -m 'multi_language_courses'
    - File must be created at backend/migrations/versions/0003_multi_language_courses.py
    - _Requirements: 4.1_

  - [ ] 2.2 Implement upgrade() function
    - Record pre-migration counts: lessons, exercises, attempts, users (store in local variables)
    - Log 'Creating languages table'
    - Create languages table with all columns and constraints
    - Log 'Creating courses table'
    - Create courses table with foreign keys and unique constraint on (source_language_id, target_language_id)
    - Log 'Creating units table'
    - Create units table with foreign key to courses (NO ondelete=CASCADE), unique constraint on (course_id, sequence), and index on course_id
    - Add unit_id (nullable integer FK to units, NO ondelete=CASCADE), sequence (nullable integer), is_published (boolean default false) columns to lessons
    - Add unique constraint on lessons (unit_id, sequence)
    - Add index on lessons.unit_id
    - Add active_course_id (nullable string FK to courses) to users
    - Add index on users.active_course_id
    - Insert three language records: en, ne, new with correct names and scripts
    - Insert six course records (new_en, new_ne, en_new, en_ne, ne_new, ne_en) all with is_published=false
    - Log 'Creating legacy unit for existing lessons'
    - Insert legacy unit into new_en course with title 'Legacy Content - Unverified' and sequence=1
    - Log 'Migrating N existing lessons to legacy unit' with actual count
    - Assign all existing lessons to legacy unit with incrementing sequence values based on PK order
    - Set is_published=false for all existing lessons
    - Log note that new_en assignment is a TEMPORARY UNVERIFIED placeholder
    - Log 'Backfilling active_course_id for N users' with count
    - For users with language_id='newari' set active_course_id='new_en'
    - For users with language_id='nepali' set active_course_id='ne_en'
    - For users with language_id='english' set active_course_id='en_ne'
    - For users with any other language_id: set active_course_id=NULL and log warning with user id and language_id value
    - Do NOT default unknown language_id values to new_en
    - Apply NOT NULL constraint on lessons.unit_id only after confirming all rows have been assigned
    - Apply NOT NULL constraint on lessons.sequence only after confirming all rows have been assigned
    - Validate post-migration counts match pre-migration counts; raise error and roll back if any differ
    - Validate no recognised-language user has NULL active_course_id; raise error and roll back if found
    - Log 'Migration 0003 completed successfully - all integrity checks passed'
    - _Requirements: 1.1-1.7, 2.1-2.7, 3.1-3.5, 4.1-4.5, 5.1-5.8, 6.1-6.6, 7.1-7.5, 11.1-11.6, 12.1-12.7_

  - [ ] 2.3 Implement downgrade() function
    - Drop index on users.active_course_id
    - Drop column users.active_course_id
    - Drop unique constraint on lessons (unit_id, sequence)
    - Drop index on lessons.unit_id
    - Drop columns from lessons: unit_id, sequence, is_published
    - Drop units table (foreign key from lessons dropped above first)
    - Drop courses table
    - Drop languages table
    - Verify user, lesson, exercise, and attempt records are intact after downgrade
    - _Requirements: 8.1, 8.2, 8.3_

  - [ ] 2.4 Write migration validation script
    - Create a standalone script: backend/scripts/validate_migration.py
    - Script connects to a specified DATABASE_URL (never hardcoded to production)
    - Takes a pre-migration snapshot: count users, lessons, exercises, attempts; record each user's xp, streak, lessons_completed
    - Runs alembic upgrade head
    - Compares post-migration counts; exits with code 1 and prints discrepancy if any count decreased
    - Compares each user's xp, streak, lessons_completed; exits with code 1 if any value changed
    - Verifies every lesson has a non-null unit_id and sequence
    - Verifies every recognised-language user has a non-null active_course_id
    - Prints 'All validation checks passed' and exits with code 0 on success
    - This script is mandatory; it MUST pass before any further tasks are executed
    - _Requirements: 9.1-9.5, 10.1-10.7, 11.1-11.6_

- [ ] 3. MANDATORY CHECKPOINT - Migration safety verification
  - Run validate_migration.py against a fresh Docker Postgres container (not production)
  - Confirm script exits with code 0
  - Confirm lesson count, exercise count, attempt count, and user count all match pre-migration snapshot
  - Confirm every user's XP, streak, and lessons_completed are unchanged
  - Confirm zero lessons have NULL unit_id or NULL sequence
  - Confirm all recognised-language users have a non-null active_course_id
  - Confirm NULL active_course_id users have warnings in the migration log
  - Review migration log for the 'TEMPORARY UNVERIFIED' notice about legacy lesson assignment
  - Run downgrade() on the same disposable database and confirm all original tables are restored
  - DO NOT proceed to task 4 until all checks above pass
  - _Requirements: 9.1-9.5, 10.1-10.7_

- [ ] 4. Create Pydantic schemas
  - [ ] 4.1 Create LanguageOut schema
    - Fields: id, name_english, name_native, script, is_active
    - Configure model_config = ConfigDict(from_attributes=True)
    - _Requirements: 13.2_

  - [ ] 4.2 Create CourseOut schema
    - Fields: id, source_language_id, target_language_id, name, description, is_published
    - Include nested source_language: LanguageOut and target_language: LanguageOut
    - Configure from_attributes=True
    - _Requirements: 14.4, 14.6_

  - [ ] 4.3 Create CourseUpdate schema
    - Single field: active_course_id (str, min_length=1)
    - _Requirements: 18.2_

  - [ ] 4.4 Create UnitOut schema
    - Fields: id, course_id, sequence, title, description, total_lessons (int), cleared_lessons (int)
    - Configure from_attributes=True
    - _Requirements: 15.3, 15.4_

  - [ ] 4.5 Update LessonOut schema
    - Add unit_id (int), sequence (int), is_published (bool) fields
    - Preserve all existing fields
    - Ensure status field (str) is present
    - _Requirements: 2.1-2.3, 17.5_

- [ ] 5. Implement backend API endpoints
  - [ ] 5.1 Create GET /api/v1/languages
    - Query languages with is_active=True
    - Return List[LanguageOut]
    - Require authentication
    - _Requirements: 13.1-13.4_

  - [ ] 5.2 Create GET /api/v1/courses
    - Accept published_only: bool = True query param
    - Filter courses by is_published when published_only=True
    - Eagerly load source_language and target_language
    - Return List[CourseOut]
    - Require authentication
    - _Requirements: 14.1-14.6_

  - [ ] 5.3 Create GET /api/v1/courses/{course_id}/units
    - Return 404 with 'Course not found' if course_id not found
    - Query units for course ordered by sequence
    - Calculate total_lessons per unit using COUNT of is_published=True lessons
    - Calculate cleared_lessons per unit by counting attempts for the authenticated user on lessons in that unit
    - Return List[UnitOut]
    - Require authentication
    - _Requirements: 15.1-15.6_

  - [ ] 5.4 Update GET /api/v1/lessons
    - Add optional course_id query param
    - Use user.active_course_id when course_id not provided
    - Return 400 with 'No active course selected' when both are unset
    - Filter to is_published=True lessons only
    - Order by unit.sequence then lesson.sequence
    - Call calculate_lesson_statuses() and attach status to each lesson
    - Require authentication
    - _Requirements: 16.1-16.6, 17.1-17.6_

  - [ ] 5.5 Create PUT /api/v1/users/me/active-course
    - Accept CourseUpdate body
    - Return 404 with 'Course not found' if course not found
    - Return 403 with 'Course is not available yet' if course is not published
    - Update user.active_course_id in database
    - Return updated user profile
    - Require authentication
    - Only update the authenticated user's own record
    - _Requirements: 18.1-18.6, 29.3_

  - [ ] 5.6 Write unit tests for all new API endpoints
    - Test GET /api/v1/languages returns only is_active=True languages
    - Test GET /api/v1/courses with published_only=True returns only published
    - Test GET /api/v1/courses with published_only=False returns all
    - Test course response includes nested language objects
    - Test GET /api/v1/courses/{id}/units returns units with correct total_lessons and cleared_lessons
    - Test GET /api/v1/courses/{id}/units returns 404 for unknown course_id
    - Test PUT /api/v1/users/me/active-course updates user and returns profile
    - Test PUT returns 403 for unpublished course
    - Test PUT returns 404 for non-existent course
    - Test GET /api/v1/lessons returns 400 when no course is set
    - Test GET /api/v1/lessons filters by provided course_id
    - Test GET /api/v1/lessons uses active_course_id when course_id not provided
    - _Requirements: 13.1-13.4, 14.1-14.6, 15.1-15.6, 18.1-18.6_

- [ ] 6. Implement lesson status calculation
  - [ ] 6.1 Create calculate_lesson_statuses() function
    - Accept user_id (int) and course_id (str) as parameters
    - Query all published lessons for course ordered by unit.sequence, lesson.sequence (JOIN units WHERE units.course_id = course_id AND lessons.is_published = True)
    - Query cleared lesson IDs: lesson IDs from attempts WHERE attempts.user_id = user_id AND lesson is in that course
    - Iterate lessons: mark 'cleared' if in cleared set, mark first non-cleared as 'current', mark rest as 'locked'
    - When all lessons are cleared, mark the last lesson as 'current'
    - Return dict mapping lesson_id to status string
    - _Requirements: 17.1-17.6_

  - [ ] 6.2 Write property test: Status Progression Invariant
    - Property: for any course and user, if a lesson has status 'current' then all lessons before it in sequence have status 'cleared' and all after have status 'locked'
    - Use Hypothesis to generate random lesson sequences and attempt subsets
    - Verify the property holds across all generated inputs
    - This test is mandatory
    - _Requirements: 17.1-17.6_

  - [ ] 6.3 Write unit tests for status edge cases
    - Test: user has cleared no lessons - first is 'current', rest are 'locked'
    - Test: user has cleared all lessons - last is 'current'
    - Test: user has cleared some lessons - correct 'current' assignment
    - Test: lessons span multiple units - ordering respects unit.sequence first
    - This test is mandatory
    - _Requirements: 17.1-17.6_

- [ ] 7. Implement course progress isolation
  - [ ] 7.1 Update lesson and attempt queries to scope by course
    - Modify all lesson queries to JOIN units and filter by unit.course_id
    - Modify cleared lesson calculation to only count attempts for lessons in the specified course
    - Verify that no cross-course contamination is possible in the query path
    - _Requirements: 19.1-19.3_

  - [ ] 7.2 Write property test: Progress Isolation
    - Property: for any two distinct courses C1 and C2, completing lessons in C1 does not change lesson statuses in C2
    - Generate random attempts for C1 lessons
    - Calculate statuses for C2
    - Verify C2 statuses are independent of C1 attempt data
    - This test is mandatory
    - _Requirements: 19.1-19.2_

  - [ ] 7.3 Write property test: Progress Preservation Across Switches
    - Property: for any user switching C1 to C2 and back to C1, cleared lesson set in C1 is identical before and after switching
    - Simulate switch via active_course_id update
    - Re-query C1 lesson statuses after switch back
    - Verify cleared set is unchanged
    - This test is mandatory
    - _Requirements: 19.3_

- [ ] 8. MANDATORY CHECKPOINT - Backend tests and API verification
  - Run all backend unit tests: pytest backend/tests/ - all must pass
  - Run all property tests: pytest backend/tests/properties/ - all must pass
  - Manually test all five API endpoints with curl or Postman against the Docker backend
  - Verify lesson filtering returns only lessons from the active course
  - Verify clearing a lesson in course A does not affect course B lesson statuses
  - Verify 403 is returned when attempting to select an unpublished course
  - Verify 400 is returned when no active course is set
  - DO NOT proceed to Flutter tasks until all checks above pass
  - _Requirements: 13.1-22.3_


- [ ] 9. Create Flutter data models
  - [ ] 9.1 Create Language Dart model
    - Define Language class with final fields: id, nameEnglish, nameNative, script, isActive
    - Implement Language.fromJson factory mapping snake_case to camelCase
    - _Requirements: 30.1, 30.2_

  - [ ] 9.2 Create Course Dart model
    - Define Course class with final fields: id, sourceLanguageId, targetLanguageId, name, description (nullable), isPublished, sourceLanguage (Language), targetLanguage (Language)
    - Implement Course.fromJson parsing nested sourceLanguage and targetLanguage objects
    - _Requirements: 31.1, 31.2_

  - [ ] 9.3 Create Unit Dart model
    - Define Unit class with final fields: id, courseId, sequence, title, description (nullable), totalLessons, clearedLessons
    - Implement Unit.fromJson
    - Add progress getter: returns clearedLessons / totalLessons; returns 0.0 when totalLessons == 0
    - _Requirements: 32.1-32.4_

  - [ ] 9.4 Update Lesson Dart model
    - Add final fields: unitId (int), sequence (int), isPublished (bool)
    - Update Lesson.fromJson to parse the three new fields
    - Preserve all existing Lesson fields and their parsing logic
    - _Requirements: 33.1-33.3_

  - [ ] 9.5 Write unit tests for Flutter model JSON parsing
    - Test Language.fromJson maps all fields correctly
    - Test Course.fromJson parses nested Language objects
    - Test Unit.fromJson parses all fields
    - Test Unit.progress returns 0.0 when totalLessons is 0
    - Test Unit.progress returns 1.0 when clearedLessons == totalLessons
    - Test Lesson.fromJson includes new unitId, sequence, isPublished fields
    - Test Lesson.fromJson preserves all previously existing fields
    - This test is mandatory
    - _Requirements: 30.1-33.3_

- [ ] 10. Update GameState and DemoUser
  - [ ] 10.1 Update DemoUser model
    - Add activeCourseId (String?, nullable) field
    - Update DemoUser.fromJson to parse active_course_id from API response
    - Preserve all existing DemoUser fields
    - _Requirements: 34.1_

  - [ ] 10.2 Extend GameState
    - Add activeCourseId (String?, nullable) field
    - Add languages (List<Language>, default const []) field
    - Add courses (List<Course>, default const []) field
    - Add units (List<Unit>, default const []) field
    - Update copyWith to support all four new fields using the standard nullable-override pattern
    - Preserve all existing GameState fields and defaults
    - _Requirements: 34.1-34.5_

- [ ] 11. Update BackendApi service
  - [ ] 11.1 Add getLanguages()
    - GET /api/v1/languages with auth header
    - Return List<Language>
    - Throw typed exception on non-200 response
    - _Requirements: 35.1_

  - [ ] 11.2 Add getCourses()
    - GET /api/v1/courses?published_only=true|false with auth header
    - Accept publishedOnly (bool, default true) parameter
    - Return List<Course>
    - Throw typed exception on non-200 response
    - _Requirements: 35.1_

  - [ ] 11.3 Add getUnitsForCourse(String courseId)
    - GET /api/v1/courses/{courseId}/units with auth header
    - Return List<Unit>
    - Throw 404 exception when course not found
    - _Requirements: 35.2_

  - [ ] 11.4 Add updateActiveCourse(String courseId)
    - PUT /api/v1/users/me/active-course with JSON body {active_course_id: courseId}
    - Return updated DemoUser
    - Throw 403 exception with message 'Course is not available yet' on 403 response
    - Throw 404 exception on 404 response
    - _Requirements: 36.2_

  - [ ] 11.5 Update getLessons()
    - Add optional courseId (String?) parameter
    - Append ?course_id=courseId to URL when provided
    - Throw descriptive exception on 400 response (no active course set)
    - Preserve all existing getLessons behaviour
    - _Requirements: 35.2_

- [ ] 12. Update GameStateNotifier
  - [ ] 12.1 Add loadLanguagesAndCourses()
    - Call api.getLanguages() and api.getCourses(publishedOnly: true)
    - Update state with languages and courses lists
    - On error: set errorMessage in state; do not crash
    - _Requirements: 35.1_

  - [ ] 12.2 Add loadUnitsForActiveCourse()
    - Guard: if activeCourseId is null, skip loading and do nothing
    - Call api.getUnitsForCourse(activeCourseId)
    - Update state.units
    - On error: set errorMessage
    - _Requirements: 35.2_

  - [ ] 12.3 Implement switchCourse(String courseId)
    - Save previous course id as a local variable before any state changes
    - Set state.isLoading = true
    - Call api.updateActiveCourse(courseId)
    - On 403 response: set state.isLoading = false, set errorMessage = 'This course is not available yet', restore activeCourseId to previous value
    - On any other error: set state.isLoading = false, set errorMessage, restore activeCourseId
    - On success: update state.user, state.activeCourseId, then call api.getUnitsForCourse(courseId) and api.getLessons(courseId: courseId)
    - Update state.units and state.lessons
    - Set state.isLoading = false
    - _Requirements: 36.1-36.5_

  - [ ] 12.4 Update signIn() to trigger course loading
    - After successful sign-in, call loadLanguagesAndCourses()
    - After successful sign-in, call loadUnitsForActiveCourse()
    - When user has no activeCourseId after sign-in, navigate to course switcher screen instead of Town
    - Preserve all existing signIn logic
    - _Requirements: 35.1-35.3_

  - [ ] 12.5 Write unit tests for GameStateNotifier course methods
    - Test loadLanguagesAndCourses updates state.languages and state.courses
    - Test loadUnitsForActiveCourse skips loading when activeCourseId is null
    - Test loadUnitsForActiveCourse updates state.units when activeCourseId is set
    - Test switchCourse success path updates activeCourseId, units, and lessons
    - Test switchCourse 403 response preserves previous activeCourseId and sets errorMessage
    - Test switchCourse network error preserves previous activeCourseId
    - Test signIn with null activeCourseId navigates to course switcher
    - Mock BackendApi using a test double
    - This test is mandatory
    - _Requirements: 35.1-36.5_

- [ ] 13. MANDATORY CHECKPOINT - State management verification
  - Review GameStateNotifier for all error paths: confirm previous state is always restored on failure
  - Confirm that switchCourse never leaves activeCourseId in an inconsistent state
  - Confirm that null activeCourseId is handled safely at every call site
  - Run all unit tests: flutter test test/unit/ - all must pass
  - DO NOT proceed to UI tasks until all checks pass
  - _Requirements: 34.1-36.5_

- [ ] 14. Create CourseSwitcher UI widget
  - [ ] 14.1 Create CourseSwitcher StatelessWidget
    - Create lib/widgets/course_switcher.dart
    - Accept courses (List<Course>) and onCourseSelected (void Function(String)) as constructor parameters
    - Scaffold with AppBar titled 'Select Course'
    - _Requirements: 23.1_

  - [ ] 14.2 Implement course card list rendering
    - Render a ListView of course cards
    - Display each course as '{course.sourceLanguage.nameEnglish} to {course.targetLanguage.nameEnglish}'
    - Show green 'Available' badge when course.isPublished == true
    - Show grey 'Coming Soon' badge when course.isPublished == false
    - Disable onTap entirely for unpublished cards (do not register a GestureDetector tap handler)
    - When courses list is empty OR all courses are unpublished, display a centred 'No courses available yet' empty-state message
    - _Requirements: 23.2-23.7_

  - [ ] 14.3 Implement course selection and loading feedback
    - On tap of published card call onCourseSelected(course.id)
    - Show CircularProgressIndicator on the selected card while switchCourse is in progress
    - On switchCourse success navigate to Town screen (replace current route)
    - On switchCourse failure show error SnackBar and restore card to unloaded state
    - _Requirements: 24.1-24.4_

  - [ ] 14.4 Write widget tests for CourseSwitcher
    - Test: widget renders correct number of course cards
    - Test: published card shows 'Available' badge
    - Test: unpublished card shows 'Coming Soon' badge
    - Test: tapping published card invokes onCourseSelected callback
    - Test: tapping unpublished card does not invoke callback
    - Test: empty course list shows 'No courses available yet' message
    - Test: all-unpublished list shows 'No courses available yet' message
    - This test is mandatory
    - _Requirements: 23.1-24.4_

- [ ] 15. Add course switcher navigation
  - [ ] 15.1 Register named route '/course-switcher'
    - Add route in MaterialApp routes or GoRouter equivalent
    - Route builds CourseSwitcher passing GameState.courses (all courses, including unpublished)
    - _Requirements: 25.1, 25.2_

  - [ ] 15.2 Add navigation entry point from Town screen and/or Profile screen
    - Add an IconButton or labelled TextButton visible on the Town screen AppBar or Profile screen
    - On tap navigate to '/course-switcher'
    - Load all courses (published_only=false) before showing switcher so coming-soon courses are visible
    - _Requirements: 25.1, 25.3_

- [ ] 16. Update Town screen for dynamic units
  - [ ] 16.1 Remove hardcoded unit header
    - Delete the hardcoded 'World 1: Home and Food' header widget
    - Replace with a call to buildUnitSections(state.units, state.lessons)
    - _Requirements: 26.1_

  - [ ] 16.2 Implement buildUnitSections()
    - For each unit in units (ordered by unit.sequence), create a unit header widget showing unit.title
    - Under each header, render only lessons where lesson.unitId == unit.id, ordered by lesson.sequence
    - Skip units that have zero rendered lessons (all lessons unpublished or list is empty)
    - Preserve existing lesson card styling and animations unchanged
    - _Requirements: 26.2-26.5_

  - [ ] 16.3 Add unit progress indicator to each unit header
    - Display a LinearProgressIndicator using unit.progress value
    - Show text '{unit.clearedLessons}/{unit.totalLessons}' beside the bar
    - When unit.totalLessons == 0 display 0% without dividing by zero
    - Apply a visual distinction (e.g. colour change) for units where progress == 1.0
    - _Requirements: 27.1-27.5_

  - [ ] 16.4 Handle empty course state in Town screen
    - When state.units is empty or no published lessons exist, show empty-state message rather than blank screen
    - _Requirements: 28.3_

  - [ ] 16.5 Write widget tests for Town screen
    - Test: renders unit headers from state.units in sequence order
    - Test: groups lessons under correct unit headers
    - Test: renders progress bar on each unit header
    - Test: skips unit header when unit has no published lessons
    - Test: shows empty-state message when units list is empty
    - Test: does not crash when units list is empty
    - This test is mandatory
    - _Requirements: 26.1-28.3_

- [ ] 17. Implement error handling and UI feedback
  - [ ] 17.1 Add error SnackBars for course operations
    - Show SnackBar on course loading failure
    - Show SnackBar on course switching failure
    - Display 'This course is not available yet' on 403 response
    - Display 'Resource not found' on 404 response
    - Display generic message for other errors
    - _Requirements: 37.1-37.4_

  - [ ] 17.2 Add retry action to error SnackBars
    - SnackBar action label 'Retry' re-invokes the failed operation
    - _Requirements: 37.5_

  - [ ] 17.3 Add loading state management
    - Show CircularProgressIndicator in Town screen while units or lessons are loading
    - Disable course switcher interactions while state.isLoading is true
    - Ensure isLoading is cleared on both success and error paths
    - _Requirements: 36.3, 37.4_

- [ ] 18. Filter unpublished lessons in Town screen
  - [ ] 18.1 Enforce published-only lesson display
    - In buildUnitSections filter lesson list to is_published == true before rendering
    - After filtering, skip the unit header entirely if the filtered lesson list is empty
    - Confirm no crash occurs when all lessons in a unit are unpublished
    - _Requirements: 28.1-28.3_

- [ ] 19. MANDATORY CHECKPOINT - Manual integration test
  - Run the Flutter app in debug mode against the Docker backend
  - Sign in with an existing user account
  - Verify Town screen shows no lessons (all legacy content is unpublished)
  - Verify Town screen shows appropriate empty-state message
  - Navigate to course switcher
  - Verify all 6 courses are shown with correct Available / Coming Soon badges
  - Verify tapping a Coming Soon card does nothing
  - Verify no crash when activeCourseId is NULL after login
  - Sign in as a user with an unrecognised language_id and confirm course switcher prompt is shown
  - DO NOT proceed to integration tests until all manual checks pass
  - _Requirements: 23.1-28.3_

- [ ] 20. Write backend integration tests
  - [ ] 20.1 Write migration integration test
    - Use a fresh Docker Postgres container as the test database
    - Seed the database with representative data: at least 3 users (one per language_id), 7 lessons with exercises, and attempts
    - Record pre-migration counts: users, lessons, exercises, attempts
    - Run alembic upgrade head
    - Assert languages table has exactly 3 rows
    - Assert courses table has exactly 6 rows all with is_published=False
    - Assert units table has exactly 1 row (the legacy unit)
    - Assert every lesson has a non-null unit_id and sequence
    - Assert lesson count matches pre-migration count
    - Assert exercise count matches pre-migration count
    - Assert attempt count matches pre-migration count
    - Assert every recognised-language user has a non-null active_course_id
    - Run alembic downgrade -1
    - Assert languages, courses, units tables no longer exist
    - Assert user, lesson, exercise, attempt records still exist with original counts
    - This test is mandatory
    - _Requirements: 4.1-5.8, 6.1-6.6, 7.1-7.5, 8.1-8.5, 9.1-9.5, 10.1-10.7, 11.1-11.6_

  - [ ] 20.2 Write API integration test: course selection flow
    - Create test user and authenticate
    - Call GET /api/v1/courses - assert response is a list (may be empty since all unpublished)
    - Call GET /api/v1/courses?published_only=false - assert 6 courses returned
    - Call PUT /api/v1/users/me/active-course with an unpublished course_id - assert 403
    - Publish one course directly in the test database
    - Call PUT /api/v1/users/me/active-course with the published course_id - assert 200 and updated user
    - Call GET /api/v1/courses/{id}/units - assert units returned
    - Call GET /api/v1/lessons - assert lessons list returned (may be empty; no crash)
    - This test is mandatory
    - _Requirements: 13.1-18.6, 21.1-21.5_

  - [ ] 20.3 Write API integration test: course switching preserves progress
    - Publish two courses in the test database
    - Create units and published lessons in each course
    - Create attempt records for the user in course A
    - Record lesson statuses for course A
    - Switch user to course B via PUT /api/v1/users/me/active-course
    - Create attempt records in course B
    - Switch user back to course A
    - Assert lesson statuses for course A are identical to recorded values
    - Assert course B statuses reflect only course B attempts
    - This test is mandatory
    - _Requirements: 19.1-19.3, 41.1-41.4_

  - [ ] 20.4 Write API integration test: authorization boundaries
    - Create two test users (user A and user B)
    - User A clears lessons in course X
    - User B queries GET /api/v1/courses/{id}/units - assert cleared_lessons reflects user B's progress only
    - Attempt PUT /api/v1/users/me/active-course for user A while authenticated as user B - assert 403 or 404
    - Assert user A's attempts are not visible in user B's responses
    - This test is mandatory
    - _Requirements: 29.1-29.4_

- [ ] 21. Write Flutter integration tests
  - [ ] 21.1 Write integration test: course switching flow
    - Use integration_test package with a test backend or mocked API
    - Launch app and sign in
    - Confirm Town screen shows empty-state (no published courses or lessons yet)
    - Navigate to course switcher
    - Confirm all 6 courses are visible with Coming Soon badges
    - Confirm tapping a Coming Soon card does not invoke navigation
    - Publish a course in the test backend
    - Reload course switcher
    - Tap the now-Available course card
    - Confirm navigation to Town screen
    - Confirm Town screen displays units from the selected course
    - This test is mandatory
    - _Requirements: 23.1-26.5_

  - [ ] 21.2 Write integration test: progress preservation across switches
    - Sign in as user with cleared lessons in course A (requires test backend setup)
    - Record cleared lesson IDs for course A
    - Switch to course B via course switcher
    - Confirm Town screen shows course B content
    - Switch back to course A
    - Confirm cleared lesson indicators in Town screen match the recorded set
    - This test is mandatory
    - _Requirements: 19.1-19.3_

  - [ ] 21.3 Write integration test: global XP preserved across switches
    - Record user XP and streak displayed in UI before switching course
    - Switch to a different course
    - Confirm XP and streak displayed values are unchanged
    - This test is mandatory
    - _Requirements: 20.1-20.5_

  - [ ] 21.4 Write integration test: null active_course_id login flow
    - Create test user with no active_course_id set
    - Sign in
    - Confirm app navigates to course switcher screen, not Town screen
    - Confirm no crash or blank screen occurs
    - This test is mandatory
    - _Requirements: 35.3_

- [ ] 22. MANDATORY FINAL CHECKPOINT - Full test suite and verification
  - Run all backend unit tests: pytest backend/tests/ - all must pass
  - Run all backend property tests: pytest backend/tests/properties/ - all must pass
  - Run all backend integration tests: pytest backend/tests/integration/ - all must pass
  - Run all Flutter unit tests: flutter test test/unit/ - all must pass
  - Run all Flutter widget tests: flutter test test/widget/ - all must pass
  - Run all Flutter integration tests: flutter test integration_test/ - all must pass
  - Re-run validate_migration.py against a clean Docker Postgres instance - must exit 0
  - Confirm zero lessons have been deleted from the database
  - Confirm zero exercises have been deleted
  - Confirm zero attempts have been deleted
  - Confirm all existing users retain their original XP, streak, and lessons_completed values
  - Confirm legacy unit exists with all 7 lessons assigned and is_published=false
  - Confirm no lesson in the legacy unit is marked as published
  - Review all code for hardcoded course IDs or language assumptions
  - Provide Phase 3 final report covering: modified files, migrations run, API endpoints added, test results, data preservation verification, and remaining unresolved items
  - DO NOT begin Phase 4 work
  - _Requirements: all_

## Notes

- ALL test tasks are mandatory. The * optional marker from the previous draft has been removed.
- No test may be skipped to accelerate delivery.
- Checkpoints at tasks 3, 8, 13, 19, and 22 are hard stops: implementation must not proceed past a checkpoint until every check listed in that checkpoint passes.
- Migration safety: validate_migration.py must always target a disposable Docker database, never a persistent or production database.
- Legacy content: the 7 existing lessons are in the legacy unit as an unverified temporary placeholder. Their teaching direction (Newari-to-English) is assumed from the user language_id but has NOT been confirmed by a native speaker.
- Cascade deletes: no ondelete=CASCADE is set on the lessons or exercises tables. Deletion of units or courses does not automatically delete lessons.
- Unknown language_id values: users with unrecognised language_id are set to active_course_id=NULL after migration, not defaulted to new_en.
- Phase 4 must NOT begin after Phase 3 completes. Await explicit instruction.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "1.4", "1.5"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "2.3"] },
    { "id": 3, "tasks": ["2.4"] },
    { "id": 4, "tasks": ["3"] },
    { "id": 5, "tasks": ["4.1", "4.2", "4.3", "4.4", "4.5"] },
    { "id": 6, "tasks": ["5.1", "5.2", "5.3", "5.4", "5.5"] },
    { "id": 7, "tasks": ["5.6", "6.1"] },
    { "id": 8, "tasks": ["6.2", "6.3", "7.1"] },
    { "id": 9, "tasks": ["7.2", "7.3"] },
    { "id": 10, "tasks": ["8"] },
    { "id": 11, "tasks": ["9.1", "9.2", "9.3", "9.4"] },
    { "id": 12, "tasks": ["9.5", "10.1", "10.2"] },
    { "id": 13, "tasks": ["11.1", "11.2", "11.3", "11.4", "11.5"] },
    { "id": 14, "tasks": ["12.1", "12.2", "12.3", "12.4"] },
    { "id": 15, "tasks": ["12.5"] },
    { "id": 16, "tasks": ["13"] },
    { "id": 17, "tasks": ["14.1", "14.2", "14.3"] },
    { "id": 18, "tasks": ["14.4", "15.1", "15.2"] },
    { "id": 19, "tasks": ["16.1", "16.2", "16.3", "16.4"] },
    { "id": 20, "tasks": ["17.1", "17.2", "17.3", "18.1"] },
    { "id": 21, "tasks": ["16.5"] },
    { "id": 22, "tasks": ["19"] },
    { "id": 23, "tasks": ["20.1", "20.2", "20.3", "20.4"] },
    { "id": 24, "tasks": ["21.1", "21.2", "21.3", "21.4"] },
    { "id": 25, "tasks": ["22"] }
  ]
}
```
