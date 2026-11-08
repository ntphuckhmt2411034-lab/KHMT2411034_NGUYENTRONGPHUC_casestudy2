import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TaskMembersScreen extends StatefulWidget {
  final String token;
  final String taskId;

  const TaskMembersScreen({
    super.key,
    required this.token,
    required this.taskId,
  });

  @override
  State<TaskMembersScreen> createState() => _TaskMembersScreenState();
}

class _TaskMembersScreenState extends State<TaskMembersScreen> {
  static const String _baseUrl = 'http://10.0.2.2:5000/api/tasks';

  bool _loading = false;
  bool _deleting = false;

  String? _error;
  String? _primaryId;

  List<Map<String, dynamic>> _assignees = [];
  List<Map<String, dynamic>> _shares = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // =====================================================
  // HAM HO TRO
  // =====================================================

  String _idOf(dynamic value) {
    if (value is Map) {
      return (value['_id'] ?? value['id'])?.toString() ?? '';
    }

    return value?.toString() ?? '';
  }

  String _nameOf(Map<String, dynamic> user) {
    final name = user['fullName']?.toString().trim() ?? '';

    return name.isEmpty ? 'Thành viên' : name;
  }

  String _errorMessage(Object error) {
    if (error is TimeoutException) {
      return 'Kết nối quá thời gian. Vui lòng thử lại.';
    }

    if (error is FormatException) {
      return error.message;
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  // =====================================================
  // SUA LOI FORMATEXCEPTION
  // KIEM TRA PHAN HOI TRUOC KHI DOC JSON
  // =====================================================

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);

    final contentType = response.headers['content-type'] ?? '';

    final url = response.request?.url.toString() ?? 'Không xác định';

    final trimmedBody = body.trimLeft();

    // Neu backend tra ve HTML thi khong jsonDecode.
    if (trimmedBody.startsWith('<!DOCTYPE') ||
        trimmedBody.startsWith('<!doctype') ||
        trimmedBody.startsWith('<html') ||
        trimmedBody.startsWith('<HTML')) {
      throw Exception(
        'API trả về HTML thay vì JSON.\n'
        'HTTP: ${response.statusCode}\n'
        'URL: $url\n'
        'Content-Type: $contentType\n'
        'Hãy kiểm tra đường dẫn API trên backend.',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw Exception(
        'API trả về dữ liệu không phải JSON.\n'
        'HTTP: ${response.statusCode}\n'
        'URL: $url\n'
        'Content-Type: $contentType',
      );
    }

    if (decoded is! Map) {
      throw Exception(
        'Dữ liệu API không hợp lệ.\n'
        'HTTP: ${response.statusCode}\n'
        'URL: $url',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  // =====================================================
  // C5 - GOI API LAY DANH SACH THANH VIEN
  // =====================================================

  Future<Map<String, dynamic>> _fetch(String path) async {
    final uri = Uri.parse('$_baseUrl/${widget.taskId}/$path');

    final response = await http
        .get(
          uri,
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 20));

    final data = _decodeResponse(response);

    if (response.statusCode != 200) {
      throw Exception(
        '${data['message'] ?? 'Yêu cầu thất bại'}\n'
        'HTTP: ${response.statusCode}\n'
        'URL: $uri',
      );
    }

    return data;
  }

  // =====================================================
  // C5 - TAI DANH SACH NGUOI DUOC GIAO VA CHIA SE
  // =====================================================

  Future<void> _load() async {
    if (_loading || _deleting) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        _fetch('assignees'),
        _fetch('shares'),
      ]);

      if (!mounted) return;

      final assigned = responses[0]['assignees'];
      final shared = responses[1]['shares'];

      if (assigned is! List || shared is! List) {
        throw Exception('Danh sách thành viên không hợp lệ.');
      }

      final assignees = assigned
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final shares = shared
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      setState(() {
        _assignees = assignees;
        _shares = shares;
        _primaryId = responses[0]['primaryAssigneeId']?.toString();
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // =====================================================
  // C6 - HUY GIAO VIEC HOAC THU HOI CHIA SE
  // =====================================================

  Future<void> _deleteMember({
    required String userId,
    required bool isAssignee,
  }) async {
    if (_loading || _deleting || userId.isEmpty) {
      return;
    }

    setState(() {
      _deleting = true;
    });

    bool success = false;

    try {
      final type = isAssignee ? 'assignees' : 'shares';

      final uri = Uri.parse('$_baseUrl/${widget.taskId}/$type/$userId');

      final response = await http
          .delete(
            uri,
            headers: {
              'Authorization': 'Bearer ${widget.token}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      final data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw Exception(
          '${data['message'] ?? 'Thao tác thất bại'}\n'
          'HTTP: ${response.statusCode}\n'
          'URL: $uri',
        );
      }

      success = true;

      _showMessage(data['message']?.toString() ?? 'Thao tác thành công.');
    } catch (error) {
      _showMessage(_errorMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }

    if (success && mounted) {
      await _load();
    }
  }

  // =====================================================
  // C6 - XAC NHAN TRUOC KHI XOA THANH VIEN
  // =====================================================

  Future<void> _confirmDelete({
    required Map<String, dynamic> user,
    required bool isAssignee,
    bool primary = false,
  }) async {
    if (_loading || _deleting) return;

    final userId = _idOf(user);

    if (userId.isEmpty) {
      _showMessage('Không xác định được tài khoản thành viên.', isError: true);
      return;
    }

    final name = _nameOf(user);

    final title = isAssignee
        ? 'Xác nhận hủy giao việc'
        : 'Xác nhận thu hồi chia sẻ';

    final description = isAssignee
        ? 'Bạn có chắc muốn hủy giao việc cho $name?'
        : 'Bạn có chắc muốn thu hồi quyền chia sẻ của $name?';

    final extra = primary
        ? '\n\nThành viên này là người phụ trách chính. '
              'Nếu hủy giao việc, vai trò phụ trách chính '
              'cũng sẽ bị xóa.'
        : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text('$description$extra'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await _deleteMember(userId: userId, isAssignee: isAssignee);
  }

  // =====================================================
  // GIAO DIEN MOT THANH VIEN
  // =====================================================

  Widget _memberTile(
    Map<String, dynamic> user, {
    String? subtitle,
    bool primary = false,
    required bool isAssignee,
  }) {
    final name = _nameOf(user);
    final email = user['email']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: CircleAvatar(
            child: Icon(primary ? Icons.star : Icons.person_outline),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (email.isNotEmpty)
                Text(email, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (subtitle != null) Text(subtitle),
              if (primary)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Phụ trách chính',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          trailing: IconButton(
            tooltip: isAssignee ? 'Hủy giao việc' : 'Thu hồi chia sẻ',
            onPressed: _loading || _deleting
                ? null
                : () => _confirmDelete(
                    user: user,
                    isAssignee: isAssignee,
                    primary: primary,
                  ),
            icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // TIEU DE TUNG NHOM THANH VIEN
  // =====================================================

  Widget _sectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        '$title ($count)',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  // =====================================================
  // GIAO DIEN MAN HINH DANH SACH THANH VIEN
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách thành viên'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loading || _deleting ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorView()
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      _sectionTitle('Người được giao', _assignees.length),

                      if (_assignees.isEmpty)
                        const ListTile(
                          title: Text('Chưa giao cho thành viên nào'),
                        ),

                      for (final user in _assignees)
                        _memberTile(
                          user,
                          isAssignee: true,
                          primary:
                              _primaryId != null &&
                              _idOf(user).toLowerCase() ==
                                  _primaryId!.toLowerCase(),
                        ),

                      const Divider(height: 24),

                      _sectionTitle('Người được chia sẻ', _shares.length),

                      if (_shares.isEmpty)
                        const ListTile(
                          title: Text('Chưa chia sẻ với thành viên nào'),
                        ),

                      for (final share in _shares)
                        _memberTile(
                          share['userId'] is Map
                              ? Map<String, dynamic>.from(
                                  share['userId'] as Map,
                                )
                              : <String, dynamic>{},
                          isAssignee: false,
                          subtitle: share['permission'] == 'editor'
                              ? 'Quyền: Editor (chỉnh sửa)'
                              : 'Quyền: Viewer (chỉ xem)',
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                if (_deleting)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  // =====================================================
  // GIAO DIEN THONG BAO LOI API
  // =====================================================

  Widget _buildErrorView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Không thể tải danh sách thành viên',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SelectableText(
              _error ?? 'Đã xảy ra lỗi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
