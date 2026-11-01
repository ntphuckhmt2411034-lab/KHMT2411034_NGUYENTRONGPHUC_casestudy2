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

// B1 - Xem danh sach cong viec
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

module.exports = router;
