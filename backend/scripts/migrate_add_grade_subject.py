#!/usr/bin/env python3
import sqlite3
import os

root = os.path.dirname(os.path.dirname(__file__))
db_path = os.path.join(root, 'teacher_assistant.db')

if not os.path.exists(db_path):
    print(f"Database file not found at {db_path}. Nothing to migrate.")
    raise SystemExit(1)

conn = sqlite3.connect(db_path)
cur = conn.cursor()
cur.execute("PRAGMA table_info('lesson_plans')")
cols = [row[1] for row in cur.fetchall()]
added = []
if 'grade' not in cols:
    cur.execute("ALTER TABLE lesson_plans ADD COLUMN grade TEXT")
    added.append('grade')
if 'subject' not in cols:
    cur.execute("ALTER TABLE lesson_plans ADD COLUMN subject TEXT")
    added.append('subject')
conn.commit()
conn.close()
if added:
    print('Added columns: ' + ', '.join(added))
else:
    print('No changes required; columns already present.')
