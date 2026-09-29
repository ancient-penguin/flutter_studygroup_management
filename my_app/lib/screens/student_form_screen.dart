import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson_schedule.dart';
import '../models/student.dart';
import '../providers/student_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/schedule_conflict.dart';

/// 2. 학생 추가 / 수정. student가 null이면 추가, 있으면 수정 모드.
///
/// 요일만 고르던 예전과 달리, 요일을 켜면 그 요일의 시작 시각과 수업 길이까지 받습니다.
/// 시간이 없으면 일정 화면에 펼칠 수가 없기 때문입니다.
class StudentFormScreen extends StatefulWidget {
  final Student? student;
  const StudentFormScreen({super.key, this.student});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _schoolCtrl;
  late final TextEditingController _gradeCtrl;
  late final TextEditingController _rateCtrl;
  String _subject = '영어';

  /// weekday(1=월 ... 7=일) -> 그 요일의 반복 규칙.
  final Map<int, LessonSchedule> _schedules = {};
  bool _saving = false;

  static const _subjects = ['영어', '수학', '국어', '기타'];
  static const _durationOptions = [30, 60, 90, 120, 150, 180];
  static const _defaultStartTime = '18:00';
  static const _defaultDurationMin = 60;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _schoolCtrl = TextEditingController(text: s?.school ?? '');
    _gradeCtrl = TextEditingController(text: s?.grade ?? '');
    _rateCtrl = TextEditingController(text: s != null ? s.hourlyRate.toString() : '');
    if (s != null) {
      _subject = s.subject;
      // 저장된 규칙을 반드시 복원한다. 예전에는 이 복원이 없어서 수정 저장만 해도
      // 요일이 기본값으로 덮어써졌다.
      for (final schedule in s.schedules) {
        _schedules[schedule.weekday] = schedule;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _gradeCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _toggleDay(int weekday) {
    setState(() {
      if (_schedules.containsKey(weekday)) {
        _schedules.remove(weekday);
      } else {
        // 이미 고른 요일이 있으면 그 시간을 따라가는 편이 입력이 빠르다.
        final reference = _schedules.values.firstOrNull;
        _schedules[weekday] = LessonSchedule(
          weekday: weekday,
          startTime: reference?.startTime ?? _defaultStartTime,
          durationMin: reference?.durationMin ?? _defaultDurationMin,
        );
      }
    });
  }

  Future<void> _pickStartTime(int weekday) async {
    final current = _schedules[weekday]!;
    final parts = current.startTime.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 18,
        minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      ),
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    setState(() => _schedules[weekday] = current.copyWith(startTime: '$hh:$mm'));
  }

  Future<void> _pickDuration(int weekday) async {
    final current = _schedules[weekday]!;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('수업 시간', style: AppText.body(size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            ..._durationOptions.map(
              (min) => ListTile(
                title: Text(formatHours(min / 60), style: AppText.body(size: 15)),
                trailing: current.durationMin == min
                    ? const Icon(Icons.check, color: AppColors.accent, size: 20)
                    : null,
                onTap: () => Navigator.pop(sheetContext, min),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _schedules[weekday] = current.copyWith(durationMin: picked));
  }

  /// 다른 학생의 반복 스케줄과 겹치는 요일이 있으면 확인을 구한다.
  /// 사용자가 취소하면 false, 겹침이 없거나 계속 진행을 택하면 true.
  Future<bool> _confirmScheduleConflicts() async {
    final allStudents = context.read<StudentProvider>().students;
    final conflicts = <ScheduleConflict>[];
    for (final schedule in _schedules.values) {
      conflicts.addAll(
        findRecurringConflicts(
          candidate: schedule,
          allStudents: allStudents,
          excludeStudentId: widget.student?.id,
        ),
      );
    }
    if (conflicts.isEmpty) return true;

    final lines = conflicts
        .map((c) => '${c.schedule.weekdayLabel} ${c.schedule.startTime}~${c.schedule.endTime} · ${c.studentName}')
        .join('\n');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text('다른 학생과 시간이 겹칩니다', style: AppText.body(size: 16, weight: FontWeight.w700)),
        content: Text(lines, style: AppText.body(size: 14, color: AppColors.mutedDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('취소', style: AppText.body(size: 14, color: AppColors.mutedDark)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              '그래도 저장',
              style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final hourlyRate = int.tryParse(_rateCtrl.text.trim());
    if (name.isEmpty || hourlyRate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름과 시급을 올바르게 입력해주세요')));
      return;
    }

    if (!await _confirmScheduleConflicts()) return;
    if (!mounted) return;

    final sortedWeekdays = _schedules.keys.toList()..sort();
    final body = {
      'name': name,
      'initial': name[0],
      'school': _schoolCtrl.text.trim(),
      'grade': _gradeCtrl.text.trim(),
      'subject': _subject,
      'hourlyRate': hourlyRate,
      'schedules': [for (final w in sortedWeekdays) _schedules[w]!.toJson()],
    };

    setState(() => _saving = true);
    try {
      final provider = context.read<StudentProvider>();
      if (widget.student == null) {
        await provider.addStudent(body);
      } else {
        await provider.updateStudent(widget.student!.id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.student != null;
    final sortedWeekdays = _schedules.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text(
          isEdit ? '학생 정보 수정' : '학생 추가',
          style: AppText.body(size: 16, weight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
          children: [
            _Field(label: '이름', controller: _nameCtrl, hint: '예: 김서연'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(flex: 2, child: _Field(label: '학교', controller: _schoolCtrl, hint: '예: 대성고')),
                const SizedBox(width: 10),
                Expanded(child: _Field(label: '학년', controller: _gradeCtrl, hint: '고2')),
              ],
            ),
            const SizedBox(height: 16),
            Text('과목', style: AppText.body(size: 13, color: AppColors.mutedDark)),
            const SizedBox(height: 7),
            Row(
              children: _subjects.map((subj) {
                final selected = _subject == subj;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _subject = subj),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.accent : AppColors.surface,
                          border: Border.all(
                            color: selected ? AppColors.accent : AppColors.cardBorder,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          subj,
                          style: AppText.body(
                            size: 14,
                            weight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _Field(
              label: '시급',
              controller: _rateCtrl,
              hint: '35,000',
              suffix: '원 / 시간',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            Text('수업 요일', style: AppText.body(size: 13, color: AppColors.mutedDark)),
            const SizedBox(height: 7),
            Row(
              children: List.generate(7, (i) {
                final weekday = i + 1;
                final selected = _schedules.containsKey(weekday);
                final isSun = weekday == 7;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => _toggleDay(weekday),
                    child: Container(
                      width: 42,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent : AppColors.surface,
                        border: Border.all(
                          color: selected ? AppColors.accent : AppColors.cardBorder,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        LessonSchedule.weekdayLabels[i],
                        style: AppText.body(
                          size: 14,
                          weight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : (isSun ? AppColors.danger : AppColors.ink),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            if (_schedules.isEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.cardBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '요일을 선택하면 그 요일의 수업 시각을 정할 수 있어요.\n정한 일정은 일정 화면에 자동으로 표시됩니다.',
                  style: AppText.body(size: 13, color: AppColors.muted),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              ...sortedWeekdays.map((weekday) {
                final schedule = _schedules[weekday]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.cardBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.greenBg,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            schedule.weekdayLabel,
                            style: AppText.body(
                              size: 13,
                              weight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _MiniPicker(
                          label: '${schedule.startTime} ~ ${schedule.endTime}',
                          onTap: () => _pickStartTime(weekday),
                        ),
                        const SizedBox(width: 8),
                        _MiniPicker(
                          label: formatHours(schedule.durationHours),
                          onTap: () => _pickDuration(weekday),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _toggleDay(weekday),
                          icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        '저장하기',
                        style: AppText.body(size: 16, weight: FontWeight.w700, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPicker extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MiniPicker({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label, style: AppText.body(size: 13, weight: FontWeight.w600)),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.body(size: 13, color: AppColors.mutedDark)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppText.body(size: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.body(size: 15, color: AppColors.hint),
            suffixText: suffix,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }
}
