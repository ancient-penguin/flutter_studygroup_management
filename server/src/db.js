const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');

const dbPath = process.env.DB_PATH || path.join(__dirname, '..', 'data', 'app.db');
const db = new DatabaseSync(dbPath);

db.exec('PRAGMA journal_mode = WAL');
db.exec('PRAGMA foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS students (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    initial TEXT NOT NULL,
    school TEXT NOT NULL,
    grade TEXT NOT NULL,
    subject TEXT NOT NULL,
    hourly_rate INTEGER NOT NULL
  );

  -- 주간 반복 규칙. 요일만 있던 예전 schedule_days 문자열과 달리 시작 시각과 길이를 함께 가진다.
  CREATE TABLE IF NOT EXISTS student_schedules (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    weekday INTEGER NOT NULL,       -- 1=월 ... 7=일 (Dart DateTime.weekday와 동일)
    start_time TEXT NOT NULL,       -- "18:00"
    duration_min INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS lessons (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    date TEXT NOT NULL,             -- "2026-09-28" ISO-8601. 문자열 비교가 곧 시간순 비교.
    start_time TEXT NOT NULL,       -- "18:00"
    end_time TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    amount INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'scheduled',
    settled_at TEXT                 -- NULL=미정산, ISO datetime=정산 완료
  );

  CREATE INDEX IF NOT EXISTS idx_lessons_student_id ON lessons(student_id);
  CREATE INDEX IF NOT EXISTS idx_lessons_date ON lessons(date);
  CREATE INDEX IF NOT EXISTS idx_student_schedules_student_id ON student_schedules(student_id);
`);

module.exports = db;
