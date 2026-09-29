process.env.DB_PATH = ':memory:';

const test = require('node:test');
const assert = require('node:assert/strict');
const lessonRepository = require('../../src/repositories/lessonRepository');
const studentRepository = require('../../src/repositories/studentRepository');

test('rowToLesson returns undefined for a falsy row', () => {
  assert.equal(lessonRepository.rowToLesson(undefined), undefined);
});

test('rowToLesson maps snake_case columns to camelCase', () => {
  const row = {
    id: 'l1',
    student_id: 's1',
    date: '2026-09-01',
    start_time: '10:00',
    end_time: '11:00',
    note: '메모',
    amount: 30000,
    status: 'completed',
    settled_at: null,
  };
  assert.deepEqual(lessonRepository.rowToLesson(row), {
    id: 'l1',
    studentId: 's1',
    date: '2026-09-01',
    startTime: '10:00',
    endTime: '11:00',
    note: '메모',
    amount: 30000,
    status: 'completed',
    settledAt: null,
  });
});

test('rowToSchedule maps snake_case columns to camelCase', () => {
  const row = { id: 'sc1', weekday: 2, start_time: '19:00', duration_min: 120 };
  assert.deepEqual(studentRepository.rowToSchedule(row), {
    id: 'sc1',
    weekday: 2,
    startTime: '19:00',
    durationMin: 120,
  });
});

test('rowToStudent returns undefined for a falsy row', () => {
  assert.equal(studentRepository.rowToStudent(undefined), undefined);
});
