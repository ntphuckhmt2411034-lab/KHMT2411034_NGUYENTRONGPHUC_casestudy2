'use strict';

const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');

const router = express.Router();

// E1 - Xac thuc JWT.
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

// GET /api/statistics/status
router.get('/status', requireAuth, async (req, res) => {
  try {
    const userId = req.userId;

    const shares = await TaskShare.find({
      userId
    })
      .select('taskId')
      .lean();

    const sharedTaskIds = shares.map(share => share.taskId);

    // Giu dung pham vi cong viec cua GET /api/tasks.
    const accessFilter = {
      $or: [
        { createdBy: userId },
        { assignedTo: userId },
        { assigneeIds: userId },
        { sharedWith: userId },
        { _id: { $in: sharedTaskIds } }
      ]
    };

    // Chi lay truong status, khong can tai toan bo task.
    const tasks = await Task.find(accessFilter)
      .select('status')
      .lean();

    const byStatus = {
      chua_thuc_hien: 0,
      dang_thuc_hien: 0,
      da_hoan_thanh: 0
    };

    for (const task of tasks) {
      if (Object.prototype.hasOwnProperty.call(
        byStatus,
        task.status
      )) {
        byStatus[task.status]++;
      }
    }

    return res.status(200).json({
      success: true,
      total: tasks.length,
      byStatus
    });
  } catch (error) {
    console.error(
      'E1 - Loi thong ke trang thai:',
      error.message
    );

    return res.status(500).json({
      success: false,
      message: 'Khong the thong ke cong viec'
    });
  }
});

module.exports = router;
