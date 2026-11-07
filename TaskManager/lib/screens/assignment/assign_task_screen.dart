import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// C1: giao cong viec cho nhieu nguoi.
/// C2: chon mot nguoi da duoc giao lam nguoi phu trach chinh.
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
  final Map<String, Map<String, dynamic>> _knownUsers = {};
  final Set<String> _assignedIds = {};
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _submitting = false;
  bool _savingPrimary = false;
  bool _loadingTask = false;
  bool _hasSearched = false;
  bool _changed = false;
  String? _primaryId;
  String? _error;
  String? _success;
  int _searchSequence = 0;

  Set<String> get _existing => {...widget.existingIds, ..._assignedIds};

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

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
      return 'Không tìm thấy công việc hoặc bạn không có quyền thao tác.';
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _loadTask() async {
    setState(() => _loadingTask = true);
    try {
      final response = await http.get(
        Uri.parse('$apiBase/tasks/${widget.taskId}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode != 200) {
        // Van co the giao viec voi danh sach existingIds da truyen vao.
        return;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return;
      final data = decoded['task'] is Map ? decoded['task'] : decoded;
      if (data is! Map) return;
      final ids = <String>{};
      if (data['assigneeIds'] is List) {
        for (final item in data['assigneeIds'] as List) {
          if (item is String && item.isNotEmpty) ids.add(item);
          if (item is Map && item['_id'] != null) {
            ids.add(item['_id'].toString());
            _knownUsers[item['_id'].toString()] =
            Map<String, dynamic>.from(item);
          }
        }
      }
      final oldAssigned = data['assignedTo'];
      if (oldAssigned is String && oldAssigned.isNotEmpty) {
        ids.add(oldAssigned);
      } else if (oldAssigned is Map && oldAssigned['_id'] != null) {
        ids.add(oldAssigned['_id'].toString());
        _knownUsers[oldAssigned['_id'].toString()] =
        Map<String, dynamic>.from(oldAssigned);
      }
      final primary = data['primaryAssigneeId'];
      final primaryId = primary is Map ? primary['_id']?.toString() : primary?.toString();
      if (!mounted) return;
      setState(() {
        _assignedIds.addAll(ids);
        if (primaryId != null && primaryId.isNotEmpty) _primaryId = primaryId;
      });
    } catch (_) {
      // Khong chan C1/C2: danh sach ban dau van duoc su dung.
    } finally {
      if (mounted) setState(() => _loadingTask = false);
    }
  }

  String _nameOf(String id) {
    final user = _knownUsers[id];
    final name = user?['fullName']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user?['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Thành viên (${id.length > 8 ? id.substring(0, 8) : id}...)';
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
      _success = null;
      _hasSearched = true;
      _results = [];
    });

    try {
      final uri = Uri.parse('$apiBase/users/search')
          .replace(queryParameters: {'q': keyword});
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 20));

      if (!mounted || requestId != _searchSequence) return;
      if (response.statusCode != 200) {
        setState(() => _error = _message(response, 'Không thể tìm kiếm thành viên.'));
        return;
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map || data['users'] is! List) {
        setState(() => _error = 'Dữ liệu tìm kiếm không hợp lệ.');
        return;
      }
      final users = (data['users'] as List)
          .whereType<Map>()
          .map((u) => Map<String, dynamic>.from(u))
          .where((u) => u['_id'] is String)
          .toList();
      setState(() {
        _results = users;
        for (final user in users) {
          _knownUsers[user['_id'] as String] = user;
        }
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
    if (id == null || _existing.contains(id) || _submitting || _savingPrimary) {
      return;
    }
    setState(() {
      if (selected) {
        _selected[id] = user;
      } else {
        _selected.remove(id);
      }
      _error = null;
      _success = null;
    });
  }

  Future<void> _assign() async {
    if (_submitting || _savingPrimary || _searching || _selected.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await http.post(
        Uri.parse('$apiBase/tasks/${widget.taskId}/assignees'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'assigneeIds': _selected.keys.toList()}),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        // Khong dong man hinh: cho phep chon nguoi phu trach chinh ngay.
        setState(() {
          _assignedIds.addAll(_selected.keys);
          _selected.clear();
          _changed = true;
          _success = 'Đã giao việc thành công. Bạn có thể chọn người phụ trách chính bên dưới.';
        });
        return;
      }
      setState(() => _error = _message(response, 'Không thể giao công việc.'));
    } on TimeoutException {
      if (mounted) {
        setState(() => _error =
        'Giao việc quá thời gian. Kiểm tra danh sách trước khi thử lại.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể kết nối backend để giao việc.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _setPrimary(String userId) async {
    if (_submitting || _savingPrimary || !_existing.contains(userId)) return;
    setState(() {
      _savingPrimary = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await http.patch(
        Uri.parse('$apiBase/tasks/${widget.taskId}/assignees/$userId'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isPrimary': true}),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _primaryId = userId;
          _changed = true;
          _success = 'Đã chỉ định ${_nameOf(userId)} làm người phụ trách chính.';
        });
        return;
      }
      setState(() => _error = _message(response, 'Không thể chỉ định người phụ trách chính.'));
    } on TimeoutException {
      if (mounted) {
        setState(() => _error =
        'Lưu người phụ trách quá thời gian. Kiểm tra lại trước khi thử lại.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể kết nối backend để chỉ định.');
      }
    } finally {
      if (mounted) setState(() => _savingPrimary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final existing = _existing.toList()..sort();
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_submitting && !_savingPrimary) {
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
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
                            Text('Công việc',
                                style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 6),
                            Text(widget.taskTitle,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text('Đã giao cho ${existing.length} người',
                                style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                    if (_loadingTask) const LinearProgressIndicator(),
                    if (_success != null) ...[
                      const SizedBox(height: 12),
                      Text(_success!, style: TextStyle(color: colorScheme.primary)),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    Text('C1 – Tìm người nhận',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      enabled: !_submitting && !_savingPrimary,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchUsers(),
                      decoration: InputDecoration(
                        labelText: 'Email hoặc họ tên',
                        hintText: 'Nhập ít nhất 2 ký tự',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Tìm kiếm',
                          onPressed: _searching || _submitting || _savingPrimary
                              ? null : _searchUsers,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _searching || _submitting || _savingPrimary
                            ? null : _searchUsers,
                        icon: const Icon(Icons.person_search_outlined),
                        label: const Text('Tìm thành viên'),
                      ),
                    ),
                    if (_searching) ...[
                      const SizedBox(height: 12),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    if (_selected.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Đã chọn (${_selected.length})',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selected.values.map((user) {
                          return InputChip(
                            label: Text(user['fullName']?.toString() ??
                                user['email']?.toString() ?? user['_id'].toString()),
                            onDeleted: _submitting || _savingPrimary
                                ? null : () => _toggle(user, false),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text('Kết quả tìm kiếm',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_hasSearched && !_searching &&
                        _results.isEmpty && _error == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Không tìm thấy tài khoản phù hợp.'),
                      ),
                    if (!_hasSearched)
                      const Text('Nhập tên hoặc email để tìm thành viên.'),
                    for (final user in _results) ...[
                      Builder(builder: (context) {
                        final id = user['_id'].toString();
                        final alreadyAssigned = _existing.contains(id);
                        final checked = _selected.containsKey(id) || alreadyAssigned;
                        return Card(
                          child: CheckboxListTile(
                            value: checked,
                            onChanged: alreadyAssigned || _submitting || _savingPrimary
                                ? null : (value) => _toggle(user, value ?? false),
                            title: Text(user['fullName']?.toString() ?? 'Không có tên'),
                            subtitle: Text(alreadyAssigned
                                ? '${user['email'] ?? ''} • Đã được giao'
                                : user['email']?.toString() ?? ''),
                            secondary: CircleAvatar(
                              child: Text((user['fullName']?.toString().isNotEmpty == true
                                  ? user['fullName'].toString()[0] : '?').toUpperCase()),
                            ),
                            controlAffinity: ListTileControlAffinity.trailing,
                          ),
                        );
                      }),
                    ],
                    if (_selected.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submitting || _savingPrimary || _searching
                              ? null : _assign,
                          icon: _submitting
                              ? const SizedBox(height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.group_add_outlined),
                          label: Text(_submitting
                              ? 'Đang giao công việc...'
                              : 'Giao việc cho ${_selected.length} người'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text('C2 – Người phụ trách chính',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('Chỉ chọn trong những người đã được giao. '
                        'Nếu vừa chọn người mới ở C1, hãy bấm Giao việc trước.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    if (existing.isEmpty)
                      const Card(child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Chưa có người được giao công việc.'),
                      )),
                    for (final id in existing)
                      Card(
                        child: ListTile(
                          leading: Icon(_primaryId == id
                              ? Icons.star : Icons.person_outline,
                              color: _primaryId == id
                                  ? colorScheme.primary : null),
                          title: Text(_nameOf(id)),
                          subtitle: Text(_primaryId == id
                              ? 'Người phụ trách chính hiện tại'
                              : 'Đã được giao công việc'),
                          trailing: _primaryId == id
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : TextButton(
                            onPressed: _submitting || _savingPrimary
                                ? null : () => _setPrimary(id),
                            child: const Text('Chọn chính'),
                          ),
                        ),
                      ),
                    if (_savingPrimary)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting || _savingPrimary
                        ? null : () => Navigator.of(context).pop(_changed),
                    icon: const Icon(Icons.check),
                    label: const Text('Hoàn tất'),
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
