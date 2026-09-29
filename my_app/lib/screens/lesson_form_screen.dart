import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson.dart';
import '../models/student.dart';
import '../providers/lesson_provider.dart';
import '../providers/student_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/schedule_conflict.dart';

/// 출결 상태에 따라 금액을 부과할지 결정합니다.
/// 휴강은 0원, 결석은 노쇼로 보고 부과합니다. 정책이 다르면 이 맵만 바꾸면 됩니다.
const _billableAttendance = {'출석': true, '보강': true, '휴강': false, '결석': true};

/// 5. 수업 기록 입력 / 수정.
///
/// [lesson]이 주어지면 수정 모드입니다. 예전에는 생성 전용이라 기존 수업을 탭해도
/// 복제본이 만들어졌습니다.
/// [initialDate]/[initialStartTime]/[initialDurationMin]은 일정 화면의 반복 일정을
/// 확정할 때 그 칸의 날짜·시각을 그대로 채워 넣기 위한 것입니다.
class LessonFormScreen extends StatefulWidget {
  final Student student;
  final LessonRecord? lesson;
  final DateTime? initialDate;
  final String? initialStartTime;
  final int? initialDurationMin;

  const LessonFormScreen({
    super.key,
    required this.student,
    this.lesson,
    this.initialDate,
    this.initialStartTime,
    this.initialDurationMin,
  });

  @override
  State<LessonFormScreen> createState() => _LessonFormScreenState();
}

class _LessonFormScreenState extends State<LessonFormScreen> {
  String _attendance = '출석';
  late final TextEditingController _noteCtrl;
  late DateTime _date;
  late TimeOfDay _start;
  late int _durationMin;
  bool _saving = false;
  bool _deleting = false;

  static const _attendances = ['출석', '보강', '휴강', '결석'];
  static const _durationOptions = [30, 60, 90, 120, 150, 180];

  bool get _isEdit => widget.lesson != null;

  String get _statusForAttendance {
    switch (_attendance) {
      case '출석':
      case '보강':
        return 'completed';
      case '결석':
        return 'noShow';
      default: // 휴강
        return 'canceled';
    }
  }

  static TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  static int _minutesBetween(String start, String end) {
    final s = _parseTime(start);
    final e = _parseTime(end);
    final diff = (e.hour * 60 + e.minute) - (s.hour * 60 + s.minute);
    return diff > 0 ? diff : 60;
  }

  @override
  void initState() {
    super.initState();
    final lesson = widget.lesson;
    _noteCtrl = TextEditingController(text: lesson?.note ?? '');

    if (lesson != null) {
      _date = lesson.date;
      _start = _parseTime(lesson.startTime);
      _durationMin = _minutesBetween(lesson.startTime, lesson.endTime);
      _attendance = switch (lesson.status) {
        LessonStatus.canceled => '휴강',
        LessonStatus.noShow => '결석',
        _ => '출석',
      };
    } else {
      // DateTime.now()는 "새 기록의 초기값"으로만 쓰입니다. 사용자가 언제든 바꿀 수 있습니다.
      _date = dateOnly(widget.initialDate ?? DateTime.now());
      _start = widget.initialStartTime != null
          ? _parseTime(widget.initialStartTime!)
          : TimeOfDay.fromDateTime(DateTime.now());
      _durationMin = widget.initialDurationMin ?? 60;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _startLabel =>
      '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}';

  String get _endLabel {
    final total = _start.hour * 60 + _start.minute + _durationMin;
    final hh = ((total ~/ 60) % 24).toString().padLeft(2, '0');
    final mm = (total % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  double get _hours => _durationMin / 60;

  /// 휴강은 0원. 그 외에는 시급 × 실제 수업 시간.
  int get _amount => (_billableAttendance[_attendance] ?? true)
      ? (widget.student.hourlyRate * _hours).round()
      : 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked != null) setState(() => _start = picked);
  }

  /// 다른 학생의 일정과 겹치면 확인을 구한다. 휴강으로 저장하는 경우는 이
  /// 후보 자체가 시간을 차지하지 않으므로 검사하지 않는다.
  /// 사용자가 취소하면 false, 겹침이 없거나 계속 진행을 택하면 true.
  Future<bool> _confirmLessonConflicts() async {
    if (_statusForAttendance == 'canceled') return true;

    final conflicts = findLessonConflicts(
      date: _date,
      startTime: _startLabel,
      durationMin: _durationMin,
      allStudents: context.read<StudentProvider>().students,
      allLessons: context.read<LessonProvider>().lessons,
      excludeLessonId: widget.lesson?.id,
    );
    if (conflicts.isEmpty) return true;

    final lines = conflicts
        .map((e) => '${e.time} (${formatHours(e.durationHours)}) · ${e.studentName}')
        .join('\n');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text('다른 일정과 시간이 겹칩니다', style: AppText.body(size: 16, weight: FontWeight.w700)),
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
    if (!await _confirmLessonConflicts()) return;
    if (!mounted) return;

    final body = {
      'studentId': widget.student.id,
      'date': isoDate(_date),
      'startTime': _startLabel,
      'endTime': _endLabel,
      'note': _noteCtrl.text.trim(),
      'amount': _amount,
      'status': _statusForAttendance,
    };

    setState(() => _saving = true);
    try {
      final provider = context.read<LessonProvider>();
      if (_isEdit) {
        await provider.updateLesson(widget.lesson!.id, body);
      } else {
        await provider.addLesson(body);
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

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text('이 수업 기록을 삭제할까요?', style: AppText.body(size: 16, weight: FontWeight.w700)),
        content: Text(
          '삭제하면 정산 합계에서도 빠집니다.',
          style: AppText.body(size: 14, color: AppColors.mutedDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('취소', style: AppText.body(size: 14, color: AppColors.mutedDark)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              '삭제',
              style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await context.read<LessonProvider>().deleteLesson(widget.lesson!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text(
          _isEdit ? '수업 기록 수정' : '수업 기록',
          style: AppText.body(size: 16, weight: FontWeight.w700),
        ),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: _deleting ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
          children: [
            _StudentCard(student: widget.student),
            const SizedBox(height: 16),

            Text('수업 날짜', style: AppText.body(size: 13, color: AppColors.mutedDark)),
            const SizedBox(height: 7),
            _PickerTile(
              icon: Icons.calendar_today_outlined,
              label: formatFullDate(_date),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            Text('시작 시각', style: AppText.body(size: 13, color: AppColors.mutedDark)),
            const SizedBox(height: 7),
            _PickerTile(
              icon: Icons.schedule_outlined,
              label: '$_startLabel ~ $_endLabel',
              onTap: _pickStartTime,
            ),
            const SizedBox(height: 16),

            Text('수업 시간', style: AppText.body(size: 13, color: AppColors.mutedDark)),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _durationOptions.map((min) {
                final selected = _durationMin == min;
                return GestureDetector(
                  onTap: () => setState(() => _durationMin = min),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent : AppColors.surface,
                      border: Border.all(color: selected ? AppColors.accent : AppColors.cardBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      formatHours(min / 60),
                      style: AppText.body(
                        size: 14,
                        weight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Text('출결', style: AppText.body(size: 13, color: AppColors.mutedDark)),
            const SizedBox(height: 7),
            Row(
              children: _attendances.map((a) {
                final selected = _attendance == a;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _attendance = a),
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
                          a,
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

            Text('진도 내용', style: AppText.body(size: 13, color: AppColors.mutedDark)),
            const SizedBox(height: 7),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              style: AppText.body(size: 15),
              decoration: InputDecoration(
                hintText: '예: 수능특강 Unit 7 독해, 오답 8문항 리뷰',
                hintStyle: AppText.body(size: 15, color: AppColors.hint),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.all(14),
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
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.clayBg,
                border: Border.all(color: const Color(0xFFEBD6C8)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('시급 × 수업 시간', style: AppText.body(size: 13, color: AppColors.clayText)),
                      Text(
                        '${formatWon(widget.student.hourlyRate)} × ${formatHours(_hours)}',
                        style: AppText.body(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppColors.clayText,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFE5CDB9)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '정산 금액',
                        style: AppText.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppColors.clayText,
                        ),
                      ),
                      Text(
                        formatWon(_amount),
                        style: AppText.body(
                          size: 26,
                          weight: FontWeight.w800,
                          color: AppColors.clayText,
                        ),
                      ),
                    ],
                  ),
                  if (_amount == 0) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '휴강은 정산 금액에 포함되지 않습니다',
                        style: AppText.body(size: 12, color: AppColors.clayText),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: (_saving || _deleting) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isEdit ? '수정 저장' : '기록 저장',
                      style: AppText.body(size: 16, weight: FontWeight.w700, color: Colors.white),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.mutedDark),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: AppText.body(size: 15))),
            const Icon(Icons.expand_more, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Student student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.greenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              student.initial,
              style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(student.name, style: AppText.body(size: 15, weight: FontWeight.w700)),
                Text(
                  '${student.grade} · ${student.subject} · 시급 ${formatWon(student.hourlyRate)}',
                  style: AppText.body(size: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
