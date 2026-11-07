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

  Future<void> _loadShares() async {
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

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! Map || data['shares'] is! List) {
        throw Exception('Du lieu khong hop le');
      }

      setState(() {
        _shares = (data['shares'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải danh sách: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _changePermission(
    String userId,
    String permission,
  ) async {
    if (_savingUserId != null) return;

    setState(() {
      _savingUserId = userId;
    });

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

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật quyền thành công'),
        ),
      );

      await _loadShares();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cập nhật quyền thất bại: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingUserId = null);
      }
    }
  }

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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadShares,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _shares.isEmpty
                  ? const Center(
                      child: Text('Chưa có người được chia sẻ'),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Viewer: Chỉ xem công việc.\n'
                          'Editor: Được chỉnh sửa công việc.',
                        ),
                        const SizedBox(height: 16),
                        for (final share in _shares)
                          _buildShareCard(share),
                      ],
                    ),
    );
  }

  Widget _buildShareCard(Map<String, dynamic> share) {
    final user = share['userId'];

    if (user is! Map) {
      return const SizedBox.shrink();
    }

    final userId = user['_id']?.toString() ?? '';
    final name = user['fullName']?.toString() ?? 'Thành viên';
    final email = user['email']?.toString() ?? '';
    final permission = share['permission']?.toString() ?? 'viewer';

    final isSaving = _savingUserId == userId;

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
                      Text(email),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('$userId-$permission'),
              initialValue: permission,
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
              onChanged: _savingUserId != null || userId.isEmpty
                  ? null
                  : (value) {
                      if (value != null && value != permission) {
                        _changePermission(userId, value);
                      }
                    },
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
