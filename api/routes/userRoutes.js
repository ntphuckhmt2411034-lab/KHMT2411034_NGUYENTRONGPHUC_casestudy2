
const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const User = require('../models/User');

const router = express.Router();

// Xac thuc JWT - cung co che voi Module B
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
// C1 - Tim nguoi dung theo email hoac ho ten
// GET /api/users/search?q=...
// =====================================================
router.get('/search', requireAuth, async (req, res) => {
  try {
    const q = req.query.q;

    if (typeof q !== 'string') {
      return res.status(400).json({
        message: 'Vui long nhap email hoac ho ten'
      });
    }

    const keyword = q.trim();

    if (keyword.length < 2 || keyword.length > 100) {
      return res.status(400).json({
        message: 'Tu khoa phai co tu 2 den 100 ky tu'
      });
    }

    // Escape ky tu dac biet cua regular expression
    const escapedKeyword = keyword.replace(
      /[.*+?^${}()|[\]\\]/g,
      '\\$&'
    );

    const regex = new RegExp(escapedKeyword, 'i');

    const users = await User.find({
      _id: { $ne: req.userId },
      $or: [
        { email: regex },
        { fullName: regex }
      ]
    })
      .select('_id fullName email avatarUrl')
      .limit(10)
      .lean();

    return res.status(200).json({
      message: 'Tim kiem nguoi dung thanh cong',
      total: users.length,
      users
    });
  } catch (error) {
    console.error('Loi tim kiem nguoi dung:', error.message);

    return res.status(500).json({
      message: 'Khong the tim kiem nguoi dung'
    });
  }
});

module.exports = router;
