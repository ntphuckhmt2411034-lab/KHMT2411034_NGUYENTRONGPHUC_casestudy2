
const express = require('express');
const bcrypt = require('bcryptjs');
const User = require('../models/User');

const router = express.Router();

// API đăng ký tài khoản
router.post('/register', async (req, res) => {
  try {
    const { fullName, email, password } = req.body || {};

    // Kiểm tra dữ liệu đầu vào
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

    // Kiểm tra định dạng email
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      return res.status(400).json({
        message: 'Email không hợp lệ'
      });
    }

    // Kiểm tra mật khẩu
    if (password.length < 8) {
      return res.status(400).json({
        message: 'Mật khẩu phải có ít nhất 8 ký tự'
      });
    }

    // Kiểm tra email đã tồn tại
    const existingUser = await User.findOne({
      email: normalizedEmail
    });

    if (existingUser) {
      return res.status(409).json({
        message: 'Email đã được đăng ký'
      });
    }

    // Băm mật khẩu trước khi lưu
    const passwordHash = await bcrypt.hash(password, 12);

    // Lưu tài khoản vào MongoDB
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

module.exports = router;
