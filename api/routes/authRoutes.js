
const express = require('express');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const jwt = require('jsonwebtoken');

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
// A2 - Dang nhap bang email va mat khau
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};

    // Kiem tra du lieu dau vao
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

    // Tim tai khoan trong MongoDB
    const user = await User.findOne({
      email: normalizedEmail
    });

    if (!user) {
      return res.status(401).json({
        message: 'Email hoặc mật khẩu không chính xác'
      });
    }

    // So sanh mat khau voi bcrypt
    const isPasswordValid = await bcrypt.compare(
      password,
      user.passwordHash
    );

    if (!isPasswordValid) {
      return res.status(401).json({
        message: 'Email hoặc mật khẩu không chính xác'
      });
    }

    // Kiem tra khoa JWT
    if (!process.env.JWT_SECRET) {
      console.error('JWT_SECRET chua duoc cau hinh');
      return res.status(500).json({
        message: 'Máy chủ chưa được cấu hình đầy đủ'
      });
    }

    // Tao JWT co thoi han 1 ngay
    const token = jwt.sign(
      { userId: user._id.toString() },
      process.env.JWT_SECRET,
      { expiresIn: '1d', algorithm: 'HS256' }
    );

    // Tra ve ket qua dang nhap
    return res.status(200).json({
      message: 'Đăng nhập thành công',
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        avatarUrl: user.avatarUrl
      }
    });
  } catch (error) {
    console.error('Loi dang nhap:', error.message);

    return res.status(500).json({
      message: 'Lỗi máy chủ khi đăng nhập'
    });
  }
});