
const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const Task = require('../models/Task');

const router = express.Router();

// Xac thuc nguoi dung bang JWT
function requireAuth(req, res, next) {
  const authorization = req.headers.authorization || '';
  const match = /^Bearer\s+(\S+)$/i.exec(authorization);

  if (!match) {
    return res.status(401).json({
      message: 'Vui long dang nhap'
    });
  }

  try {
    if (!process.env.JWT_SECRET) {
      return res.status(500).json({
        message: 'Server chua cau hinh JWT'
      });
    }

    const decoded = jwt.verify(
      match[1],
      process.env.JWT_SECRET,
      { algorithms: ['HS256'] }
    );

    if (
      !decoded ||
      typeof decoded.userId !== 'string' ||
      !mongoose.isValidObjectId(decoded.userId)
    ) {
      return res.status(401).json({
        message: 'Token khong hop le'
      });
    }

    req.userId = decoded.userId;
    next();
  } catch (error) {
    return res.status(401).json({
      message: 'Token khong hop le hoac het han'
    });
  }
}

// =====================================================
// B1 - Xem danh sach cong viec
// GET /api/tasks
// =====================================================
router.get('/', requireAuth, async (req, res) => {
  try {
    const userId = req.userId;

    const tasks = await Task.find({
      $or: [
        { createdBy: userId },
        { assignedTo: userId },
        { sharedWith: userId }
      ]
    })
      .sort({ createdAt: -1 })
      .lean();

    return res.status(200).json({
      message: 'Lay danh sach cong viec thanh cong',
      total: tasks.length,
      tasks
    });
  } catch (error) {
    console.error('Loi lay danh sach:', error.message);

    return res.status(500).json({
      message: 'Khong the lay danh sach cong viec'
    });
  }
});

// =====================================================
// B2.1 - Xem chi tiet cong viec
// GET /api/tasks/:id
// =====================================================
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    // Chi cho phep nguoi co quyen xem cong viec
    const task = await Task.findOne({
      _id: taskId,
      $or: [
        { createdBy: req.userId },
        { assignedTo: req.userId },
        { sharedWith: req.userId }
      ]
    }).lean();

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen truy cap'
      });
    }

    return res.status(200).json({
      message: 'Lay chi tiet cong viec thanh cong',
      task
    });
  } catch (error) {
    console.error('Loi xem chi tiet cong viec:', error.message);

    return res.status(500).json({
      message: 'Khong the lay chi tiet cong viec'
    });
  }
});

// =====================================================
// B2.2 - Tao cong viec moi
// POST /api/tasks
// =====================================================
router.post('/', requireAuth, async (req, res) => {
  try {
    const {
      title,
      description,
      status,
      priority,
      startDate,
      dueDate
    } = req.body || {};

    // Kiem tra ten cong viec
    if (typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({
        message: 'Vui long nhap ten cong viec'
      });
    }

    // Kiem tra mo ta
    if (
      description !== undefined &&
      typeof description !== 'string'
    ) {
      return res.status(400).json({
        message: 'Mo ta khong hop le'
      });
    }

    // Gia tri trang thai hop le
    const validStatuses = [
      'chua_thuc_hien',
      'dang_thuc_hien',
      'da_hoan_thanh'
    ];

    if (
      status !== undefined &&
      !validStatuses.includes(status)
    ) {
      return res.status(400).json({
        message: 'Trang thai khong hop le'
      });
    }

    // Gia tri do uu tien hop le
    const validPriorities = [
      'thap',
      'trung_binh',
      'cao'
    ];

    if (
      priority !== undefined &&
      !validPriorities.includes(priority)
    ) {
      return res.status(400).json({
        message: 'Do uu tien khong hop le'
      });
    }

    // Chuyen chuoi ngay thang sang Date
    function parseDate(value) {
      if (
        value === undefined ||
        value === null ||
        value === ''
      ) {
        return null;
      }

      if (typeof value !== 'string') {
        return new Date(NaN);
      }

      return new Date(value);
    }

    const parsedStartDate = parseDate(startDate);
    const parsedDueDate = parseDate(dueDate);

    // Kiem tra ngay thang hop le
    if (
      (parsedStartDate &&
        Number.isNaN(parsedStartDate.getTime())) ||
      (parsedDueDate &&
        Number.isNaN(parsedDueDate.getTime()))
    ) {
      return res.status(400).json({
        message: 'Ngay thang khong hop le'
      });
    }

    // Han hoan thanh khong duoc truoc ngay bat dau
    if (
      parsedStartDate &&
      parsedDueDate &&
      parsedDueDate < parsedStartDate
    ) {
      return res.status(400).json({
        message: 'Han hoan thanh khong duoc truoc ngay bat dau'
      });
    }

    // Tao cong viec trong MongoDB
    const task = await Task.create({
      title: title.trim(),
      description: description ?? '',
      status: status ?? 'chua_thuc_hien',
      priority: priority ?? 'trung_binh',
      startDate: parsedStartDate,
      dueDate: parsedDueDate,

      // Lay ID nguoi tao tu JWT
      createdBy: req.userId
    });

    return res.status(201).json({
      message: 'Tao cong viec thanh cong',
      task
    });
  } catch (error) {
    console.error('Loi tao cong viec:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu cong viec khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the tao cong viec'
    });
  }
});

// =====================================================
// Export router - luon nam o cuoi file
// =====================================================

/**
 * B2.3 - Chinh sua cong viec
 * PUT /api/tasks/:id
 */
router.put('/:id', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    // Chi nguoi tao moi duoc sua cong viec trong B2.3
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen sua'
      });
    }

    const body = req.body;

    if (
      !body ||
      typeof body !== 'object' ||
      Array.isArray(body)
    ) {
      return res.status(400).json({
        message: 'Du lieu cap nhat khong hop le'
      });
    }

    const allowedFields = [
      'title',
      'description',
      'status',
      'priority',
      'startDate',
      'dueDate'
    ];

    const fields = Object.keys(body);

    if (
      fields.length === 0 ||
      fields.some(field => !allowedFields.includes(field))
    ) {
      return res.status(400).json({
        message: 'Truong cap nhat khong hop le'
      });
    }

    if (body.title !== undefined) {
      if (
        typeof body.title !== 'string' ||
        !body.title.trim()
      ) {
        return res.status(400).json({
          message: 'Ten cong viec khong hop le'
        });
      }

      task.title = body.title.trim();
    }

    if (body.description !== undefined) {
      if (typeof body.description !== 'string') {
        return res.status(400).json({
          message: 'Mo ta khong hop le'
        });
      }

      task.description = body.description;
    }

    if (body.status !== undefined) {
      const validStatuses = [
        'chua_thuc_hien',
        'dang_thuc_hien',
        'da_hoan_thanh'
      ];

      if (!validStatuses.includes(body.status)) {
        return res.status(400).json({
          message: 'Trang thai khong hop le'
        });
      }

      task.status = body.status;
    }

    if (body.priority !== undefined) {
      const validPriorities = [
        'thap',
        'trung_binh',
        'cao'
      ];

      if (!validPriorities.includes(body.priority)) {
        return res.status(400).json({
          message: 'Do uu tien khong hop le'
        });
      }

      task.priority = body.priority;
    }

    function parseDate(value) {
      if (value === null || value === '') {
        return null;
      }

      if (typeof value !== 'string') {
        return new Date(NaN);
      }

      return new Date(value);
    }

    if (body.startDate !== undefined) {
      const date = parseDate(body.startDate);

      if (date && Number.isNaN(date.getTime())) {
        return res.status(400).json({
          message: 'Ngay bat dau khong hop le'
        });
      }

      task.startDate = date;
    }

    if (body.dueDate !== undefined) {
      const date = parseDate(body.dueDate);

      if (date && Number.isNaN(date.getTime())) {
        return res.status(400).json({
          message: 'Han hoan thanh khong hop le'
        });
      }

      task.dueDate = date;
    }

    if (
      task.startDate &&
      task.dueDate &&
      task.dueDate < task.startDate
    ) {
      return res.status(400).json({
        message: 'Han hoan thanh khong duoc truoc ngay bat dau'
      });
    }

    await task.save();

    return res.status(200).json({
      message: 'Cap nhat cong viec thanh cong',
      task
    });

  } catch (error) {
    console.error('Loi cap nhat cong viec:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu cap nhat khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the cap nhat cong viec'
    });
  }
});

/**
 * B2.4 - Xoa cong viec
 * DELETE /api/tasks/:id
 */
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;

    // Kiem tra ID MongoDB
    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    // Chi nguoi tao moi co quyen xoa cong viec
    const task = await Task.findOneAndDelete({
      _id: taskId,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen xoa'
      });
    }

    return res.status(200).json({
      message: 'Xoa cong viec thanh cong',
      taskId: task._id
    });

  } catch (error) {
    console.error('Loi xoa cong viec:', error.message);

    return res.status(500).json({
      message: 'Khong the xoa cong viec'
    });
  }
});

/**
 * B3 - Cap nhat trang thai cong viec
 * PATCH /api/tasks/:id/status
 */
router.patch('/:id/status', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;

    // Kiem tra ID MongoDB
    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    // Kiem tra du lieu gui len
    const body = req.body;

    if (
      !body ||
      typeof body !== 'object' ||
      Array.isArray(body) ||
      Object.keys(body).length !== 1 ||
      !Object.prototype.hasOwnProperty.call(body, 'status')
    ) {
      return res.status(400).json({
        message: 'Chi duoc cap nhat truong status'
      });
    }

    const validStatuses = [
      'chua_thuc_hien',
      'dang_thuc_hien',
      'da_hoan_thanh'
    ];

    if (!validStatuses.includes(body.status)) {
      return res.status(400).json({
        message: 'Trang thai cong viec khong hop le'
      });
    }

    // B3: Chi nguoi tao duoc cap nhat trang thai.
    // Quyen editor se duoc mo rong o Module C.
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen cap nhat'
      });
    }

    task.status = body.status;

    await task.save();

    return res.status(200).json({
      message: 'Cap nhat trang thai thanh cong',
      task
    });

  } catch (error) {
    console.error('Loi cap nhat trang thai:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu cong viec khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the cap nhat trang thai'
    });
  }
});

/**
 * B4 - Cap nhat do uu tien cong viec
 * PATCH /api/tasks/:id/priority
 */
router.patch('/:id/priority', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    const body = req.body;

    if (
      !body ||
      typeof body !== 'object' ||
      Array.isArray(body) ||
      Object.keys(body).length !== 1 ||
      !Object.prototype.hasOwnProperty.call(body, 'priority')
    ) {
      return res.status(400).json({
        message: 'Chi duoc cap nhat truong priority'
      });
    }

    const validPriorities = ['thap', 'trung_binh', 'cao'];

    if (!validPriorities.includes(body.priority)) {
      return res.status(400).json({
        message: 'Do uu tien khong hop le'
      });
    }

    // B4: Chi nguoi tao duoc thay doi do uu tien.
    // Quyen editor se duoc bo sung trong Module C.
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen cap nhat'
      });
    }

    task.priority = body.priority;
    await task.save();

    return res.status(200).json({
      message: 'Cap nhat do uu tien thanh cong',
      task
    });
  } catch (error) {
    console.error('Loi cap nhat do uu tien:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu cong viec khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the cap nhat do uu tien'
    });
  }
});

module.exports = router;