
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/main.dart';

void main() {
  testWidgets('A1 - Hien thi man hinh dang ky', (tester) async {
    await tester.pumpWidget(const TaskManagerApp());

    expect(find.text('Tạo tài khoản'), findsOneWidget);
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Xác nhận mật khẩu'), findsOneWidget);
    expect(find.text('Đăng ký tài khoản'), findsOneWidget);
  });

  testWidgets('A2 - Chuyen tu dang ky sang dang nhap', (tester) async {
    await tester.pumpWidget(const TaskManagerApp());

    final loginLink = find.text('Đã có tài khoản? Đăng nhập');

    await tester.ensureVisible(loginLink);
    await tester.tap(loginLink);
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
