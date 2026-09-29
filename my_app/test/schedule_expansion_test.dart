// 주간 반복 규칙이 일정 화면에 제대로 펼쳐지는지 검증하는 순수 단위 테스트.
// 서버가 없어도 돌아갑니다.
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/models/lesson.dart';
import 'package:my_app/models/lesson_schedule.dart';
import 'package:my_app/models/student.dart';
import 'package:my_app/utils/lesson_stats.dart';
import 'package:my_app/utils/schedule_expansion.dart';

Student buildStudent({
  String id = 's1',
  String name = '김서연',
  List<LessonSchedule> schedules = const [],
}) => Student(
  id: id,
  name: name,
  initial: name[0],
  school: '대성고',
  grade: '고2',
  subject: '영어',
  hourlyRate: 35000,
  schedules: schedules,
);

LessonRecord buildLesson({
  String id = 'l1',
  String studentId = 's1',
  required DateTime date,
  String startTime = '19:00',
  String endTime = '21:00',
  int amount = 70000,
  LessonStatus status = LessonStatus.completed,
  DateTime? settledAt,
}) => LessonRecord(
  id: id,
  studentId: studentId,
  date: date,
  startTime: startTime,
  endTime: endTime,
  note: '',
  amount: amount,
  status: status,
  settledAt: settledAt,
);

void main() {
  // 2026-09-29는 화요일.
  final tuesday = DateTime(2026, 9, 29);
  final wednesday = DateTime(2026, 9, 30);

  group('entriesForDate', () {
    test('반복 규칙만 있고 수업 기록이 없으면 가상 일정이 나타난다', () {
      final student = buildStudent(
        schedules: const [LessonSchedule(weekday: 2, startTime: '19:00', durationMin: 120)],
      );

      final entries = entriesForDate(tuesday, [student], []);

      expect(entries, hasLength(1));
      expect(entries.single.isVirtual, isTrue);
      expect(entries.single.studentName, '김서연');
      expect(entries.single.time, '19:00');
      expect(entries.single.durationHours, 2.0);
    });

    test('규칙의 요일이 아닌 날에는 아무것도 나오지 않는다', () {
      final student = buildStudent(
        schedules: const [LessonSchedule(weekday: 2, startTime: '19:00', durationMin: 120)],
      );

      expect(entriesForDate(wednesday, [student], []), isEmpty);
    });

    test('같은 시각에 실제 수업 기록이 있으면 가상 일정은 사라진다 (중복 표시 방지)', () {
      final student = buildStudent(
        schedules: const [LessonSchedule(weekday: 2, startTime: '19:00', durationMin: 120)],
      );
      final lesson = buildLesson(date: tuesday, startTime: '19:00');

      final entries = entriesForDate(tuesday, [student], [lesson]);

      expect(entries, hasLength(1));
      expect(entries.single.isVirtual, isFalse);
      expect(entries.single.lessonId, 'l1');
    });

    test('같은 날 다른 시각의 수업은 가상 일정과 함께 둘 다 보인다', () {
      final student = buildStudent(
        schedules: const [LessonSchedule(weekday: 2, startTime: '19:00', durationMin: 120)],
      );
      final extra = buildLesson(id: 'l2', date: tuesday, startTime: '09:00', endTime: '10:00');

      final entries = entriesForDate(tuesday, [student], [extra]);

      expect(entries, hasLength(2));
      // 시작 시각 순으로 정렬된다.
      expect(entries.first.time, '09:00');
      expect(entries.first.isVirtual, isFalse);
      expect(entries.last.time, '19:00');
      expect(entries.last.isVirtual, isTrue);
    });

    test('다른 날짜의 수업 기록은 섞여 들어오지 않는다', () {
      final student = buildStudent();
      final otherDay = buildLesson(date: wednesday);

      expect(entriesForDate(tuesday, [student], [otherDay]), isEmpty);
    });

    test('여러 학생의 규칙이 모두 같은 날에 모인다', () {
      final a = buildStudent(
        id: 's1',
        name: '김서연',
        schedules: const [LessonSchedule(weekday: 2, startTime: '19:00', durationMin: 120)],
      );
      final b = buildStudent(
        id: 's2',
        name: '박준호',
        schedules: const [LessonSchedule(weekday: 2, startTime: '21:00', durationMin: 90)],
      );

      final entries = entriesForDate(tuesday, [a, b], []);

      expect(entries.map((e) => e.studentName), ['김서연', '박준호']);
    });
  });

  group('startOfWeek / weekDays', () {
    test('주는 항상 월요일에서 시작한다', () {
      // 2026-09-29(화)가 속한 주의 월요일은 2026-09-28.
      expect(startOfWeek(tuesday), DateTime(2026, 9, 28));
      // 일요일에도 그 주의 월요일을 돌려준다.
      expect(startOfWeek(DateTime(2026, 10, 4)), DateTime(2026, 9, 28));
    });

    test('weekDays는 월요일부터 7일을 돌려준다', () {
      final days = weekDays(startOfWeek(tuesday));
      expect(days, hasLength(7));
      expect(days.first, DateTime(2026, 9, 28));
      expect(days.last, DateTime(2026, 10, 4));
      expect(days.first.weekday, DateTime.monday);
    });
  });

  group('StudentSettlement', () {
    test('휴강(canceled)은 금액과 시간에서 빠진다', () {
      final lessons = [
        buildLesson(id: 'l1', date: tuesday, amount: 70000),
        buildLesson(
          id: 'l2',
          date: wednesday,
          amount: 0,
          status: LessonStatus.canceled,
        ),
      ];

      final settlement = StudentSettlement.from(lessons);

      // 횟수는 2건 모두 세지만, 금액과 시간은 정산 대상만 더한다.
      expect(settlement.lessonCount, 2);
      expect(settlement.totalAmount, 70000);
      expect(settlement.totalHours, 2.0);
    });

    test('결석(noShow)은 부과된 금액이 정산에 포함된다', () {
      final lessons = [
        buildLesson(id: 'l1', date: tuesday, amount: 70000),
        buildLesson(
          id: 'l2',
          date: wednesday,
          amount: 70000,
          status: LessonStatus.noShow,
        ),
      ];

      final settlement = StudentSettlement.from(lessons);

      // 결석은 휴강과 달리 노쇼로 부과되므로 금액·시간 모두 합산된다.
      expect(settlement.lessonCount, 2);
      expect(settlement.totalAmount, 140000);
      expect(settlement.totalHours, 4.0);
    });

    test('수업이 없으면 미정산이 아니라 내역 없음이다', () {
      final settlement = StudentSettlement.from([]);
      expect(settlement.isEmpty, isTrue);
      expect(settlement.statusLabel, '내역 없음');
    });

    test('정산 대상이 모두 settledAt을 가져야 완료로 본다', () {
      final settledAt = DateTime(2026, 10, 1);
      expect(
        StudentSettlement.from([
          buildLesson(id: 'l1', date: tuesday, settledAt: settledAt),
          buildLesson(id: 'l2', date: wednesday),
        ]).settled,
        isFalse,
      );
      expect(
        StudentSettlement.from([
          buildLesson(id: 'l1', date: tuesday, settledAt: settledAt),
          buildLesson(id: 'l2', date: wednesday, settledAt: settledAt),
        ]).settled,
        isTrue,
      );
    });
  });

  group('lessonsInMonth / lessonsInWeek', () {
    test('월 필터는 해당 월만 남긴다', () {
      final lessons = [
        buildLesson(id: 'l1', date: DateTime(2026, 9, 29)),
        buildLesson(id: 'l2', date: DateTime(2026, 10, 1)),
      ];
      expect(lessonsInMonth(lessons, DateTime(2026, 9)).map((l) => l.id), ['l1']);
      expect(lessonsInMonth(lessons, DateTime(2026, 10)).map((l) => l.id), ['l2']);
    });

    test('주 필터는 월요일~일요일 경계를 포함한다', () {
      final weekStart = DateTime(2026, 9, 28); // 월
      final lessons = [
        buildLesson(id: 'mon', date: DateTime(2026, 9, 28)),
        buildLesson(id: 'sun', date: DateTime(2026, 10, 4)),
        buildLesson(id: 'next', date: DateTime(2026, 10, 5)),
      ];
      expect(lessonsInWeek(lessons, weekStart).map((l) => l.id), ['mon', 'sun']);
    });
  });

  group('Student 계산 게터', () {
    test('scheduleDaysLabel은 규칙에서 생성된다', () {
      final student = buildStudent(
        schedules: const [
          LessonSchedule(weekday: 5, startTime: '20:00', durationMin: 60),
          LessonSchedule(weekday: 1, startTime: '20:00', durationMin: 60),
          LessonSchedule(weekday: 3, startTime: '20:00', durationMin: 60),
        ],
      );
      expect(student.scheduleDaysLabel, '월·수·금');
    });

    test('nextLessonAt은 기준 시각 이후 가장 가까운 수업을 찾는다', () {
      final student = buildStudent(
        schedules: const [
          LessonSchedule(weekday: 2, startTime: '19:00', durationMin: 120),
          LessonSchedule(weekday: 4, startTime: '19:00', durationMin: 120),
        ],
      );
      // 2026-09-28 월요일 낮 -> 다음은 화요일 19:00
      expect(student.nextLessonAt(DateTime(2026, 9, 28, 12)), DateTime(2026, 9, 29, 19));
      // 화요일 20:00(수업 시작 후) -> 다음은 목요일 19:00
      expect(student.nextLessonAt(DateTime(2026, 9, 29, 20)), DateTime(2026, 10, 1, 19));
    });

    test('규칙이 없으면 다음 수업 라벨은 빈 문자열', () {
      expect(buildStudent().nextLessonLabel(DateTime(2026, 9, 28)), '');
    });
  });

  test('LessonSchedule.endTime은 길이를 더해 계산한다', () {
    expect(
      const LessonSchedule(weekday: 1, startTime: '18:00', durationMin: 90).endTime,
      '19:30',
    );
    expect(
      const LessonSchedule(weekday: 1, startTime: '23:30', durationMin: 60).endTime,
      '00:30',
    );
  });
}
