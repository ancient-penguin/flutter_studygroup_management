const crypto = require('node:crypto');
const studentRepository = require('./repositories/studentRepository');
const lessonRepository = require('./repositories/lessonRepository');

// weekday: 1=월 ... 7=일 (Dart DateTime.weekday와 동일)
const seedStudents = [
  {
    id: 's1',
    name: '김서연',
    initial: '서',
    school: '대성고',
    grade: '고2',
    subject: '영어',
    hourlyRate: 35000,
    schedules: [
      { weekday: 2, startTime: '19:00', durationMin: 120 },
      { weekday: 4, startTime: '19:00', durationMin: 120 },
    ],
  },
  {
    id: 's2',
    name: '박준호',
    initial: '준',
    school: '한빛중',
    grade: '중3',
    subject: '수학',
    hourlyRate: 30000,
    schedules: [
      { weekday: 2, startTime: '21:00', durationMin: 90 },
      { weekday: 4, startTime: '21:00', durationMin: 90 },
    ],
  },
  {
    id: 's3',
    name: '이민재',
    initial: '민',
    school: '경신고',
    grade: '고1',
    subject: '영어',
    hourlyRate: 30000,
    schedules: [{ weekday: 3, startTime: '17:00', durationMin: 90 }],
  },
  {
    id: 's4',
    name: '최하은',
    initial: '하',
    school: '숭덕중',
    grade: '중2',
    subject: '수학',
    hourlyRate: 28000,
    schedules: [
      { weekday: 2, startTime: '18:00', durationMin: 90 },
      { weekday: 4, startTime: '18:00', durationMin: 90 },
    ],
  },
  {
    id: 's5',
    name: '정지우',
    initial: '지',
    school: '풍문고',
    grade: '고3',
    subject: '영어',
    hourlyRate: 40000,
    schedules: [
      { weekday: 1, startTime: '20:00', durationMin: 120 },
      { weekday: 3, startTime: '20:00', durationMin: 120 },
      { weekday: 5, startTime: '20:00', durationMin: 120 },
    ],
  },
];

function toIsoDate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function addMinutes(hhmm, minutes) {
  const [h, m] = hhmm.split(':').map(Number);
  const total = h * 60 + m + minutes;
  const hh = String(Math.floor(total / 60) % 24).padStart(2, '0');
  const mm = String(total % 60).padStart(2, '0');
  return `${hh}:${mm}`;
}

/// today 이전에서 해당 요일이 나타난 가장 최근 날짜들을 count개 돌려준다.
function recentDatesForWeekday(weekday, count, today) {
  const dates = [];
  const cursor = new Date(today);
  cursor.setDate(cursor.getDate() - 1); // 오늘은 제외하고 과거만
  while (dates.length < count) {
    if (cursor.getDay() === weekday % 7) dates.push(new Date(cursor));
    cursor.setDate(cursor.getDate() - 1);
  }
  return dates;
}

/// 시드 수업은 김서연(s1)의 반복 규칙을 과거로 되짚어 생성한다.
/// 고정 날짜를 박아두면 언제 시드하든 일정 화면이 비어 보이므로 오늘 기준으로 만든다.
function buildSeedLessons(today) {
  const student = seedStudents[0];
  const notes = ['수능특강 Unit 7 독해', '모의고사 오답 정리', '어법 특강 · 분사구문'];
  const lessons = [];

  for (const schedule of student.schedules) {
    for (const date of recentDatesForWeekday(schedule.weekday, 2, today)) {
      lessons.push({
        studentId: student.id,
        date: toIsoDate(date),
        startTime: schedule.startTime,
        endTime: addMinutes(schedule.startTime, schedule.durationMin),
        note: notes[lessons.length % notes.length],
        amount: Math.round((student.hourlyRate * schedule.durationMin) / 60),
        status: 'completed',
      });
    }
  }
  return lessons.sort((a, b) => a.date.localeCompare(b.date)).slice(0, 3);
}

function seedIfEmpty() {
  if (studentRepository.count() > 0) return false;

  for (const student of seedStudents) {
    studentRepository.insert(student);
  }
  for (const lesson of buildSeedLessons(new Date())) {
    lessonRepository.insert({ id: crypto.randomUUID(), ...lesson });
  }
  return true;
}

if (require.main === module) {
  const seeded = seedIfEmpty();
  console.log(seeded ? 'Seeded database.' : 'Database already has data; skipped seeding.');
}

module.exports = {
  seedIfEmpty,
  toIsoDate,
  addMinutes,
  recentDatesForWeekday,
  buildSeedLessons,
};
