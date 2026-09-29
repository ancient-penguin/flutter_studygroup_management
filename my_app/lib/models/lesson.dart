enum LessonStatus { completed, inProgress, scheduled, canceled, noShow }

/// "2026-09-28" 형태의 ISO 날짜 문자열을 만듭니다. 서버 date 컬럼과 같은 포맷입니다.
String isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 시각 정보를 버린 날짜만의 DateTime. 날짜 비교용.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// 수업 기록 모델. 서버의 lessons 테이블과 1:1로 대응합니다.
class LessonRecord {
  final String id;
  final String studentId;

  /// 실제 날짜. 예전 dateLabel("9. 18")은 연도가 없어 정렬·범위조회가 불가능했습니다.
  final DateTime date;
  final String startTime;
  final String endTime;
  final String note;
  final int amount;
  final LessonStatus status;

  /// 정산 완료 시각. null이면 미정산.
  final DateTime? settledAt;

  const LessonRecord({
    required this.id,
    required this.studentId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.note,
    required this.amount,
    this.status = LessonStatus.scheduled,
    this.settledAt,
  });

  bool get isSettled => settledAt != null;

  /// 정산 금액에 포함되는 수업인지. 휴강(canceled)만 제외합니다.
  /// 결석(noShow)은 노쇼로 부과되는 금액이라 정산에 포함됩니다.
  bool get countsTowardSettlement => status != LessonStatus.canceled;

  bool isOn(DateTime day) =>
      date.year == day.year && date.month == day.month && date.day == day.day;

  bool isInMonth(DateTime month) => date.year == month.year && date.month == month.month;

  factory LessonRecord.fromJson(Map<String, dynamic> json) => LessonRecord(
    id: json['id'] as String,
    studentId: json['studentId'] as String,
    date: DateTime.parse(json['date'] as String),
    startTime: json['startTime'] as String,
    endTime: json['endTime'] as String,
    note: json['note'] as String? ?? '',
    amount: json['amount'] as int,
    status: LessonStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => LessonStatus.scheduled,
    ),
    settledAt: json['settledAt'] == null
        ? null
        : DateTime.tryParse(json['settledAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'date': isoDate(date),
    'startTime': startTime,
    'endTime': endTime,
    'note': note,
    'amount': amount,
    'status': status.name,
    'settledAt': settledAt?.toIso8601String(),
  };
}
