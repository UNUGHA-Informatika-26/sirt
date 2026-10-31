import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirt_app/screens/login_screen.dart';

void main() {
  testWidgets('halaman masuk SiRT tampil', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Masuk ke SiRT'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Kata sandi'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Daftar sebagai warga'), findsOneWidget);
  });
}
