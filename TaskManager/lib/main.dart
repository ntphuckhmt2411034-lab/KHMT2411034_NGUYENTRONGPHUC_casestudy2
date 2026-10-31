
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TaskManagerApp());
}

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskManager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
      ),
      home: const RegisterScreen(),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isRegistering = false;

  // Android Emulator truy cập backend chạy trên máy tính.
  static const String _apiUrl =
      'http://10.0.2.2:5000/api/auth/register';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _register() async {
    if (_isRegistering) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isRegistering = true;
    });

    try {
      final response = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'password': _passwordController.text,
        }),
      )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      dynamic data;

      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        data = null;
      }

      String message = 'Đăng ký thất bại. Vui lòng thử lại.';

      if (data is Map && data['message'] is String) {
        message = data['message'] as String;
      }

      if (response.statusCode == 201) {
        _showMessage(
          'Đăng ký tài khoản thành công!',
          success: true,
        );

        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmController.clear();
      } else if (response.statusCode == 409) {
        _showMessage('Email này đã được đăng ký.');
      } else {
        _showMessage(message);
      }
    } on TimeoutException {
      _showMessage(
        'Kết nối quá thời gian. Vui lòng kiểm tra máy chủ.',
      );
    } catch (_) {
      _showMessage(
        'Không thể kết nối Backend. Kiểm tra Node.js và mạng.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CircleAvatar(
                          radius: 32,
                          backgroundColor: Color(0xFFE8F0FF),
                          child: Icon(
                            Icons.task_alt,
                            size: 34,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Tạo tài khoản',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        const Text(
                          'Bắt đầu quản lý và giao công việc cùng TaskManager',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Họ tên
                        TextFormField(
                          controller: _nameController,
                          textCapitalization:
                          TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            prefixIcon: Icon(
                              Icons.person_outline,
                            ),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập họ tên';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType:
                          TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                            ),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';

                            if (email.isEmpty) {
                              return 'Vui lòng nhập email';
                            }

                            if (!RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(email)) {
                              return 'Email không hợp lệ';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Mật khẩu
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hidePassword = !_hidePassword;
                                });
                              },
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập mật khẩu';
                            }

                            if (value.length < 8) {
                              return 'Mật khẩu phải có ít nhất 8 ký tự';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Xác nhận mật khẩu
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _hideConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _register(),
                          decoration: InputDecoration(
                            labelText: 'Xác nhận mật khẩu',
                            prefixIcon: const Icon(
                              Icons.lock_reset,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hideConfirmPassword =
                                  !_hideConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _hideConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng xác nhận mật khẩu';
                            }

                            if (value != _passwordController.text) {
                              return 'Mật khẩu xác nhận không khớp';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Nút đăng ký
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed:
                            _isRegistering ? null : _register,
                            child: _isRegistering
                                ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'Đăng ký tài khoản',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        const Text(
                          'Đã có tài khoản? Đăng nhập',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
