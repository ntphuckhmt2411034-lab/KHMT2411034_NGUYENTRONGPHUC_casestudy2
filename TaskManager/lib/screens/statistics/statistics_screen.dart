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
  static const String _url = 'http://10.0.2.2:5000/api/statistics/status';

  bool _loading = true;
  String? _error;

  int _total = 0;
  int _notStarted = 0;
  int _inProgress = 0;
  int _completed = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(_url),
            headers: {'Authorization': 'Bearer ${widget.token}'},
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 401) {
        setState(() {
          _error = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        });
        return;
      }

      if (response.statusCode != 200) {
        setState(() {
          _error = 'Không thể tải dữ liệu thống kê.';
        });
        return;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map ||
          decoded['success'] != true ||
          decoded['total'] is! int ||
          decoded['byStatus'] is! Map) {
        throw const FormatException('Dữ liệu thống kê không hợp lệ');
      }

      final status = decoded['byStatus'] as Map;

      final total = decoded['total'];
      final notStarted = status['chua_thuc_hien'];
      final inProgress = status['dang_thuc_hien'];
      final completed = status['da_hoan_thanh'];

      if (total is! int ||
          notStarted is! int ||
          inProgress is! int ||
          completed is! int ||
          total < 0 ||
          notStarted < 0 ||
          inProgress < 0 ||
          completed < 0 ||
          total != notStarted + inProgress + completed) {
        throw const FormatException('Số liệu thống kê không hợp lệ');
      }

      setState(() {
        _total = total;
        _notStarted = notStarted;
        _inProgress = inProgress;
        _completed = completed;
      });
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
        setState(() {
          _loading = false;
        });
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 14),
          Text(
            '$count',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
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
    final percent = _total == 0 ? 0.0 : count / _total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
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
              value: percent,
              minHeight: 12,
              color: color,
              backgroundColor: const Color(0xFFE7EBF3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statisticsBody() {
    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tổng quan trạng thái công việc',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dữ liệu được cập nhật từ hệ thống TaskManager.',
            style: TextStyle(color: Color(0xFF697892)),
          ),
          const SizedBox(height: 22),
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
          const SizedBox(height: 26),
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
                  color: const Color(0xFF3B82F6),
                ),
                _progressRow(
                  label: 'Đã hoàn thành',
                  count: _completed,
                  color: const Color(0xFF198A69),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loadStatistics,
            icon: const Icon(Icons.refresh),
            label: const Text('Cập nhật thống kê'),
          ),
        ],
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
            ? Center(
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
              )
            : _statisticsBody(),
      ),
    );
  }
}
