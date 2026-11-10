
'use strict';

const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

const Notification = require('../models/Notification');

const router = express.Router();

// D7 - Xac thuc JWT cho tat ca API thong bao.
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
  } catch (_) {
    return res.status(401).json({
      message: 'Token khong hop le hoac het han'
    });
  }
}

router.use(requireAuth);

// D7.1 - Lay danh sach thong bao cua nguoi dang nhap.
// GET /api/notifications?filter=all
// GET /api/notifications?filter=unread
// GET /api/notifications?filter=read
router.get('/', async (req, res) => {
  try {
    const filter = req.query.filter || 'all';

    if (
      typeof filter !== 'string' ||
      !['all', 'unread', 'read'].includes(filter)
    ) {
      return res.status(400).json({
        message: 'Bo loc khong hop le'
      });
    }

    const query = {
      userId: req.userId
    };

    if (filter === 'unread') {
      query.isRead = false;
    }

    if (filter === 'read') {
      query.isRead = true;
    }

    const [notifications, total, unreadCount] =
      await Promise.all([
        Notification.find(query)
          .select(
            'taskId type title message isRead createdAt'
          )
          .sort({ createdAt: -1, _id: -1 })
          .limit(100)
          .lean(),

        Notification.countDocuments(query),

        Notification.countDocuments({
          userId: req.userId,
          isRead: false
        })
      ]);

    return res.status(200).json({
      success: true,
      filter,
      total,
      returned: notifications.length,
      unreadCount,
      notifications: notifications.map(item => ({
        id: String(item._id),
        taskId: String(item.taskId),
        type: item.type,
        title: item.title,
        message: item.message,
        isRead: item.isRead,
        createdAt: item.createdAt
      }))
    });
  } catch (error) {
    console.error('D7 - Loi lay thong bao:', error.message);

    return res.status(500).json({
      message: 'Khong the lay danh sach thong bao'
    });
  }
});

// D7.2 - Dem so thong bao chua doc.
// GET /api/notifications/unread-count
router.get('/unread-count', async (req, res) => {
  try {
    const unreadCount = await Notification.countDocuments({
      userId: req.userId,
      isRead: false
    });

    return res.status(200).json({
      success: true,
      unreadCount
    });
  } catch (error) {
    console.error('D7 - Loi dem thong bao:', error.message);

    return res.status(500).json({
      message: 'Khong the dem thong bao chua doc'
    });
  }
});

// D7.3 - Danh dau tat ca thong bao la da doc.
// PATCH /api/notifications/read-all
router.patch('/read-all', async (req, res) => {
  try {
    const result = await Notification.updateMany(
      {
        userId: req.userId,
        isRead: false
      },
      {
        $set: { isRead: true }
      }
    );

    return res.status(200).json({
      success: true,
      modifiedCount: result.modifiedCount,
      message: 'Da danh dau tat ca thong bao la da doc'
    });
  } catch (error) {
    console.error(
      'D7 - Loi danh dau tat ca:',
      error.message
    );

    return res.status(500).json({
      message: 'Khong the danh dau tat ca thong bao'
    });
  }
});

// D7.4 - Danh dau mot thong bao la da doc.
// PATCH /api/notifications/:id/read
router.patch('/:id/read', async (req, res) => {
  try {
    const notificationId = req.params.id;

    if (!mongoose.isValidObjectId(notificationId)) {
      return res.status(400).json({
        message: 'ID thong bao khong hop le'
      });
    }

    // Bat buoc khop ca ID thong bao va nguoi nhan.
    const notification = await Notification.findOneAndUpdate(
      {
        _id: notificationId,
        userId: req.userId
      },
      {
        $set: { isRead: true }
      },
      {
        new: true
      }
    ).lean();

    if (!notification) {
      return res.status(404).json({
        message: 'Khong tim thay thong bao hoac khong co quyen'
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Da danh dau thong bao la da doc',
      notification: {
        id: String(notification._id),
        taskId: String(notification.taskId),
        type: notification.type,
        title: notification.title,
        message: notification.message,
        isRead: notification.isRead,
        createdAt: notification.createdAt
      }
    });
  } catch (error) {
    console.error(
      'D7 - Loi danh dau thong bao:',
      error.message
    );

    return res.status(500).json({
      message: 'Khong the danh dau thong bao la da doc'
    });
  }
});

module.exports = router;
