import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StatisticsScreen extends StatefulWidget {
  final String token;

  const StatisticsScreen({super.key, required this.token});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const String _baseUrl = 'http://10.0.2.2:5000/api/statistics';

  bool _loading = true;
  String? _error;

  // E1 - Thong ke trang thai.
  int _total = 0;
  int _notStarted = 0;
  int _inProgress = 0;
  int _completed = 0;

  // E2 - Thong ke giao viec va phu trach.
  int _assignedCount = 0;
  int _primaryCount = 0;
  int _createdCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<Map<String, dynamic>> _fetchStatistics(String endpoint) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/$endpoint'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 401) {
      throw const _StatisticsException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }

    if (response.statusCode != 200) {
      throw _StatisticsException(
        'Không thể tải dữ liệu $endpoint (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      throw const FormatException('Phản hồi thống kê không hợp lệ.');
    }

    return decoded;
  }

  int _readCount(Map data, String key) {
    final value = data[key];

    if (value is! int || value < 0) {
      throw FormatException('Chỉ số $key không hợp lệ.');
    }

    return value;
  }

  Future<void> _loadStatistics() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // E1 - Lay thong ke trang thai.
      final statusData = await _fetchStatistics('status');

      if (statusData['byStatus'] is! Map) {
        throw const FormatException('Thiếu dữ liệu trạng thái công việc.');
      }

      final status = statusData['byStatus'] as Map;

      final total = _readCount(statusData, 'total');
      final notStarted = _readCount(status, 'chua_thuc_hien');
      final inProgress = _readCount(status, 'dang_thuc_hien');
      final completed = _readCount(status, 'da_hoan_thanh');

      if (total != notStarted + inProgress + completed) {
        throw const FormatException('Tổng trạng thái không khớp.');
      }

      // E2 - Lay thong ke duoc giao, phu trach, da tao.
      final assignmentData = await _fetchStatistics('assignments');

      final assignedCount = _readCount(assignmentData, 'assignedCount');
      final primaryCount = _readCount(assignmentData, 'primaryCount');
      final createdCount = _readCount(assignmentData, 'createdCount');

      if (!mounted) return;

      setState(() {
        _total = total;
        _notStarted = notStarted;
        _inProgress = inProgress;
        _completed = completed;

        _assignedCount = assignedCount;
        _primaryCount = primaryCount;
        _createdCount = createdCount;
      });
    } on _StatisticsException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error = 'Kết nối quá thời gian. Vui lòng thử lại.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể kết nối hoặc đọc dữ liệu thống kê.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _statCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF697892)),
          ),
        ],
      ),
    );
  }

  Widget _progressRow({
    required String label,
    required int count,
    required Color color,
  }) {
    final percentage = _total == 0 ? 0.0 : count / _total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label)),
              Text(
                '$count / $_total',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 12,
              color: color,
              backgroundColor: const Color(0xFFE7EBF3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _statisticsBody() {
    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Trạng thái công việc'),
          const SizedBox(height: 8),
          const Text(
            'Thống kê những công việc bạn có quyền xem.',
            style: TextStyle(color: Color(0xFF697892)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  title: 'Tổng công việc',
                  count: _total,
                  icon: Icons.list_alt,
                  color: const Color(0xFF3458A6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  title: 'Chưa thực hiện',
                  count: _notStarted,
                  icon: Icons.pending_actions,
                  color: const Color(0xFF697892),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  title: 'Đang thực hiện',
                  count: _inProgress,
                  icon: Icons.timelapse,
                  color: const Color(0xFFC17A19),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  title: 'Đã hoàn thành',
                  count: _completed,
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF198A69),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE9EDF5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Phân bố trạng thái',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 22),
                _progressRow(
                  label: 'Chưa thực hiện',
                  count: _notStarted,
                  color: const Color(0xFF94A3B8),
                ),
                _progressRow(
                  label: 'Đang thực hiện',
                  count: _inProgress,
                  color: const Color(0xFFF59E0B),
                ),
                _progressRow(
                  label: 'Đã hoàn thành',
                  count: _completed,
                  color: const Color(0xFF198A69),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // E2 - Thong ke giao viec.
          _sectionTitle('Phân công và phụ trách'),
          const SizedBox(height: 8),
          const Text(
            'Thống kê theo vai trò của tài khoản đang đăng nhập.',
            style: TextStyle(color: Color(0xFF697892)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  title: 'Được giao',
                  count: _assignedCount,
                  icon: Icons.group_outlined,
                  color: const Color(0xFF3458A6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  title: 'Phụ trách chính',
                  count: _primaryCount,
                  icon: Icons.person_pin_outlined,
                  color: const Color(0xFFC17A19),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statCard(
            title: 'Công việc đã tạo',
            count: _createdCount,
            icon: Icons.create_new_folder_outlined,
            color: const Color(0xFF198A69),
          ),
          const SizedBox(height: 14),
          const Text(
            'Một công việc có thể thuộc nhiều nhóm vai trò. '
            'Không cộng các chỉ số này để tính tổng công việc.',
            style: TextStyle(fontSize: 12, color: Color(0xFF697892)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadStatistics,
            icon: const Icon(Icons.refresh),
            label: const Text('Cập nhật thống kê'),
          ),
        ],
      ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Color(0xFFC94A55),
            ),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadStatistics,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê công việc'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loading ? null : _loadStatistics,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _errorBody()
            : _statisticsBody(),
      ),
    );
  }
}

class _StatisticsException implements Exception {
  final String message;

  const _StatisticsException(this.message);
}
