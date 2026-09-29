import 'lesson_schedule.dart';

/// 학생 모델. 서버의 students 테이블 + student_schedules를 함께 담습니다.
class Student {
  final String id;
  final String name;
  final String initial; // 아바타에 쓰는 이름 첫 글자
  final String school;
  final String grade;
  final String subject;
  final int hourlyRate;

  /// 주간 반복 수업 규칙. 예전의 scheduleDays/nextLessonLabel 문자열을 대체합니다.
  final List<LessonSchedule> schedules;

  const Student({
    required this.id,
    required this.name,
    required this.initial,
    required this.school,
    required this.grade,
    required this.subject,
    required this.hourlyRate,
    this.schedules = const [],
  });

  /// "월·수·금". 저장된 값이 아니라 규칙에서 매번 생성하므로 낡을 수가 없습니다.
  String get scheduleDaysLabel {
    final weekdays = schedules.map((s) => s.weekday).toSet().toList()..sort();
    return weekdays.map((w) => LessonSchedule.weekdayLabels[w - 1]).join('·');
  }

  /// from 이후 가장 먼저 돌아오는 반복 수업 시각. 규칙이 없으면 null.
  DateTime? nextLessonAt(DateTime from) {
    if (schedules.isEmpty) return null;
    DateTime? best;
    for (final s in schedules) {
      final parts = s.startTime.split(':');
      final h = int.tryParse(parts.first) ?? 0;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      // 오늘부터 7일을 훑어 해당 요일의 다음 발생을 찾는다.
      for (var i = 0; i <= 7; i++) {
        final day = DateTime(from.year, from.month, from.day + i);
        if (day.weekday != s.weekday) continue;
        final at = DateTime(day.year, day.month, day.day, h, m);
        if (at.isBefore(from)) continue;
        if (best == null || at.isBefore(best)) best = at;
        break;
      }
    }
    return best;
  }

  /// "화 19:00". 다음 수업이 없으면 빈 문자열.
  String nextLessonLabel(DateTime from) {
    final at = nextLessonAt(from);
    if (at == null) return '';
    final label = LessonSchedule.weekdayLabels[at.weekday - 1];
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '$label $hh:$mm';
  }

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['id'] as String,
    name: json['name'] as String,
    initial: json['initial'] as String,
    school: json['school'] as String,
    grade: json['grade'] as String,
    subject: json['subject'] as String,
    hourlyRate: json['hourlyRate'] as int,
    schedules: ((json['schedules'] as List?) ?? const [])
        .map((e) => LessonSchedule.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'initial': initial,
    'school': school,
    'grade': grade,
    'subject': subject,
    'hourlyRate': hourlyRate,
    'schedules': schedules.map((s) => s.toJson()).toList(),
  };
}
