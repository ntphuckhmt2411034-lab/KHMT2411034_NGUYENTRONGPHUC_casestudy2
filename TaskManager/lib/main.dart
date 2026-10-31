import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TaskManagerApp());
}

// Android Emulator ket noi backend tren may tinh.
const String apiBaseUrl = 'http://10.0.2.2:5000/api/auth';

// Luu token tam trong bo nho ung dung.
// Chua luu mat khau hoac token xuong file.
class AuthSession {
  static String? token;
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

String responseMessage(http.Response response, String fallback) {
  try {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
  } catch (_) {
    // Su dung thong bao mac dinh neu response khong phai JSON.
  }
  return fallback;
}

void showAppMessage(
    BuildContext context,
    String message, {
      bool success = false,
    }) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ======================================================
// A1 - DANG KY TAI KHOAN
// ======================================================

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isRegistering) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isRegistering = true);

    try {
      final response = await http
          .post(
        Uri.parse('$apiBaseUrl/register'),
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

      if (response.statusCode == 201) {
        showAppMessage(
          context,
          'Đăng ký tài khoản thành công!',
          success: true,
        );

        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmController.clear();
      } else if (response.statusCode == 409) {
        showAppMessage(context, 'Email này đã được đăng ký.');
      } else {
        showAppMessage(
          context,
          responseMessage(response, 'Đăng ký thất bại.'),
        );
      }
    } on TimeoutException {
      if (mounted) {
        showAppMessage(context, 'Kết nối quá thời gian.');
      }
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'Không thể kết nối backend. Kiểm tra Node.js và mạng.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
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
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 30),

                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập họ tên';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
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

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline),
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

                        TextFormField(
                          controller: _confirmController,
                          obscureText: _hideConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _register(),
                          decoration: InputDecoration(
                            labelText: 'Xác nhận mật khẩu',
                            prefixIcon: const Icon(Icons.lock_reset),
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
                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: _isRegistering
                              ? null
                              : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Đã có tài khoản? Đăng nhập',
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

// ======================================================
// A2 - DANG NHAP
// ======================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoggingIn) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoggingIn = true);

    try {
      final response = await http
          .post(
        Uri.parse('$apiBaseUrl/login'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'email': _emailController.text.trim().toLowerCase(),
          'password': _passwordController.text,
        }),
      )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      Map<String, dynamic>? data;

      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        data = null;
      }

      if (response.statusCode == 200 &&
          data?['token'] is String &&
          (data!['token'] as String).isNotEmpty &&
          data['user'] is Map) {
        AuthSession.token = data['token'] as String;

        final user = data['user'] as Map;

        final fullName = user['fullName']?.toString() ?? 'Người dùng';
        final email = user['email']?.toString() ?? '';

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => WelcomeScreen(
              fullName: fullName,
              email: email,
            ),
          ),
              (route) => false,
        );
      } else if (response.statusCode == 401) {
        showAppMessage(
          context,
          'Email hoặc mật khẩu không chính xác.',
        );
      } else {
        showAppMessage(
          context,
          responseMessage(response, 'Đăng nhập thất bại.'),
        );
      }
    } on TimeoutException {
      if (mounted) {
        showAppMessage(context, 'Kết nối quá thời gian.');
      }
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'Không thể kết nối backend. Kiểm tra Node.js và mạng.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
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
                            Icons.lock_person_outlined,
                            size: 34,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Đăng nhập',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chào mừng bạn quay lại TaskManager',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 30),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
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

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline),
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
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _isLoggingIn ? null : _login,
                            child: _isLoggingIn
                                ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'Đăng nhập',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: _isLoggingIn
                              ? null
                              : () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Chưa có tài khoản? Đăng ký',
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

// ======================================================
// MAN HINH SAU KHI DANG NHAP THANH CONG
// ======================================================

class WelcomeScreen extends StatelessWidget {
  final String fullName;
  final String email;

  const WelcomeScreen({
    super.key,
    required this.fullName,
    required this.email,
  });

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi TaskManager không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // A3: xoa JWT dang giu trong bo nho Flutter.
    AuthSession.token = null;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskManager'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: Colors.green,
                  size: 76,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Đăng nhập thành công!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Xin chào, $fullName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 19),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Bạn đã đăng nhập vào TaskManager.\n'
                      'Các chức năng quản lý công việc sẽ được '
                      'phát triển trong những phần tiếp theo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: 220,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
