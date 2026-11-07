import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ShareTaskScreen extends StatefulWidget {
  final String token;
  final String taskId;
  final String taskTitle;

  const ShareTaskScreen({
    super.key,
    required this.token,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<ShareTaskScreen> createState() => _ShareTaskScreenState();
}

class _ShareTaskScreenState extends State<ShareTaskScreen> {
  static const String apiBase = 'http://10.0.2.2:5000/api';

  final TextEditingController _searchController = TextEditingController();
  final Map<String, Map<String, dynamic>> _selected = {};

  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  bool _sharing = false;
  String? _message;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty || _loading || _sharing) return;

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final uri = Uri.parse('$apiBase/users/search').replace(
        queryParameters: {'q': keyword},
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw Exception('Tim kiem that bai: ${response.statusCode}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! Map || data['users'] is! List) {
        throw Exception('Du lieu tim kiem khong hop le');
      }

      setState(() {
        _users = (data['users'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Không tìm được thành viên: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _share() async {
    if (_selected.isEmpty || _sharing) return;

    setState(() {
      _sharing = true;
      _message = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBase/tasks/${widget.taskId}/shares'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'userIds': _selected.keys.toList()}),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Chia sẻ thất bại: $e');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chia sẻ công việc'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.taskTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Người được chia sẻ có quyền chỉ xem (viewer).',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Nhập email hoặc họ tên',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _searchUsers(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _searchUsers,
                    icon: const Icon(Icons.person_search),
                    label: const Text('Tìm thành viên'),
                  ),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_message!),
                    ),
                  const SizedBox(height: 16),
                  Text('Đã chọn: ${_selected.length} người'),
                  for (final user in _users)
                    CheckboxListTile(
                      title: Text(
                        user['fullName']?.toString() ?? 'Không có tên',
                      ),
                      subtitle: Text(user['email']?.toString() ?? ''),
                      value: _selected.containsKey(user['_id'].toString()),
                      onChanged: (checked) {
                        final id = user['_id']?.toString();
                        if (id == null) return;

                        setState(() {
                          if (checked == true) {
                            if (_selected.length < 50) {
                              _selected[id] = user;
                            }
                          } else {
                            _selected.remove(id);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty || _sharing ? null : _share,
                  icon: const Icon(Icons.share),
                  label: Text(
                    _sharing
                        ? 'Đang chia sẻ...'
                        : 'Chia sẻ cho ${_selected.length} người',
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
