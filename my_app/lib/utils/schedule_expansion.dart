import '../models/lesson.dart';
import '../models/schedule_entry.dart';
import '../models/student.dart';

/// 해당 날짜에 보여줄 일정 = 실제 수업 기록 + (아직 기록되지 않은) 주간 반복 규칙.
///
/// 이 함수가 학생 등록 때 고른 요일과 일정 화면을 잇는 유일한 지점입니다.
/// 반복 규칙을 DB에 미리 수업으로 만들어두지 않고 조회 시점에 펼치므로,
/// 요일을 바꿔도 과거 기록은 그대로 남고 미래 표시만 달라집니다.
List<ScheduleEntry> entriesForDate(
  DateTime date,
  List<Student> students,
  List<LessonRecord> lessons,
) {
  final studentsById = {for (final s in students) s.id: s};

  final dayLessons = lessons.where((l) => l.isOn(date)).toList();
  final entries = dayLessons
      .map((l) => ScheduleEntry.fromLesson(l, studentsById[l.studentId]))
      .toList();

  // 이미 실제 기록이 있는 (학생, 시작시각) 조합은 가상으로 또 띄우지 않는다.
  final taken = dayLessons.map((l) => '${l.studentId}@${l.startTime}').toSet();

  for (final student in students) {
    for (final schedule in student.schedules) {
      if (schedule.weekday != date.weekday) continue;
      if (taken.contains('${student.id}@${schedule.startTime}')) continue;
      entries.add(ScheduleEntry.fromSchedule(schedule, student, date));
    }
  }

  entries.sort((a, b) => a.time.compareTo(b.time));
  return entries;
}

/// date가 속한 주의 월요일.
DateTime startOfWeek(DateTime date) {
  final d = dateOnly(date);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// weekStart부터 7일.
List<DateTime> weekDays(DateTime weekStart) =>
    List.generate(7, (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i));
