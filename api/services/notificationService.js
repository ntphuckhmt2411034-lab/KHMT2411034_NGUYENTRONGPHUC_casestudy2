const Notification = require('../models/Notification');

async function createNotification({
  userId,
  taskId,
  type,
  title,
  message
}) {
  if (!userId || !taskId || !type || !title || !message) {
    throw new Error('Thieu thong tin tao thong bao');
  }

  return Notification.create({
    userId,
    taskId,
    type,
    title,
    message,
    isRead: false
  });
}

async function createAssignmentNotification({ userId, task }) {
  return createNotification({
    userId,
    taskId: task._id,
    type: 'task_assigned',
    title: 'Ban duoc giao cong viec moi',
    message: `Ban vua duoc giao cong viec: ${task.title}`
  });
}

// D2 - Tao thong bao cho nguoi vua duoc moi chia se.
async function createShareNotification({ userId, task, permission = 'viewer' }) {
  return createNotification({
    userId,
    taskId: task._id,
    type: 'task_shared',
    title: 'Ban duoc moi tham gia cong viec',
    message: `Ban duoc chia se cong viec: ${task.title} (quyen ${permission})`
  });
}

module.exports = {
  createNotification,
  createAssignmentNotification,
  createShareNotification
};
