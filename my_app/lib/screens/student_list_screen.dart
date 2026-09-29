import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/student.dart';
import '../providers/lesson_provider.dart';
import '../providers/student_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/lesson_stats.dart';
import '../utils/schedule_expansion.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/student_list_tile.dart';
import 'student_detail_screen.dart';
import 'student_form_screen.dart';

/// 1단계: StatefulWidget + ListView + Card + Text로 시작하는 학생 목록 화면.
class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String _filter = '전체';

  @override
  void initState() {
    super.initState();
    // 탭 전환마다 이 화면이 새로 생성되므로 재진입이 곧 새로고침이 된다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await Future.wait([
      context.read<StudentProvider>().fetchStudents(),
      context.read<LessonProvider>().fetchLessons(),
    ]);
  }

  List<Student> _filtered(List<Student> students) {
    if (_filter == '전체') return students;
    return students.where((s) => s.subject == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final students = provider.students;
    final filtered = _filtered(students);
    final englishCount = students.where((s) => s.subject == '영어').length;
    final mathCount = students.where((s) => s.subject == '수학').length;
    final lessonProvider = context.watch<LessonProvider>();
    final now = DateTime.now();

    // 카드 문구대로 실제 기간을 건다. 예전에는 "이번 주"/"이번 달"이라고 써놓고
    // 전체 기간 수업을 세고 있었다.
    final weekLessons = lessonsInWeek(lessonProvider.lessons, startOfWeek(now));
    final totalLessons = weekLessons.length;
    final totalAmount = StudentSettlement.from(
      lessonsInMonth(lessonProvider.lessons, now),
    ).totalAmount;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatMonth(now), style: AppText.body(size: 13, color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Text('학생', style: AppText.display(size: 28)),
                    ],
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.cardBorder),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.search, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(label: '이번 주 수업', value: '$totalLessons', unit: '회'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: '이번 달 정산 예정',
                      value: formatWon(totalAmount),
                      unit: '',
                      valueColor: AppColors.clayText,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  _FilterChip(
                    label: '전체 ${students.length}',
                    selected: _filter == '전체',
                    onTap: () => setState(() => _filter = '전체'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '영어 $englishCount',
                    selected: _filter == '영어',
                    onTap: () => setState(() => _filter = '영어'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '수학 $mathCount',
                    selected: _filter == '수학',
                    onTap: () => setState(() => _filter = '수학'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.status == LoadStatus.error
                  ? _ErrorState(
                      message: provider.errorMessage ?? '알 수 없는 오류',
                      onRetry: () => context.read<StudentProvider>().fetchStudents(),
                    )
                  : provider.status == LoadStatus.loading && students.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final s = filtered[i];
                        return StudentListTile(
                          student: s,
                          alt: i.isOdd,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => StudentDetailScreen(student: s)),
                          ),
                        );
                      },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.ink,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentFormScreen()),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('학생 추가', style: AppText.body(size: 15, weight: FontWeight.w700, color: Colors.white)),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.students),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color valueColor;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: value, style: AppText.body(size: 22, weight: FontWeight.w800, color: valueColor)),
              TextSpan(text: unit, style: AppText.body(size: 14, color: AppColors.muted)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 40, color: AppColors.muted),
          const SizedBox(height: 10),
          Text('불러오기 실패', style: AppText.body(size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(message, style: AppText.body(size: 12, color: AppColors.muted)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          border: Border.all(color: selected ? AppColors.ink : AppColors.cardBorder),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppText.body(
            size: 13,
            weight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
