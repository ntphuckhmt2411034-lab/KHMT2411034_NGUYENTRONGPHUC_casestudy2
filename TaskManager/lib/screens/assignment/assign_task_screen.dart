import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// C1 - Tim tai khoan va giao viec cho nhieu nguoi.
/// Backend tu kiem tra quyen cua nguoi tao cong viec.
class AssignTaskScreen extends StatefulWidget {
  final String token;
  final String taskId;
  final String taskTitle;
  final List<String> existingIds;

  const AssignTaskScreen({
    super.key,
    required this.token,
    required this.taskId,
    required this.taskTitle,
    this.existingIds = const [],
  });

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  static const String apiBase = 'http://10.0.2.2:5000/api';

  final TextEditingController _searchController = TextEditingController();
  final Map<String, Map<String, dynamic>> _selected = {};
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _submitting = false;
  bool _hasSearched = false;
  String? _error;
  int _searchSequence = 0;

  Set<String> get _existing => widget.existingIds.toSet();

  @override
  void dispose() {
    _searchSequence++;
    _searchController.dispose();
    super.dispose();
  }

  String _message(http.Response response, String fallback) {
    if (response.statusCode == 401) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (response.statusCode == 403 || response.statusCode == 404) {
      return 'Không tìm thấy công việc hoặc bạn không có quyền giao việc.';
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _searchUsers() async {
    final keyword = _searchController.text.trim();
    if (keyword.length < 2 || keyword.length > 100) {
      setState(() {
        _error = 'Nhập từ 2 đến 100 ký tự để tìm thành viên.';
        _results = [];
      });
      return;
    }

    final requestId = ++_searchSequence;
    setState(() {
      _searching = true;
      _error = null;
      _hasSearched = true;
      _results = [];
    });

    try {
      final uri = Uri.parse('$apiBase/users/search')
          .replace(queryParameters: {'q': keyword});
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(const Duration(seconds: 20));

      if (!mounted || requestId != _searchSequence) return;
      if (response.statusCode != 200) {
        setState(() {
          _error = _message(response, 'Không thể tìm kiếm thành viên.');
        });
        return;
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map || data['users'] is! List) {
        setState(() {
          _error = 'Dữ liệu tìm kiếm không hợp lệ.';
        });
        return;
      }
      setState(() {
        _results = (data['users'] as List)
            .whereType<Map>()
            .map((u) => Map<String, dynamic>.from(u))
            .where((u) => u['_id'] is String)
            .toList();
      });
    } on TimeoutException {
      if (mounted && requestId == _searchSequence) {
        setState(() => _error = 'Tìm kiếm quá thời gian. Thử lại.');
      }
    } catch (_) {
      if (mounted && requestId == _searchSequence) {
        setState(() => _error = 'Không thể kết nối backend.');
      }
    } finally {
      if (mounted && requestId == _searchSequence) {
        setState(() => _searching = false);
      }
    }
  }

  void _toggle(Map<String, dynamic> user, bool selected) {
    final id = user['_id']?.toString();
    if (id == null || _existing.contains(id) || _submitting) return;
    setState(() {
      if (selected) {
        _selected[id] = user;
      } else {
        _selected.remove(id);
      }
      _error = null;
    });
  }

  Future<void> _assign() async {
    if (_submitting || _searching || _selected.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final response = await http
          .post(
            Uri.parse('$apiBase/tasks/${widget.taskId}/assignees'),
            headers: {
              'Authorization': 'Bearer ${widget.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'assigneeIds': _selected.keys.toList()}),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) {
        return;
      }
      if (response.statusCode == 200) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _error = _message(response, 'Không thể giao công việc.');
      });
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _error =
              'Giao việc quá thời gian. Hãy kiểm tra lại trước khi thử lại.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể kết nối backend để giao việc.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Giao công việc')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Công việc',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.taskTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Đã giao cho ${_existing.length} người',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tìm người nhận',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchUsers(),
                    decoration: InputDecoration(
                      labelText: 'Email hoặc họ tên',
                      hintText: 'Nhập ít nhất 2 ký tự',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'Tìm kiếm',
                        onPressed: _searching || _submitting
                            ? null
                            : _searchUsers,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _searching || _submitting
                          ? null
                          : _searchUsers,
                      icon: const Icon(Icons.person_search_outlined),
                      label: const Text('Tìm thành viên'),
                    ),
                  ),
                  if (_searching) ...[
                    const SizedBox(height: 12),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  if (_selected.isNotEmpty) ...[
                    Text(
                      'Đã chọn (${_selected.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selected.values.map((user) {
                        final id = user['_id'].toString();
                        return InputChip(
                          label: Text(
                            user['fullName']?.toString() ??
                                user['email']?.toString() ??
                                id,
                          ),
                          onDeleted: _submitting
                              ? null
                              : () => _toggle(user, false),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'Kết quả tìm kiếm',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_hasSearched &&
                      !_searching &&
                      _results.isEmpty &&
                      _error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Không tìm thấy tài khoản phù hợp.'),
                    ),
                  if (!_hasSearched)
                    const Text('Nhập tên hoặc email để tìm thành viên.'),
                  for (final user in _results) ...[
                    Builder(
                      builder: (context) {
                        final id = user['_id'].toString();
                        final alreadyAssigned = _existing.contains(id);
                        final checked =
                            _selected.containsKey(id) || alreadyAssigned;
                        return Card(
                          child: CheckboxListTile(
                            value: checked,
                            onChanged: alreadyAssigned || _submitting
                                ? null
                                : (value) => _toggle(user, value ?? false),
                            title: Text(
                              user['fullName']?.toString() ?? 'Không có tên',
                            ),
                            subtitle: Text(
                              alreadyAssigned
                                  ? '${user['email'] ?? ''} • Đã được giao'
                                  : user['email']?.toString() ?? '',
                            ),
                            secondary: CircleAvatar(
                              child: Text(
                                (user['fullName']?.toString().isNotEmpty == true
                                        ? user['fullName'].toString()[0]
                                        : '?')
                                    .toUpperCase(),
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.trailing,
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty || _submitting || _searching
                      ? null
                      : _assign,
                  icon: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.group_add_outlined),
                  label: Text(
                    _submitting
                        ? 'Đang giao công việc...'
                        : 'Giao việc cho ${_selected.length} người',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
