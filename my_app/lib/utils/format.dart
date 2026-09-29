import '../models/lesson_schedule.dart';

/// 1240000 -> "1,240,000원". 음수도 "-1,240,000원"으로 올바르게 끊습니다.
String formatWon(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    if (i != 0 && fromEnd % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer원';
}

/// 2.0 -> "2시간", 1.5 -> "1.5시간", 0.5 -> "30분"
String formatHours(double hours) {
  if (hours > 0 && hours < 1) return '${(hours * 60).round()}분';
  final label = hours == hours.roundToDouble() ? hours.toInt().toString() : hours.toString();
  return '$label시간';
}

/// 2026-09-28 -> "9. 28"
String formatShortDate(DateTime date) => '${date.month}. ${date.day}';

/// 2026-09-28 -> "9월 28일 월요일"
String formatFullDate(DateTime date) =>
    '${date.month}월 ${date.day}일 ${LessonSchedule.weekdayLabels[date.weekday - 1]}요일';

/// 2026-09-28 -> "2026년 9월"
String formatMonth(DateTime date) => '${date.year}년 ${date.month}월';
