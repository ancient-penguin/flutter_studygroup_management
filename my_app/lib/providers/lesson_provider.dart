import 'package:flutter/foundation.dart';

import '../models/lesson.dart';
import '../services/api_client.dart';
import '../utils/lesson_stats.dart';
import 'student_provider.dart';

class LessonProvider extends ChangeNotifier {
  final ApiClient _api;
  LessonProvider(this._api);

  List<LessonRecord> _lessons = [];
  LoadStatus _status = LoadStatus.idle;
  String? _errorMessage;

  LoadStatus get status => _status;
  String? get errorMessage => _errorMessage;

  List<LessonRecord> get lessons => List.unmodifiable(_lessons);

  List<LessonRecord> lessonsForStudent(String studentId) =>
      _lessons.where((l) => l.studentId == studentId).toList();

  List<LessonRecord> lessonsForStudentInMonth(String studentId, DateTime month) =>
      lessonsInMonth(lessonsForStudent(studentId), month);

  /// 항상 전체 수업을 받아옵니다.
  ///
  /// 예전에는 studentId 인자를 받아 전역 목록을 한 학생 것으로 갈아끼웠는데,
  /// 화면들이 이 전역 목록을 필터해 쓰기 때문에 다른 학생 정산이 조용히 0이 되는 함정이었습니다.
  /// 특정 학생/기간이 필요하면 lessonsForStudent 같은 게터로 걸러 쓰세요.
  Future<void> fetchLessons() async {
    _status = LoadStatus.loading;
    notifyListeners();
    try {
      _lessons = await _api.getLessons();
      _status = LoadStatus.loaded;
      _errorMessage = null;
    } catch (e) {
      _status = LoadStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<LessonRecord> addLesson(Map<String, dynamic> body) async {
    final lesson = await _api.createLesson(body);
    _lessons = [..._lessons, lesson];
    notifyListeners();
    return lesson;
  }

  Future<LessonRecord> updateLesson(String id, Map<String, dynamic> body) async {
    final updated = await _api.updateLesson(id, body);
    _lessons = _lessons.map((l) => l.id == id ? updated : l).toList();
    notifyListeners();
    return updated;
  }

  Future<LessonRecord> setSettled(String id, bool settled) async {
    final updated = await _api.setLessonSettled(id, settled);
    _lessons = _lessons.map((l) => l.id == id ? updated : l).toList();
    notifyListeners();
    return updated;
  }

  /// 한 학생의 기간 내 수업을 한꺼번에 정산 처리합니다.
  Future<void> setSettledForStudent(String studentId, DateTime month, bool settled) async {
    final targets = lessonsForStudentInMonth(studentId, month)
        .where((l) => l.countsTowardSettlement && l.isSettled != settled);
    for (final lesson in targets) {
      await setSettled(lesson.id, settled);
    }
  }

  Future<void> deleteLesson(String id) async {
    await _api.deleteLesson(id);
    _lessons = _lessons.where((l) => l.id != id).toList();
    notifyListeners();
  }

  /// 서버의 ON DELETE CASCADE에 맞춰 로컬에서도 그 학생의 수업을 지웁니다.
  /// 이게 없으면 삭제된 학생의 수업이 남아 정산 합계를 부풀립니다.
  void dropLessonsForStudent(String studentId) {
    _lessons = _lessons.where((l) => l.studentId != studentId).toList();
    notifyListeners();
  }
}
