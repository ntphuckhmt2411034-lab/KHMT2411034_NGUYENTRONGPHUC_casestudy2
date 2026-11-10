import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'task_edit_screen.dart';
import 'task_email_history_screen.dart';
import '../assignment/assign_task_screen.dart';
import '../sharing/share_task_screen.dart';
import '../sharing/manage_share_permissions_screen.dart';
import '../assignment/task_members_screen.dart';

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

  // B4 - Ba muc do uu tien.
  static const Map<String, String> priorityOptions = {
    'thap': 'Thấp',
    'trung_binh': 'Trung bình',
    'cao': 'Cao',
  };

  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isUpdatingStatus = false;
  bool _isUpdatingPriority = false;
  bool _wasUpdated = false;

  String? _error;
  Map<String, dynamic>? _task;

  bool get _isBusy =>
      _isLoading || _isDeleting || _isUpdatingStatus || _isUpdatingPriority;

  // JWT chi dung de an/hien nut.
  // Backend kiem tra quyen thuc te.
  String? get _currentUserId {
    try {
      final parts = widget.token.split('.');
      if (parts.length != 3) return null;

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );

      if (payload is! Map) return null;

      final userId = payload['userId'];

      return userId is String && userId.isNotEmpty ? userId : null;
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

  // C4 - Nguoi tao hoac nguoi co quyen editor duoc chinh sua.
  bool get _canEdit {
    if (_canManage) return true;

    final task = _task;
    if (task == null) return false;

    return task['sharePermission'] == 'editor';
  }

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  // B2.1 - Xem chi tiet cong viec.
  Future<void> _loadDetail() async {
    if (!mounted || _isDeleting || _isUpdatingStatus || _isUpdatingPriority) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _task = null;
    });

    try {
      final response = await http
          .get(
        Uri.parse('$apiUrl/${widget.taskId}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 401) {
        setState(() {
          _error = 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
        });
        return;
      }

      if (response.statusCode == 403 || response.statusCode == 404) {
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

  // B2.3 - Mo man hinh chinh sua.
  Future<void> _openEditTask() async {
    if (!_canEdit || _isBusy) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TaskEditScreen(token: widget.token, taskId: widget.taskId),
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

  // C1 - Mo man hinh giao viec (chi nguoi tao).
  Future<void> _openAssignTask() async {
    if (!_canManage || _isBusy) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AssignTaskScreen(
          token: widget.token,
          taskId: widget.taskId,
          taskTitle: _task?['title']?.toString() ?? 'Công việc',
          existingIds: [
            if (_idOf(_task?['assignedTo']) != null)
              _idOf(_task?['assignedTo'])!,
            if (_task?['assigneeIds'] is List)
              ...(_task!['assigneeIds'] as List).map(_idOf).whereType<String>(),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (updated == true) {
      _wasUpdated = true;
      await _loadDetail();
      if (mounted && _error == null) {
        _showMessage('Giao công việc thành công!');
      }
    }
  }

  // B3 - Hop thoai doi trang thai.
  Future<void> _openStatusDialog() async {
    if (!_canEdit || _isBusy) return;

    final currentStatus = _task?['status']?.toString();

    String selectedStatus = statusOptions.containsKey(currentStatus)
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
    if (!_canEdit || _isBusy) return;
    if (!statusOptions.containsKey(newStatus)) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final response = await http
          .patch(
        Uri.parse('$apiUrl/${widget.taskId}/status'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      )
          .timeout(const Duration(seconds: 20));

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

      _showMessage(
        _responseMessage(response, 'Không thể cập nhật trạng thái.'),
      );
    } on TimeoutException {
      if (mounted) {
        _showMessage('Cập nhật trạng thái thất bại: Kết nối quá thời gian.');
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

  // B4 - Hop thoai chon do uu tien.
  Future<void> _openPriorityDialog() async {
    if (!_canEdit || _isBusy) return;

    final currentPriority = _task?['priority']?.toString();

    String selectedPriority = priorityOptions.containsKey(currentPriority)
        ? currentPriority!
        : 'trung_binh';

    final newPriority = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Cập nhật độ ưu tiên'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chọn mức độ ưu tiên cho công việc:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPriority,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Mức độ ưu tiên',
                      border: OutlineInputBorder(),
                    ),
                    items: priorityOptions.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedPriority = value;
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
                  onPressed: selectedPriority == currentPriority
                      ? null
                      : () {
                    Navigator.pop(dialogContext, selectedPriority);
                  },
                  child: const Text('Lưu ưu tiên'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || newPriority == null) return;

    await _updatePriority(newPriority);
  }

  // B4 - PATCH /api/tasks/:id/priority
  Future<void> _updatePriority(String newPriority) async {
    if (!_canEdit || _isBusy) return;
    if (!priorityOptions.containsKey(newPriority)) return;

    setState(() {
      _isUpdatingPriority = true;
    });

    try {
      final response = await http
          .patch(
        Uri.parse('$apiUrl/${widget.taskId}/priority'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'priority': newPriority}),
      )
          .timeout(const Duration(seconds: 20));

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

        _showMessage('Cập nhật độ ưu tiên thành công!');
        return;
      }

      _showMessage(
        _responseMessage(response, 'Không thể cập nhật độ ưu tiên.'),
      );
    } on TimeoutException {
      if (mounted) {
        _showMessage('Cập nhật độ ưu tiên thất bại: Kết nối quá thời gian.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Không thể kết nối backend để cập nhật độ ưu tiên.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPriority = false;
        });
      }
    }
  }

  // Doc thong bao loi backend.
  String _responseMessage(http.Response response, String fallback) {
    if (response.statusCode == 401) {
      return 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
    }

    if (response.statusCode == 403 || response.statusCode == 404) {
      return 'Không tìm thấy công việc hoặc bạn không có quyền thao tác.';
    }

    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
    } catch (_) {
      // Giu thong bao mac dinh.
    }

    return fallback;
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
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Xóa công việc'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    await _deleteTask();
  }

  // B2.4 - DELETE /api/tasks/:id
  Future<void> _deleteTask() async {
    if (!_canManage || _isBusy) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final response = await http
          .delete(
        Uri.parse('$apiUrl/${widget.taskId}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showMessage('Xóa công việc thành công!');

        Navigator.pop(context, true);
        return;
      }

      _showMessage(_responseMessage(response, 'Không thể xóa công việc.'));
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

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Tra ve true neu da sua, xoa, doi trang thai/uu tien.
  void _goBack() {
    if (_isDeleting || _isUpdatingStatus || _isUpdatingPriority) {
      return;
    }

    Navigator.pop(context, _wasUpdated);
  }

  int _assignedCount(Map<String, dynamic> task) {
    final ids = <String>{};
    final legacy = _idOf(task['assignedTo']);
    if (legacy != null) ids.add(legacy);
    if (task['assigneeIds'] is List) {
      ids.addAll((task['assigneeIds'] as List).map(_idOf).whereType<String>());
    }
    return ids.length;
  }

  // C2 - Hien thi vai tro, khong hien ObjectId dai tren giao dien.
  Widget _primaryAssigneeSection(Map<String, dynamic> task) {
    final primaryValue = task['primaryAssigneeId'];
    final primaryId = _idOf(primaryValue);
    final currentId = _currentUserId;
    final isPrimary =
        primaryId != null &&
            currentId != null &&
            primaryId.toLowerCase() == currentId.toLowerCase();

    String? primaryName;
    final primaryInfo = task['primaryAssignee'];
    if (primaryInfo is Map) {
      primaryName = (primaryInfo['fullName'] ?? primaryInfo['name'])
          ?.toString()
          .trim();
    }
    if ((primaryName == null || primaryName.isEmpty) && primaryValue is Map) {
      primaryName = (primaryValue['fullName'] ?? primaryValue['name'])
          ?.toString()
          .trim();
    }

    final hasPrimary = primaryId != null && primaryId.isNotEmpty;
    final label = !hasPrimary
        ? 'Chưa chỉ định người phụ trách chính'
        : isPrimary
        ? 'Bạn là người phụ trách chính'
        : (primaryName != null && primaryName.isNotEmpty)
        ? primaryName
        : 'Đã chỉ định người phụ trách chính';

    return Row(
      children: [
        Icon(
          hasPrimary ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 19,
          color: hasPrimary ? const Color(0xFF4165AD) : Colors.grey,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  String _statusLabel(dynamic status) {
    return statusOptions[status?.toString()] ?? 'Không xác định';
  }

  String _priorityLabel(dynamic priority) {
    return priorityOptions[priority?.toString()] ?? 'Không xác định';
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

  // Giao dien C7 - Thong tin ngan gon theo luoi hai cot.
  Widget _infoCell({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF63758D)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7B8797),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.edit_outlined,
                size: 15,
                color: Color(0xFF4165AD),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF1)),
      ),
      child: child,
    );
  }

  Widget _compactAction({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: Icon(icon, size: 21, color: const Color(0xFF4165AD)),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(0xFF9AA6B5),
        size: 19,
      ),
      onTap: onTap,
    );
  }

  // D6 - Lich su email chi hien thi cho nguoi tao cong viec.
  Future<void> _openEmailHistory() async {
    if (!_canManage || _isBusy) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TaskEmailHistoryScreen(
          token: widget.token,
          taskId: widget.taskId,
          taskTitle: _task?['title']?.toString() ?? 'Công việc',
        ),
      ),
    );
  }

  Future<void> _openMembersAndRefresh() async {
    if (!_canManage || _isBusy) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            TaskMembersScreen(token: widget.token, taskId: widget.taskId),
      ),
    );
    if (!mounted) return;
    // Danh sach thanh vien co the da thay doi do C6.
    _wasUpdated = true;
    await _loadDetail();
  }

  Future<void> _openShareTask() async {
    if (!_canManage || _isBusy) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ShareTaskScreen(
          token: widget.token,
          taskId: widget.taskId,
          taskTitle: _task?['title']?.toString() ?? 'Công việc',
        ),
      ),
    );
    if (!mounted) return;
    if (updated == true) _wasUpdated = true;
    await _loadDetail();
  }

  Future<void> _openPermissions() async {
    if (!_canManage || _isBusy) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ManageSharePermissionsScreen(
          token: widget.token,
          taskId: widget.taskId,
        ),
      ),
    );
    if (!mounted) return;
    _wasUpdated = true;
    await _loadDetail();
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    const primaryBlue = Color(0xFF3459A6);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop &&
            !_isDeleting &&
            !_isUpdatingStatus &&
            !_isUpdatingPriority) {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF6F8FC),
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Chi tiết công việc',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back),
            onPressed: (_isDeleting || _isUpdatingStatus || _isUpdatingPriority)
                ? null
                : _goBack,
          ),
          actions: [
            if (!_isLoading && _error == null && _canEdit)
              IconButton(
                tooltip: 'Chỉnh sửa công việc',
                onPressed: _isBusy ? null : _openEditTask,
                icon: const Icon(Icons.edit_outlined, size: 21),
              ),
            if (!_isLoading && _error == null && _canManage)
              PopupMenuButton<String>(
                tooltip: 'Thêm tùy chọn',
                onSelected: (value) {
                  if (value == 'delete') _confirmDeleteTask();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 19),
                        SizedBox(width: 8),
                        Text(
                          'Xóa công việc',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            IconButton(
              tooltip: 'Làm mới',
              onPressed: _isBusy ? null : _loadDetail,
              icon: const Icon(Icons.refresh, size: 21),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
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
            ? const Center(child: Text('Không có dữ liệu công việc.'))
            : SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['title']?.toString() ?? 'Không có tiêu đề',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if ((task['description']?.toString() ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            task['description'].toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF667487),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(
                          height: 1,
                          color: Color(0xFFE9EDF4),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _infoCell(
                                label: 'Trạng thái',
                                value: _statusLabel(task['status']),
                                icon: Icons.pending_actions_outlined,
                                onTap: _canEdit && !_isBusy
                                    ? _openStatusDialog
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _infoCell(
                                label: 'Độ ưu tiên',
                                value: _priorityLabel(task['priority']),
                                icon: Icons.flag_outlined,
                                onTap: _canEdit && !_isBusy
                                    ? _openPriorityDialog
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const Divider(
                          height: 12,
                          color: Color(0xFFE9EDF4),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _infoCell(
                                label: 'Ngày bắt đầu',
                                value: _dateLabel(task['startDate']),
                                icon: Icons.event_available_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _infoCell(
                                label: 'Hạn hoàn thành',
                                value: _dateLabel(task['dueDate']),
                                icon: Icons.event_outlined,
                              ),
                            ),
                          ],
                        ),
                        if (_canEdit)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Nhấn vào trạng thái hoặc độ ưu tiên để thay đổi.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8793A5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Thành viên & phân quyền',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF0FC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_assignedCount(task)} người được giao',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        _primaryAssigneeSection(task),
                        if (_canManage) ...[
                          const Divider(
                            height: 24,
                            color: Color(0xFFE9EDF4),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isBusy
                                      ? null
                                      : _openAssignTask,
                                  icon: const Icon(
                                    Icons.group_add_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Giao việc'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryBlue,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isBusy
                                      ? null
                                      : _openShareTask,
                                  icon: const Icon(
                                    Icons.share_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Chia sẻ'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryBlue,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          _compactAction(
                            label: 'Danh sách thành viên',
                            icon: Icons.groups_outlined,
                            onTap: _isBusy
                                ? null
                                : _openMembersAndRefresh,
                          ),
                          const Divider(
                            height: 1,
                            color: Color(0xFFF0F2F7),
                          ),
                          _compactAction(
                            label: 'Quản lý quyền chia sẻ',
                            icon: Icons.admin_panel_settings_outlined,
                            onTap: _isBusy ? null : _openPermissions,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_canManage) ...[
                    const SizedBox(height: 12),
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông báo qua email',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Xem các email đã gửi liên quan đến công việc.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667487),
                            ),
                          ),
                          _compactAction(
                            label: 'Lịch sử gửi email',
                            icon: Icons.mark_email_read_outlined,
                            onTap: _isBusy ? null : _openEmailHistory,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (_isDeleting || _isUpdatingStatus || _isUpdatingPriority)
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
                                    : _isUpdatingStatus
                                    ? 'Đang cập nhật trạng thái...'
                                    : 'Đang cập nhật độ ưu tiên...',
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
