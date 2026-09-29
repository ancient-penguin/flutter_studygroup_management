process.env.DB_PATH = ':memory:';

const test = require('node:test');
const assert = require('node:assert/strict');
const studentRepository = require('../../src/repositories/studentRepository');
const { monthRange, validateLesson } = require('../../src/routes/lessons');

test('monthRange builds YYYY-MM-01 ~ YYYY-MM-31 boundaries', () => {
  assert.deepEqual(monthRange('2026-09'), { from: '2026-09-01', to: '2026-09-31' });
});

test('validateLesson requires studentId/date/startTime/endTime/amount on create', () => {
  const error = validateLesson({});
  assert.match(error, /required/);
});

test('validateLesson allows partial body when partial:true', () => {
  const error = validateLesson({}, { partial: true });
  assert.equal(error, null);
});

test('validateLesson rejects unknown studentId', (t) => {
  t.mock.method(studentRepository, 'getById', () => undefined);
  const error = validateLesson({
    studentId: 'missing',
    date: '2026-09-01',
    startTime: '10:00',
    endTime: '11:00',
    amount: 1000,
  });
  assert.equal(error, 'Student not found');
});

test('validateLesson rejects malformed date', (t) => {
  t.mock.method(studentRepository, 'getById', () => ({ id: 's1' }));
  const error = validateLesson({
    studentId: 's1',
    date: '2026/09/01',
    startTime: '10:00',
    endTime: '11:00',
    amount: 1000,
  });
  assert.equal(error, 'date must be YYYY-MM-DD');
});

test('validateLesson rejects malformed startTime/endTime', (t) => {
  t.mock.method(studentRepository, 'getById', () => ({ id: 's1' }));
  const error = validateLesson({
    studentId: 's1',
    date: '2026-09-01',
    startTime: '9:00',
    endTime: '11:00',
    amount: 1000,
  });
  assert.equal(error, 'startTime must be HH:mm');
});

test('validateLesson rejects endTime not after startTime', (t) => {
  t.mock.method(studentRepository, 'getById', () => ({ id: 's1' }));
  const error = validateLesson({
    studentId: 's1',
    date: '2026-09-01',
    startTime: '11:00',
    endTime: '10:00',
    amount: 1000,
  });
  assert.equal(error, 'endTime must be after startTime');
});

test('validateLesson rejects negative amount', (t) => {
  t.mock.method(studentRepository, 'getById', () => ({ id: 's1' }));
  const error = validateLesson({
    studentId: 's1',
    date: '2026-09-01',
    startTime: '10:00',
    endTime: '11:00',
    amount: -1,
  });
  assert.equal(error, 'amount must be a non-negative number');
});

test('validateLesson rejects unknown status', (t) => {
  t.mock.method(studentRepository, 'getById', () => ({ id: 's1' }));
  const error = validateLesson({
    studentId: 's1',
    date: '2026-09-01',
    startTime: '10:00',
    endTime: '11:00',
    amount: 1000,
    status: 'bogus',
  });
  assert.match(error, /status must be one of/);
});

test('validateLesson accepts a fully valid lesson', (t) => {
  t.mock.method(studentRepository, 'getById', () => ({ id: 's1' }));
  const error = validateLesson({
    studentId: 's1',
    date: '2026-09-01',
    startTime: '10:00',
    endTime: '11:00',
    amount: 1000,
    status: 'scheduled',
  });
  assert.equal(error, null);
});
