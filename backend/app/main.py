from datetime import datetime, timedelta, timezone

from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select, func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload
import jwt

from app.config import settings
from app.database import SessionLocal
from app.models import Attempt, Course, Exercise, Language, Lesson, Unit, User
from app.schemas import (
    AnswerIn, AttemptIn, AuthOut, CourseOut, CourseUpdate, Credentials,
    LanguageOut, LeaderboardEntryOut, LessonOut, ProfileUpdate, Registration,
    UnitOut, UserOut,
)
from app.security import create_token, hash_password, verify_password

app = FastAPI(title="Glossa API", version="2.0.0")
origins = [item.strip() for item in settings.cors_origins.split(",") if item.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
bearer = HTTPBearer(auto_error=False)


def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(db_session),
) -> User:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Authentication required")
    try:
        payload = jwt.decode(credentials.credentials, settings.jwt_secret, algorithms=["HS256"])
        user_id = int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        raise HTTPException(status_code=401, detail="Invalid or expired access token")
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=401, detail="Account not found")
    return user


def xp_to_next(user: User) -> int:
    return user.level * 150 if user.level > 1 else 100


def current_streak(user: User) -> int:
    if user.last_activity_date is None:
        return 0
    today = datetime.now(timezone.utc).date()
    if user.last_activity_date < today - timedelta(days=1):
        return 0
    return user.streak


def user_output(user: User) -> UserOut:
    return UserOut(
        id=user.id, name=user.name, email=user.email, hero_index=user.hero_index,
        hero_class_name=user.hero_class_name, language_id=user.language_id,
        active_course_id=user.active_course_id, xp=user.xp,
        xp_to_next_level=xp_to_next(user), level=user.level,
        streak=current_streak(user), words_found=user.words_found,
        lessons_completed=user.lessons_completed,
    )


def auth_output(user: User) -> AuthOut:
    return AuthOut(access_token=create_token(user.id), user=user_output(user))


def _resolve_course_id(course_id: str | None, user: User) -> str:
    """Resolve which course to use: explicit param or user's active course."""
    if course_id is not None:
        return course_id
    if user.active_course_id is not None:
        return user.active_course_id
    return "en_ne"


def lesson_statuses(db: Session, user: User, course_id: str | None = None) -> dict[str, str]:
    """Calculate cleared/current/locked status for lessons in a course."""
    cid = _resolve_course_id(course_id, user)

    # Query published lessons in this course, ordered by unit.sequence then lesson.sequence
    lessons = list(
        db.scalars(
            select(Lesson)
            .join(Unit, Lesson.unit_id == Unit.id)
            .where(Unit.course_id == cid, Lesson.is_published == True)
            .order_by(Unit.sequence, Lesson.sequence)
        ).all()
    )
    if not lessons:
        return {}

    # Get cleared lesson IDs from attempts for this user in this course
    cleared_ids = set(
        db.scalars(
            select(Attempt.lesson_id)
            .where(Attempt.user_id == user.id)
        ).all()
    )

    result = {}
    previous_cleared = True
    for lesson in lessons:
        if lesson.id in cleared_ids:
            result[lesson.id] = "cleared"
            previous_cleared = True
        elif previous_cleared:
            result[lesson.id] = "current"
            previous_cleared = False
        else:
            result[lesson.id] = "locked"
    return result


# ─── Health ────────────────────────────────────────────────────


@app.get("/health")
def health():
    return {"status": "ok"}


# ─── Auth ──────────────────────────────────────────────────────


@app.post("/api/v1/auth/register", response_model=AuthOut, status_code=201)
def register(payload: Registration, db: Session = Depends(db_session)):
    if db.scalar(select(User).where(User.email == payload.email.lower())):
        raise HTTPException(status_code=409, detail="An account with this email already exists")
    user = User(
        name=payload.name.strip(),
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        active_course_id=None,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="An account with this email already exists")
    db.refresh(user)
    return auth_output(user)


@app.post("/api/v1/auth/login", response_model=AuthOut)
def login(payload: Credentials, db: Session = Depends(db_session)):
    user = db.scalar(select(User).where(User.email == payload.email.lower()))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email or password is incorrect")
    return auth_output(user)


# ─── User profile ──────────────────────────────────────────────


@app.get("/api/v1/me", response_model=UserOut)
def get_me(user: User = Depends(current_user)):
    return user_output(user)


@app.patch("/api/v1/me", response_model=UserOut)
def update_me(
    payload: ProfileUpdate,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(user, key, value)
    db.commit()
    db.refresh(user)
    return user_output(user)


@app.put("/api/v1/users/me/active-course", response_model=UserOut)
def update_active_course(
    payload: CourseUpdate,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    course = db.get(Course, payload.active_course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")
    if not course.is_published:
        raise HTTPException(status_code=403, detail="Course is not available yet")
    user.active_course_id = course.id
    db.commit()
    db.refresh(user)
    return user_output(user)


# ─── Languages ─────────────────────────────────────────────────


@app.get("/api/v1/languages", response_model=list[LanguageOut])
def get_languages(db: Session = Depends(db_session), user: User = Depends(current_user)):
    return list(db.scalars(select(Language).where(Language.is_active == True)).all())


# ─── Courses ───────────────────────────────────────────────────


@app.get("/api/v1/courses", response_model=list[CourseOut])
def get_courses(
    published_only: bool = Query(True),
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    query = select(Course).options(
        selectinload(Course.source_language),
        selectinload(Course.target_language),
    )
    if published_only:
        query = query.where(Course.is_published == True)
    return list(db.scalars(query).all())


# ─── Units ─────────────────────────────────────────────────────


@app.get("/api/v1/courses/{course_id}/units", response_model=list[UnitOut])
def get_units_for_course(
    course_id: str,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    course = db.get(Course, course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")

    units = list(
        db.scalars(
            select(Unit)
            .where(Unit.course_id == course_id)
            .order_by(Unit.sequence)
        ).all()
    )

    # Get cleared lesson IDs for this user
    cleared_ids = set(
        db.scalars(select(Attempt.lesson_id).where(Attempt.user_id == user.id)).all()
    )

    result = []
    for unit in units:
        # Count published lessons in this unit
        published_lessons = list(
            db.scalars(
                select(Lesson).where(
                    Lesson.unit_id == unit.id, Lesson.is_published == True
                )
            ).all()
        )
        total_lessons = len(published_lessons)
        cleared_lessons = sum(1 for l in published_lessons if l.id in cleared_ids)
        result.append(
            UnitOut(
                id=unit.id,
                course_id=unit.course_id,
                sequence=unit.sequence,
                title=unit.title,
                description=unit.description,
                total_lessons=total_lessons,
                cleared_lessons=cleared_lessons,
            )
        )
    return result


# ─── Lessons ──────────────────────────────────────────────────


@app.get("/api/v1/lessons")
def get_lessons(
    course_id: str | None = Query(None),
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    cid = _resolve_course_id(course_id, user)
    statuses = lesson_statuses(db, user, cid)

    lessons = list(
        db.scalars(
            select(Lesson)
            .join(Unit, Lesson.unit_id == Unit.id)
            .where(Unit.course_id == cid, Lesson.is_published == True)
            .order_by(Unit.sequence, Lesson.sequence)
        ).all()
    )

    return [
        {
            "id": l.id,
            "unit_id": l.unit_id,
            "sequence": l.sequence,
            "title": l.title,
            "subtitle": l.subtitle,
            "exercise_type": l.exercise_type,
            "status": statuses.get(l.id, "locked"),
            "xp_reward": l.xp_reward,
            "word_count": l.word_count,
            "required_level": l.required_level,
            "is_published": l.is_published,
        }
        for l in lessons
    ]


@app.get("/api/v1/lessons/{lesson_id}/exercises")
def get_exercises(
    lesson_id: str,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    lesson = db.scalar(
        select(Lesson).where(Lesson.id == lesson_id).options(selectinload(Lesson.exercises))
    )
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")
    if lesson_statuses(db, user).get(lesson_id) == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")
    return [
        {
            "id": e.id,
            "type": e.exercise_type,
            "instruction": e.instruction,
            "prompt": e.prompt,
            "prompt_hint": e.prompt_hint,
            "image_key": e.image_key,
            "audio_key": e.audio_key,
            "options": e.options,
            "pairs": e.pairs,
        }
        for e in sorted(lesson.exercises, key=lambda x: (x.sequence or 0, x.id))
    ]


@app.post("/api/v1/lessons/{lesson_id}/attempts")
def submit_attempt(
    lesson_id: str,
    payload: AttemptIn,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    user = db.scalar(
        select(User)
        .where(User.id == user.id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    lesson = db.scalar(
        select(Lesson).where(Lesson.id == lesson_id).options(selectinload(Lesson.exercises))
    )
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")
    existing = db.scalar(select(Attempt).where(Attempt.user_id == user.id, Attempt.lesson_id == lesson_id))
    if existing:
        return {
            "completed": True,
            "already_completed": True,
            "correct_answers": existing.correct_answers,
            "total_questions": existing.total_questions,
            "xp_earned": existing.xp_earned,
            "user": user_output(user),
        }
    if lesson_statuses(db, user).get(lesson_id) == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")

    exercises = {e.id: e for e in lesson.exercises}
    submitted = {}
    for answer in payload.answers:
        submitted[answer.exercise_id] = answer
    if set(submitted) != set(exercises):
        raise HTTPException(status_code=422, detail="Submit exactly one answer for every exercise")

    correct = 0
    for exercise_id, exercise in exercises.items():
        answer = submitted[exercise_id]
        if exercise.pairs is not None:
            is_correct = answer.selected_pairs == exercise.pairs
        else:
            is_correct = answer.selected_option_id == exercise.answer_id
        if not is_correct:
            raise HTTPException(status_code=422, detail="Lesson answers are incomplete or incorrect")
        correct += 1

    xp_earned = lesson.xp_reward
    user.xp += xp_earned
    user.words_found += lesson.word_count
    user.lessons_completed += 1
    today = datetime.now(timezone.utc).date()
    if user.last_activity_date != today:
        yesterday = today - timedelta(days=1)
        user.streak = user.streak + 1 if user.last_activity_date == yesterday else 1
        user.last_activity_date = today
    while user.xp >= xp_to_next(user):
        user.level += 1

    levels = [(2, "Traveler"), (4, "Speaker"), (6, "Guardian")]
    user.hero_class_name = (
        "Master"
        if user.level >= 7
        else next((title for limit, title in levels if user.level <= limit), "Master")
    )

    total_questions = sum(
        len(e.pairs) if e.pairs is not None else 1 for e in exercises.values()
    )
    correct_count = sum(
        len(submitted[e.id].selected_pairs or {})
        if e.pairs is not None
        else int(submitted[e.id].selected_option_id == e.answer_id)
        for e in exercises.values()
    )
    attempt = Attempt(
        user_id=user.id,
        lesson_id=lesson_id,
        correct_answers=correct_count,
        total_questions=total_questions,
        xp_earned=xp_earned,
    )
    db.add(attempt)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        existing = db.scalar(
            select(Attempt).where(Attempt.user_id == user.id, Attempt.lesson_id == lesson_id)
        )
        return {
            "completed": True,
            "already_completed": True,
            "correct_answers": existing.correct_answers if existing else 0,
            "total_questions": existing.total_questions if existing else 0,
            "xp_earned": existing.xp_earned if existing else 0,
            "user": user_output(user),
        }
    db.refresh(user)
    return {
        "completed": True,
        "already_completed": False,
        "correct_answers": correct_count,
        "total_questions": total_questions,
        "xp_earned": xp_earned,
        "user": user_output(user),
    }


@app.post("/api/v1/lessons/{lesson_id}/answer")
def check_answer(
    lesson_id: str,
    answer: AnswerIn,
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    exercise = db.get(Exercise, answer.exercise_id)
    if exercise is None or exercise.lesson_id != lesson_id:
        raise HTTPException(status_code=404, detail="Exercise not found")
    if lesson_statuses(db, user).get(lesson_id) == "locked":
        raise HTTPException(status_code=403, detail="Lesson is locked")
    if exercise.pairs is not None:
        correct = bool(answer.selected_pairs) and all(
            exercise.pairs.get(key) == value for key, value in answer.selected_pairs.items()
        )
    else:
        correct = answer.selected_option_id == exercise.answer_id
    return {"correct": correct}


# ─── Leaderboard ───────────────────────────────────────────────


@app.get("/api/v1/leaderboard", response_model=list[LeaderboardEntryOut])
def get_leaderboard(
    filter: str = "weekly",
    db: Session = Depends(db_session),
    user: User = Depends(current_user),
):
    if filter not in {"weekly", "alltime"}:
        raise HTTPException(status_code=422, detail="filter must be weekly or alltime")
    if filter == "weekly":
        start = datetime.now(timezone.utc) - timedelta(days=7)
        scores = dict(
            db.execute(
                select(Attempt.user_id, func.sum(Attempt.xp_earned))
                .where(Attempt.completed_at >= start)
                .group_by(Attempt.user_id)
            ).all()
        )
        rows = (
            db.scalars(select(User).where(User.id.in_(scores.keys())).order_by(User.name)).all()
            if scores
            else []
        )
        rows.sort(key=lambda row: (-scores[row.id], row.name))
        score_for = lambda row: scores[row.id]
    else:
        rows = db.scalars(select(User).order_by(User.xp.desc(), User.name)).all()
        score_for = lambda row: row.xp
    return [
        LeaderboardEntryOut(
            rank=index,
            name=row.name,
            level=row.level,
            class_name=row.hero_class_name,
            xp=score_for(row),
            hero_index=row.hero_index,
            is_current_user=row.id == user.id,
        )
        for index, row in enumerate(rows[:100], start=1)
    ]
