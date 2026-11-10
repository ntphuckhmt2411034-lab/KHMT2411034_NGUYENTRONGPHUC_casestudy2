import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../tasks/task_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  final String token;

  const NotificationScreen({super.key, required this.token});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const String _api = 'http://10.0.2.2:5000/api/notifications';

  String _filter = 'all';
  bool _loading = false;
  bool _working = false;
  String? _error;

  int _unreadCount = 0;
  int _total = 0;

  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${widget.token}',
  };

  String _errorFor(http.Response response) {
    if (response.statusCode == 401) {
      return 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
    }

    if (response.statusCode == 403 || response.statusCode == 404) {
      return 'Không tìm thấy thông báo hoặc bạn không có quyền truy cập.';
    }

    return 'Yêu cầu thất bại (HTTP ${response.statusCode}).';
  }

  Future<void> _refresh() async {
    if (_loading || _working) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(_api).replace(queryParameters: {'filter': _filter});

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() => _error = _errorFor(response));
        return;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map || decoded['notifications'] is! List) {
        setState(() {
          _error = 'Dữ liệu thông báo không hợp lệ.';
        });
        return;
      }

      final notifications = (decoded['notifications'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      setState(() {
        _items = notifications;
        _unreadCount = decoded['unreadCount'] is int
            ? decoded['unreadCount'] as int
            : 0;
        _total = decoded['total'] is int ? decoded['total'] as int : 0;
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
          _error = 'Không thể kết nối Backend hoặc đọc dữ liệu.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _markRead(String id) async {
    try {
      final response = await http
          .patch(Uri.parse('$_api/$id/read'), headers: _headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return true;
      }

      if (mounted) {
        _showMessage(_errorFor(response));
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Không thể đánh dấu thông báo đã đọc.');
      }
    }

    return false;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    if (_working || _loading) return;

    final id = item['id']?.toString() ?? '';
    final taskId = item['taskId']?.toString() ?? '';

    if (id.isEmpty) return;

    setState(() => _working = true);

    final ok = item['isRead'] == true || await _markRead(id);

    if (!mounted) return;

    setState(() => _working = false);

    if (!ok) return;

    await _refresh();

    if (!mounted) return;

    if (taskId.isEmpty || taskId == 'null') {
      _showMessage('Thông báo này không có công việc liên quan.');
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TaskDetailScreen(token: widget.token, taskId: taskId),
      ),
    );

    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _readAll() async {
    if (_working || _loading || _unreadCount == 0) {
      return;
    }

    setState(() => _working = true);

    try {
      final response = await http
          .patch(Uri.parse('$_api/read-all'), headers: _headers)
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode != 200) {
        _showMessage(_errorFor(response));
        return;
      }

      _showMessage('Đã đánh dấu tất cả là đã đọc.');
    } catch (_) {
      if (mounted) {
        _showMessage('Không thể cập nhật thông báo.');
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }

    await _refresh();
  }

  void _changeFilter(String value) {
    if (_filter == value || _loading || _working) {
      return;
    }

    setState(() => _filter = value);
    _refresh();
  }

  String _timeLabel(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();

    if (date == null) return 'Không rõ thời gian';

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'task_due_reminder':
        return Icons.alarm_outlined;
      case 'task_assigned':
        return Icons.assignment_ind_outlined;
      case 'task_shared':
        return Icons.people_outline;
      case 'task_completed':
        return Icons.task_alt;
      default:
        return Icons.notifications_outlined;
    }
  }

  Widget _notificationTile(Map<String, dynamic> item) {
    final read = item['isRead'] == true;
    final title = item['title']?.toString() ?? 'Thông báo';
    final message = item['message']?.toString() ?? '';
    final type = item['type']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: read ? Colors.white : const Color(0xFFEDF3FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: read ? const Color(0xFFE5EAF1) : const Color(0xFFBCD0FA),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _loading || _working ? null : () => _openNotification(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFDEE9FF),
                child: Icon(_typeIcon(type), color: const Color(0xFF3458A6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: read ? FontWeight.w600 : FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(message, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(
                      _timeLabel(item['createdAt']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF697892),
                      ),
                    ),
                  ],
                ),
              ),
              if (!read)
                const Padding(
                  padding: EdgeInsets.only(left: 7, top: 4),
                  child: Icon(Icons.circle, size: 10, color: Color(0xFF3458A6)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String filter, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == filter,
        onSelected: _loading || _working ? null : (_) => _changeFilter(filter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loading || _working ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$_unreadCount thông báo chưa đọc',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _unreadCount > 0 && !_working && !_loading
                        ? _readAll
                        : null,
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Đọc tất cả'),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('all', 'Tất cả'),
                  _chip('unread', 'Chưa đọc'),
                  _chip('read', 'Đã đọc'),
                ],
              ),
            ),
            if (_loading || _working) const LinearProgressIndicator(),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                          OutlinedButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    )
                  : _items.isEmpty && !_loading
                  ? const Center(
                      child: Text('Chưa có thông báo trong bộ lọc này.'),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _items.length) {
                            return Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                _total > _items.length
                                    ? 'Hiển thị ${_items.length}/$_total thông báo mới nhất.'
                                    : 'Tổng: $_total thông báo',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF697892),
                                ),
                              ),
                            );
                          }

                          return _notificationTile(_items[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
