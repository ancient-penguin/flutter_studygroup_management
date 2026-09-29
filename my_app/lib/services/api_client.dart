import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/lesson.dart';
import '../models/student.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// 백엔드(server/) REST API 클라이언트.
/// 안드로이드 에뮬레이터에서는 localhost가 에뮬레이터 자신을 가리키므로 10.0.2.2를 써야 합니다.
/// 실제 기기에서 테스트하려면 baseUrl에 PC의 LAN IP를 직접 넘기세요.
class ApiClient {
  final String baseUrl;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl();

  static String _defaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  Map<String, String> get _headers => {'Content-Type': 'application/json; charset=utf-8'};

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'HTTP ${response.statusCode}';
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map && body['error'] != null) message = body['error'] as String;
      } catch (_) {}
      throw ApiException(message);
    }
    if (response.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<List<Student>> getStudents() async {
    final response = await http.get(Uri.parse('$baseUrl/api/students'));
    final data = _decode(response) as List;
    return data.map((e) => Student.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Student> createStudent(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/students'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return Student.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<Student> updateStudent(String id, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/students/$id'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return Student.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<void> deleteStudent(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/api/students/$id'));
    _decode(response);
  }

  /// from/to는 "YYYY-MM-DD", month는 "YYYY-MM". 모두 선택적이고 조합 가능합니다.
  Future<List<LessonRecord>> getLessons({
    String? studentId,
    String? from,
    String? to,
    String? month,
  }) async {
    final params = <String, String>{
      'studentId': ?studentId,
      'from': ?from,
      'to': ?to,
      'month': ?month,
    };
    final uri = params.isEmpty
        ? Uri.parse('$baseUrl/api/lessons')
        : Uri.parse('$baseUrl/api/lessons').replace(queryParameters: params);
    final response = await http.get(uri);
    final data = _decode(response) as List;
    return data.map((e) => LessonRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LessonRecord> createLesson(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/lessons'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return LessonRecord.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<LessonRecord> updateLesson(String id, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/lessons/$id'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return LessonRecord.fromJson(_decode(response) as Map<String, dynamic>);
  }

  /// 정산 완료 표시/해제. settled_at을 서버가 기록합니다.
  Future<LessonRecord> setLessonSettled(String id, bool settled) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/lessons/$id/settlement'),
      headers: _headers,
      body: jsonEncode({'settled': settled}),
    );
    return LessonRecord.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<void> deleteLesson(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/api/lessons/$id'));
    _decode(response);
  }
}
