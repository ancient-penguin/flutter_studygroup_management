const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, resetDb } = require('./helpers/testApp');
const studentRepository = require('../../src/repositories/studentRepository');
const lessonRepository = require('../../src/repositories/lessonRepository');

test.beforeEach(() => resetDb());

function createStudent() {
  return studentRepository.create({
    name: '김서연',
    initial: '서',
    school: '대성고',
    grade: '고2',
    subject: '영어',
    hourlyRate: 35000,
    schedules: [],
  });
}

test('POST /api/lessons rejects an unknown studentId', async () => {
  const res = await request(app).post('/api/lessons').send({
    studentId: 'does-not-exist',
    date: '2026-09-01',
    startTime: '10:00',
    endTime: '11:00',
    amount: 30000,
  });
  assert.equal(res.status, 400);
  assert.equal(res.body.error, 'Student not found');
});

test('POST /api/lessons creates a lesson for an existing student', async () => {
  const student = createStudent();
  const res = await request(app).post('/api/lessons').send({
    studentId: student.id,
    date: '2026-09-01',
    startTime: '10:00',
    endTime: '11:00',
    amount: 30000,
  });
  assert.equal(res.status, 201);
  assert.equal(res.body.studentId, student.id);
  assert.equal(res.body.status, 'scheduled');
});

test('GET /api/lessons?month=YYYY-MM filters by month', async () => {
  const student = createStudent();
  lessonRepository.create({
    studentId: student.id,
    date: '2026-08-15',
    startTime: '10:00',
    endTime: '11:00',
    amount: 10000,
  });
  lessonRepository.create({
    studentId: student.id,
    date: '2026-09-10',
    startTime: '10:00',
    endTime: '11:00',
    amount: 20000,
  });

  const res = await request(app).get('/api/lessons').query({ month: '2026-09' });
  assert.equal(res.status, 200);
  assert.equal(res.body.length, 1);
  assert.equal(res.body[0].date, '2026-09-10');
});

test('GET /api/lessons rejects a malformed month', async () => {
  const res = await request(app).get('/api/lessons').query({ month: '2026-9' });
  assert.equal(res.status, 400);
});

test('PATCH /api/lessons/:id/settlement sets and clears settledAt', async () => {
  const student = createStudent();
  const lesson = lessonRepository.create({
    studentId: student.id,
    date: '2026-09-01',
    startTime: '10:00',
    endTime: '11:00',
    amount: 30000,
  });

  const settled = await request(app)
    .patch(`/api/lessons/${lesson.id}/settlement`)
    .send({ settled: true });
  assert.equal(settled.status, 200);
  assert.ok(settled.body.settledAt);

  const unsettled = await request(app)
    .patch(`/api/lessons/${lesson.id}/settlement`)
    .send({ settled: false });
  assert.equal(unsettled.status, 200);
  assert.equal(unsettled.body.settledAt, null);
});

test('DELETE /api/lessons/:id removes the lesson', async () => {
  const student = createStudent();
  const lesson = lessonRepository.create({
    studentId: student.id,
    date: '2026-09-01',
    startTime: '10:00',
    endTime: '11:00',
    amount: 30000,
  });

  const del = await request(app).delete(`/api/lessons/${lesson.id}`);
  assert.equal(del.status, 204);

  const get = await request(app).get(`/api/lessons/${lesson.id}`);
  assert.equal(get.status, 404);
});
