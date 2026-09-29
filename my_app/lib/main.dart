import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/lesson_provider.dart';
import 'providers/student_provider.dart';
import 'screens/schedule_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/settlement_screen.dart';
import 'screens/student_list_screen.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';

void main() {
  final apiClient = ApiClient();
  final lessonProvider = LessonProvider(apiClient);
  // 학생이 지워지면 서버는 수업까지 cascade 삭제한다. 로컬 목록도 같이 비우도록 연결한다.
  final studentProvider = StudentProvider(
    apiClient,
    onStudentDeleted: lessonProvider.dropLessonsForStudent,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: studentProvider..fetchStudents()),
        ChangeNotifierProvider.value(value: lessonProvider..fetchLessons()),
      ],
      child: const TutorManagerApp(),
    ),
  );
}

class TutorManagerApp extends StatelessWidget {
  const TutorManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '과외 관리',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: '/',
      routes: {
        '/': (_) => const StudentListScreen(),
        '/schedule': (_) => const ScheduleScreen(),
        '/settlement': (_) => const SettlementScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
