process.env.DB_PATH = ':memory:';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  toIsoDate,
  addMinutes,
  recentDatesForWeekday,
  buildSeedLessons,
} = require('../../src/seed');

test('toIsoDate formats a Date as YYYY-MM-DD', () => {
  assert.equal(toIsoDate(new Date(2026, 8, 5)), '2026-09-05');
});

test('addMinutes rolls over the hour', () => {
  assert.equal(addMinutes('18:30', 90), '20:00');
});

test('addMinutes wraps past midnight', () => {
  assert.equal(addMinutes('23:30', 60), '00:30');
});

test('recentDatesForWeekday returns past dates only, matching the requested weekday', () => {
  // 2026-09-30 is a Wednesday (weekday=3 in Dart's 1=Mon..7=Sun convention)
  const today = new Date(2026, 8, 30);
  const dates = recentDatesForWeekday(3, 2, today);
  assert.equal(dates.length, 2);
  for (const date of dates) {
    assert.ok(date < today);
    assert.equal(date.getDay(), 3 % 7);
  }
});

test('buildSeedLessons returns at most 3 lessons sorted by date', () => {
  const lessons = buildSeedLessons(new Date(2026, 8, 30));
  assert.ok(lessons.length <= 3);
  const dates = lessons.map((l) => l.date);
  assert.deepEqual(dates, [...dates].sort());
  for (const lesson of lessons) {
    assert.equal(lesson.studentId, 's1');
    assert.equal(lesson.status, 'completed');
  }
});
