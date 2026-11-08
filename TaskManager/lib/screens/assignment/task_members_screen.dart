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
  static const _baseUrl = 'http://10.0.2.2:5000/api/tasks';

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _assignees = [];
  List<Map<String, dynamic>> _shares = [];
  String? _primaryId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _idOf(dynamic value) {
    if (value is Map) return (value['_id'] ?? value['id'])?.toString() ?? '';
    return value?.toString() ?? '';
  }

  Future<Map<String, dynamic>> _fetch(String path) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/${widget.taskId}/$path'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    ).timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const FormatException('Dữ liệu không hợp lệ');
    final data = Map<String, dynamic>.from(decoded);
    if (response.statusCode != 200) {
      throw Exception(data['message']?.toString() ?? 'Lỗi HTTP ${response.statusCode}');
    }
    return data;
  }

  Future<void> _load() async {
    if (_loading) return;
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
        throw const FormatException('Danh sách thành viên không hợp lệ');
      }
      setState(() {
        _assignees = assigned
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
        _shares = shared
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
        _primaryId = responses[0]['primaryAssigneeId']?.toString();
      });
    } on TimeoutException {
      if (mounted) setState(() => _error = 'Kết nối quá thời gian.');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _memberTile(Map<String, dynamic> user, {String? subtitle, bool primary = false}) {
    final name = user['fullName']?.toString().trim();
    final email = user['email']?.toString() ?? '';
    return ListTile(
      leading: CircleAvatar(child: Icon(primary ? Icons.star : Icons.person_outline)),
      title: Text(name == null || name.isEmpty ? 'Chưa có tên' : name),
      subtitle: Text(subtitle == null ? email : '$email\n$subtitle'),
      isThreeLine: subtitle != null,
      trailing: primary ? const Chip(label: Text('Phụ trách chính')) : null,
    );
  }

  Widget _sectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text('$title ($count)', style: Theme.of(context).textTheme.titleMedium),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách thành viên'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
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
                        OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      _sectionTitle('Người được giao', _assignees.length),
                      if (_assignees.isEmpty)
                        const ListTile(title: Text('Chưa giao cho thành viên nào')),
                      for (final user in _assignees)
                        _memberTile(
                          user,
                          primary: _primaryId != null &&
                              _idOf(user['_id']).toLowerCase() == _primaryId!.toLowerCase(),
                        ),
                      const Divider(height: 24),
                      _sectionTitle('Người được chia sẻ', _shares.length),
                      if (_shares.isEmpty)
                        const ListTile(title: Text('Chưa chia sẻ với thành viên nào')),
                      for (final share in _shares)
                        _memberTile(
                          share['userId'] is Map
                              ? Map<String, dynamic>.from(share['userId'] as Map)
                              : <String, dynamic>{},
                          subtitle: share['permission'] == 'editor'
                              ? 'Quyền: Editor (chỉnh sửa)'
                              : 'Quyền: Viewer (chỉ xem)',
                        ),
                    ],
                  ),
                ),
    );
  }
}
