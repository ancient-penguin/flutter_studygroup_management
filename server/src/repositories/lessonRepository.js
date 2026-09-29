const crypto = require('node:crypto');
const db = require('../db');

function rowToLesson(row) {
  if (!row) return undefined;
  return {
    id: row.id,
    studentId: row.student_id,
    date: row.date,
    startTime: row.start_time,
    endTime: row.end_time,
    note: row.note,
    amount: row.amount,
    status: row.status,
    settledAt: row.settled_at ?? null,
  };
}

/// date가 ISO "YYYY-MM-DD"라 문자열 비교만으로 날짜 범위 조회가 된다.
/// filters: { studentId, from, to } — 모두 선택적이며 조합 가능.
function list(filters = {}) {
  const where = [];
  const params = {};
  if (filters.studentId) {
    where.push('student_id = @studentId');
    params.studentId = filters.studentId;
  }
  if (filters.from) {
    where.push('date >= @from');
    params.from = filters.from;
  }
  if (filters.to) {
    where.push('date <= @to');
    params.to = filters.to;
  }
  const sql =
    'SELECT * FROM lessons' +
    (where.length ? ` WHERE ${where.join(' AND ')}` : '') +
    ' ORDER BY date, start_time';
  const rows = db.prepare(sql).all(params);
  return rows.map(rowToLesson);
}

function listAll() {
  return list();
}

function listByStudentId(studentId) {
  return list({ studentId });
}

function getById(id) {
  const row = db.prepare('SELECT * FROM lessons WHERE id = ?').get(id);
  return rowToLesson(row);
}

function insert(lesson) {
  db.prepare(
    `INSERT INTO lessons (id, student_id, date, start_time, end_time, note, amount, status, settled_at)
     VALUES (@id, @studentId, @date, @startTime, @endTime, @note, @amount, @status, @settledAt)`
  ).run({
    id: lesson.id,
    studentId: lesson.studentId,
    date: lesson.date,
    startTime: lesson.startTime,
    endTime: lesson.endTime,
    note: lesson.note ?? '',
    amount: lesson.amount,
    status: lesson.status ?? 'scheduled',
    settledAt: lesson.settledAt ?? null,
  });
}

function create(fields) {
  const lesson = {
    id: crypto.randomUUID(),
    studentId: fields.studentId,
    date: fields.date,
    startTime: fields.startTime,
    endTime: fields.endTime,
    note: fields.note ?? '',
    amount: fields.amount,
    status: fields.status ?? 'scheduled',
    settledAt: fields.settledAt ?? null,
  };
  insert(lesson);
  return lesson;
}

function update(id, fields) {
  const existing = getById(id);
  if (!existing) return undefined;
  const merged = { ...existing, ...fields, id };
  db.prepare(
    `UPDATE lessons
     SET student_id = @studentId, date = @date, start_time = @startTime,
         end_time = @endTime, note = @note, amount = @amount, status = @status,
         settled_at = @settledAt
     WHERE id = @id`
  ).run({
    id: merged.id,
    studentId: merged.studentId,
    date: merged.date,
    startTime: merged.startTime,
    endTime: merged.endTime,
    note: merged.note ?? '',
    amount: merged.amount,
    status: merged.status,
    settledAt: merged.settledAt ?? null,
  });
  return getById(id);
}

/// settled=true면 지금 시각을 정산 완료 시점으로 기록하고, false면 해제한다.
function setSettled(id, settled) {
  const existing = getById(id);
  if (!existing) return undefined;
  const settledAt = settled ? new Date().toISOString() : null;
  db.prepare('UPDATE lessons SET settled_at = ? WHERE id = ?').run(settledAt, id);
  return getById(id);
}

function remove(id) {
  const result = db.prepare('DELETE FROM lessons WHERE id = ?').run(id);
  return result.changes > 0;
}

function count() {
  return db.prepare('SELECT COUNT(*) AS n FROM lessons').get().n;
}

module.exports = {
  list,
  listAll,
  listByStudentId,
  getById,
  insert,
  create,
  update,
  setSettled,
  remove,
  count,
  rowToLesson,
};
