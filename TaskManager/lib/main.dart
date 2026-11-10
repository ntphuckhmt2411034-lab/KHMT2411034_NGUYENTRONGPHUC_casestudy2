import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'screens/profile/change_password_screen.dart';
import 'screens/tasks/task_list_screen.dart';
import 'screens/notifications/notification_screen.dart';
import 'screens/statistics/statistics_screen.dart';

void main() {
  runApp(const TaskManagerApp());
}

// Android Emulator truy cap backend tren may tinh.
const String apiBaseUrl = 'http://10.0.2.2:5000/api/auth';
const String tasksApiUrl = 'http://10.0.2.2:5000/api/tasks';

// Session trong bo nho; khong luu mat khau xuong thiet bi.
class AuthSession {
  static String? token;
}

class AppPalette {
  static const Color primary = Color(0xFF3458A6);
  static const Color primaryDark = Color(0xFF223E7C);
  static const Color canvas = Color(0xFFF5F7FC);
  static const Color ink = Color(0xFF1D2C46);
  static const Color muted = Color(0xFF697892);
  static const Color green = Color(0xFF198A69);
  static const Color amber = Color(0xFFC17A19);
  static const Color red = Color(0xFFC94A55);
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
          seedColor: AppPalette.primary,
          primary: AppPalette.primary,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: AppPalette.canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppPalette.canvas,
          foregroundColor: AppPalette.ink,
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    // Fallback khi backend khong tra JSON.
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
      backgroundColor: success ? AppPalette.green : AppPalette.red,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ======================================================
// A1 - DANG KY TAI KHOAN (giu nguyen nghiep vu)
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
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'fullName': _nameController.text.trim(),
              'email': _emailController.text.trim().toLowerCase(),
              'password': _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 201) {
        showAppMessage(context, 'Đăng ký tài khoản thành công!', success: true);
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmController.clear();
      } else if (response.statusCode == 409) {
        showAppMessage(context, 'Email này đã được đăng ký.');
      } else {
        showAppMessage(context, responseMessage(response, 'Đăng ký thất bại.'));
      }
    } on TimeoutException {
      if (mounted) showAppMessage(context, 'Kết nối quá thời gian.');
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'Không thể kết nối backend. Kiểm tra Node.js và mạng.',
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
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
                            color: AppPalette.primary,
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
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Vui lòng nhập họ tên'
                              : null,
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
                            if (email.isEmpty) return 'Vui lòng nhập email';
                            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(email)) {
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
                              onPressed: () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
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
                              onPressed: () => setState(() {
                                _hideConfirmPassword = !_hideConfirmPassword;
                              }),
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
                            onPressed: _isRegistering ? null : _register,
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
                          child: const Text('Đã có tài khoản? Đăng nhập'),
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
// A2 - DANG NHAP (giu nguyen nghiep vu)
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
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
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
        if (decoded is Map<String, dynamic>) data = decoded;
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
            builder: (_) => WelcomeScreen(fullName: fullName, email: email),
          ),
          (route) => false,
        );
      } else if (response.statusCode == 401) {
        showAppMessage(context, 'Email hoặc mật khẩu không chính xác.');
      } else {
        showAppMessage(
          context,
          responseMessage(response, 'Đăng nhập thất bại.'),
        );
      }
    } on TimeoutException {
      if (mounted) showAppMessage(context, 'Kết nối quá thời gian.');
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'Không thể kết nối backend. Kiểm tra Node.js và mạng.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
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
                            color: AppPalette.primary,
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
                            if (email.isEmpty) return 'Vui lòng nhập email';
                            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(email)) {
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
                              onPressed: () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
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
                              : () => Navigator.of(context).pop(),
                          child: const Text('Chưa có tài khoản? Đăng ký'),
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
// DASHBOARD SAU DANG NHAP - DU LIEU THAT TU API
// ======================================================
class WelcomeScreen extends StatefulWidget {
  final String fullName;
  final String email;

  const WelcomeScreen({super.key, required this.fullName, required this.email});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late String _fullName = widget.fullName;
  bool _loading = true;
  String? _dashboardError;
  List<Map<String, dynamic>> _tasks = [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _loadUnreadNotifications();
  }

  // D7 - Lay so thong bao chua doc, khong lam gian doan Dashboard.
  Future<void> _loadUnreadNotifications() async {
    final token = AuthSession.token;
    if (token == null || token.isEmpty) return;

    try {
      final response = await http
          .get(
            Uri.parse('http://10.0.2.2:5000/api/notifications/unread-count'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted ||
          response.statusCode != 200 ||
          AuthSession.token != token) {
        return;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map && data['unreadCount'] is int) {
        setState(() {
          _unreadNotifications = data['unreadCount'] as int;
        });
      }
    } catch (_) {
      // Loi API thong bao khong anh huong cac chuc nang cu.
    }
  }

  // D7 - Mo danh sach thong bao va cap nhat badge khi quay lai.
  Future<void> _openNotifications() async {
    final token = AuthSession.token;
    if (token == null || token.isEmpty) {
      showAppMessage(
        context,
        'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => NotificationScreen(token: token)),
    );

    if (!mounted) return;
    await _loadUnreadNotifications();
    if (mounted) await _loadDashboard();
  }

  Widget _notificationButton() {
    return IconButton(
      tooltip: 'Thông báo ($_unreadNotifications chưa đọc)',
      onPressed: _openNotifications,
      icon: Badge(
        isLabelVisible: _unreadNotifications > 0,
        label: Text(
          _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
        ),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }

  void _updateWelcome(String fullName, String email) {
    if (!mounted) return;
    setState(() {
      _fullName = fullName;
    });
  }

  Future<void> _loadDashboard() async {
    final token = AuthSession.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _dashboardError = 'Phiên đăng nhập không hợp lệ.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _dashboardError = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(tasksApiUrl),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (response.statusCode == 401) {
        setState(() {
          _dashboardError = 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.';
        });
        return;
      }
      if (response.statusCode != 200) {
        setState(() {
          _dashboardError = responseMessage(
            response,
            'Không thể tải số liệu công việc.',
          );
        });
        return;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map || data['tasks'] is! List) {
        setState(() {
          _dashboardError = 'Dữ liệu công việc không hợp lệ.';
        });
        return;
      }

      setState(() {
        _tasks = (data['tasks'] as List)
            .whereType<Map>()
            .map((task) => Map<String, dynamic>.from(task))
            .toList();
      });
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _dashboardError = 'Kết nối quá thời gian. Vui lòng thử lại.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dashboardError = 'Không thể kết nối backend hoặc đọc dữ liệu.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  int get _completed =>
      _tasks.where((task) => task['status'] == 'da_hoan_thanh').length;

  int get _inProgress =>
      _tasks.where((task) => task['status'] == 'dang_thuc_hien').length;

  int get _notStarted =>
      _tasks.where((task) => task['status'] == 'chua_thuc_hien').length;

  int get _overdue {
    final today = _dateOnly(DateTime.now());
    return _tasks.where((task) {
      if (task['status'] == 'da_hoan_thanh') return false;
      final due = _parseDate(task['dueDate']);
      return due != null && _dateOnly(due).isBefore(today);
    }).length;
  }

  List<Map<String, dynamic>> get _upcomingTasks {
    final today = _dateOnly(DateTime.now());
    final result = _tasks.where((task) {
      if (task['status'] == 'da_hoan_thanh') return false;
      final due = _parseDate(task['dueDate']);
      return due != null && !_dateOnly(due).isBefore(today);
    }).toList();

    result.sort((a, b) {
      final aDate = _parseDate(a['dueDate'])!;
      final bDate = _parseDate(b['dueDate'])!;
      return aDate.compareTo(bDate);
    });
    return result.take(3).toList();
  }

  String _formatDate(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return 'Chưa thiết lập';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _openTasks() async {
    final token = AuthSession.token;
    if (token == null || token.isEmpty) {
      showAppMessage(
        context,
        'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
      );
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TaskListScreen(token: token)));
    if (mounted) await _loadDashboard();
  }

  Future<void> _openStatistics() async {
    final token = AuthSession.token;

    if (token == null || token.isEmpty) {
      showAppMessage(
        context,
        'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
      );
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => StatisticsScreen(token: token)));

    if (mounted) {
      await _loadDashboard();
    }
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(onUpdated: _updateWelcome),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi TaskManager không?',
        ),
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
    AuthSession.token = null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _statCard({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(color: AppPalette.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _overviewCard() {
    final total = _tasks.length;
    final progress = total == 0 ? 0.0 : _completed / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.primary, AppPalette.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined, color: Colors.white70),
              const SizedBox(width: 9),
              Text(
                'TIẾN ĐỘ CÔNG VIỆC',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '$_completed / $total đã hoàn thành',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: total == 0
                  ? const ColoredBox(color: Colors.white24)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_notStarted > 0)
                          Expanded(
                            flex: _notStarted,
                            child: const ColoredBox(color: Color(0xFF94A3B8)),
                          ),
                        if (_inProgress > 0)
                          Expanded(
                            flex: _inProgress,
                            child: const ColoredBox(color: Color(0xFFF59E0B)),
                          ),
                        if (_completed > 0)
                          Expanded(
                            flex: _completed,
                            child: const ColoredBox(color: Color(0xFF16A34A)),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            total == 0
                ? 'Tạo công việc đầu tiên để bắt đầu theo dõi.'
                : 'Theo dõi tiến độ và tập trung vào những việc quan trọng.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _upcomingCard() {
    final upcoming = _upcomingTasks;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Công việc sắp đến hạn',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                    fontSize: 16,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openTasks,
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Chưa có công việc chưa hoàn thành nào có hạn sắp tới.',
                style: TextStyle(color: AppPalette.muted),
              ),
            )
          else
            for (final task in upcoming) ...[
              const Divider(height: 18, color: Color(0xFFEEF1F6)),
              InkWell(
                onTap: _openTasks,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECF1FF),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.assignment_outlined,
                          color: AppPalette.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['title']?.toString() ?? 'Không có tiêu đề',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppPalette.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hạn: ${_formatDate(task['dueDate'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppPalette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF8F9AB0)),
                    ],
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _dashboardBody() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Text(
            'Xin chào,',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppPalette.muted),
          ),
          const SizedBox(height: 2),
          Text(
            _fullName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Đây là tổng quan những công việc bạn có quyền xem.',
            style: TextStyle(color: AppPalette.muted, fontSize: 13),
          ),
          const SizedBox(height: 22),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_dashboardError != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppPalette.red,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(_dashboardError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loadDashboard,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          else ...[
            _overviewCard(),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    label: 'Tổng công việc',
                    value: _tasks.length,
                    icon: Icons.list_alt,
                    color: AppPalette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    label: 'Đã hoàn thành',
                    value: _completed,
                    icon: Icons.check_circle_outline,
                    color: AppPalette.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    label: 'Đang thực hiện',
                    value: _inProgress,
                    icon: Icons.timelapse,
                    color: AppPalette.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    label: 'Quá hạn',
                    value: _overdue,
                    icon: Icons.warning_amber_outlined,
                    color: AppPalette.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Chưa thực hiện: $_notStarted',
              style: const TextStyle(fontSize: 12, color: AppPalette.muted),
            ),
            const SizedBox(height: 24),
            _upcomingCard(),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _openTasks,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Quản lý công việc'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TaskManager',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        actions: [
          _notificationButton(),
          IconButton(
            tooltip: 'Làm mới tổng quan',
            onPressed: _loading
                ? null
                : () async {
                    await _loadDashboard();
                    await _loadUnreadNotifications();
                  },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: SafeArea(child: _dashboardBody()),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          height: 70,
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index == 1) {
              _openTasks();
            } else if (index == 2) {
              _openProfile();
            } else if (index == 3) {
              _openStatistics();
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Tổng quan',
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Công việc',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Tài khoản',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Thống kê',
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// A4 - XEM VA CAP NHAT THONG TIN CA NHAN
// ======================================================
class ProfileScreen extends StatefulWidget {
  final void Function(String fullName, String email)? onUpdated;

  const ProfileScreen({super.key, this.onUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  String? _loadError;
  String _originalName = '';
  String _originalEmail = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final token = AuthSession.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _loadError = 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _loadError = response.statusCode == 401
              ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'
              : responseMessage(response, 'Không thể tải thông tin cá nhân.');
        });
        return;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map || data['user'] is! Map) {
        setState(() => _loadError = 'Dữ liệu hồ sơ không hợp lệ.');
        return;
      }

      final user = data['user'] as Map;
      final name = user['fullName']?.toString() ?? '';
      final email = user['email']?.toString() ?? '';
      _originalName = name;
      _originalEmail = email;
      _nameController.text = name;
      _emailController.text = email;
      widget.onUpdated?.call(name, email);
    } on TimeoutException {
      if (mounted) {
        setState(() => _loadError = 'Kết nối quá thời gian.');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = 'Không thể kết nối backend hoặc đọc dữ liệu.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelEditing() {
    _nameController.text = _originalName;
    _emailController.text = _originalEmail;
    setState(() => _isEditing = false);
  }

  Future<void> _saveProfile() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final token = AuthSession.token;
    if (token == null || token.isEmpty) {
      showAppMessage(
        context,
        'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final response = await http
          .put(
            Uri.parse('$apiBaseUrl/me'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode({
              'fullName': _nameController.text.trim(),
              'email': _emailController.text.trim().toLowerCase(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (response.statusCode != 200) {
        showAppMessage(
          context,
          response.statusCode == 401
              ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'
              : responseMessage(response, 'Cập nhật thất bại.'),
        );
        return;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map || data['user'] is! Map) {
        showAppMessage(context, 'Phản hồi cập nhật không hợp lệ.');
        return;
      }

      final user = data['user'] as Map;
      final name = user['fullName']?.toString() ?? '';
      final email = user['email']?.toString() ?? '';
      _originalName = name;
      _originalEmail = email;
      _nameController.text = name;
      _emailController.text = email;
      widget.onUpdated?.call(name, email);
      setState(() => _isEditing = false);
      showAppMessage(
        context,
        'Cập nhật thông tin cá nhân thành công!',
        success: true,
      );
    } on TimeoutException {
      if (mounted) showAppMessage(context, 'Kết nối quá thời gian.');
    } catch (_) {
      if (mounted) {
        showAppMessage(context, 'Không thể kết nối backend hoặc đọc dữ liệu.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _loadProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Card(
                      color: Colors.white,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const CircleAvatar(
                                radius: 34,
                                child: Icon(Icons.person, size: 34),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Hồ sơ của tôi',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _nameController,
                                readOnly: !_isEditing,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Họ và tên',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Vui lòng nhập họ tên'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                readOnly: !_isEditing,
                                keyboardType: TextInputType.emailAddress,
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
                                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(email)) {
                                    return 'Email không hợp lệ';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              if (!_isEditing)
                                FilledButton.icon(
                                  onPressed: () =>
                                      setState(() => _isEditing = true),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Chỉnh sửa'),
                                )
                              else ...[
                                FilledButton.icon(
                                  onPressed: _isSaving ? null : _saveProfile,
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: _isSaving ? null : _cancelEditing,
                                  child: const Text('Hủy chỉnh sửa'),
                                ),
                              ],
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: (_isEditing || _isSaving)
                                    ? null
                                    : () {
                                        final token = AuthSession.token;
                                        if (token == null || token.isEmpty) {
                                          showAppMessage(
                                            context,
                                            'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
                                          );
                                          return;
                                        }
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ChangePasswordScreen(
                                                  token: token,
                                                ),
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.lock_reset),
                                label: const Text('Đổi mật khẩu'),
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
