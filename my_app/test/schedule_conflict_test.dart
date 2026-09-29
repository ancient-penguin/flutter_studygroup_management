// 다른 학생/일정과의 시간 겹침 감지가 올바른지 검증하는 순수 단위 테스트.
// 서버가 없어도 돌아갑니다.
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/models/lesson.dart';
import 'package:my_app/models/lesson_schedule.dart';
import 'package:my_app/models/student.dart';
import 'package:my_app/utils/schedule_conflict.dart';

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
}) => LessonRecord(
  id: id,
  studentId: studentId,
  date: date,
  startTime: startTime,
  endTime: endTime,
  note: '',
  amount: amount,
  status: status,
);

void main() {
  // 2026-09-29는 화요일.
  final tuesday = DateTime(2026, 9, 29);

  group('rangesOverlap', () {
    test('겹치는 구간은 true', () {
      expect(rangesOverlap('19:00', 120, '20:00', 60), isTrue);
    });

    test('맞닿기만 하고 겹치지 않으면 false', () {
      expect(rangesOverlap('18:00', 60, '19:00', 60), isFalse);
    });

    test('완전히 떨어진 구간은 false', () {
      expect(rangesOverlap('09:00', 60, '19:00', 60), isFalse);
    });
  });

  group('findRecurringConflicts', () {
    test('다른 학생의 같은 요일·겹치는 시간을 찾는다', () {
      final a = buildStudent(
        id: 's1',
        name: '김서연',
        schedules: const [LessonSchedule(weekday: 2, startTime: '19:00', durationMin: 120)],
      );
      final b = buildStudent(id: 's2', name: '박준호');

      final conflicts = findRecurringConflicts(
        candidate: const LessonSchedule(weekday: 2, startTime: '20:00', durationMin: 60),
        allStudents: [a, b],
        excludeStudentId: 's2',
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.single.studentName, '김서연');
    });

    test('자기 자신(excludeStudentId)은 충돌로 잡지 않는다', () {
      final a = buildStudent(
        id: 's1',
        schedules: const [LessonSchedule(weekday: 2, startTime: '19:00', durationMin: 120)],
      );

      final conflicts = findRecurringConflicts(
        candidate: const LessonSchedule(weekday: 2, startTime: '19:30', durationMin: 60),
        allStudents: [a],
        excludeStudentId: 's1',
      );

      expect(conflicts, isEmpty);
    });

    test('요일이 다르면 시간이 겹쳐도 충돌이 아니다', () {
      final a = buildStudent(
        schedules: const [LessonSchedule(weekday: 3, startTime: '19:00', durationMin: 120)],
      );

      final conflicts = findRecurringConflicts(
        candidate: const LessonSchedule(weekday: 2, startTime: '19:00', durationMin: 120),
        allStudents: [a],
      );

      expect(conflicts, isEmpty);
    });
  });

  group('findLessonConflicts', () {
    test('같은 날 다른 학생의 실제 레슨과 겹치면 찾는다', () {
      final lesson = buildLesson(id: 'l1', studentId: 's1', date: tuesday, startTime: '19:00', endTime: '21:00');

      final conflicts = findLessonConflicts(
        date: tuesday,
        startTime: '20:00',
        durationMin: 60,
        allStudents: [buildStudent(id: 's1')],
        allLessons: [lesson],
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.single.lessonId, 'l1');
    });

    test('취소(canceled)된 레슨은 충돌로 보지 않는다', () {
      final lesson = buildLesson(
        id: 'l1',
        date: tuesday,
        startTime: '19:00',
        endTime: '21:00',
        status: LessonStatus.canceled,
      );

      final conflicts = findLessonConflicts(
        date: tuesday,
        startTime: '20:00',
        durationMin: 60,
        allStudents: [buildStudent()],
        allLessons: [lesson],
      );

      expect(conflicts, isEmpty);
    });

    test('수정 중인 레슨 자기 자신은 excludeLessonId로 제외된다', () {
      final lesson = buildLesson(id: 'l1', date: tuesday, startTime: '19:00', endTime: '21:00');

      final conflicts = findLessonConflicts(
        date: tuesday,
        startTime: '19:00',
        durationMin: 120,
        allStudents: [buildStudent()],
        allLessons: [lesson],
        excludeLessonId: 'l1',
      );

      expect(conflicts, isEmpty);
    });

    test('다른 학생의 아직 확정 안 된 반복 스케줄과도 겹치면 찾는다', () {
      final student = buildStudent(
        id: 's2',
        name: '박준호',
        schedules: const [LessonSchedule(weekday: 2, startTime: '20:00', durationMin: 90)],
      );

      final conflicts = findLessonConflicts(
        date: tuesday,
        startTime: '20:30',
        durationMin: 60,
        allStudents: [student],
        allLessons: const [],
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.single.isVirtual, isTrue);
      expect(conflicts.single.studentName, '박준호');
    });
  });
}
