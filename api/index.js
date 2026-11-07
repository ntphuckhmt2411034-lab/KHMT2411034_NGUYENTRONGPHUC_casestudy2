
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');

const authRoutes = require('./routes/authRoutes');
const taskRoutes = require('./routes/taskRoutes');
const userRoutes = require('./routes/userRoutes');
const assignmentRoutes = require('./routes/assignmentRoutes');

// C3 - API chia se cong viec
const taskShareRoutes = require('./routes/taskShareRoutes');

const app = express();

app.use(express.json());
app.use(cors());

// API kiem tra server
app.get('/', (req, res) => {
  res.json({
    message: 'API TaskManager đang chạy!'
  });
});

// Module A - Quan ly tai khoan
app.use('/api/auth', authRoutes);

// Module B - Quan ly cong viec
app.use('/api/tasks', taskRoutes);

// Module C1 - Tim kiem nguoi dung
app.use('/api/users', userRoutes);

// Module C1, C2 - Giao viec va chi dinh nguoi phu trach chinh
app.use('/api/tasks', assignmentRoutes);

// Module C3 - Chia se cong viec cho nhieu nguoi
app.use('/api/tasks', taskShareRoutes);

const PORT = process.env.PORT || 5000;

async function startServer() {
  try {
    if (!process.env.MONGODB_URI) {
      throw new Error('Thiếu MONGODB_URI trong file .env');
    }

    await mongoose.connect(process.env.MONGODB_URI);

    console.log('Kết nối MongoDB thành công!');

    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  } catch (error) {
    console.error(
      'Không thể khởi động backend:',
      error.message
    );
    process.exit(1);
  }
}

startServer();
