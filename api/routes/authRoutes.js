
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const router = express.Router();

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Chi tra ve thong tin an toan cho frontend.
function publicUser(user) {
  return {
    id: user._id,
    fullName: user.fullName,
    email: user.email,
    avatarUrl: user.avatarUrl || ''
  };
}

// Middleware xac thuc JWT cho API can dang nhap.
function requireAuth(req, res, next) {
  const authorization = req.headers.authorization || '';
  const match = /^Bearer\s+(\S+)$/i.exec(authorization);

  if (!match) {
    return res.status(401).json({
      message: 'Vui lòng đăng nhập để tiếp tục'
    });
  }

  if (!process.env.JWT_SECRET) {
    return res.status(500).json({
      message: 'Máy chủ chưa được cấu hình đầy đủ'
    });
  }

  try {
    const decoded = jwt.verify(
      match[1],
      process.env.JWT_SECRET,
      { algorithms: ['HS256'] }
    );

    if (
      !decoded ||
      typeof decoded !== 'object' ||
      typeof decoded.userId !== 'string'
    ) {
      return res.status(401).json({
        message: 'Token không hợp lệ'
      });
    }

    req.userId = decoded.userId;
    next();
  } catch (_) {
    return res.status(401).json({
      message: 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn'
    });
  }
}

// ======================================================
// A1 - DANG KY
// POST /api/auth/register
// ======================================================

router.post('/register', async (req, res) => {
  try {
    const { fullName, email, password } = req.body || {};

    if (
      typeof fullName !== 'string' ||
      typeof email !== 'string' ||
      typeof password !== 'string' ||
      !fullName.trim() ||
      !email.trim() ||
      !password
    ) {
      return res.status(400).json({
        message: 'Vui lòng nhập đầy đủ thông tin'
      });
    }

    const name = fullName.trim();
    const normalizedEmail = email.trim().toLowerCase();

    if (!emailRegex.test(normalizedEmail)) {
      return res.status(400).json({
        message: 'Email không hợp lệ'
      });
    }

    if (password.length < 8) {
      return res.status(400).json({
        message: 'Mật khẩu phải có ít nhất 8 ký tự'
      });
    }

    const existingUser = await User.findOne({
      email: normalizedEmail
    });

    if (existingUser) {
      return res.status(409).json({
        message: 'Email đã được đăng ký'
      });
    }

    const passwordHash = await bcrypt.hash(password, 12);

    const user = await User.create({
      fullName: name,
      email: normalizedEmail,
      passwordHash
    });

    return res.status(201).json({
      message: 'Đăng ký tài khoản thành công',
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email
      }
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        message: 'Email đã được đăng ký'
      });
    }

    console.error('Lỗi đăng ký:', error.message);

    return res.status(500).json({
      message: 'Lỗi máy chủ, vui lòng thử lại'
    });
  }
});

// ======================================================
// A2 - DANG NHAP
// POST /api/auth/login
// ======================================================

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};

    if (
      typeof email !== 'string' ||
      typeof password !== 'string' ||
      !email.trim() ||
      !password
    ) {
      return res.status(400).json({
        message: 'Vui lòng nhập email và mật khẩu'
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const user = await User.findOne({
      email: normalizedEmail
    });

    if (!user) {
      return res.status(401).json({
        message: 'Email hoặc mật khẩu không chính xác'
      });
    }

    const isPasswordValid = await bcrypt.compare(
      password,
      user.passwordHash
    );

    if (!isPasswordValid) {
      return res.status(401).json({
        message: 'Email hoặc mật khẩu không chính xác'
      });
    }

    if (!process.env.JWT_SECRET) {
      return res.status(500).json({
        message: 'Máy chủ chưa được cấu hình đầy đủ'
      });
    }

    const token = jwt.sign(
      { userId: user._id.toString() },
      process.env.JWT_SECRET,
      { expiresIn: '1d', algorithm: 'HS256' }
    );

    return res.status(200).json({
      message: 'Đăng nhập thành công',
      token,
      user: publicUser(user)
    });
  } catch (error) {
    console.error('Lỗi đăng nhập:', error.message);

    return res.status(500).json({
      message: 'Lỗi máy chủ khi đăng nhập'
    });
  }
});

// ======================================================
// A4 - XEM THONG TIN CA NHAN
// GET /api/auth/me
// ======================================================

router.get('/me', requireAuth, async (req, res) => {
  try {
    const user = await User.findById(req.userId);

    if (!user) {
      return res.status(404).json({
        message: 'Không tìm thấy tài khoản'
      });
    }

    return res.status(200).json({
      message: 'Lấy thông tin cá nhân thành công',
      user: publicUser(user)
    });
  } catch (error) {
    console.error('Lỗi lấy thông tin cá nhân:', error.message);

    return res.status(500).json({
      message: 'Không thể lấy thông tin cá nhân'
    });
  }
});

// ======================================================
// A4 - CAP NHAT THONG TIN CA NHAN
// PUT /api/auth/me
// ======================================================

router.put('/me', requireAuth, async (req, res) => {
  try {
    const body = req.body || {};
    const { fullName, email } = body;

    // Chi cho phep cap nhat ho ten va email.
    // Khong chap nhan cac truong nhu passwordHash, _id.
    const allowedFields = ['fullName', 'email'];
    const receivedFields = Object.keys(body);

    if (
      receivedFields.length === 0 ||
      receivedFields.some((field) => !allowedFields.includes(field))
    ) {
      return res.status(400).json({
        message: 'Chỉ được cập nhật họ tên và email'
      });
    }

    if (
      (fullName !== undefined &&
        (typeof fullName !== 'string' || !fullName.trim())) ||
      (email !== undefined &&
        (typeof email !== 'string' || !email.trim()))
    ) {
      return res.status(400).json({
        message: 'Thông tin cập nhật không hợp lệ'
      });
    }

    const updates = {};

    if (fullName !== undefined) {
      updates.fullName = fullName.trim();
    }

    if (email !== undefined) {
      const normalizedEmail = email.trim().toLowerCase();

      if (!emailRegex.test(normalizedEmail)) {
        return res.status(400).json({
          message: 'Email không hợp lệ'
        });
      }

      const existingUser = await User.findOne({
        email: normalizedEmail,
        _id: { $ne: req.userId }
      });

      if (existingUser) {
        return res.status(409).json({
          message: 'Email đã được sử dụng'
        });
      }

      updates.email = normalizedEmail;
    }

    const user = await User.findByIdAndUpdate(
      req.userId,
      { $set: updates },
      { new: true, runValidators: true }
    );

    if (!user) {
      return res.status(404).json({
        message: 'Không tìm thấy tài khoản'
      });
    }

    return res.status(200).json({
      message: 'Cập nhật thông tin cá nhân thành công',
      user: publicUser(user)
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        message: 'Email đã được sử dụng'
      });
    }

    if (error.name === 'CastError') {
      return res.status(401).json({
        message: 'Token không hợp lệ'
      });
    }

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Thông tin cập nhật không hợp lệ'
      });
    }

    console.error('Lỗi cập nhật thông tin cá nhân:', error.message);

    return res.status(500).json({
      message: 'Không thể cập nhật thông tin cá nhân'
    });
  }
});

module.exports = router;
