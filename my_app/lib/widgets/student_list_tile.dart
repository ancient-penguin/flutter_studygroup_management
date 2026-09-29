import 'package:flutter/material.dart';

import '../models/student.dart';
import '../theme/app_theme.dart';

class StudentListTile extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;
  final bool alt; // 아바타 색 교차용

  const StudentListTile({
    super.key,
    required this.student,
    required this.onTap,
    this.alt = false,
  });

  @override
  Widget build(BuildContext context) {
    final nextLesson = student.nextLessonLabel(DateTime.now());
    final badgeBg = alt ? AppColors.clayBg : AppColors.greenBg;
    final badgeFg = alt ? AppColors.clayTextLight : AppColors.accent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                student.initial,
                style: AppText.body(size: 16, weight: FontWeight.w700, color: badgeFg),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: AppText.body(size: 16, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    '${student.grade} · ${student.subject}${student.schedules.isEmpty ? '' : ' · ${student.scheduleDaysLabel}'}',
                    style: AppText.body(size: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            // 다음 수업은 저장된 문자열이 아니라 반복 규칙에서 매번 계산한다.
            // 예전에는 앱에서 만든 학생의 nextLessonLabel이 영영 빈 문자열이었다.
            if (nextLesson.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    nextLesson,
                    style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.accent),
                  ),
                  const SizedBox(height: 3),
                  Text('다음 수업', style: AppText.body(size: 12, color: AppColors.muted)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
