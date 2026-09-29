const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, resetDb } = require('./helpers/testApp');
const studentRepository = require('../../src/repositories/studentRepository');

test.beforeEach(() => resetDb());

test('POST /api/students creates a student with schedules', async () => {
  const res = await request(app)
    .post('/api/students')
    .send({
      name: '홍길동',
      initial: '홍',
      school: '테스트고',
      grade: '고1',
      subject: '수학',
      hourlyRate: 30000,
      schedules: [{ weekday: 1, startTime: '18:00', durationMin: 90 }],
    });

  assert.equal(res.status, 201);
  assert.equal(res.body.name, '홍길동');
  assert.equal(res.body.schedules.length, 1);
  assert.equal(res.body.schedules[0].startTime, '18:00');
});

test('POST /api/students rejects a missing required field', async () => {
  const res = await request(app).post('/api/students').send({ name: '홍길동' });
  assert.equal(res.status, 400);
  assert.match(res.body.error, /required/);
});

test('GET /api/students/:id returns 404 for unknown id', async () => {
  const res = await request(app).get('/api/students/does-not-exist');
  assert.equal(res.status, 404);
});

test('GET /api/students/:id returns an existing student', async () => {
  const created = studentRepository.create({
    name: '김서연',
    initial: '서',
    school: '대성고',
    grade: '고2',
    subject: '영어',
    hourlyRate: 35000,
    schedules: [],
  });

  const res = await request(app).get(`/api/students/${created.id}`);
  assert.equal(res.status, 200);
  assert.equal(res.body.id, created.id);
  assert.equal(res.body.name, '김서연');
});

test('PUT /api/students/:id partially updates without touching schedules when omitted', async () => {
  const created = studentRepository.create({
    name: '김서연',
    initial: '서',
    school: '대성고',
    grade: '고2',
    subject: '영어',
    hourlyRate: 35000,
    schedules: [{ weekday: 2, startTime: '19:00', durationMin: 120 }],
  });

  const res = await request(app)
    .put(`/api/students/${created.id}`)
    .send({ hourlyRate: 40000 });

  assert.equal(res.status, 200);
  assert.equal(res.body.hourlyRate, 40000);
  assert.equal(res.body.schedules.length, 1);
  assert.equal(res.body.schedules[0].startTime, '19:00');
});

test('DELETE /api/students/:id removes the student', async () => {
  const created = studentRepository.create({
    name: '삭제될학생',
    initial: '삭',
    school: '테스트고',
    grade: '고1',
    subject: '수학',
    hourlyRate: 20000,
    schedules: [],
  });

  const del = await request(app).delete(`/api/students/${created.id}`);
  assert.equal(del.status, 204);

  const get = await request(app).get(`/api/students/${created.id}`);
  assert.equal(get.status, 404);
});
