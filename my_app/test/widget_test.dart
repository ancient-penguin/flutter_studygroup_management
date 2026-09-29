import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_app/main.dart';
import 'package:my_app/providers/lesson_provider.dart';
import 'package:my_app/providers/student_provider.dart';
import 'package:my_app/services/api_client.dart';

void main() {
  testWidgets('학생 목록 화면이 첫 화면으로 뜬다', (WidgetTester tester) async {
    final apiClient = ApiClient();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => StudentProvider(apiClient)),
          ChangeNotifierProvider(create: (_) => LessonProvider(apiClient)),
        ],
        child: const TutorManagerApp(),
      ),
    );
    await tester.pump();

    expect(find.text('학생'), findsAtLeastNWidgets(1));
  });
}
