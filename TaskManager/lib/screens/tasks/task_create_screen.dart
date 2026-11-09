import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TaskCreateScreen extends StatefulWidget {
  final String token;

  const TaskCreateScreen({super.key, required this.token});

  @override
  State<TaskCreateScreen> createState() => _TaskCreateScreenState();
}

class _TaskCreateScreenState extends State<TaskCreateScreen> {
  static const String apiUrl = 'http://10.0.2.2:5000/api/tasks';

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _status = 'chua_thuc_hien';
  String _priority = 'trung_binh';

  DateTime? _startDate;
  DateTime? _dueDate;

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // D5 - Hien thi ngay va gio theo dinh dang Viet Nam.
  String _formatDateTime(DateTime? date) {
    if (date == null) {
      return 'Chưa thiết lập';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  // D5 - Gui thoi diem chinh xac ve Backend.
  // UTC giup tranh sai lech mui gio giua Flutter va Node.js.
  String? _toApiDateTime(DateTime? date) {
    if (date == null) {
      return null;
    }

    return date.toUtc().toIso8601String();
  }

  // D5 - Chon ngay truoc, sau do chon gio.
  Future<void> _selectDateTime({required bool isStartDate}) async {
    if (_isSaving) return;

    final current = isStartDate ? _startDate : _dueDate;
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStartDate ? 'Chọn ngày bắt đầu' : 'Chọn hạn hoàn thành',
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    final initialTime = current != null
        ? TimeOfDay.fromDateTime(current)
        : TimeOfDay.fromDateTime(now);

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: isStartDate ? 'Chọn giờ bắt đầu' : 'Chọn giờ hoàn thành',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (!mounted || selectedTime == null) {
      return;
    }

    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    setState(() {
      if (isStartDate) {
        _startDate = selectedDateTime;
      } else {
        _dueDate = selectedDateTime;
      }
    });
  }

  Future<void> _createTask() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate != null &&
        _dueDate != null &&
        _dueDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hạn hoàn thành không được trước ngày bắt đầu.'),
        ),
      );
      return;
    }

    // D5 - Khong cho tao cong viec chua hoan thanh
    // voi han hoan thanh da qua.
    if (_dueDate != null &&
        _status != 'da_hoan_thanh' &&
        !_dueDate!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hạn hoàn thành phải lớn hơn thời gian hiện tại.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final body = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'status': _status,
        'priority': _priority,
        'startDate': _toApiDateTime(_startDate),
        'dueDate': _toApiDateTime(_dueDate),
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Authorization': 'Bearer ${widget.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 201) {
        Navigator.pop(context, true);
        return;
      }

      String message = 'Không thể tạo công việc.';

      try {
        final result = jsonDecode(utf8.decode(response.bodyBytes));

        if (result is Map && result['message'] is String) {
          message = result['message'] as String;
        }
      } catch (_) {
        // Su dung thong bao loi mac dinh.
      }

      if (response.statusCode == 401) {
        message = 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Kết nối quá thời gian.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể kết nối backend.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // D5 - Nut chon ngay va gio.
  Widget _dateField({
    required String label,
    required DateTime? value,
    required bool isStartDate,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isSaving
            ? null
            : () => _selectDateTime(isStartDate: isStartDate),
        icon: const Icon(Icons.event),
        label: Text(
          '$label: ${_formatDateTime(value)}',
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo công việc mới')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Thông tin công việc',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _titleController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Tên công việc *',
                  hintText: 'Nhập tên công việc',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.task_alt),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên công việc';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                enabled: !_isSaving,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  hintText: 'Nhập mô tả công việc',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'chua_thuc_hien',
                    child: Text('Chưa thực hiện'),
                  ),
                  DropdownMenuItem(
                    value: 'dang_thuc_hien',
                    child: Text('Đang thực hiện'),
                  ),
                  DropdownMenuItem(
                    value: 'da_hoan_thanh',
                    child: Text('Đã hoàn thành'),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _status = value);
                        }
                      },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Độ ưu tiên',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'thap', child: Text('Thấp')),
                  DropdownMenuItem(
                    value: 'trung_binh',
                    child: Text('Trung bình'),
                  ),
                  DropdownMenuItem(value: 'cao', child: Text('Cao')),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _priority = value);
                        }
                      },
              ),

              const SizedBox(height: 20),

              Text(
                'Thời gian công việc',
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 8),

              Text(
                'Chọn ngày và giờ để hệ thống nhắc việc chính xác.',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 12),

              _dateField(
                label: 'Ngày bắt đầu',
                value: _startDate,
                isStartDate: true,
              ),

              const SizedBox(height: 10),

              _dateField(
                label: 'Hạn hoàn thành',
                value: _dueDate,
                isStartDate: false,
              ),

              if (_startDate != null || _dueDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () {
                            setState(() {
                              _startDate = null;
                              _dueDate = null;
                            });
                          },
                    icon: const Icon(Icons.clear),
                    label: const Text('Xóa thời gian đã chọn'),
                  ),
                ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isSaving ? null : _createTask,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_task),
                label: Text(_isSaving ? 'Đang tạo...' : 'Tạo công việc'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
