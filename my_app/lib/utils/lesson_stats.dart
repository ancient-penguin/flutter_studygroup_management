import '../models/lesson.dart';

/// "19:00" 같은 시:분 문자열을 자정 기준 분(minute)으로 변환합니다.
int? _parseTimeToMinutes(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// startTime/endTime 문자열로부터 수업 시간을 시간 단위로 계산합니다. 파싱 실패 시 0.
double lessonDurationHours(LessonRecord lesson) {
  final start = _parseTimeToMinutes(lesson.startTime);
  final end = _parseTimeToMinutes(lesson.endTime);
  if (start == null || end == null || end <= start) return 0;
  return (end - start) / 60;
}

/// 특정 월의 수업만 추립니다. 정산 화면이 "9월"이라고 쓰고 전체 기간을 더하던 문제를 막습니다.
List<LessonRecord> lessonsInMonth(List<LessonRecord> lessons, DateTime month) =>
    lessons.where((l) => l.isInMonth(month)).toList();

/// 특정 주(weekStart ~ +6일)의 수업만 추립니다.
List<LessonRecord> lessonsInWeek(List<LessonRecord> lessons, DateTime weekStart) {
  final start = dateOnly(weekStart);
  final end = start.add(const Duration(days: 6));
  return lessons.where((l) {
    final d = dateOnly(l.date);
    return !d.isBefore(start) && !d.isAfter(end);
  }).toList();
}

/// 학생 한 명의 수업기록 목록을 정산 요약으로 집계합니다.
/// 넘기는 리스트는 이미 기간 필터가 걸려 있어야 합니다(lessonsInMonth 등).
class StudentSettlement {
  /// 기간 내 전체 수업 횟수(취소 포함).
  final int lessonCount;

  /// 정산 대상(취소 제외) 수업의 시간 합계.
  final double totalHours;

  /// 정산 대상(취소 제외) 금액 합계.
  final int totalAmount;

  /// 정산 대상 수업이 모두 settledAt을 가진 경우에만 true.
  /// 예전에는 서버에 정산 필드가 없어 수업 상태로 근사했지만, 이제 실제 값입니다.
  final bool settled;

  /// 기간 내 수업이 아예 없는 경우. "미정산"과 구분하기 위해 둡니다.
  final bool isEmpty;

  const StudentSettlement({
    required this.lessonCount,
    required this.totalHours,
    required this.totalAmount,
    required this.settled,
    required this.isEmpty,
  });

  factory StudentSettlement.from(List<LessonRecord> lessons) {
    if (lessons.isEmpty) {
      return const StudentSettlement(
        lessonCount: 0,
        totalHours: 0,
        totalAmount: 0,
        settled: false,
        isEmpty: true,
      );
    }
    // 휴강/결석(canceled)은 시간과 금액 모두에서 빠집니다.
    final billable = lessons.where((l) => l.countsTowardSettlement).toList();
    final totalHours = billable.fold<double>(0, (sum, l) => sum + lessonDurationHours(l));
    final totalAmount = billable.fold<int>(0, (sum, l) => sum + l.amount);
    final settled = billable.isNotEmpty && billable.every((l) => l.isSettled);

    return StudentSettlement(
      lessonCount: lessons.length,
      totalHours: totalHours,
      totalAmount: totalAmount,
      settled: settled,
      isEmpty: false,
    );
  }

  /// 상태 배지 문구.
  String get statusLabel => isEmpty ? '내역 없음' : (settled ? '완료' : '미정산');
}
