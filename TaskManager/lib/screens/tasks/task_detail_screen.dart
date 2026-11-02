
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'task_edit_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String token;
  final String taskId;

  const TaskDetailScreen({
    super.key,
    required this.token,
    required this.taskId,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  static const String apiUrl = 'http://10.0.2.2:5000/api/tasks';

  static const Map<String, String> statusOptions = {
    'chua_thuc_hien': 'Chưa thực hiện',
    'dang_thuc_hien': 'Đang thực hiện',
    'da_hoan_thanh': 'Đã hoàn thành',
  };

  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isUpdatingStatus = false;
  bool _wasUpdated = false;

  String? _error;
  Map<String, dynamic>? _task;

  bool get _isBusy => _isLoading || _isDeleting || _isUpdatingStatus;

  // JWT chi dung de an/hien cac nut thao tac.
  // Backend phai kiem tra quyen thuc te.
  String? get _currentUserId {
    try {
      final parts = widget.token.split('.');
      if (parts.length != 3) return null;

      final payload = jsonDecode(
        utf8.decode(
          base64Url.decode(base64Url.normalize(parts[1])),
        ),
      );

      if (payload is! Map) return null;

      final userId = payload['userId'];

      return userId is String && userId.isNotEmpty
          ? userId
          : null;
    } catch (_) {
      return null;
    }
  }

  String? _idOf(dynamic value) {
    if (value is String) return value;

    if (value is Map) {
      return (value['_id'] ?? value['id'])?.toString();
    }

    return null;
  }

  bool get _canManage {
    final userId = _currentUserId;
    final task = _task;

    if (userId == null || task == null) return false;

    return _idOf(task['createdBy']) == userId;
  }

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (!mounted || _isDeleting || _isUpdatingStatus) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _task = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/${widget.taskId}'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 401) {
        setState(() {
          _error = 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
        });
        return;
      }

      if (response.statusCode == 403 ||
          response.statusCode == 404) {
        setState(() {
          _error = 'Không tìm thấy công việc hoặc bạn không có quyền xem.';
        });
        return;
      }

      if (response.statusCode != 200) {
        setState(() {
          _error = 'Không thể tải chi tiết công việc.';
        });
        return;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! Map || data['task'] is! Map) {
        setState(() {
          _error = 'Dữ liệu công việc không hợp lệ.';
        });
        return;
      }

      setState(() {
        _task = Map<String, dynamic>.from(data['task'] as Map);
      });
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error = 'Kết nối quá thời gian.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể kết nối backend.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // B2.3 - Chinh sua cong viec.
  Future<void> _openEditTask() async {
    if (!_canManage || _isBusy) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskEditScreen(
          token: widget.token,
          taskId: widget.taskId,
        ),
      ),
    );

    if (!mounted) return;

    if (updated == true) {
      _wasUpdated = true;

      await _loadDetail();

      if (!mounted) return;

      if (_error == null) {
        _showMessage('Cập nhật công việc thành công!');
      }
    }
  }

  // B3 - Hien thi hop thoai doi trang thai.
  Future<void> _openStatusDialog() async {
    if (!_canManage || _isBusy) return;

    final currentStatus = _task?['status']?.toString();

    String selectedStatus =
    statusOptions.containsKey(currentStatus)
        ? currentStatus!
        : 'chua_thuc_hien';

    final newStatus = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Cập nhật trạng thái'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chọn trạng thái mới cho công việc:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Trạng thái',
                      border: OutlineInputBorder(),
                    ),
                    items: statusOptions.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedStatus = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: selectedStatus == currentStatus
                      ? null
                      : () {
                    Navigator.pop(dialogContext, selectedStatus);
                  },
                  child: const Text('Lưu trạng thái'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || newStatus == null) return;

    await _updateStatus(newStatus);
  }

  // B3 - PATCH /api/tasks/:id/status
  Future<void> _updateStatus(String newStatus) async {
    if (!_canManage || _isBusy) return;
    if (!statusOptions.containsKey(newStatus)) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final response = await http.patch(
        Uri.parse('$apiUrl/${widget.taskId}/status'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': newStatus,
        }),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data is! Map || data['task'] is! Map) {
          _showMessage('Dữ liệu cập nhật không hợp lệ.');
          return;
        }

        setState(() {
          _task = Map<String, dynamic>.from(data['task'] as Map);
          _wasUpdated = true;
        });

        _showMessage('Cập nhật trạng thái thành công!');
        return;
      }

      String message = 'Không thể cập nhật trạng thái.';

      if (response.statusCode == 401) {
        message = 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
      } else if (response.statusCode == 403 ||
          response.statusCode == 404) {
        message =
        'Không tìm thấy công việc hoặc bạn không có quyền cập nhật.';
      } else if (response.statusCode == 400) {
        message = 'Trạng thái công việc không hợp lệ.';
      } else {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));

          if (data is Map && data['message'] is String) {
            message = data['message'] as String;
          }
        } catch (_) {
          // Giu thong bao mac dinh.
        }
      }

      _showMessage(message);
    } on TimeoutException {
      if (mounted) {
        _showMessage('Cập nhật thất bại: Kết nối quá thời gian.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Không thể kết nối backend để cập nhật trạng thái.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  // B2.4 - Xac nhan xoa cong viec.
  Future<void> _confirmDeleteTask() async {
    if (!_canManage || _isBusy) return;

    final taskTitle = _task?['title']?.toString() ?? 'công việc này';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận xóa công việc'),
          content: Text(
            'Bạn có chắc chắn muốn xóa "$taskTitle"?\n\n'
                'Công việc sẽ bị xóa vĩnh viễn và không thể khôi phục.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Xóa công việc'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    await _deleteTask();
  }

  // B2.4 - Xoa cong viec.
  Future<void> _deleteTask() async {
    if (!_canManage || _isBusy) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final response = await http.delete(
        Uri.parse('$apiUrl/${widget.taskId}'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 204) {
        _showMessage('Xóa công việc thành công!');

        Navigator.pop(context, true);
        return;
      }

      String message = 'Không thể xóa công việc.';

      if (response.statusCode == 401) {
        message = 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
      } else if (response.statusCode == 403 ||
          response.statusCode == 404) {
        message = 'Không tìm thấy công việc hoặc bạn không có quyền xóa.';
      } else {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));

          if (data is Map && data['message'] is String) {
            message = data['message'] as String;
          }
        } catch (_) {
          // Giu thong bao mac dinh.
        }
      }

      _showMessage(message);
    } on TimeoutException {
      if (mounted) {
        _showMessage('Xóa thất bại: Kết nối quá thời gian.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Không thể kết nối backend để xóa công việc.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _goBack() {
    if (_isDeleting || _isUpdatingStatus) return;

    Navigator.pop(context, _wasUpdated);
  }

  String _statusLabel(dynamic status) {
    return statusOptions[status?.toString()] ?? 'Không xác định';
  }

  String _priorityLabel(dynamic priority) {
    switch (priority) {
      case 'thap':
        return 'Thấp';
      case 'trung_binh':
        return 'Trung bình';
      case 'cao':
        return 'Cao';
      default:
        return 'Không xác định';
    }
  }

  String _dateLabel(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'Chưa thiết lập';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) return 'Không hợp lệ';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isDeleting && !_isUpdatingStatus) {
          _goBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết công việc'),
          leading: IconButton(
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back),
            onPressed: _isDeleting || _isUpdatingStatus
                ? null
                : _goBack,
          ),
          actions: [
            if (!_isLoading && _error == null && _canManage) ...[
              IconButton(
                tooltip: 'Chỉnh sửa',
                onPressed: _isBusy ? null : _openEditTask,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Xóa công việc',
                onPressed: _isBusy ? null : _confirmDeleteTask,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
              ),
            ],
            IconButton(
              tooltip: 'Làm mới',
              onPressed: _isBusy ? null : _loadDetail,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _isLoading
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
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loadDetail,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        )
            : task == null
            ? const Center(
          child: Text('Không có dữ liệu công việc.'),
        )
            : SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['title']?.toString() ??
                                'Không có tiêu đề',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            task['description']
                                ?.toString()
                                .isNotEmpty ==
                                true
                                ? task['description'].toString()
                                : 'Chưa có mô tả.',
                          ),
                          const Divider(height: 32),
                          _infoRow(
                            'Trạng thái',
                            _statusLabel(task['status']),
                            Icons.pending_actions,
                          ),

                          // B3 - Nut cap nhat trang thai.
                          if (_canManage) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isBusy
                                    ? null
                                    : _openStatusDialog,
                                icon: const Icon(
                                  Icons.sync_alt,
                                ),
                                label: const Text(
                                  'Đổi trạng thái',
                                ),
                              ),
                            ),
                          ],

                          const Divider(height: 24),
                          _infoRow(
                            'Độ ưu tiên',
                            _priorityLabel(task['priority']),
                            Icons.flag_outlined,
                          ),
                          _infoRow(
                            'Ngày bắt đầu',
                            _dateLabel(task['startDate']),
                            Icons.event_available_outlined,
                          ),
                          _infoRow(
                            'Hạn hoàn thành',
                            _dateLabel(task['dueDate']),
                            Icons.event_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_isDeleting || _isUpdatingStatus)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0x66000000),
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                _isDeleting
                                    ? 'Đang xóa công việc...'
                                    : 'Đang cập nhật trạng thái...',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
