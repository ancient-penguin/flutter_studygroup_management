import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:my_app/providers/student_provider.dart';
import 'package:my_app/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('raw http.get to localhost:3000', () async {
    print('A: starting raw http.get');
    final res = await http.get(Uri.parse('http://localhost:3000/api/students')).timeout(const Duration(seconds: 5));
    print('B: got status ${res.statusCode}');
    expect(res.statusCode, 200);
  });

  test('ApiClient.getStudents via StudentProvider.fetchStudents', () async {
    print('C: starting fetchStudents');
    final apiClient = ApiClient();
    final provider = StudentProvider(apiClient);
    await provider.fetchStudents().timeout(const Duration(seconds: 5));
    print('D: fetchStudents done, status=${provider.status}, count=${provider.students.length}');
    expect(provider.status, LoadStatus.loaded);
  });

  testWidgets('pumpWidget a plain Text with GoogleFonts-based style settles quickly', (tester) async {
    print('E: pumping widget');
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('hello'))),
    );
    print('F: pumped, now pumpAndSettle');
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    print('G: settled');
  });
}
