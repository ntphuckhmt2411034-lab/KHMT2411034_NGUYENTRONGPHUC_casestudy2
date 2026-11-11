const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const TaskActivity = require('../models/TaskActivity');

const router = express.Router();

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

// E4 - XEM LICH SU HOAT DONG
// GET /api/tasks/:id/activities
router.get('/:id/activities', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    const task = await Task.findById(taskId)
      .select('_id createdBy assignedTo assigneeIds sharedWith')
      .lean();

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec'
      });
    }

    const userId = req.userId.toLowerCase();

    const isCreator =
      String(task.createdBy).toLowerCase() === userId;

    const isAssignee =
      String(task.assignedTo || '').toLowerCase() === userId ||
      (task.assigneeIds || []).some(
        id => String(id).toLowerCase() === userId
      );

    const isSharedWith =
      (task.sharedWith || []).some(
        id => String(id).toLowerCase() === userId
      );

    const share = await TaskShare.findOne({
      taskId: task._id,
      userId: req.userId
    }).select('_id').lean();

    if (!isCreator && !isAssignee && !isSharedWith && !share) {
      return res.status(403).json({
        message: 'Ban khong co quyen xem lich su cong viec'
      });
    }

    const activities = await TaskActivity.find({
      taskId: task._id
    })
      .populate('userId', 'fullName')
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    return res.status(200).json({
      message: 'Lay lich su hoat dong thanh cong',
      total: activities.length,
      activities
    });
  } catch (error) {
    console.error('E4 - Loi lay lich su hoat dong:', error.message);

    return res.status(500).json({
      message: 'Khong the lay lich su hoat dong'
    });
  }
});

module.exports = router;
