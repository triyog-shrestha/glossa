# Requirements Document

## Feature: Multi-Language Course Architecture

## Introduction

This document specifies the functional requirements for transforming the Glossa language learning app from a single-direction learner into a comprehensive multi-language course platform. The system supports three languages (English, Nepali, Newari) with six bidirectional learning courses, introduces unit-based lesson organisation, and preserves all existing user data including lessons, exercises, attempts, XP, streaks, and progress.

The requirements are derived from the approved design document and reflect the following mandatory constraints confirmed by the product owner:

- All database migration tests, data preservation tests, course isolation tests, and core Flutter integration tests are **mandatory** and cannot be skipped.
- Unknown legacy language selections are preserved as-is; users must explicitly choose a supported course. The system must handle a NULL or unset active_course_id safely at every point.
- Existing lessons, exercises, and attempts must be protected from accidental deletion. Cascade delete relationships are restricted to administrative paths only.
- The course switcher clearly distinguishes published, coming-soon, and unavailable courses. Ordinary users cannot enter unpublished courses.
- Assignment of existing lessons to new_en is a temporary, unverified legacy mapping. These lessons remain unpublished until a native speaker reviews and approves them.
- Migration validation must run against a disposable or backup database, never against the production database directly.
- A mandatory checkpoint verifies that all existing users, lessons, exercises, attempts, XP, and streaks are intact after migration completes.

## Glossary

- **System**: The Glossa language learning application (backend API + Flutter mobile app)
- **Backend**: FastAPI-based REST API server with PostgreSQL database
- **Frontend**: Flutter mobile application
- **Database**: PostgreSQL relational database
- **Migration**: Alembic database migration script
- **Language**: A supported language (English, Nepali, or Newari)
- **Course**: A learning direction from source language to target language (e.g., English to Nepali)
- **Unit**: A thematic grouping of lessons within a course
- **Lesson**: An individual learning activity with exercises
- **Exercise**: A question-answer item belonging to a lesson
- **Attempt**: A record of a user completing a lesson
- **Active_Course**: The course a user has explicitly selected
- **Null_Active_Course**: A user with no course selected; treated as a valid unset state requiring a selection prompt
- **Published_Course**: A course available to users (is_published=true)
- **Coming_Soon_Course**: A course seeded but not yet published (is_published=false)
- **Legacy_Content**: The 7 existing Newari lessons placed into a temporary legacy unit pending native-speaker verification
- **Legacy_Unit**: The placeholder unit holding Legacy_Content in the new_en course
- **Course_Switcher**: Flutter UI component for browsing and selecting courses
- **Town_Screen**: Flutter UI displaying units and lessons for the active course
- **GameState**: Flutter state management provider

## Requirements

### Requirement 1: Database Schema Foundation

**User Story:** As a system architect, I want a normalised database schema with languages, courses, and units tables, so that the system supports multiple learning directions with proper relational integrity.

#### Acceptance Criteria

1. THE Database SHALL create a languages table with columns: id (primary key), name_english, name_native, script, is_active
2. THE Database SHALL create a courses table with columns: id (primary key), source_language_id (FK to languages), target_language_id (FK to languages), name, description, is_published, created_at
3. THE Database SHALL create a units table with columns: id (primary key auto-increment), course_id (FK to courses), sequence (integer), title, description
4. THE Database SHALL enforce a unique constraint on courses (source_language_id, target_language_id)
5. THE Database SHALL enforce a unique constraint on units (course_id, sequence)
6. THE Database SHALL NOT apply CASCADE DELETE from course to units on the production migration path; deletion of courses and units is restricted to explicit administrative SQL
7. THE Database SHALL NOT apply CASCADE DELETE from unit to lessons on the production migration path; lessons are protected from accidental deletion via the application's foreign key

### Requirement 2: Lesson Schema Modification

**User Story:** As a system architect, I want lessons organised within units and courses, so that content is properly grouped and filterable.

#### Acceptance Criteria

1. THE Database SHALL add column unit_id (integer, FK to units, nullable during migration, NOT NULL after backfill) to lessons
2. THE Database SHALL add column sequence (integer, nullable during migration, NOT NULL after backfill) to lessons
3. THE Database SHALL add column is_published (boolean, default false) to lessons
4. THE Database SHALL enforce a unique constraint on lessons (unit_id, sequence)
5. THE Database SHALL enforce NOT NULL on lessons.unit_id only after the backfill step confirms every row has been assigned
6. THE Database SHALL enforce NOT NULL on lessons.sequence only after the backfill step confirms every row has been assigned
7. THE Database SHALL preserve all existing lesson records, exercises, and attempt foreign key relationships throughout the migration

### Requirement 3: User Schema Modification

**User Story:** As a user, I want the system to remember which course I am learning, so that I can switch without losing my place.

#### Acceptance Criteria

1. THE Database SHALL add column active_course_id (string, FK to courses, nullable) to users
2. THE Database SHALL create an index on users.active_course_id
3. THE Database SHALL preserve the existing language_id column unchanged
4. WHEN a user has active_course_id=NULL, THEN THE System SHALL treat the user as having no active course and prompt selection on next login
5. WHEN a user's active_course_id references a non-existent or deleted course, THEN THE System SHALL set active_course_id=NULL and require the user to select again

### Requirement 4: Seed Data Initialisation

**User Story:** As a system administrator, I want the database pre-populated with language and course records, so that the course switcher has data immediately.

#### Acceptance Criteria

1. THE Migration SHALL insert three language records: English (id='en'), Nepali (id='ne'), Newari (id='new')
2. THE Migration SHALL insert six course records with IDs: new_en, new_ne, en_new, en_ne, ne_new, ne_en
3. THE Migration SHALL set all six courses to is_published=false initially
4. THE Migration SHALL set is_active=true for all three languages
5. THE Migration SHALL set scripts: English='Latin', Nepali='Devanagari', Newari='Devanagari'

### Requirement 5: Legacy Content Migration

**User Story:** As a system administrator, I want existing Newari lessons preserved during migration, so that content and user progress are not lost.

#### Acceptance Criteria

1. THE Migration SHALL create exactly one legacy unit in the new_en course with title 'Legacy Content - Unverified'
2. THE Migration SHALL assign all existing lessons to that legacy unit
3. THE Migration SHALL assign sequence numbers to existing lessons based on their current primary key order
4. THE Migration SHALL set is_published=false for every existing lesson; no lesson is published automatically
5. THE Migration SHALL treat the new_en assignment as a temporary placeholder; the actual teaching direction of these lessons has NOT been verified and SHALL be documented as such in migration logs
6. THE Migration SHALL preserve all lesson fields: id, title, subtitle, exercise_type, xp_reward, word_count, required_level
7. THE Migration SHALL preserve all exercise records and their lesson_id foreign keys without modification
8. THE Migration SHALL NOT delete any lesson or exercise record

### Requirement 6: User Active Course Backfill

**User Story:** As a user with an existing account, I want the migration to preserve my language preference without forcing an incorrect course assignment.

#### Acceptance Criteria

1. WHEN a user has language_id='newari', THEN THE Migration SHALL set active_course_id='new_en'
2. WHEN a user has language_id='nepali', THEN THE Migration SHALL set active_course_id='ne_en'
3. WHEN a user has language_id='english', THEN THE Migration SHALL set active_course_id='en_ne'
4. WHEN a user has an unrecognised or unsupported language_id value, THEN THE Migration SHALL set active_course_id=NULL and log a warning identifying that user's id and language_id value
5. THE Migration SHALL NOT silently default unknown language_id values to new_en
6. WHEN active_course_id is NULL after backfill, THEN THE System SHALL prompt that user to select a course on next login

### Requirement 7: Attempt Record Preservation

**User Story:** As a user with completed lessons, I want all attempt history preserved, so that XP, streaks, and cleared lessons remain intact.

#### Acceptance Criteria

1. THE Migration SHALL preserve every attempt record with no deletions
2. THE Migration SHALL maintain all foreign keys between attempts and lessons
3. THE Migration SHALL maintain all foreign keys between attempts and users
4. WHEN querying attempts after migration, THE System SHALL return a count identical to the pre-migration count
5. THE Migration SHALL preserve attempt fields: user_id, lesson_id, xp_earned, words_found, completed_at

### Requirement 8: Migration Rollback Safety

**User Story:** As a database administrator, I want a safe rollback mechanism, so that I can revert the migration if issues arise.

#### Acceptance Criteria

1. THE Migration SHALL provide a downgrade() function that removes all added columns in reverse dependency order
2. THE Migration SHALL provide a downgrade() function that drops created tables (units, courses, languages) in reverse dependency order
3. WHEN downgrading, THE Migration SHALL leave user, lesson, exercise, and attempt records in their pre-migration state
4. THE Migration SHALL execute within a database transaction so that a mid-migration failure causes a full rollback
5. THE Migration downgrade() SHALL be tested in isolation on a disposable database before it is considered safe

### Requirement 9: Migration Environment Safety

**User Story:** As a database administrator, I want migration validation to run against a safe environment, so that the production database is never the first target of an untested migration.

#### Acceptance Criteria

1. THE Migration SHALL be validated against a disposable test database (Docker container or CI environment) before being applied to any persistent database
2. THE Migration validation script SHALL take a pre-migration snapshot of row counts for users, lessons, exercises, and attempts
3. THE Migration validation script SHALL compare post-migration row counts against the snapshot and fail if any count decreases
4. WHEN the migration validation script detects a discrepancy, THEN it SHALL abort, print the affected table name, expected count, and actual count, and exit with a non-zero code
5. THE Migration validation script SHALL be a separate runnable script, not embedded in the Alembic migration file itself

### Requirement 10: Post-Migration Data Preservation Checkpoint

**User Story:** As a database administrator, I want a mandatory verification step after migration, so that I can confirm all data is intact before the app goes live.

#### Acceptance Criteria

1. AFTER running migration upgrade(), a data preservation check SHALL verify: user count matches pre-migration snapshot
2. AFTER running migration upgrade(), the check SHALL verify: lesson count matches pre-migration snapshot
3. AFTER running migration upgrade(), the check SHALL verify: exercise count matches pre-migration snapshot
4. AFTER running migration upgrade(), the check SHALL verify: attempt count matches pre-migration snapshot
5. AFTER running migration upgrade(), the check SHALL verify: every user's XP, streak, and lessons_completed match the pre-migration snapshot
6. WHEN any check fails, THE verification script SHALL print the failing table, expected count, and actual count, and exit with a non-zero code
7. THE verification step IS MANDATORY and must pass before any other Phase 3 implementation tasks proceed

### Requirement 11: Migration Validation Counts

**User Story:** As a database administrator, I want the migration to self-validate row counts, so that data loss is caught immediately.

#### Acceptance Criteria

1. THE Migration SHALL record lesson count before any schema changes begin
2. THE Migration SHALL record attempt count before any schema changes begin
3. THE Migration SHALL record user count before any schema changes begin
4. WHEN lesson count after migration differs from before, THE Migration SHALL raise an error and roll back
5. WHEN attempt count after migration differs from before, THE Migration SHALL raise an error and roll back
6. WHEN any user has NULL active_course_id after backfill and their original language_id was a recognised value, THE Migration SHALL raise an error

### Requirement 12: Migration Logging

**User Story:** As a database administrator, I want detailed migration logs, so that I can trace any failure.

#### Acceptance Criteria

1. THE Migration SHALL log 'Creating languages table' before that step
2. THE Migration SHALL log 'Creating courses table' before that step
3. THE Migration SHALL log 'Creating units table' before that step
4. THE Migration SHALL log 'Migrating N existing lessons to legacy unit' with the count
5. THE Migration SHALL log 'Backfilling active_course_id for N users' with the count
6. THE Migration SHALL log 'Warning: user id=X has unrecognised language_id=Y, setting active_course_id=NULL' for each unrecognised user
7. WHEN migration completes successfully, THE Migration SHALL log 'Migration 0003 completed successfully - all integrity checks passed'

### Requirement 13: Language API Endpoint

**User Story:** As a frontend developer, I want an API endpoint to retrieve active languages, so that the app can display language options.

#### Acceptance Criteria

1. THE Backend SHALL provide GET /api/v1/languages returning all languages with is_active=true
2. THE Backend SHALL return id, name_english, name_native, script, is_active in each language object
3. THE Backend SHALL require authentication
4. THE Backend SHALL return a JSON array

### Requirement 14: Course API Endpoint

**User Story:** As a user, I want to browse available courses, so that I can choose a learning direction.

#### Acceptance Criteria

1. THE Backend SHALL provide GET /api/v1/courses
2. WHEN published_only=true (default), THE Backend SHALL return only courses with is_published=true
3. WHEN published_only=false, THE Backend SHALL return all courses including unpublished
4. THE Backend SHALL include nested source_language and target_language objects in each course response
5. THE Backend SHALL require authentication
6. THE Backend SHALL return a JSON array

### Requirement 15: Unit API Endpoint

**User Story:** As a user viewing a course, I want to see units with lesson counts, so that I understand structure and progress.

#### Acceptance Criteria

1. THE Backend SHALL provide GET /api/v1/courses/{course_id}/units
2. THE Backend SHALL return units ordered by sequence
3. THE Backend SHALL include total_lessons count per unit (published lessons only)
4. THE Backend SHALL include cleared_lessons count per unit for the authenticated user
5. WHEN course_id does not exist, THE Backend SHALL return 404 with message 'Course not found'
6. THE Backend SHALL require authentication

### Requirement 16: Lesson Filtering by Course

**User Story:** As a user with an active course, I want to see only lessons from that course.

#### Acceptance Criteria

1. THE Backend SHALL modify GET /api/v1/lessons to accept optional course_id query parameter
2. WHEN course_id is provided, THE Backend SHALL return only published lessons from units in that course
3. WHEN course_id is not provided, THE Backend SHALL use the user's active_course_id
4. WHEN neither course_id is provided nor active_course_id is set (NULL), THE Backend SHALL return 400 with message 'No active course selected'
5. THE Backend SHALL filter out lessons with is_published=false
6. THE Backend SHALL order results by unit.sequence then lesson.sequence

### Requirement 17: Lesson Status Calculation

**User Story:** As a user viewing lessons, I want each lesson to show cleared, current, or locked status.

#### Acceptance Criteria

1. THE Backend SHALL mark lessons that have at least one attempt record as 'cleared'
2. THE Backend SHALL mark the first non-cleared lesson in sequence as 'current'
3. THE Backend SHALL mark all lessons after the 'current' lesson as 'locked'
4. THE Backend SHALL calculate status per course in isolation from other courses
5. THE Backend SHALL include a status field in every LessonOut response
6. WHEN all lessons in a course are cleared, THE Backend SHALL mark the last lesson as 'current'

### Requirement 18: Active Course Selection API

**User Story:** As a user, I want to switch my active course via the API.

#### Acceptance Criteria

1. THE Backend SHALL provide PUT /api/v1/users/me/active-course
2. THE Backend SHALL accept a JSON body with active_course_id field
3. WHEN active_course_id references a published course, THE Backend SHALL update user.active_course_id
4. WHEN active_course_id references an unpublished course, THE Backend SHALL return 403 with message 'Course is not available yet'
5. WHEN active_course_id does not exist, THE Backend SHALL return 404 with message 'Course not found'
6. THE Backend SHALL return the updated user profile after a successful change

### Requirement 19: Course Progress Isolation

**User Story:** As a user learning multiple courses, I want progress in one course independent of others.

#### Acceptance Criteria

1. WHEN calculating lesson status for course A, THE Backend SHALL only consider attempts for lessons whose unit belongs to course A
2. WHEN a user completes a lesson in course A, THE Backend SHALL NOT change lesson status in course B
3. WHEN a user switches to course B and back to course A, THE Backend SHALL restore the identical set of cleared lesson statuses that existed before switching

### Requirement 20: Global Progress Preservation

**User Story:** As a user switching courses, I want XP, level, and streak preserved.

#### Acceptance Criteria

1. WHEN a user completes a lesson in any course, THE Backend SHALL increment user.xp globally
2. WHEN an XP threshold is reached, THE Backend SHALL increment user.level
3. WHEN a user completes a lesson, THE Backend SHALL update user.streak and last_activity_date
4. WHEN a user switches courses, THE Backend SHALL NOT modify user.xp, user.level, or user.streak
5. THE Backend SHALL maintain lessons_completed as a global count across all courses

### Requirement 21: API Error Responses

**User Story:** As a frontend developer, I want consistent structured error responses.

#### Acceptance Criteria

1. WHEN a course_id does not exist, THE Backend SHALL return 404 with JSON body containing detail: 'Course not found'
2. WHEN a user selects an unpublished course, THE Backend SHALL return 403 with detail: 'Course is not available yet'
3. WHEN required parameters are missing, THE Backend SHALL return 400 with a descriptive detail message
4. WHEN authentication fails, THE Backend SHALL return 401
5. All error responses SHALL use JSON format with a 'detail' field

### Requirement 22: Database Index Performance

**User Story:** As a system operator, I want efficient queries so API responses remain fast.

#### Acceptance Criteria

1. THE Database SHALL create an index on users.active_course_id
2. THE Database SHALL create an index on units.course_id
3. THE Database SHALL create an index on lessons.unit_id

### Requirement 23: Course Switcher UI - Status Display

**User Story:** As a user browsing courses, I want clear visual distinction between available, coming-soon, and unavailable courses.

#### Acceptance Criteria

1. THE Frontend SHALL create a CourseSwitcher widget displaying all courses received from the API
2. THE Frontend SHALL display each course as '{sourceLanguage.nameEnglish} to {targetLanguage.nameEnglish}'
3. WHEN is_published=true, THE Frontend SHALL display an 'Available' badge (green) on the course card
4. WHEN is_published=false, THE Frontend SHALL display a 'Coming Soon' badge (grey) on the course card
5. WHEN is_published=false, THE Frontend SHALL disable the course card tap entirely
6. WHEN a user attempts to interact with a disabled (unpublished) course card, THE Frontend SHALL do nothing: no navigation, no error, no spinner
7. WHEN the courses list is empty or all courses are unpublished, THE Frontend SHALL display a 'No courses available yet' empty-state message

### Requirement 24: Course Switcher UI - Selection

**User Story:** As a user, I want to select an available course from the switcher.

#### Acceptance Criteria

1. WHEN a user taps a published course card, THE Frontend SHALL call GameStateNotifier.switchCourse(courseId)
2. WHEN switchCourse is in progress, THE Frontend SHALL show a loading indicator on the selected card
3. WHEN switchCourse succeeds, THE Frontend SHALL navigate to the Town screen
4. WHEN switchCourse fails, THE Frontend SHALL display an error SnackBar and restore the previous card state

### Requirement 25: Course Switcher Navigation

**User Story:** As a user on Town or Profile, I want easy access to the course switcher.

#### Acceptance Criteria

1. THE Frontend SHALL provide navigation to the course switcher from the Town screen or Profile screen
2. THE Frontend SHALL add a named route '/course-switcher' to the app router
3. WHEN navigating to the course switcher, THE Frontend SHALL load all courses (including unpublished) so the user sees coming-soon courses

### Requirement 26: Town Screen - Dynamic Units

**User Story:** As a user viewing my active course, I want the Town screen to show dynamic unit headers.

#### Acceptance Criteria

1. THE Frontend SHALL remove the hardcoded 'World 1: Home and Food' header
2. THE Frontend SHALL group lessons by unitId when rendering
3. THE Frontend SHALL display unit headers ordered by unit.sequence
4. THE Frontend SHALL display lessons within each unit ordered by lesson.sequence
5. THE Frontend SHALL preserve existing lesson card styling and animations

### Requirement 27: Unit Progress Indicator

**User Story:** As a user viewing units, I want progress indicators on each unit header.

#### Acceptance Criteria

1. THE Frontend SHALL display a progress bar on each unit header
2. THE Frontend SHALL calculate progress as clearedLessons / totalLessons
3. WHEN totalLessons is zero, THE Frontend SHALL display 0% and not divide by zero
4. WHEN all lessons in a unit are cleared, THE Frontend SHALL display 100%
5. THE Frontend SHALL visually distinguish completed units from incomplete ones

### Requirement 28: Legacy Content Visibility

**User Story:** As a user, I want unpublished and unverified lessons hidden, so that I only encounter verified content.

#### Acceptance Criteria

1. THE Frontend SHALL display only lessons with is_published=true
2. THE Frontend SHALL not display the legacy unit or any unit that has zero published lessons
3. WHEN a course has no published units, THE Frontend SHALL display an empty-state message rather than a blank screen

### Requirement 29: Course Authorization

**User Story:** As a system administrator, I want users restricted to their own data, so that progress data stays private.

#### Acceptance Criteria

1. THE Backend SHALL require authentication on all language, course, unit, and lesson endpoints
2. WHEN calculating cleared_lessons for a unit, THE Backend SHALL scope the count to the authenticated user only
3. WHEN updating active_course_id, THE Backend SHALL only update the authenticated user's own record
4. THE Backend SHALL not expose another user's progress, XP, or attempt data in any response

### Requirement 30: Flutter Language Model

**User Story:** As a Flutter developer, I want a Language data model.

#### Acceptance Criteria

1. THE Frontend SHALL define a Language class with final fields: id, nameEnglish, nameNative, script, isActive
2. THE Frontend SHALL provide Language.fromJson mapping snake_case API fields to camelCase Dart fields

### Requirement 31: Flutter Course Model

**User Story:** As a Flutter developer, I want a Course data model with nested language objects.

#### Acceptance Criteria

1. THE Frontend SHALL define a Course class with final fields: id, sourceLanguageId, targetLanguageId, name, description, isPublished, sourceLanguage, targetLanguage
2. THE Frontend SHALL provide Course.fromJson parsing nested sourceLanguage and targetLanguage as Language objects

### Requirement 32: Flutter Unit Model

**User Story:** As a Flutter developer, I want a Unit data model with progress information.

#### Acceptance Criteria

1. THE Frontend SHALL define a Unit class with final fields: id, courseId, sequence, title, description, totalLessons, clearedLessons
2. THE Frontend SHALL provide Unit.fromJson
3. THE Frontend SHALL provide a progress getter returning clearedLessons / totalLessons
4. WHEN totalLessons is zero, THE Unit.progress getter SHALL return 0.0

### Requirement 33: Flutter Lesson Model Update

**User Story:** As a Flutter developer, I want the Lesson model to include unit and sequence fields.

#### Acceptance Criteria

1. THE Frontend SHALL add unitId (int), sequence (int), and isPublished (bool) fields to the Lesson class
2. THE Frontend SHALL update Lesson.fromJson to parse these fields
3. THE Frontend SHALL preserve all existing Lesson fields

### Requirement 34: GameState Extension

**User Story:** As a Flutter developer, I want GameState to include course and unit data.

#### Acceptance Criteria

1. THE Frontend SHALL add activeCourseId (String?, nullable) to GameState
2. THE Frontend SHALL add languages (List<Language>, default empty) to GameState
3. THE Frontend SHALL add courses (List<Course>, default empty) to GameState
4. THE Frontend SHALL add units (List<Unit>, default empty) to GameState
5. THE Frontend SHALL update copyWith to support all new fields

### Requirement 35: Course and Language Loading

**User Story:** As a user opening the app, I want courses and languages loaded automatically.

#### Acceptance Criteria

1. THE Frontend SHALL load languages and courses on app start (after authentication)
2. WHEN a user has an active_course_id, THE Frontend SHALL load units for that course
3. WHEN a user has no active_course_id (NULL), THE Frontend SHALL navigate to the course switcher instead of the Town screen
4. WHEN loading fails, THE Frontend SHALL display an error message with a retry option

### Requirement 36: Course Switching Logic

**User Story:** As a user, I want to switch courses from the UI.

#### Acceptance Criteria

1. THE Frontend SHALL provide switchCourse(courseId) in GameStateNotifier
2. WHEN called, THE Frontend SHALL call PUT /api/v1/users/me/active-course
3. WHEN the backend confirms the change, THE Frontend SHALL update activeCourseId, units, and lessons in GameState
4. WHEN the backend returns 403, THE Frontend SHALL display 'This course is not available yet' and preserve the previous course
5. WHEN any error occurs, THE Frontend SHALL preserve the previous course selection and display an error message

### Requirement 37: Flutter Error Handling

**User Story:** As a user experiencing errors, I want clear feedback so I understand what went wrong.

#### Acceptance Criteria

1. WHEN any network request fails, THE Frontend SHALL display an error SnackBar
2. WHEN the API returns 403 for an unpublished course, THE Frontend SHALL display 'This course is not available yet'
3. WHEN the API returns 404, THE Frontend SHALL display 'Resource not found'
4. WHEN course switching fails, THE Frontend SHALL preserve the current course selection without reverting to a blank state
5. THE Frontend SHALL offer a retry action for failed load operations

### Requirement 38: Backward Compatibility

**User Story:** As a system maintainer, I want language_id preserved during transition so rollback is possible.

#### Acceptance Criteria

1. THE Migration SHALL preserve users.language_id column and its values unchanged
2. THE Backend SHALL continue to accept language_id on user creation
3. THE Backend SHALL use active_course_id as the primary course selection mechanism
4. WHEN active_course_id is NULL and language_id is a recognised value, THE Backend SHALL use language_id to infer the default course for read operations only (not for writes)

### Requirement 39: Lesson Sequence Uniqueness

**User Story:** As a content administrator, I want lesson sequences unique within units so ordering is unambiguous.

#### Acceptance Criteria

1. THE Database SHALL enforce a unique constraint on (unit_id, sequence) in lessons
2. WHEN attempting to insert a lesson with a duplicate (unit_id, sequence), THE Database SHALL reject the insert

### Requirement 40: Course Direction Uniqueness

**User Story:** As a content administrator, I want each language-pair direction to map to exactly one course.

#### Acceptance Criteria

1. THE Database SHALL enforce a unique constraint on (source_language_id, target_language_id) in courses
2. THE Database SHALL allow the reverse direction as a separate course

### Requirement 41: Attempt History Queryability

**User Story:** As a user, I want my attempt history preserved and queryable across course switches.

#### Acceptance Criteria

1. THE Backend SHALL return all attempts for the authenticated user across all courses
2. THE Backend SHALL preserve attempt.completed_at timestamps
3. THE Backend SHALL maintain the foreign key chain attempt to lesson to unit to course
4. THE Backend SHALL NOT delete or modify attempt records during course switching
