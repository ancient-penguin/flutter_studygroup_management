/// 학생의 주간 반복 수업 규칙. 서버의 student_schedules 테이블과 1:1로 대응합니다.
///
/// 예전 Student.scheduleDays("월·수·금")는 표시용 문자열이라 요일만 있고 시간이 없었고,
/// 그래서 일정으로 펼칠 수가 없었습니다. 이 모델은 요일 + 시작 시각 + 길이를 함께 가집니다.
class LessonSchedule {
  final String? id;
  final int weekday; // 1=월 ... 7=일 (DateTime.weekday와 동일)
  final String startTime; // "18:00"
  final int durationMin;

  const LessonSchedule({
    this.id,
    required this.weekday,
    required this.startTime,
    required this.durationMin,
  });

  static const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  String get weekdayLabel => weekdayLabels[weekday - 1];

  /// startTime + durationMin. 자정을 넘기면 24시간으로 감싸 "00:30" 형태가 됩니다.
  String get endTime {
    final parts = startTime.split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final total = h * 60 + m + durationMin;
    final hh = ((total ~/ 60) % 24).toString().padLeft(2, '0');
    final mm = (total % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  double get durationHours => durationMin / 60;

  LessonSchedule copyWith({int? weekday, String? startTime, int? durationMin}) => LessonSchedule(
    id: id,
    weekday: weekday ?? this.weekday,
    startTime: startTime ?? this.startTime,
    durationMin: durationMin ?? this.durationMin,
  );

  factory LessonSchedule.fromJson(Map<String, dynamic> json) => LessonSchedule(
    id: json['id'] as String?,
    weekday: json['weekday'] as int,
    startTime: json['startTime'] as String,
    durationMin: json['durationMin'] as int,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'weekday': weekday,
    'startTime': startTime,
    'durationMin': durationMin,
  };
}
