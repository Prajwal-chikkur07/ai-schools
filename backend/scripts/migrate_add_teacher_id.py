"""
Migration: Add teacher_id column and make grade/subject NOT NULL.

Run once against the existing database:
    python -m scripts.migrate_add_teacher_id

This script is idempotent — safe to run multiple times.
"""
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.utils.config import settings
from sqlalchemy import create_engine, text

engine = create_engine(settings.DATABASE_URL)

with engine.connect() as conn:
    # 1. Add teacher_id column if it doesn't exist (default to 'teacher_01' for existing rows)
    try:
        conn.execute(text(
            "ALTER TABLE lesson_plans ADD COLUMN teacher_id VARCHAR DEFAULT 'teacher_01' NOT NULL"
        ))
        print("Added teacher_id column.")
    except Exception as e:
        print(f"teacher_id column already exists or error: {e}")

    # 2. Fill any NULL grade/subject rows with placeholder so NOT NULL constraint can be added
    conn.execute(text(
        "UPDATE lesson_plans SET grade = 'Unknown' WHERE grade IS NULL"
    ))
    conn.execute(text(
        "UPDATE lesson_plans SET subject = 'Unknown' WHERE subject IS NULL"
    ))

    # 3. Create indexes for fast scoped queries
    try:
        conn.execute(text(
            "CREATE INDEX IF NOT EXISTS ix_lesson_plans_teacher_grade_subject "
            "ON lesson_plans (teacher_id, grade, subject)"
        ))
        print("Created composite index.")
    except Exception as e:
        print(f"Index creation error: {e}")

    conn.commit()
    print("Migration complete.")
