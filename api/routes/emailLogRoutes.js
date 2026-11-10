
'use strict';

const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

const Task = require('../models/Task');
const EmailLog = require('../models/EmailLog');

const router = express.Router();

// D6 - Xac thuc JWT.
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

// D6 - Lay lich su email cua mot cong viec.
// GET /api/tasks/:taskId/email-history
router.get('/:taskId/email-history', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.taskId;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    // Chi chu so huu cong viec duoc xem lich su email.
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.userId
    })
      .select('_id title createdBy')
      .lean();

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen'
      });
    }

    const status = req.query.status;

    const validStatuses = [
      'pending',
      'sent',
      'failed'
    ];

    if (
      status !== undefined &&
      !validStatuses.includes(status)
    ) {
      return res.status(400).json({
        message: 'Trang thai loc khong hop le'
      });
    }

    const filter = { taskId: task._id };

    if (status) {
      filter.status = status;
    }

    // Gioi han so ban ghi tra ve de tranh tai qua lon.
    const logs = await EmailLog.find(filter)
      .select(
        'recipientEmail eventType subject status ' +
        'attempts errorMessage sentAt createdAt'
      )
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    return res.status(200).json({
      success: true,
      taskId: String(task._id),
      taskTitle: task.title,
      total: logs.length,
      emailHistory: logs.map(log => ({
        id: String(log._id),
        recipientEmail: log.recipientEmail,
        eventType: log.eventType,
        subject: log.subject,
        status: log.status,
        attempts: log.attempts,
        errorMessage: log.errorMessage || '',
        sentAt: log.sentAt,
        createdAt: log.createdAt
      }))
    });

  } catch (error) {
    console.error(
      'D6 - Loi lay lich su email:',
      error.message
    );

    return res.status(500).json({
      message: 'Khong the lay lich su email'
    });
  }
});

module.exports = router;
