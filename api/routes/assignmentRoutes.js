
const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

const Task = require('../models/Task');
const User = require('../models/User');

const router = express.Router();

// Xac thuc JWT - tuong thich Module A va B
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
// C1 - Giao cong viec cho mot hoac nhieu nguoi
// POST /api/tasks/:id/assignees
// =====================================================
// C5 - Creator can view all assignees and the primary assignee.
// GET /api/tasks/:id/assignees
router.get('/:id/assignees', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;
    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({ message: 'ID cong viec khong hop le' });
    }

    // Only the creator may inspect the full member roster.
    const task = await Task.findOne({ _id: taskId, createdBy: req.userId })
      .select('assignedTo assigneeIds primaryAssigneeId')
      .lean();
    if (!task) {
      return res.status(404).json({ message: 'Khong tim thay cong viec hoac khong co quyen' });
    }

    // Keep legacy Module B assignee, deduplicate by id.
    const ids = [...new Set([
      ...(task.assigneeIds || []).map(value => value.toString()),
      ...(task.assignedTo ? [task.assignedTo.toString()] : []),
    ])];

    const assignees = await User.find({ _id: { $in: ids } })
      .select('_id fullName email')
      .lean();
    const primaryId = task.primaryAssigneeId?.toString() || null;
    assignees.sort((a, b) => {
      if (a._id.toString() === primaryId) return -1;
      if (b._id.toString() === primaryId) return 1;
      return (a.fullName || '').localeCompare(b.fullName || '');
    });

    return res.status(200).json({
      message: 'Lay danh sach nguoi duoc giao thanh cong',
      taskId: task._id,
      total: assignees.length,
      primaryAssigneeId: primaryId,
      assignees,
    });
  } catch (error) {
    console.error('Loi C5 lay danh sach nguoi duoc giao:', error.message);
    return res.status(500).json({ message: 'Khong the lay danh sach nguoi duoc giao' });
  }
});
router.post('/:id/assignees', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;
    const body = req.body;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    if (
      !body ||
      typeof body !== 'object' ||
      Array.isArray(body) ||
      Object.keys(body).length !== 1 ||
      !Array.isArray(body.assigneeIds) ||
      body.assigneeIds.length === 0 ||
      body.assigneeIds.length > 50
    ) {
      return res.status(400).json({
        message: 'Danh sach nguoi duoc giao khong hop le'
      });
    }

    const ids = body.assigneeIds;

    if (
      ids.some(
        id =>
          typeof id !== 'string' ||
          !mongoose.isValidObjectId(id)
      )
    ) {
      return res.status(400).json({
        message: 'Co ID nguoi dung khong hop le'
      });
    }

    const uniqueIds = [
      ...new Set(ids.map(id => id.toLowerCase()))
    ];

    if (uniqueIds.length !== ids.length) {
      return res.status(400).json({
        message: 'Danh sach co nguoi dung trung lap'
      });
    }

    if (uniqueIds.includes(req.userId.toLowerCase())) {
      return res.status(400).json({
        message: 'Khong the giao viec cho chinh minh'
      });
    }

    // Chi nguoi tao moi duoc giao viec
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen giao'
      });
    }

    // Tat ca nguoi nhan phai ton tai
    const users = await User.find({
      _id: { $in: uniqueIds }
    })
      .select('_id fullName email')
      .lean();

    if (users.length !== uniqueIds.length) {
      return res.status(400).json({
        message: 'Mot hoac nhieu tai khoan khong ton tai'
      });
    }

    // Giu lai nguoi da duoc giao truoc do
    const existingIds = (task.assigneeIds || [])
      .map(id => id.toString().toLowerCase());

    // Bao toan du lieu assignedTo cu cua Module B
    if (task.assignedTo) {
      existingIds.push(
        task.assignedTo.toString().toLowerCase()
      );
    }

    const mergedIds = [
      ...new Set([...existingIds, ...uniqueIds])
    ];

    task.assigneeIds = mergedIds;

    await task.save();

    const assignees = await User.find({
      _id: { $in: mergedIds }
    })
      .select('_id fullName email')
      .lean();

    return res.status(200).json({
      message: 'Giao cong viec thanh cong',
      taskId: task._id,
      total: assignees.length,
      assignees
    });
  } catch (error) {
    console.error('Loi giao cong viec:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu giao viec khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the giao cong viec'
    });
  }
});

// =====================================================
// C2 - Chi dinh nguoi phu trach chinh
// PATCH /api/tasks/:id/assignees/:userId
// Body: { "isPrimary": true }
// =====================================================
router.patch('/:id/assignees/:userId', requireAuth, async (req, res) => {
  try {
    const { id, userId } = req.params;

    if (!mongoose.isValidObjectId(id) ||
        !mongoose.isValidObjectId(userId)) {
      return res.status(400).json({
        message: 'ID cong viec hoac nguoi dung khong hop le'
      });
    }

    if (!req.body ||
        req.body.isPrimary !== true ||
        Object.keys(req.body).length !== 1) {
      return res.status(400).json({
        message: 'Yeu cau isPrimary phai bang true'
      });
    }

    // Chi nguoi tao cong viec duoc chi dinh
    const task = await Task.findOne({
      _id: id,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen'
      });
    }

    const assignedIds = (task.assigneeIds || [])
      .map(value => value.toString().toLowerCase());

    // Tuong thich du lieu Module B
    if (task.assignedTo) {
      assignedIds.push(task.assignedTo.toString().toLowerCase());
    }

    if (!assignedIds.includes(userId.toLowerCase())) {
      return res.status(400).json({
        message: 'Nguoi duoc chon chua duoc giao cong viec'
      });
    }

    const user = await User.findById(userId)
      .select('_id fullName email')
      .lean();

    if (!user) {
      return res.status(404).json({
        message: 'Nguoi dung khong ton tai'
      });
    }

    // Chi thay doi nguoi phu trach chinh
    task.primaryAssigneeId = user._id;
    await task.save();

    return res.status(200).json({
      message: 'Chi dinh nguoi phu trach chinh thanh cong',
      taskId: task._id,
      primaryAssigneeId: task.primaryAssigneeId,
      primaryAssignee: user
    });
  } catch (error) {
    console.error('Loi C2:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu chi dinh khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the chi dinh nguoi phu trach chinh'
    });
  }
});

module.exports = router;
