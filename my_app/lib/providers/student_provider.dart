import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../services/api_client.dart';

enum LoadStatus { idle, loading, loaded, error }

class StudentProvider extends ChangeNotifier {
  final ApiClient _api;

  /// 학생이 삭제됐을 때 호출됩니다. 서버가 ON DELETE CASCADE로 수업까지 지우므로
  /// LessonProvider도 같이 정리하라고 알리는 용도입니다(main.dart에서 연결).
  final void Function(String studentId)? onStudentDeleted;

  StudentProvider(this._api, {this.onStudentDeleted});

  List<Student> _students = [];
  LoadStatus _status = LoadStatus.idle;
  String? _errorMessage;

  List<Student> get students => List.unmodifiable(_students);
  LoadStatus get status => _status;
  String? get errorMessage => _errorMessage;

  Future<void> fetchStudents() async {
    _status = LoadStatus.loading;
    notifyListeners();
    try {
      _students = await _api.getStudents();
      _status = LoadStatus.loaded;
      _errorMessage = null;
    } catch (e) {
      _status = LoadStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<Student> addStudent(Map<String, dynamic> body) async {
    final student = await _api.createStudent(body);
    _students = [..._students, student];
    notifyListeners();
    return student;
  }

  Future<Student> updateStudent(String id, Map<String, dynamic> body) async {
    final updated = await _api.updateStudent(id, body);
    _students = _students.map((s) => s.id == id ? updated : s).toList();
    notifyListeners();
    return updated;
  }

  Future<void> deleteStudent(String id) async {
    await _api.deleteStudent(id);
    _students = _students.where((s) => s.id != id).toList();
    onStudentDeleted?.call(id);
    notifyListeners();
  }
}
