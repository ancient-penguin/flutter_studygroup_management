import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson.dart';
import '../models/lesson_schedule.dart';
import '../models/schedule_entry.dart';
import '../models/student.dart';
import '../providers/lesson_provider.dart';
import '../providers/student_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/schedule_expansion.dart';
import '../widgets/app_bottom_nav.dart';
import 'lesson_form_screen.dart';

/// 4. 수업 일정: 주간 스트립 + 선택한 날의 타임라인.
///
/// 예전에는 9월 21~27일이 상수로 박혀 있고 lesson.dateLabel과 문자열이 같은지로
/// 필터해서, 그 주를 벗어난 수업은 영원히 보이지 않았습니다.
/// 지금은 실제 날짜로 비교하고 주 단위로 이동할 수 있습니다.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = dateOnly(DateTime.now());
    // 탭 전환마다 화면이 새로 만들어지므로, 여기서 다시 읽으면 재진입이 곧 새로고침이 된다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await Future.wait([
      context.read<StudentProvider>().fetchStudents(),
      context.read<LessonProvider>().fetchLessons(),
    ]);
  }

  void _shiftWeek(int weeks) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + weeks * 7,
      );
    });
  }

  void _goToday() => setState(() => _selectedDate = dateOnly(DateTime.now()));

  /// 반복 일정 칸을 탭했을 때. 그 날짜·시각을 채운 채 수업 기록 화면으로 보냅니다.
  Future<void> _openEntry(ScheduleEntry entry, List<Student> students) async {
    final student = students.where((s) => s.id == entry.studentId).firstOrNull;
    if (student == null) return;

    if (entry.isVirtual) {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.studentName} · ${entry.time}',
                  style: AppText.body(size: 17, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatFullDate(entry.date)}의 반복 일정이에요.\n아직 수업 기록으로 저장되지 않았습니다.',
                  style: AppText.body(size: 14, color: AppColors.mutedDark),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: Text(
                      '수업 기록하기',
                      style: AppText.body(size: 15, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true || !mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LessonFormScreen(
            student: student,
            initialDate: entry.date,
            initialStartTime: entry.time,
            initialDurationMin: entry.durationMin,
          ),
        ),
      );
      return;
    }

    // 실제 기록은 수정 모드로 연다.
    final lesson = context
        .read<LessonProvider>()
        .lessons
        .where((l) => l.id == entry.lessonId)
        .firstOrNull;
    if (lesson == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LessonFormScreen(student: student, lesson: lesson)),
    );
  }

  /// 학생을 고르고 선택한 날짜로 수업을 기록합니다.
  Future<void> _addLessonForDate(List<Student> students) async {
    final student = await showModalBottomSheet<Student>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text(
              '${formatFullDate(_selectedDate)} 수업 기록',
              style: AppText.body(size: 15, weight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('학생을 선택하세요', style: AppText.body(size: 13, color: AppColors.muted)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: students
                    .map(
                      (s) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.greenBg,
                          child: Text(
                            s.initial,
                            style: AppText.body(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        title: Text(s.name, style: AppText.body(size: 15, weight: FontWeight.w600)),
                        subtitle: Text(
                          '${s.subject} · ${s.grade}',
                          style: AppText.body(size: 12, color: AppColors.muted),
                        ),
                        onTap: () => Navigator.pop(sheetContext, s),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (student == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonFormScreen(student: student, initialDate: _selectedDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lessonProvider = context.watch<LessonProvider>();
    final students = context.watch<StudentProvider>().students;

    final weekStart = startOfWeek(_selectedDate);
    final days = weekDays(weekStart);
    final entries = entriesForDate(_selectedDate, students, lessonProvider.lessons);
    final totalHours = entries.fold<double>(0, (sum, e) => sum + e.durationHours);
    final today = dateOnly(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('일정', style: AppText.display(size: 28)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _shiftWeek(-1),
                        icon: const Icon(Icons.chevron_left, color: AppColors.ink),
                        tooltip: '이전 주',
                      ),
                      OutlinedButton(
                        onPressed: _goToday,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.cardBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Text('오늘', style: AppText.body(size: 13, weight: FontWeight.w700)),
                      ),
                      IconButton(
                        onPressed: () => _shiftWeek(1),
                        icon: const Icon(Icons.chevron_right, color: AppColors.ink),
                        tooltip: '다음 주',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.cardBorder),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: days.map((day) {
                  final selected = day == _selectedDate;
                  final isToday = day == today;
                  final isSun = day.weekday == 7;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = day),
                    child: Container(
                      width: 42,
                      height: 62,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            LessonSchedule.weekdayLabels[day.weekday - 1],
                            style: AppText.body(
                              size: 12,
                              color: selected
                                  ? Colors.white70
                                  : (isSun ? AppColors.danger : AppColors.muted),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: AppText.body(
                              size: 16,
                              weight: FontWeight.w800,
                              color: selected
                                  ? Colors.white
                                  : (isSun ? AppColors.danger : AppColors.ink),
                            ),
                          ),
                          const SizedBox(height: 3),
                          // 오늘 표시 점
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isToday
                                  ? (selected ? Colors.white : AppColors.accent)
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Text(
                    formatFullDate(_selectedDate),
                    style: AppText.body(size: 17, weight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entries.isEmpty
                          ? '예정된 수업 없음'
                          : '수업 ${entries.length}건 · ${formatHours(totalHours)}',
                      style: AppText.body(size: 13, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: entries.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.only(top: 60),
                        children: [_EmptyDay(date: _selectedDate)],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _TimelineRow(
                          entry: entries[i],
                          onTap: () => _openEntry(entries[i], students),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: students.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.ink,
              onPressed: () => _addLessonForDate(students),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('수업 기록', style: AppText.body(weight: FontWeight.w700, color: Colors.white)),
            ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.schedule),
    );
  }
}

({String label, Color bg, Color fg}) _statusMeta(LessonStatus status) {
  switch (status) {
    case LessonStatus.completed:
      return (label: '완료', bg: AppColors.greenBg, fg: AppColors.greenText);
    case LessonStatus.inProgress:
      return (label: '진행 중', bg: AppColors.clayBg, fg: AppColors.clayText);
    case LessonStatus.scheduled:
      return (label: '예정', bg: AppColors.divider, fg: AppColors.mutedDark);
    case LessonStatus.canceled:
      return (label: '취소', bg: AppColors.divider, fg: AppColors.danger);
    case LessonStatus.noShow:
      return (label: '결석', bg: AppColors.divider, fg: AppColors.danger);
  }
}

class _TimelineRow extends StatelessWidget {
  final ScheduleEntry entry;
  final VoidCallback onTap;

  const _TimelineRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = entry.isVirtual
        ? (label: '반복', bg: AppColors.clayBg, fg: AppColors.clayText)
        : _statusMeta(entry.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(entry.time, style: AppText.body(size: 14, weight: FontWeight.w700)),
                  Text(
                    formatHours(entry.durationHours),
                    style: AppText.body(size: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                    decoration: BoxDecoration(
                      // 가상(반복) 항목은 아직 DB에 없다는 걸 색으로 구분한다.
                      color: entry.isVirtual ? AppColors.bg : AppColors.surface,
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.studentName,
                              style: AppText.body(size: 15, weight: FontWeight.w700),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: meta.bg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                meta.label,
                                style: AppText.body(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: meta.fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(entry.subtitle, style: AppText.body(size: 13, color: AppColors.mutedDark)),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: Container(
                      color: entry.isVirtual ? AppColors.muted : AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final DateTime date;
  const _EmptyDay({required this.date});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_available_outlined, size: 40, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            '${LessonSchedule.weekdayLabels[date.weekday - 1]}요일에는 예정된 수업이 없어요',
            style: AppText.body(size: 14, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
