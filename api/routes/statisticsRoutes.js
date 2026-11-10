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

// =====================================================
// E2 - Thong ke cong viec duoc giao va phu trach
// GET /api/statistics/assignments
// =====================================================
router.get('/assignments', requireAuth, async (req, res) => {
  try {
    const userId = req.userId;

    const [
      assignedCount,
      primaryCount,
      createdCount
    ] = await Promise.all([
      Task.countDocuments({
        $or: [
          { assignedTo: userId },
          { assigneeIds: userId }
        ]
      }),

      Task.countDocuments({
        primaryAssigneeId: userId
      }),

      Task.countDocuments({
        createdBy: userId
      })
    ]);

    return res.status(200).json({
      success: true,
      assignedCount,
      primaryCount,
      createdCount
    });
  } catch (error) {
    console.error(
      'E2 - Loi thong ke giao viec:',
      error.message
    );

    return res.status(500).json({
      success: false,
      message: 'Khong the thong ke giao viec'
    });
  }
});

// =====================================================
// E3 - Thong ke cong viec sap den han va qua han
// GET /api/statistics/deadlines
// =====================================================
router.get('/deadlines', requireAuth, async (req, res) => {
  try {
    const userId = req.userId;

    const shares = await TaskShare.find({
      userId
    })
      .select('taskId')
      .lean();

    const sharedTaskIds = shares.map(share => share.taskId);

    const accessFilter = {
      $or: [
        { createdBy: userId },
        { assignedTo: userId },
        { assigneeIds: userId },
        { sharedWith: userId },
        { _id: { $in: sharedTaskIds } }
      ]
    };

    const now = new Date();
    const next24Hours = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    // Qua han: dueDate < now, chua hoan thanh, dueDate khac null
    const overdueQuery = {
      ...accessFilter,
      dueDate: { $ne: null, $lt: now },
      status: { $ne: 'da_hoan_thanh' }
    };

    // Sap den han trong vong 24h: now <= dueDate <= next24Hours, chua hoan thanh
    const dueSoonQuery = {
      ...accessFilter,
      dueDate: { $ne: null, $gte: now, $lte: next24Hours },
      status: { $ne: 'da_hoan_thanh' }
    };

    const [overdueCount, dueSoonCount] = await Promise.all([
      Task.countDocuments(overdueQuery),
      Task.countDocuments(dueSoonQuery)
    ]);

    return res.status(200).json({
      success: true,
      overdueCount,
      dueSoonCount
    });
  } catch (error) {
    console.error(
      'E3 - Loi thong ke thoi han:',
      error.message
    );

    return res.status(500).json({
      success: false,
      message: 'Khong the thong ke thoi han cong viec'
    });
  }
});

module.exports = router;