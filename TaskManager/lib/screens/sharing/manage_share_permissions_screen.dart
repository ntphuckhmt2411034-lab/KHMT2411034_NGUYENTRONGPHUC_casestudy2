
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ManageSharePermissionsScreen extends StatefulWidget {
  final String token;
  final String taskId;

  const ManageSharePermissionsScreen({
    super.key,
    required this.token,
    required this.taskId,
  });

  @override
  State<ManageSharePermissionsScreen> createState() =>
      _ManageSharePermissionsScreenState();
}

class _ManageSharePermissionsScreenState
    extends State<ManageSharePermissionsScreen> {
  static const String apiBase = 'http://10.0.2.2:5000/api';

  List<Map<String, dynamic>> _shares = [];

  bool _loading = true;
  String? _error;
  String? _savingUserId;

  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  // =====================================================
  // HAM DUNG CHUNG - DOC PHAN HOI TU BACKEND
  // =====================================================
  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map) {
      throw const FormatException('Dữ liệu máy chủ không hợp lệ');
    }

    return Map<String, dynamic>.from(decoded);
  }

  String _errorMessage(Object error) {
    if (error is TimeoutException) {
      return 'Kết nối quá thời gian. Vui lòng thử lại.';
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
        ),
      );
  }

  // =====================================================
  // C4 / C5 - LAY DANH SACH NGUOI DUOC CHIA SE
  // GET /api/tasks/:id/shares
  // =====================================================
  Future<void> _loadShares() async {
    if (_savingUserId != null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$apiBase/tasks/${widget.taskId}/shares'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(const Duration(seconds: 20));

      final data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ??
              'Lỗi HTTP ${response.statusCode}',
        );
      }

      if (data['shares'] is! List) {
        throw const FormatException(
          'Danh sách chia sẻ không hợp lệ',
        );
      }

      if (!mounted) return;

      setState(() {
        _shares = (data['shares'] as List)
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải danh sách: ${_errorMessage(error)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // =====================================================
  // C4 - THAY DOI QUYEN VIEWER / EDITOR
  // PATCH /api/tasks/:id/shares/:userId/permission
  // =====================================================
  Future<void> _changePermission(
      String userId,
      String permission,
      ) async {
    if (_savingUserId != null || _loading || userId.isEmpty) {
      return;
    }

    if (permission != 'viewer' && permission != 'editor') {
      return;
    }

    setState(() {
      _savingUserId = userId;
    });

    bool success = false;

    try {
      final response = await http.patch(
        Uri.parse(
          '$apiBase/tasks/${widget.taskId}/shares/'
              '$userId/permission',
        ),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'permission': permission,
        }),
      ).timeout(const Duration(seconds: 20));

      final data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ??
              'Lỗi HTTP ${response.statusCode}',
        );
      }

      success = true;
      _showMessage('Cập nhật quyền thành công');
    } catch (error) {
      _showMessage(
        'Cập nhật quyền thất bại: ${_errorMessage(error)}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _savingUserId = null);
      }
    }

    if (success && mounted) {
      await _loadShares();
    }
  }

  // =====================================================
  // C6 - XAC NHAN THU HOI QUYEN CHIA SE
  // =====================================================
  Future<void> _confirmRevoke(
      String userId,
      String name,
      String permission,
      ) async {
    if (_loading || _savingUserId != null || userId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận thu hồi quyền'),
        content: Text(
          'Bạn có chắc muốn thu hồi quyền '
              '${permission == 'editor' ? 'Editor' : 'Viewer'} '
              'của $name?\n\n'
              'Thành viên sẽ không còn quyền truy cập '
              'thông qua chia sẻ công việc này.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Thu hồi quyền'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    await _revokeShare(userId);
  }

  // =====================================================
  // C6 - THU HOI QUYEN CHIA SE
  // DELETE /api/tasks/:id/shares/:userId
  // =====================================================
  Future<void> _revokeShare(String userId) async {
    if (_loading || _savingUserId != null || userId.isEmpty) {
      return;
    }

    setState(() {
      _savingUserId = userId;
    });

    bool success = false;

    try {
      final response = await http.delete(
        Uri.parse(
          '$apiBase/tasks/${widget.taskId}/shares/$userId',
        ),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(const Duration(seconds: 20));

      final data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw Exception(
          data['message']?.toString() ??
              'Lỗi HTTP ${response.statusCode}',
        );
      }

      success = true;

      _showMessage(
        data['message']?.toString() ??
            'Thu hồi quyền chia sẻ thành công',
      );
    } catch (error) {
      _showMessage(
        'Thu hồi quyền thất bại: ${_errorMessage(error)}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _savingUserId = null);
      }
    }

    if (success && mounted) {
      await _loadShares();
    }
  }

  // =====================================================
  // GIAO DIEN DANH SACH QUYEN CHIA SE
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý quyền chia sẻ'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loading || _savingUserId != null
                ? null
                : _loadShares,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadShares,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      )
          : _shares.isEmpty
          ? RefreshIndicator(
        onRefresh: _loadShares,
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Center(
              child: Text(
                'Chưa có người được chia sẻ',
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _savingUserId == null
            ? _loadShares
            : () async {},
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Viewer: Chỉ xem công việc.\n'
                  'Editor: Được chỉnh sửa công việc.\n\n'
                  'Chỉ người tạo công việc mới được '
                  'thay đổi hoặc thu hồi quyền chia sẻ.',
            ),
            const SizedBox(height: 16),
            for (final share in _shares)
              _buildShareCard(share),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // THE THANH VIEN - C4 + C6
  // =====================================================
  Widget _buildShareCard(Map<String, dynamic> share) {
    final user = share['userId'];

    if (user is! Map) {
      return const SizedBox.shrink();
    }

    final userId = user['_id']?.toString() ?? '';
    final rawName = user['fullName']?.toString().trim() ?? '';
    final name = rawName.isEmpty ? 'Thành viên' : rawName;
    final email = user['email']?.toString() ?? '';
    final permission = share['permission']?.toString() ?? 'viewer';

    final validPermission =
    permission == 'editor' ? 'editor' : 'viewer';

    final isSaving = _savingUserId == userId;
    final isBusy = _loading || _savingUserId != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.person_outline),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        email,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // C4 - Chinh sua Viewer / Editor
            DropdownButtonFormField<String>(
              key: ValueKey('$userId-$validPermission'),
              initialValue: validPermission,
              decoration: const InputDecoration(
                labelText: 'Quyền chia sẻ',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'viewer',
                  child: Text('Viewer - Chỉ xem'),
                ),
                DropdownMenuItem(
                  value: 'editor',
                  child: Text('Editor - Chỉnh sửa'),
                ),
              ],
              onChanged: isBusy || userId.isEmpty
                  ? null
                  : (value) {
                if (value != null &&
                    value != validPermission) {
                  _changePermission(userId, value);
                }
              },
            ),

            const SizedBox(height: 12),

            // C6 - Thu hoi quyen chia se
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: isBusy || userId.isEmpty
                    ? null
                    : () => _confirmRevoke(
                  userId,
                  name,
                  validPermission,
                ),
                icon: const Icon(
                  Icons.person_remove_outlined,
                ),
                label: const Text('Thu hồi quyền'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(
                    color: Colors.red,
                  ),
                ),
              ),
            ),

            if (isSaving) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
