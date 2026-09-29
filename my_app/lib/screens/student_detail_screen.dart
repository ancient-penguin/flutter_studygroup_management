import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson.dart';
import '../models/student.dart';
import '../providers/lesson_provider.dart';
import '../providers/student_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/lesson_stats.dart';
import 'lesson_form_screen.dart';
import 'student_form_screen.dart';

/// 3. 학생 상세: 정산 요약 + 수업 기록 리스트.
class StudentDetailScreen extends StatelessWidget {
  final Student student;
  const StudentDetailScreen({super.key, required this.student});

  Future<void> _confirmDelete(BuildContext context, Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: Text(
          '${student.name} 학생을 삭제할까요?',
          style: AppText.body(size: 16, weight: FontWeight.w700),
        ),
        content: Text(
          '수업 기록도 함께 삭제되며 되돌릴 수 없습니다.',
          style: AppText.body(size: 14, color: AppColors.mutedDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              '취소',
              style: AppText.body(
                size: 14,
                weight: FontWeight.w700,
                color: AppColors.mutedDark,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              '삭제',
              style: AppText.body(
                size: 14,
                weight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // StudentProvider가 onStudentDeleted로 LessonProvider까지 정리한다.
      await context.read<StudentProvider>().deleteStudent(student.id);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  } //Future

  @override
  Widget build(BuildContext context) {
    final liveStudent = context.watch<StudentProvider>().students.firstWhere(
      (s) => s.id == student.id,
      orElse: () => student,
    );
    final allLessons = context.watch<LessonProvider>().lessonsForStudent(liveStudent.id);
    // 최근 수업이 위로 오도록 정렬
    final lessons = [...allLessons]..sort((a, b) => b.date.compareTo(a.date));
    final thisMonth = DateTime.now();
    final settlement = StudentSettlement.from(lessonsInMonth(allLessons, thisMonth));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentFormScreen(student: liveStudent),
                          ),
                        ),
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.ink,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _confirmDelete(context, liveStudent),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.greenBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      liveStudent.initial,
                      style: AppText.body(
                        size: 22,
                        weight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(liveStudent.name, style: AppText.display(size: 24)),
                      const SizedBox(height: 5),
                      Text(
                        '${liveStudent.school} ${liveStudent.grade} · ${liveStudent.subject}',
                        style: AppText.body(
                          size: 13,
                          color: AppColors.mutedDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  _InfoPill(text: formatWon(liveStudent.hourlyRate)),
                  const SizedBox(width: 8),
                  if (liveStudent.schedules.isNotEmpty)
                    _InfoPill(text: liveStudent.scheduleDaysLabel),
                  if (liveStudent.nextLessonLabel(DateTime.now()).isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _InfoPill(text: '다음 ${liveStudent.nextLessonLabel(DateTime.now())}'),
                  ],
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.cardBorder),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${thisMonth.month}월 정산 예정',
                            style: AppText.body(
                              size: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            formatWon(settlement.totalAmount),
                            style: AppText.body(
                              size: 22,
                              weight: FontWeight.w800,
                              color: AppColors.clayText,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '진행 회차',
                            style: AppText.body(
                              size: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${settlement.lessonCount}회',
                            style: AppText.body(
                              size: 15,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: settlement.settled ? 1.0 : 0.0,
                      minHeight: 8,
                      backgroundColor: AppColors.divider,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                itemCount: lessons.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final l = lessons[i];
                  return _LessonRow(
                    lesson: l,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LessonFormScreen(student: liveStudent, lesson: l),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.ink,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LessonFormScreen(student: liveStudent)),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          '수업 기록 추가',
          style: AppText.body(weight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;
  const _InfoPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: AppText.body(size: 13)),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final LessonRecord lesson;
  final VoidCallback onTap;
  const _LessonRow({required this.lesson, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                formatShortDate(lesson.date),
                style: AppText.body(size: 17, weight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 34, color: AppColors.divider),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.note,
                    style: AppText.body(size: 14, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lesson.startTime} – ${lesson.endTime}',
                    style: AppText.body(size: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              formatWon(lesson.amount),
              style: AppText.body(size: 14, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
