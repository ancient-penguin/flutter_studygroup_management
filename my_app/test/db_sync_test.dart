// 서버 DB가 바뀔 때 각 화면이 실제로 갱신되는지 확인하는 통합성 테스트.
// 실행 중인 백엔드(http://localhost:3000)에 실제 HTTP 요청을 보내 검증합니다.
// 사전 조건: `cd server && npm start` 로 백엔드가 떠 있어야 합니다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:my_app/models/lesson.dart';
import 'package:my_app/models/student.dart';
import 'package:my_app/providers/lesson_provider.dart';
import 'package:my_app/providers/student_provider.dart';
import 'package:my_app/screens/schedule_screen.dart';
import 'package:my_app/screens/settlement_detail_screen.dart';
import 'package:my_app/screens/student_detail_screen.dart';
import 'package:my_app/screens/student_list_screen.dart';
import 'package:my_app/services/api_client.dart';
import 'package:my_app/utils/format.dart';
import 'package:my_app/utils/lesson_stats.dart';
import 'package:my_app/utils/schedule_expansion.dart';

const _baseUrl = 'http://localhost:3000';
const _headers = {'Content-Type': 'application/json; charset=utf-8'};

Future<Map<String, dynamic>> _apiCreateStudent(Map<String, dynamic> body) async {
  final res = await http.post(Uri.parse('$_baseUrl/api/students'), headers: _headers, body: jsonEncode(body));
  return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
}

Future<void> _apiUpdateStudent(String id, Map<String, dynamic> body) async {
  await http.put(Uri.parse('$_baseUrl/api/students/$id'), headers: _headers, body: jsonEncode(body));
}

Future<void> _apiDeleteStudent(String id) async {
  await http.delete(Uri.parse('$_baseUrl/api/students/$id'));
}

Future<Map<String, dynamic>> _apiCreateLesson(Map<String, dynamic> body) async {
  final res = await http.post(Uri.parse('$_baseUrl/api/lessons'), headers: _headers, body: jsonEncode(body));
  return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
}

Future<void> _apiDeleteLesson(String id) async {
  await http.delete(Uri.parse('$_baseUrl/api/lessons/$id'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test는 기본적으로 모든 HttpClient 요청을 400으로 가짜 응답하도록 막는다.
  // 이 테스트는 실제 로컬 백엔드에 붙어야 하므로 그 오버라이드를 해제한다.
  HttpOverrides.global = null;

  late String studentId;
  late Student testStudent;

  // 오늘 기준으로 날짜를 잡는다. 예전처럼 "9. 26" 같은 고정 라벨을 쓰면
  // 실행 시점이 달라질 때 화면이 보여주는 주/달과 어긋난다.
  final today = dateOnly(DateTime.now());

  setUp(() async {
    // 반복 일정이 있으면 일정 화면에 가상 항목이 함께 떠서 검증이 흐려지므로
    // 이 테스트 학생은 규칙 없이 만든다.
    final json = await _apiCreateStudent({
      'name': 'QA싱크테스트',
      'initial': 'Q',
      'school': 'QA고',
      'grade': '고1',
      'subject': '영어',
      'hourlyRate': 10000,
      'schedules': [],
    });
    studentId = json['id'] as String;
    testStudent = Student.fromJson(json);
  });

  tearDown(() async {
    await _apiDeleteStudent(studentId); // ON DELETE CASCADE로 테스트 수업도 함께 삭제됨
  });

  testWidgets('학생 상세 화면: 서버 DB에서 학생 정보를 수정하면 화면이 갱신된다', (tester) async {
    final apiClient = ApiClient();
    final studentProvider = StudentProvider(apiClient);
    final lessonProvider = LessonProvider(apiClient);
    await studentProvider.fetchStudents();
    await lessonProvider.fetchLessons();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: studentProvider),
          ChangeNotifierProvider.value(value: lessonProvider),
        ],
        child: MaterialApp(home: StudentDetailScreen(student: testStudent)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('QA싱크테스트'), findsOneWidget);
    expect(find.textContaining('10,000원'), findsOneWidget);
    expect(find.text('0회'), findsOneWidget); // 아직 수업 기록 없음

    // --- DB(서버)에서 학생 정보가 바뀌는 상황을 시뮬레이션 ---
    await _apiUpdateStudent(studentId, {
      'name': 'QA싱크테스트_수정됨',
      'initial': 'Q',
      'school': 'QA고',
      'grade': '고2',
      'subject': '수학',
      'hourlyRate': 55000,
      'schedules': [
        {'weekday': 3, 'startTime': '11:00', 'durationMin': 60},
      ],
    });

    // 새로 수업 기록도 하나 추가 (정산 카드 recompute 확인용).
    // 상세 화면은 "이번 달" 기준으로 집계하므로 오늘 날짜로 만든다.
    final lesson = await _apiCreateLesson({
      'studentId': studentId,
      'date': isoDate(today),
      'startTime': '10:00',
      'endTime': '11:00',
      'note': 'QA 정산 확인용',
      'amount': 30000,
      'status': 'completed',
    });

    // 앱이 서버 최신 상태를 다시 받아오는 시점(새로고침/재진입 등)을 재현
    await studentProvider.fetchStudents();
    await lessonProvider.fetchLessons();
    await tester.pumpAndSettle();

    expect(find.text('QA싱크테스트_수정됨'), findsOneWidget);
    expect(find.text('QA싱크테스트'), findsNothing); // 옛 이름 스냅샷이 남아있지 않아야 함
    expect(find.textContaining('55,000원'), findsOneWidget); // 새 시급
    expect(find.text('1회'), findsOneWidget); // 새 수업 반영된 진행 회차
    expect(find.textContaining('30,000원'), findsOneWidget); // 정산 예정 금액 + 수업 금액 표시

    // 요일 규칙이 계산된 라벨로 나타난다 (예전 scheduleDays 문자열 대체)
    expect(find.textContaining('수'), findsWidgets);

    await _apiDeleteLesson(lesson['id'] as String);
  });

  testWidgets('정산 상세 화면: 서버 DB의 시급/수업 변경이 반영된다', (tester) async {
    final apiClient = ApiClient();
    final studentProvider = StudentProvider(apiClient);
    final lessonProvider = LessonProvider(apiClient);
    await studentProvider.fetchStudents();
    await lessonProvider.fetchLessons();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: studentProvider),
          ChangeNotifierProvider.value(value: lessonProvider),
        ],
        child: MaterialApp(home: SettlementDetailScreen(student: testStudent)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('QA싱크테스트'), findsWidgets);
    expect(find.textContaining('10,000원'), findsOneWidget); // 시급 미니스탯

    await _apiUpdateStudent(studentId, {
      'name': 'QA싱크테스트',
      'initial': 'Q',
      'school': 'QA고',
      'grade': '고1',
      'subject': '영어',
      'hourlyRate': 77000,
      'schedules': [],
    });
    await studentProvider.fetchStudents();
    await tester.pumpAndSettle();

    expect(find.textContaining('77,000원'), findsOneWidget);
  });

  testWidgets('정산 상세 화면: 휴강은 정산 금액에 포함되지 않는다', (tester) async {
    final apiClient = ApiClient();
    final studentProvider = StudentProvider(apiClient);
    final lessonProvider = LessonProvider(apiClient);

    final normal = await _apiCreateLesson({
      'studentId': studentId,
      'date': isoDate(today),
      'startTime': '10:00',
      'endTime': '11:00',
      'note': 'QA 정상 수업',
      'amount': 10000,
      'status': 'completed',
    });
    // 휴강은 금액 0으로 저장된다(수업 기록 화면의 정책과 동일).
    final canceled = await _apiCreateLesson({
      'studentId': studentId,
      'date': isoDate(today),
      'startTime': '14:00',
      'endTime': '15:00',
      'note': 'QA 휴강',
      'amount': 0,
      'status': 'canceled',
    });

    await studentProvider.fetchStudents();
    await lessonProvider.fetchLessons();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: studentProvider),
          ChangeNotifierProvider.value(value: lessonProvider),
        ],
        child: MaterialApp(home: SettlementDetailScreen(student: testStudent)),
      ),
    );
    await tester.pumpAndSettle();

    // 2건이 목록에 있지만 청구 금액은 정상 수업 1건분만.
    expect(find.text('2회'), findsOneWidget);
    expect(find.textContaining('휴강'), findsWidgets);
    final settlement = StudentSettlement.from(
      lessonProvider.lessonsForStudentInMonth(studentId, today),
    );
    expect(settlement.totalAmount, 10000);

    await _apiDeleteLesson(normal['id'] as String);
    await _apiDeleteLesson(canceled['id'] as String);
  });

  testWidgets('일정 화면: 서버에 추가된 실제 수업이 오늘 타임라인에 나타난다', (tester) async {
    final apiClient = ApiClient();
    final studentProvider = StudentProvider(apiClient);
    final lessonProvider = LessonProvider(apiClient);
    await studentProvider.fetchStudents();
    await lessonProvider.fetchLessons();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: studentProvider),
          ChangeNotifierProvider.value(value: lessonProvider),
        ],
        child: const MaterialApp(home: ScheduleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 일정 화면은 오늘이 속한 주를 보여주고 오늘 날짜가 기본 선택된다.
    expect(find.text('QA싱크테스트'), findsNothing); // 아직 오늘 수업 없음

    final lesson = await _apiCreateLesson({
      'studentId': studentId,
      'date': isoDate(today),
      'startTime': '10:00',
      'endTime': '11:30',
      'note': 'QA_스케줄_동기화_확인',
      'amount': 20000,
      'status': 'scheduled',
    });

    // 서버(DB)에 생긴 변화를 앱이 다시 읽어오는 시점을 재현
    await lessonProvider.fetchLessons();
    await tester.pumpAndSettle();

    expect(find.text('QA싱크테스트'), findsOneWidget);
    expect(find.textContaining('QA_스케줄_동기화_확인'), findsOneWidget);

    await _apiDeleteLesson(lesson['id'] as String);
  });

  testWidgets('일정 화면: 학생의 주간 반복 요일이 실제 일정으로 펼쳐진다', (tester) async {
    final apiClient = ApiClient();
    final studentProvider = StudentProvider(apiClient);
    final lessonProvider = LessonProvider(apiClient);

    // 오늘 요일에 반복 규칙을 준다. 예전에는 요일을 저장해도 일정 화면이
    // lessons만 봤기 때문에 아무것도 나타나지 않았다.
    await _apiUpdateStudent(studentId, {
      'name': 'QA반복테스트',
      'initial': 'Q',
      'school': 'QA고',
      'grade': '고1',
      'subject': '영어',
      'hourlyRate': 10000,
      'schedules': [
        {'weekday': today.weekday, 'startTime': '07:15', 'durationMin': 90},
      ],
    });

    await studentProvider.fetchStudents();
    await lessonProvider.fetchLessons();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: studentProvider),
          ChangeNotifierProvider.value(value: lessonProvider),
        ],
        child: const MaterialApp(home: ScheduleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 수업 기록은 하나도 없지만 반복 규칙이 가상 일정으로 보여야 한다.
    expect(lessonProvider.lessonsForStudent(studentId), isEmpty);
    expect(find.text('QA반복테스트'), findsOneWidget);
    expect(find.text('07:15'), findsOneWidget);
    expect(find.textContaining('반복'), findsWidgets);
  });

  testWidgets('학생 목록 화면: 요약 카드가 이번 주/이번 달 실제 합계를 반영한다', (tester) async {
    final apiClient = ApiClient();
    final studentProvider = StudentProvider(apiClient);
    final lessonProvider = LessonProvider(apiClient);
    await studentProvider.fetchStudents();
    await lessonProvider.fetchLessons();

    final baselineWeekCount =
        lessonsInWeek(lessonProvider.lessons, startOfWeek(today)).length;
    final baselineMonthAmount =
        StudentSettlement.from(lessonsInMonth(lessonProvider.lessons, today)).totalAmount;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: studentProvider),
          ChangeNotifierProvider.value(value: lessonProvider),
        ],
        child: const MaterialApp(home: StudentListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('$baselineWeekCount'), findsWidgets);
    expect(find.textContaining(formatWon(baselineMonthAmount)), findsOneWidget);

    final lesson = await _apiCreateLesson({
      'studentId': studentId,
      'date': isoDate(today),
      'startTime': '10:00',
      'endTime': '11:00',
      'note': 'QA 목록 합계 확인',
      'amount': 15000,
      'status': 'completed',
    });
    await lessonProvider.fetchLessons();
    await studentProvider.fetchStudents();
    await tester.pumpAndSettle();

    expect(find.textContaining('${baselineWeekCount + 1}'), findsWidgets);
    expect(
      find.textContaining(formatWon(baselineMonthAmount + 15000)),
      findsOneWidget,
    );

    await _apiDeleteLesson(lesson['id'] as String);
  });
}
