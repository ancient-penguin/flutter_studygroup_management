import 'lesson.dart';
import 'lesson_schedule.dart';
import 'student.dart';
import '../utils/lesson_stats.dart';

/// 일정 화면의 타임라인 한 칸.
///
/// 두 가지 출처가 있습니다:
///  - 실제 수업 기록(LessonRecord) -> isVirtual=false, lessonId 있음
///  - 학생의 주간 반복 규칙을 그 날짜로 펼친 것 -> isVirtual=true, lessonId 없음
/// 가상 엔트리는 DB에 없고, 탭해서 확정하면 그때 실제 수업으로 저장됩니다.
class ScheduleEntry {
  final DateTime date;
  final String time;
  final double durationHours;
  final String studentName;
  final String subtitle;
  final LessonStatus status;
  final bool isVirtual;
  final String? lessonId;
  final String? studentId;
  final int durationMin;

  const ScheduleEntry({
    required this.date,
    required this.time,
    required this.durationHours,
    required this.studentName,
    required this.subtitle,
    required this.status,
    this.isVirtual = false,
    this.lessonId,
    this.studentId,
    this.durationMin = 0,
  });

  factory ScheduleEntry.fromLesson(LessonRecord lesson, Student? student) => ScheduleEntry(
    date: lesson.date,
    time: lesson.startTime,
    durationHours: lessonDurationHours(lesson),
    studentName: student?.name ?? '알 수 없는 학생',
    subtitle: student == null
        ? (lesson.note.isEmpty ? '학생 정보 없음' : lesson.note)
        : '${student.subject} · ${student.grade}${lesson.note.isEmpty ? '' : ' · ${lesson.note}'}',
    status: lesson.status,
    isVirtual: false,
    lessonId: lesson.id,
    studentId: lesson.studentId,
    durationMin: (lessonDurationHours(lesson) * 60).round(),
  );

  /// 반복 규칙을 특정 날짜로 펼친 가상 엔트리.
  factory ScheduleEntry.fromSchedule(
    LessonSchedule schedule,
    Student student,
    DateTime date,
  ) => ScheduleEntry(
    date: date,
    time: schedule.startTime,
    durationHours: schedule.durationHours,
    studentName: student.name,
    subtitle: '${student.subject} · ${student.grade} · 반복 일정',
    status: LessonStatus.scheduled,
    isVirtual: true,
    studentId: student.id,
    durationMin: schedule.durationMin,
  );
}
