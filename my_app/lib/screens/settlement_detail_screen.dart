import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson.dart';
import '../models/student.dart';
import '../providers/lesson_provider.dart';
import '../providers/student_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/lesson_stats.dart';

/// 7. 학생별 정산 상세: 회차별 내역 + 정산 완료 처리.
///
/// [month]가 정산 대상 월입니다. 예전에는 화면이 "9월"이라고 써놓고 실제로는
/// 전체 기간을 더했습니다.
class SettlementDetailScreen extends StatefulWidget {
  final Student student;
  final DateTime? month;

  const SettlementDetailScreen({super.key, required this.student, this.month});

  @override
  State<SettlementDetailScreen> createState() => _SettlementDetailScreenState();
}

class _SettlementDetailScreenState extends State<SettlementDetailScreen> {
  late DateTime _month;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    final m = widget.month ?? DateTime.now();
    _month = DateTime(m.year, m.month);
  }

  Future<void> _toggleSettled(String studentId, bool settled) async {
    setState(() => _updating = true);
    try {
      await context.read<LessonProvider>().setSettledForStudent(studentId, _month, settled);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('정산 처리 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveStudent = context.watch<StudentProvider>().students.firstWhere(
      (s) => s.id == widget.student.id,
      orElse: () => widget.student,
    );
    final lessonProvider = context.watch<LessonProvider>();
    final lessons = lessonProvider.lessonsForStudentInMonth(liveStudent.id, _month)
      ..sort((a, b) => a.date.compareTo(b.date));
    final settlement = StudentSettlement.from(lessons);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text(
          '${liveStudent.name} · ${_month.month}월 정산',
          style: AppText.body(size: 16, weight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.cardBorder),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${formatMonth(_month)} 청구 금액',
                        style: AppText.body(size: 13, color: AppColors.muted),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: settlement.settled ? AppColors.greenBg : AppColors.clayBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          settlement.isEmpty
                              ? '내역 없음'
                              : (settlement.settled ? '정산 완료' : '미정산'),
                          style: AppText.body(
                            size: 12,
                            weight: FontWeight.w700,
                            color: settlement.settled ? AppColors.greenText : AppColors.clayText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(formatWon(settlement.totalAmount), style: AppText.display(size: 34)),
                  const Divider(height: 28, color: AppColors.divider),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MiniStat(label: '수업 횟수', value: '${settlement.lessonCount}회'),
                      _MiniStat(label: '총 시간', value: formatHours(settlement.totalHours)),
                      _MiniStat(label: '시급', value: formatWon(liveStudent.hourlyRate)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('수업 내역', style: AppText.body(size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (lessons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    '${_month.month}월에 등록된 수업 기록이 없어요',
                    style: AppText.body(size: 13, color: AppColors.muted),
                  ),
                ),
              ),
            ...lessons.map((lesson) {
              final canceled = !lesson.countsTowardSettlement;
              final isNoShow = lesson.status == LessonStatus.noShow;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 58,
                        child: Text(
                          formatShortDate(lesson.date),
                          style: AppText.body(size: 14, weight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          canceled
                              ? '${lesson.startTime} – ${lesson.endTime} · 휴강'
                              : '${lesson.startTime} – ${lesson.endTime} · ${formatHours(lessonDurationHours(lesson))}'
                                  '${isNoShow ? ' · 결석' : ''}',
                          style: AppText.body(size: 13, color: AppColors.mutedDark),
                        ),
                      ),
                      if (lesson.isSettled)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.check_circle, size: 15, color: AppColors.greenText),
                        ),
                      Text(
                        formatWon(lesson.amount),
                        style: AppText.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: canceled ? AppColors.muted : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: settlement.settled ? AppColors.surface : AppColors.accent,
                side: settlement.settled
                    ? const BorderSide(color: AppColors.cardBorder)
                    : BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: (settlement.isEmpty || _updating)
                  ? null
                  : () => _toggleSettled(liveStudent.id, !settlement.settled),
              child: _updating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      settlement.settled ? '정산 완료 취소' : '정산 완료로 표시',
                      style: AppText.body(
                        size: 16,
                        weight: FontWeight.w700,
                        color: settlement.settled ? AppColors.ink : Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.body(size: 12, color: AppColors.muted)),
        const SizedBox(height: 5),
        Text(value, style: AppText.body(size: 15, weight: FontWeight.w700)),
      ],
    );
  }
}
