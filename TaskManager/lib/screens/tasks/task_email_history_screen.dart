import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// D6 - Lich su email cua cong viec (Backend chi cho nguoi tao xem).
class TaskEmailHistoryScreen extends StatefulWidget {
  final String token;
  final String taskId;
  final String taskTitle;

  const TaskEmailHistoryScreen({
    super.key,
    required this.token,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<TaskEmailHistoryScreen> createState() => _TaskEmailHistoryScreenState();
}

class _TaskEmailHistoryScreenState extends State<TaskEmailHistoryScreen> {
  static const String _apiUrl = 'http://10.0.2.2:5000/api/tasks';

  bool _loading = false;
  String? _error;
  String _filter = 'all';
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_apiUrl/${widget.taskId}/email-history')
          .replace(queryParameters: _filter == 'all' ? null : {'status': _filter});
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (response.statusCode == 401) {
        setState(() => _error = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
        return;
      }
      if (response.statusCode == 403 || response.statusCode == 404) {
        setState(() => _error = 'Không tìm thấy công việc hoặc bạn không có quyền xem lịch sử email.');
        return;
      }
      if (response.statusCode != 200) {
        setState(() => _error = 'Không thể tải lịch sử email (HTTP ${response.statusCode}).');
        return;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['emailHistory'] is! List) {
        setState(() => _error = 'Dữ liệu lịch sử email không hợp lệ.');
        return;
      }

      final items = (decoded['emailHistory'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      setState(() => _logs = items);
    } on TimeoutException {
      if (mounted) setState(() => _error = 'Kết nối quá thời gian.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể kết nối Backend hoặc đọc dữ liệu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectFilter(String value) {
    if (value == _filter || _loading) return;
    setState(() => _filter = value);
    _loadHistory();
  }

  String _eventLabel(dynamic value) {
    switch (value?.toString()) {
      case 'task_due_reminder':
        return 'Nhắc việc trước hạn';
      case 'task_assigned':
        return 'Giao công việc';
      case 'task_shared':
        return 'Chia sẻ công việc';
      case 'task_completed':
        return 'Hoàn thành công việc';
      case 'task_updated':
        return 'Cập nhật công việc';
      default:
        final text = value?.toString() ?? '';
        return text.isEmpty ? 'Thông báo email' : text;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'sent':
        return 'Đã gửi';
      case 'failed':
        return 'Gửi thất bại';
      case 'pending':
        return 'Đang chờ';
      default:
        return status.isEmpty ? 'Không xác định' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'sent':
        return const Color(0xFF16804A);
      case 'failed':
        return const Color(0xFFB42318);
      default:
        return const Color(0xFF91620E);
    }
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return 'Chưa có';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return 'Không hợp lệ';
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _infoLine(String name, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        '$name: $value',
        style: const TextStyle(fontSize: 13, color: Color(0xFF556174)),
      ),
    );
  }

  Widget _emailCard(Map<String, dynamic> log) {
    final status = (log['status'] ?? '').toString();
    final recipient = (log['recipientEmail'] ?? '').toString();
    final subject = (log['subject'] ?? '').toString();
    final error = (log['errorMessage'] ?? '').toString().trim();
    final attempts = log['attempts']?.toString() ?? '0';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 20, color: Color(0xFF3459A6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _eventLabel(log['eventType']),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(status),
                  ),
                ),
              ],
            ),
            if (subject.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(subject, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            _infoLine('Người nhận', recipient.isEmpty ? 'Không có' : recipient),
            _infoLine('Số lần thử gửi', attempts),
            _infoLine('Tạo lúc', _formatDate(log['createdAt'])),
            if (log['sentAt'] != null)
              _infoLine('Gửi thành công lúc', _formatDate(log['sentAt'])),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Lỗi: $error',
                  style: const TextStyle(color: Color(0xFFB42318), fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Lịch sử gửi email'),
        backgroundColor: const Color(0xFFF6F8FC),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loading ? null : _loadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Text(
                widget.taskTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip('all', 'Tất cả'),
                  _filterChip('sent', 'Đã gửi'),
                  _filterChip('failed', 'Thất bại'),
                  _filterChip('pending', 'Đang chờ'),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _loading ? null : _loadHistory,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _logs.isEmpty && !_loading
                      ? const Center(child: Text('Chưa có email trong bộ lọc này.'))
                      : RefreshIndicator(
                          onRefresh: _loadHistory,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _logs.length,
                            itemBuilder: (context, index) => _emailCard(_logs[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(title),
        selected: _filter == value,
        onSelected: _loading ? null : (_) => _selectFilter(value),
      ),
    );
  }
}
