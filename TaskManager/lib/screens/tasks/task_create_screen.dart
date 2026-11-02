
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TaskCreateScreen extends StatefulWidget {
  final String token;

  const TaskCreateScreen({
    super.key,
    required this.token,
  });

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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chọn ngày';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String? _toApiDate(DateTime? date) {
    if (date == null) return null;

    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    if (_isSaving) return;

    final current = isStartDate ? _startDate : _dueDate;

    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStartDate
          ? 'Chọn ngày bắt đầu'
          : 'Chọn hạn hoàn thành',
    );

    if (!mounted || selected == null) return;

    setState(() {
      if (isStartDate) {
        _startDate = selected;
      } else {
        _dueDate = selected;
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
          content: Text(
            'Hạn hoàn thành không được trước ngày bắt đầu.',
          ),
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
        'startDate': _toApiDate(_startDate),
        'dueDate': _toApiDate(_dueDate),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kết nối quá thời gian.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể kết nối backend.'),
          ),
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

  Widget _dateField({
    required String label,
    required DateTime? value,
    required bool isStartDate,
  }) {
    return OutlinedButton.icon(
      onPressed: _isSaving
          ? null
          : () => _selectDate(isStartDate: isStartDate),
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text('$label: ${_formatDate(value)}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo công việc mới'),
      ),
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
                  DropdownMenuItem(
                    value: 'thap',
                    child: Text('Thấp'),
                  ),
                  DropdownMenuItem(
                    value: 'trung_binh',
                    child: Text('Trung bình'),
                  ),
                  DropdownMenuItem(
                    value: 'cao',
                    child: Text('Cao'),
                  ),
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

              _dateField(
                label: 'Ngày bắt đầu',
                value: _startDate,
                isStartDate: true,
              ),

              _dateField(
                label: 'Hạn hoàn thành',
                value: _dueDate,
                isStartDate: false,
              ),

              if (_startDate != null || _dueDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                      setState(() {
                        _startDate = null;
                        _dueDate = null;
                      });
                    },
                    child: const Text('Xóa ngày đã chọn'),
                  ),
                ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isSaving ? null : _createTask,
                icon: _isSaving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.add_task),
                label: Text(
                  _isSaving ? 'Đang tạo...' : 'Tạo công việc',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
