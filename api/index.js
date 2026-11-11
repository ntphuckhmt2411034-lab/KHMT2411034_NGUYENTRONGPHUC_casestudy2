
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

// D6 - API xem lich su gui email
const emailLogRoutes = require('./routes/emailLogRoutes');
const notificationRoutes = require('./routes/notificationRoutes');

// E1 - API thong ke cong viec
const statisticsRoutes = require('./routes/statisticsRoutes');

// E4 - Lich su hoat dong cong viec
const taskActivityRoutes = require('./routes/taskActivityRoutes');

// D5 - Tu dong nhac han cong viec
const {
  sweepTaskReminders
} = require('./services/taskReminderService');

const app = express();

app.use(express.json());
app.use(cors());

// API kiem tra server
app.get('/', (req, res) => {
  res.json({
    message: 'API TaskManager Ä‘ang cháº¡y!'
  });
});

// Module A - Quan ly tai khoan
app.use('/api/auth', authRoutes);

// Module B - Quan ly cong viec
app.use('/api/tasks', taskRoutes);

// Module C1 - Tim kiem nguoi dung
app.use('/api/users', userRoutes);

// Module C1, C2 - Giao viec
app.use('/api/tasks', assignmentRoutes);

// Module C3 - Chia se cong viec
app.use('/api/tasks', taskShareRoutes);

// D6 - Lich su email cua cong viec
app.use('/api/tasks', emailLogRoutes);

app.use('/api/notifications', notificationRoutes);

// E1 - Thong ke cong viec
app.use('/api/statistics', statisticsRoutes);

// E4 - Lich su hoat dong cong viec
app.use('/api/tasks', taskActivityRoutes);

const PORT = process.env.PORT || 5000;

// D5 - Kiem tra nhac viec moi 5 phut
const REMINDER_INTERVAL_MS = 5 * 60 * 1000;

// D5 - Chay kiem tra va xu ly loi
async function runReminderSweep() {
  try {
    await sweepTaskReminders();
  } catch (error) {
    console.error(
      'D5 - Loi kiem tra nhac han:',
      error.message
    );
  }
}

async function startServer() {
  try {
    if (!process.env.MONGODB_URI) {
      throw new Error('Thiáº¿u MONGODB_URI trong file .env');
    }

    await mongoose.connect(process.env.MONGODB_URI);

    // D5 - Tao index MongoDB de chong nhac trung
    await mongoose.model('TaskReminder').init();

    console.log('Káº¿t ná»‘i MongoDB thÃ nh cÃ´ng!');

    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);

      // D5 - Quet lan dau khi khoi dong Backend
      runReminderSweep();

      // D5 - Sau do quet dinh ky moi 5 phut
      setInterval(
        runReminderSweep,
        REMINDER_INTERVAL_MS
      );

      console.log(
        'D5 - Scheduler dang hoat dong, kiem tra moi 5 phut'
      );
    });

  } catch (error) {
    console.error(
      'KhÃ´ng thá»ƒ khá»Ÿi Ä‘á»™ng backend:',
      error.message
    );

    process.exit(1);
  }
}

startServer();

