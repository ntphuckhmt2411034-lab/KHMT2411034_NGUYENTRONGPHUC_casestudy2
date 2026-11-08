import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'task_create_screen.dart';
import 'task_detail_screen.dart';

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

  // B1 - Phan loai danh sach.
  String _scope = 'all';

  // B6 - Tim kiem va loc.
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _statusFilter = 'all';
  String _priorityFilter = 'all';
  String _assigneeFilter = 'all';

  // B7 - Sap xep cong viec.
  String _sortBy = 'created_desc';

  static const Map<String, String> statusOptions = {
    'all': 'Tất cả trạng thái',
    'chua_thuc_hien': 'Chưa thực hiện',
    'dang_thuc_hien': 'Đang thực hiện',
    'da_hoan_thanh': 'Đã hoàn thành',
  };

  static const Map<String, String> priorityOptions = {
    'all': 'Tất cả ưu tiên',
    'thap': 'Thấp',
    'trung_binh': 'Trung bình',
    'cao': 'Cao',
  };

  // B7 - Sau lua chon sap xep.
  static const Map<String, String> sortOptions = {
    'created_desc': 'Ngày tạo: Mới nhất',
    'created_asc': 'Ngày tạo: Cũ nhất',
    'due_asc': 'Hạn hoàn thành: Gần nhất',
    'due_desc': 'Hạn hoàn thành: Xa nhất',
    'priority_desc': 'Độ ưu tiên: Cao đến thấp',
    'priority_asc': 'Độ ưu tiên: Thấp đến cao',
  };

  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _statusFilter != 'all' ||
      _priorityFilter != 'all' ||
      _assigneeFilter != 'all';

  // ID trong JWT chi dung de phan loai giao dien.
  // Quyen truy cap thuc te do backend kiem tra.
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // B1 - Tai danh sach cong viec.
  Future<void> _loadTasks() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(apiUrl),
            headers: {'Authorization': 'Bearer ${widget.token}'},
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 401) {
        setState(() {
          _error = 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
        });
        return;
      }

      if (response.statusCode != 200) {
        setState(() {
          _error = 'Không thể tải danh sách công việc.';
        });
        return;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! Map || data['tasks'] is! List) {
        setState(() {
          _error = 'Dữ liệu công việc không hợp lệ.';
        });
        return;
      }

      final rawTasks = data['tasks'] as List;

      setState(() {
        _tasks = rawTasks
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        // B6 - Dat lai bo loc neu nguoi duoc
        // giao khong con trong danh sach.
        final selectedId = _assigneeFilter;

        if (selectedId != 'all' &&
            selectedId != 'unassigned' &&
            !_tasks.any((task) => _assigneeIdsOf(task).contains(selectedId))) {
          _assigneeFilter = 'all';
        }
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
          _error = 'Không thể kết nối backend hoặc đọc dữ liệu.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // B2.2 - Mo man hinh tao cong viec.
  Future<void> _openCreateTask() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskCreateScreen(token: widget.token)),
    );

    if (!mounted) return;

    if (created == true) {
      setState(() {
        _scope = 'all';
      });

      _clearFilters();

      await _loadTasks();

      if (!mounted) return;

      if (_error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo công việc thành công!')),
        );
      }
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

    return values.any(
      (value) => _idOf(value)?.toLowerCase() == userId.toLowerCase(),
    );
  }

  // C1/C2 - Ho tro ca assignedTo cu va danh sach assigneeIds moi.
  Set<String> _assigneeIdsOf(Map<String, dynamic> task) {
    final result = <String>{};
    final legacyId = _idOf(task['assignedTo']);
    if (legacyId != null && legacyId.isNotEmpty) result.add(legacyId);

    final values = task['assigneeIds'];
    if (values is List) {
      for (final value in values) {
        final id = _idOf(value);
        if (id != null && id.isNotEmpty) result.add(id);
      }
    }
    return result;
  }

  // B6 - Danh sach nguoi duoc giao.
  Map<String, String> get _assigneeOptions {
    final options = <String, String>{
      'all': 'Tất cả người được giao',
      'unassigned': 'Chưa giao cho ai',
    };

    for (final task in _tasks) {
      final assigned = <dynamic>[
        task['assignedTo'],
        if (task['assigneeIds'] is List) ...(task['assigneeIds'] as List),
      ];

      for (final value in assigned) {
        final id = _idOf(value);
        if (id == null || id.isEmpty) continue;

        String label = '';
        if (value is Map) {
          label =
              (value['fullName'] ?? value['name'] ?? value['email'])
                  ?.toString() ??
              '';
        }
        if (label.trim().isEmpty) {
          label = id == _currentUserId
              ? 'Tôi'
              : 'Tài khoản ${id.length > 8 ? id.substring(0, 8) : id}...';
        }
        // Uu tien ten khi API tra ve thong tin nguoi dung.
        if (!options.containsKey(id) || value is Map) {
          options[id] = label;
        }
      }
    }

    return options;
  }

  // =====================================================
  // B7 - HAM HO TRO SAP XEP
  // =====================================================

  // Doc ngay tu MongoDB.
  // Gia tri null hoac ngay sai duoc xem la chua co ngay.
  DateTime? _parseTaskDate(dynamic value) {
    if (value == null) return null;

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    return DateTime.tryParse(raw);
  }

  // So sanh ngay.
  // Ngay trong luon nam cuoi danh sach,
  // bat ke dang sap xep tang hay giam.
  int _compareDates(dynamic first, dynamic second, {required bool ascending}) {
    final dateA = _parseTaskDate(first);
    final dateB = _parseTaskDate(second);

    if (dateA == null && dateB == null) return 0;
    if (dateA == null) return 1;
    if (dateB == null) return -1;

    final comparison = dateA.compareTo(dateB);

    return ascending ? comparison : -comparison;
  }

  // Chuyen do uu tien thanh so de sap xep.
  int _priorityRank(dynamic priority) {
    switch (priority?.toString()) {
      case 'thap':
        return 1;
      case 'trung_binh':
        return 2;
      case 'cao':
        return 3;
      default:
        return 0;
    }
  }

  // B7 - So sanh hai cong viec.
  int _compareTasks(Map<String, dynamic> first, Map<String, dynamic> second) {
    int comparison;

    switch (_sortBy) {
      case 'created_asc':
        comparison = _compareDates(
          first['createdAt'],
          second['createdAt'],
          ascending: true,
        );
        break;

      case 'due_asc':
        comparison = _compareDates(
          first['dueDate'],
          second['dueDate'],
          ascending: true,
        );
        break;

      case 'due_desc':
        comparison = _compareDates(
          first['dueDate'],
          second['dueDate'],
          ascending: false,
        );
        break;

      case 'priority_desc':
        comparison = _priorityRank(second['priority'])
            .compareTo(_priorityRank(first['priority']));
        break;

      case 'priority_asc':
        comparison = _priorityRank(first['priority'])
            .compareTo(_priorityRank(second['priority']));
        break;

      case 'created_desc':
      default:
        comparison = _compareDates(
          first['createdAt'],
          second['createdAt'],
          ascending: false,
        );
        break;
    }

    if (comparison != 0) {
      return comparison;
    }

    // Neu hai cong viec cung gia tri,
    // uu tien cong viec tao moi hon.
    final byCreatedDate = _compareDates(
      first['createdAt'],
      second['createdAt'],
      ascending: false,
    );

    if (byCreatedDate != 0) {
      return byCreatedDate;
    }

    // Tieu chi cuoi de ket qua on dinh.
    return (first['_id']?.toString() ?? '').compareTo(
      second['_id']?.toString() ?? '',
    );
  }

  // =====================================================
  // B1 + B6 + B7 - PHAN LOAI, LOC VA SAP XEP
  // =====================================================

  // C7 - Phan loai theo vai tro; giu mot cong viec trong moi nhom phu hop.
  List<Map<String, dynamic>> get _scopeTasks {
    final userId = _currentUserId;
    if (_scope == 'all' || userId == null) return _tasks;

    final normalizedId = userId.toLowerCase();
    return _tasks.where((task) {
      switch (_scope) {
        case 'created':
          return _idOf(task['createdBy'])?.toLowerCase() == normalizedId;
        case 'assigned':
          return _assigneeIdsOf(task)
              .any((id) => id.toLowerCase() == normalizedId);
        case 'shared':
          final legacyShare = _containsUser(task['sharedWith'], userId);
          final permission = task['sharePermission']?.toString();
          return legacyShare ||
              permission == 'viewer' ||
              permission == 'editor';
        default:
          return true;
      }
    }).toList();
  }

  // C7 - Tien do duoc tinh tren nhom dang chon, khong theo bo loc tim kiem.
  Widget _buildProgressSummary() {
    final tasks = _scopeTasks;
    final total = tasks.length;
    final pending = tasks
        .where((task) => task['status'] == 'chua_thuc_hien')
        .length;
    final inProgress = tasks
        .where((task) => task['status'] == 'dang_thuc_hien')
        .length;
    final completed = tasks
        .where((task) => task['status'] == 'da_hoan_thanh')
        .length;
    final progress = total == 0 ? 0.0 : completed / total;
    final label = switch (_scope) {
      'created' => 'Tôi tạo',
      'assigned' => 'Được giao',
      'shared' => 'Được chia sẻ',
      _ => 'Tất cả công việc',
    };

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiến độ - $label',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Đã hoàn thành $completed/$total công việc '
              '(${(progress * 100).round()}%)',
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(label: Text('Chưa thực hiện: $pending')),
                Chip(label: Text('Đang thực hiện: $inProgress')),
                Chip(label: Text('Hoàn thành: $completed')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _visibleTasks {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = _scopeTasks.where((task) {
      // B6.1 - Tim theo ten cong viec.
      final title = task['title']?.toString().toLowerCase() ?? '';

      if (query.isNotEmpty && !title.contains(query)) {
        return false;
      }

      // B6.2 - Loc trang thai.
      if (_statusFilter != 'all' &&
          task['status']?.toString() != _statusFilter) {
        return false;
      }

      // B6.3 - Loc do uu tien.
      if (_priorityFilter != 'all' &&
          task['priority']?.toString() != _priorityFilter) {
        return false;
      }

      // B6.4 - Loc nguoi duoc giao.
      final assignedIds = _assigneeIdsOf(task);

      if (_assigneeFilter == 'unassigned') {
        if (assignedIds.isNotEmpty) return false;
      } else if (_assigneeFilter != 'all') {
        if (!assignedIds.contains(_assigneeFilter)) return false;
      }

      return true;
    }).toList();

    // B7 - Chi sap xep danh sach da loc.
    // Khong thay doi du lieu goc trong _tasks.
    filtered.sort(_compareTasks);

    return filtered;
  }

  // B6 - Xoa bo loc, giu nhom va sap xep B7.
  void _clearFilters() {
    _searchController.clear();

    if (!mounted) return;

    setState(() {
      _searchQuery = '';
      _statusFilter = 'all';
      _priorityFilter = 'all';
      _assigneeFilter = 'all';
    });
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
    if (value == null || value.toString().isEmpty) {
      return 'Chưa thiết lập';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return 'Không hợp lệ';
    }

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  // B6 + B7 - Thanh tim kiem, loc va sap xep.
  Widget _buildSearchAndFilters() {
    final assignees = _assigneeOptions;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // B6 - Tim kiem theo ten.
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên công việc...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa từ khóa',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();

                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),

          const SizedBox(height: 12),

          // B6 - Loc trang thai va do uu tien.
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('status-$_statusFilter'),
                  initialValue: _statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: statusOptions.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _statusFilter = value;
                    });
                  },
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('priority-$_priorityFilter'),
                  initialValue: _priorityFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Độ ưu tiên',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: priorityOptions.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(
                        entry.value == 'Tất cả ưu tiên'
                            ? 'Tất cả'
                            : entry.value,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _priorityFilter = value;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // B6 - Loc nguoi duoc giao.
          DropdownButtonFormField<String>(
            key: ValueKey('assignee-$_assigneeFilter'),
            initialValue: assignees.containsKey(_assigneeFilter)
                ? _assigneeFilter
                : 'all',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Người được giao',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: assignees.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _assigneeFilter = value;
              });
            },
          ),

          const SizedBox(height: 10),

          // B7 - Chon tieu chi sap xep.
          DropdownButtonFormField<String>(
            key: ValueKey('sort-$_sortBy'),
            initialValue: _sortBy,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sắp xếp công việc',
              prefixIcon: Icon(Icons.sort),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: sortOptions.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _sortBy = value;
              });
            },
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Hiển thị ${_visibleTasks.length}/${_tasks.length} công việc',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Xóa bộ lọc'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // B1 + B2 + B3 + B4 + B5 - The cong viec.
  Widget _buildTaskCard(Map<String, dynamic> task) {
    final title = task['title']?.toString() ?? 'Không có tiêu đề';

    final description = task['description']?.toString() ?? '';

    final status = _statusLabel(task['status']?.toString());

    final priority = _priorityLabel(task['priority']?.toString());

    final dueDate = _dateLabel(task['dueDate']);

    // C2 - Nhan vai tro tren danh sach cong viec.
    final primaryId = _idOf(task['primaryAssigneeId']);
    final isPrimary =
        primaryId != null &&
        primaryId.isNotEmpty &&
        primaryId.toLowerCase() == _currentUserId?.toLowerCase();
    final hasPrimary = primaryId != null && primaryId.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final taskId = task['_id']?.toString();

          if (taskId == null || taskId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không tìm thấy ID công việc.')),
            );
            return;
          }

          final updated = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TaskDetailScreen(token: widget.token, taskId: taskId),
            ),
          );

          if (!mounted) return;

          // Tai lai danh sach sau khi co thay doi.
          if (updated == true) {
            await _loadTasks();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),

              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description),
              ],

              if (isPrimary) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 20,
                        color: Color(0xFFB77900),
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Bạn là người phụ trách chính',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF805500),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (hasPrimary) ...[
                const SizedBox(height: 10),
                const Chip(
                  avatar: Icon(Icons.star_outline, size: 18),
                  label: Text('Đã có người phụ trách chính'),
                ),
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
          // B2 - Tao cong viec.
          IconButton(
            tooltip: 'Tạo công việc',
            onPressed: _openCreateTask,
            icon: const Icon(Icons.add),
          ),

          // B1 - Lam moi.
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

                  // B1 - Giu bon nhom cong viec.
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: ChoiceChip(
                                label: Text(option.$2),
                                selected: _scope == option.$1,
                                onSelected: (_) {
                                  setState(() {
                                    _scope = option.$1;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Không xác định được tài khoản để phân loại công việc.',
                      ),
                    ),

                  // B6 + B7 - Bo loc va sap xep.
                  _buildSearchAndFilters(),

                  // C7 - Thong ke nam trong danh sach cuon,
                  // tranh tran man hinh Android nho.
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadTasks,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                        children: [
                          _buildProgressSummary(),
                          if (visibleTasks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    _tasks.isEmpty
                                        ? Icons.inbox_outlined
                                        : Icons.search_off,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _tasks.isEmpty
                                        ? 'Chưa có công việc nào.'
                                        : 'Không tìm thấy công việc phù hợp.',
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_hasActiveFilters) ...[
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _clearFilters,
                                      icon: const Icon(Icons.filter_alt_off),
                                      label: const Text('Xóa bộ lọc'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  for (final task in visibleTasks)
                                    _buildTaskCard(task),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
