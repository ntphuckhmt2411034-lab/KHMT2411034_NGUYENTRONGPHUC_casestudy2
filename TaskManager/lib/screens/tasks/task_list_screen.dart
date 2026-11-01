import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TaskListScreen extends StatefulWidget {
  final String token;

  const TaskListScreen({super.key, required this.token});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  static const String apiUrl = 'http://10.0.2.2:5000/api/tasks';

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _tasks = [];
  String _scope = 'all';

  // Chỉ dùng ID từ token để phân loại dữ liệu hiển thị.
  // Quyền truy cập thực tế luôn do backend xác thực.
  String? get _currentUserId {
    try {
      final parts = widget.token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return null;
      final id = payload['userId'];
      return id is String && id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (response.statusCode == 401) {
        setState(() => _error = 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
        return;
      }
      if (response.statusCode != 200) {
        setState(() => _error = 'Không thể tải danh sách công việc.');
        return;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map || data['tasks'] is! List) {
        setState(() => _error = 'Dữ liệu công việc không hợp lệ.');
        return;
      }

      final rawTasks = data['tasks'] as List;
      setState(() {
        _tasks = rawTasks
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } on TimeoutException {
      if (mounted) setState(() => _error = 'Kết nối quá thời gian.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể kết nối backend hoặc đọc dữ liệu.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _idOf(dynamic value) {
    if (value is String) return value;
    if (value is Map) {
      final id = value['_id'] ?? value['id'];
      return id?.toString();
    }
    return null;
  }

  bool _containsUser(dynamic values, String userId) {
    if (values is! List) return false;
    return values.any((value) => _idOf(value) == userId);
  }

  List<Map<String, dynamic>> get _visibleTasks {
    final userId = _currentUserId;
    if (_scope == 'all' || userId == null) return _tasks;

    return _tasks.where((task) {
      switch (_scope) {
        case 'created':
          return _idOf(task['createdBy']) == userId;
        case 'assigned':
          return _idOf(task['assignedTo']) == userId;
        case 'shared':
          return _containsUser(task['sharedWith'], userId);
        default:
          return true;
      }
    }).toList();
  }

  String _statusLabel(String? value) {
    switch (value) {
      case 'chua_thuc_hien':
        return 'Chưa thực hiện';
      case 'dang_thuc_hien':
        return 'Đang thực hiện';
      case 'da_hoan_thanh':
        return 'Đã hoàn thành';
      default:
        return 'Không xác định';
    }
  }

  String _priorityLabel(String? value) {
    switch (value) {
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
    if (value == null || value.toString().isEmpty) return 'Chưa thiết lập';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'Không hợp lệ';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final title = task['title']?.toString() ?? 'Không có tiêu đề';
    final description = task['description']?.toString() ?? '';
    final status = _statusLabel(task['status']?.toString());
    final priority = _priorityLabel(task['priority']?.toString());
    final dueDate = _dateLabel(task['dueDate']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.pending_actions, size: 18),
                  label: Text(status),
                ),
                Chip(
                  avatar: const Icon(Icons.flag_outlined, size: 18),
                  label: Text('Ưu tiên: $priority'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Hạn hoàn thành: $dueDate')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleTasks = _visibleTasks;
    final hasUserId = _currentUserId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách công việc'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _isLoading ? null : _loadTasks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loadTasks,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        )
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tổng số công việc: ${_tasks.length}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            if (hasUserId)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final option in const [
                      ('all', 'Tất cả'),
                      ('created', 'Tôi tạo'),
                      ('assigned', 'Được giao'),
                      ('shared', 'Được chia sẻ'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(option.$2),
                          selected: _scope == option.$1,
                          onSelected: (_) => setState(() => _scope = option.$1),
                        ),
                      ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Không xác định được tài khoản để phân loại công việc.'),
              ),
            Expanded(
              child: visibleTasks.isEmpty
                  ? Center(
                child: Text(
                  _tasks.isEmpty
                      ? 'Chưa có công việc nào.'
                      : 'Không có công việc trong mục này.',
                ),
              )
                  : RefreshIndicator(
                onRefresh: _loadTasks,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleTasks.length,
                  itemBuilder: (context, index) =>
                      _buildTaskCard(visibleTasks[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
