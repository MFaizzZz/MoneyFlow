import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneyflow/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders form fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData(useMaterial3: true), home: LoginScreen()),
    );

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Belum punya akun? Register'), findsOneWidget);
  });
}
