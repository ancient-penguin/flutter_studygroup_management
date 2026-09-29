import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/lesson_provider.dart';
import '../providers/student_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/lesson_stats.dart';
import '../widgets/app_bottom_nav.dart';
import 'settlement_detail_screen.dart';

/// 6. 월별 정산: 총액 카드 + 학생별 정산 내역.
///
/// 예전에는 월 선택 버튼이 비어 있고(onPressed: () {}) 집계도 전체 기간이라
/// "9월 정산"이라는 라벨이 사실과 달랐습니다. 이제 _month 기준으로 실제 필터링합니다.
class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await Future.wait([
      context.read<StudentProvider>().fetchStudents(),
      context.read<LessonProvider>().fetchLessons(),
    ]);
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentProvider>().students;
    final lessonProvider = context.watch<LessonProvider>();
    final settlements = {
      for (final s in students)
        s.id: StudentSettlement.from(lessonProvider.lessonsForStudentInMonth(s.id, _month)),
    };
    final totalAmount = settlements.values.fold<int>(0, (sum, v) => sum + v.totalAmount);
    final totalLessons = settlements.values.fold<int>(0, (sum, v) => sum + v.lessonCount);
    final totalHours = settlements.values.fold<double>(0, (sum, v) => sum + v.totalHours);
    final settledAmount = settlements.values
        .where((v) => v.settled)
        .fold<int>(0, (sum, v) => sum + v.totalAmount);
    final unsettledAmount = totalAmount - settledAmount;
    final unsettledCount =
        settlements.values.where((v) => !v.isEmpty && !v.settled).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('정산', style: AppText.display(size: 28)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _shiftMonth(-1),
                        icon: const Icon(Icons.chevron_left, color: AppColors.ink),
                        tooltip: '이전 달',
                      ),
                      Text(
                        formatMonth(_month),
                        style: AppText.body(size: 14, weight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: () => _shiftMonth(1),
                        icon: const Icon(Icons.chevron_right, color: AppColors.ink),
                        tooltip: '다음 달',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_month.month}월 정산 예정 금액', style: AppText.body(size: 13, color: const Color(0xFFB9B3A8))),
                  const SizedBox(height: 10),
                  Text(formatWon(totalAmount), style: AppText.body(size: 34, weight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Text('수업 $totalLessons회', style: AppText.body(size: 13, color: const Color(0xFFD5CFC4))),
                    const SizedBox(width: 16),
                    Text('학생 ${students.length}명', style: AppText.body(size: 13, color: const Color(0xFFD5CFC4))),
                    const SizedBox(width: 16),
                    Text('총 ${formatHours(totalHours)}', style: AppText.body(size: 13, color: const Color(0xFFD5CFC4))),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(child: _StatCard(label: '정산 완료', value: formatWon(settledAmount), color: AppColors.greenText)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(label: '미정산', value: formatWon(unsettledAmount), color: AppColors.clayText)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('학생별 내역', style: AppText.body(size: 15, weight: FontWeight.w700)),
                  Text('미정산 $unsettledCount명', style: AppText.body(size: 13, color: AppColors.muted)),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                itemCount: students.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final s = students[i];
                  final settlement = settlements[s.id]!;
                  final settled = settlement.settled;
                  final empty = settlement.isEmpty;
                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettlementDetailScreen(student: s, month: _month),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.cardBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: i.isOdd ? AppColors.clayBg : AppColors.greenBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              s.initial,
                              style: AppText.body(
                                size: 14,
                                weight: FontWeight.w700,
                                color: i.isOdd ? AppColors.clayTextLight : AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: AppText.body(size: 15, weight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(
                                  '${settlement.lessonCount}회 · ${formatHours(settlement.totalHours)}',
                                  style: AppText.body(size: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(formatWon(settlement.totalAmount), style: AppText.body(size: 15, weight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: empty
                                      ? AppColors.divider
                                      : (settled ? AppColors.greenBg : AppColors.clayBg),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  settlement.statusLabel,
                                  style: AppText.body(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: empty
                                        ? AppColors.mutedDark
                                        : (settled ? AppColors.greenText : AppColors.clayText),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.settlement),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(value, style: AppText.body(size: 20, weight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
