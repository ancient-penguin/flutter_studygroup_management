import '../models/lesson.dart';
import '../models/lesson_schedule.dart';
import '../models/schedule_entry.dart';
import '../models/student.dart';
import 'schedule_expansion.dart';

int _toMinutes(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.first) ?? 0;
  final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  return h * 60 + m;
}

/// [startA, startA+durationMinA)와 [startB, startB+durationMinB)가 겹치는지.
bool rangesOverlap(String startA, int durationMinA, String startB, int durationMinB) {
  final aStart = _toMinutes(startA);
  final aEnd = aStart + durationMinA;
  final bStart = _toMinutes(startB);
  final bEnd = bStart + durationMinB;
  return aStart < bEnd && bStart < aEnd;
}

/// 반복 스케줄 등록 시 부딪히는 다른 학생의 반복 규칙 한 건.
class ScheduleConflict {
  final String studentName;
  final LessonSchedule schedule;
  const ScheduleConflict(this.studentName, this.schedule);
}

/// [candidate]와 같은 요일에, [excludeStudentId]를 제외한 다른 학생들의 반복
/// 규칙 중 시간이 겹치는 것을 모두 찾는다.
List<ScheduleConflict> findRecurringConflicts({
  required LessonSchedule candidate,
  required List<Student> allStudents,
  String? excludeStudentId,
}) {
  final conflicts = <ScheduleConflict>[];
  for (final student in allStudents) {
    if (student.id == excludeStudentId) continue;
    for (final schedule in student.schedules) {
      if (schedule.weekday != candidate.weekday) continue;
      if (rangesOverlap(
        candidate.startTime,
        candidate.durationMin,
        schedule.startTime,
        schedule.durationMin,
      )) {
        conflicts.add(ScheduleConflict(student.name, schedule));
      }
    }
  }
  return conflicts;
}

/// [date]의 [startTime]~[startTime]+[durationMin]과 겹치는, 취소되지 않은
/// 기존 일정(실제 레슨 또는 아직 확정 안 된 반복 스케줄)을 모두 찾는다.
/// [excludeLessonId]는 수정 중인 레슨 자기 자신을 제외하기 위한 것이다.
List<ScheduleEntry> findLessonConflicts({
  required DateTime date,
  required String startTime,
  required int durationMin,
  required List<Student> allStudents,
  required List<LessonRecord> allLessons,
  String? excludeLessonId,
}) {
  final entries = entriesForDate(date, allStudents, allLessons);
  return entries.where((entry) {
    if (excludeLessonId != null && entry.lessonId == excludeLessonId) return false;
    if (entry.status == LessonStatus.canceled) return false;
    return rangesOverlap(startTime, durationMin, entry.time, entry.durationMin);
  }).toList();
}
