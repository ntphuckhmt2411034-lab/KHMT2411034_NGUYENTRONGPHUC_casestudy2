
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

module.exports = router;
