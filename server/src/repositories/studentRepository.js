const crypto = require('node:crypto');
const db = require('../db');

function rowToSchedule(row) {
  return {
    id: row.id,
    weekday: row.weekday,
    startTime: row.start_time,
    durationMin: row.duration_min,
  };
}

function listSchedules(studentId) {
  const rows = db
    .prepare('SELECT * FROM student_schedules WHERE student_id = ? ORDER BY weekday, start_time')
    .all(studentId);
  return rows.map(rowToSchedule);
}

/// 학생 한 명을 API 응답 형태로 만든다. 주간 반복 규칙은 항상 함께 내려간다.
function rowToStudent(row) {
  if (!row) return undefined;
  return {
    id: row.id,
    name: row.name,
    initial: row.initial,
    school: row.school,
    grade: row.grade,
    subject: row.subject,
    hourlyRate: row.hourly_rate,
    schedules: listSchedules(row.id),
  };
}

function listAll() {
  const rows = db.prepare('SELECT * FROM students ORDER BY rowid').all();
  return rows.map(rowToStudent);
}

function getById(id) {
  const row = db.prepare('SELECT * FROM students WHERE id = ?').get(id);
  return rowToStudent(row);
}

/// 해당 학생의 반복 규칙을 통째로 교체한다. 부분 수정 대신 replace로 두어
/// 앱이 보낸 목록이 곧 최종 상태가 되게 한다.
function replaceSchedules(studentId, schedules) {
  db.prepare('DELETE FROM student_schedules WHERE student_id = ?').run(studentId);
  const insertStmt = db.prepare(
    `INSERT INTO student_schedules (id, student_id, weekday, start_time, duration_min)
     VALUES (@id, @studentId, @weekday, @startTime, @durationMin)`
  );
  for (const schedule of schedules) {
    insertStmt.run({
      id: schedule.id ?? crypto.randomUUID(),
      studentId,
      weekday: schedule.weekday,
      startTime: schedule.startTime,
      durationMin: schedule.durationMin,
    });
  }
}

function insert(student) {
  db.prepare(
    `INSERT INTO students (id, name, initial, school, grade, subject, hourly_rate)
     VALUES (@id, @name, @initial, @school, @grade, @subject, @hourlyRate)`
  ).run({
    id: student.id,
    name: student.name,
    initial: student.initial,
    school: student.school,
    grade: student.grade,
    subject: student.subject,
    hourlyRate: student.hourlyRate,
  });
  replaceSchedules(student.id, student.schedules ?? []);
}

function create(fields) {
  const id = crypto.randomUUID();
  insert({
    id,
    name: fields.name,
    initial: fields.initial,
    school: fields.school,
    grade: fields.grade,
    subject: fields.subject,
    hourlyRate: fields.hourlyRate,
    schedules: fields.schedules ?? [],
  });
  return getById(id);
}

function update(id, fields) {
  const existing = getById(id);
  if (!existing) return undefined;
  const merged = { ...existing, ...fields, id };
  db.prepare(
    `UPDATE students
     SET name = @name, initial = @initial, school = @school, grade = @grade,
         subject = @subject, hourly_rate = @hourlyRate
     WHERE id = @id`
  ).run({
    id: merged.id,
    name: merged.name,
    initial: merged.initial,
    school: merged.school,
    grade: merged.grade,
    subject: merged.subject,
    hourlyRate: merged.hourlyRate,
  });
  // schedules를 아예 보내지 않은 요청은 기존 규칙을 건드리지 않는다.
  if (fields.schedules !== undefined) {
    replaceSchedules(id, fields.schedules ?? []);
  }
  return getById(id);
}

function remove(id) {
  const result = db.prepare('DELETE FROM students WHERE id = ?').run(id);
  return result.changes > 0;
}

function count() {
  return db.prepare('SELECT COUNT(*) AS n FROM students').get().n;
}

module.exports = {
  listAll,
  getById,
  insert,
  create,
  update,
  remove,
  count,
  rowToStudent,
  rowToSchedule,
};
