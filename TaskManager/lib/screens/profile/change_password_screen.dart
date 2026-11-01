
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChangePasswordScreen extends StatefulWidget {
  final String token;

  const ChangePasswordScreen({
    super.key,
    required this.token,
  });

  @override
  State<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSaving = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final response = await http.put(
        Uri.parse('http://10.0.2.2:5000/api/auth/change-password'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'currentPassword': _currentController.text,
          'newPassword': _newController.text,
        }),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Không thể đổi mật khẩu.';

      if (response.statusCode == 200) {
        _currentController.clear();
        _newController.clear();
        _confirmController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đổi mật khẩu thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kết nối quá thời gian.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể kết nối backend hoặc đọc dữ liệu.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.lock_reset,
                          size: 64,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Thay đổi mật khẩu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _currentController,
                          obscureText: _hideCurrent,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu hiện tại',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                    () => _hideCurrent = !_hideCurrent,
                              ),
                              icon: Icon(
                                _hideCurrent
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) =>
                          value == null || value.isEmpty
                              ? 'Vui lòng nhập mật khẩu hiện tại'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newController,
                          obscureText: _hideNew,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu mới',
                            prefixIcon: const Icon(Icons.lock_reset),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                    () => _hideNew = !_hideNew,
                              ),
                              icon: Icon(
                                _hideNew
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 8) {
                              return 'Mật khẩu phải có ít nhất 8 ký tự';
                            }
                            if (value == _currentController.text) {
                              return 'Mật khẩu mới phải khác mật khẩu cũ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _hideConfirm,
                          decoration: InputDecoration(
                            labelText: 'Xác nhận mật khẩu mới',
                            prefixIcon: const Icon(Icons.verified_user_outlined),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                    () => _hideConfirm = !_hideConfirm,
                              ),
                              icon: Icon(
                                _hideConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) =>
                          value != _newController.text
                              ? 'Mật khẩu xác nhận không khớp'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _changePassword,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              _isSaving
                                  ? 'Đang đổi mật khẩu...'
                                  : 'Lưu mật khẩu mới',
                            ),
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
