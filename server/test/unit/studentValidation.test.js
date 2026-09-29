process.env.DB_PATH = ':memory:';

const test = require('node:test');
const assert = require('node:assert/strict');
const { validateSchedules, validateStudent } = require('../../src/routes/students');

test('validateSchedules accepts undefined (no change)', () => {
  assert.equal(validateSchedules(undefined), null);
});

test('validateSchedules rejects non-array', () => {
  assert.equal(validateSchedules('nope'), 'schedules must be an array');
});

test('validateSchedules rejects out-of-range weekday', () => {
  const error = validateSchedules([{ weekday: 8, startTime: '10:00', durationMin: 60 }]);
  assert.equal(error, 'schedules[].weekday must be an integer 1-7');
});

test('validateSchedules rejects malformed startTime', () => {
  const error = validateSchedules([{ weekday: 1, startTime: '9:00', durationMin: 60 }]);
  assert.equal(error, 'schedules[].startTime must be HH:mm');
});

test('validateSchedules rejects non-positive durationMin', () => {
  const error = validateSchedules([{ weekday: 1, startTime: '09:00', durationMin: 0 }]);
  assert.equal(error, 'schedules[].durationMin must be a positive integer');
});

test('validateSchedules accepts a valid list', () => {
  const error = validateSchedules([{ weekday: 1, startTime: '09:00', durationMin: 60 }]);
  assert.equal(error, null);
});

test('validateStudent requires name/subject/hourlyRate on create', () => {
  const error = validateStudent({});
  assert.match(error, /required/);
});

test('validateStudent allows partial body when partial:true', () => {
  const error = validateStudent({}, { partial: true });
  assert.equal(error, null);
});

test('validateStudent rejects negative hourlyRate', () => {
  const error = validateStudent({
    name: '홍길동',
    initial: '홍',
    school: '테스트고',
    grade: '고1',
    subject: '수학',
    hourlyRate: -1,
  });
  assert.equal(error, 'hourlyRate must be a non-negative number');
});

test('validateStudent delegates schedules validation', () => {
  const error = validateStudent({
    name: '홍길동',
    initial: '홍',
    school: '테스트고',
    grade: '고1',
    subject: '수학',
    hourlyRate: 30000,
    schedules: [{ weekday: 9, startTime: '09:00', durationMin: 60 }],
  });
  assert.equal(error, 'schedules[].weekday must be an integer 1-7');
});

test('validateStudent accepts a fully valid student', () => {
  const error = validateStudent({
    name: '홍길동',
    initial: '홍',
    school: '테스트고',
    grade: '고1',
    subject: '수학',
    hourlyRate: 30000,
    schedules: [{ weekday: 1, startTime: '09:00', durationMin: 60 }],
  });
  assert.equal(error, null);
});
