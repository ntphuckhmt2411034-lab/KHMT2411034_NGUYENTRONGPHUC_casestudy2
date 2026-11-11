const TaskActivity = require('../models/TaskActivity');

async function logTaskActivity({
  taskId,
  userId,
  action,
  details = {}
}) {
  try {
    if (!taskId || !userId || !action) {
      throw new Error('Thieu thong tin ghi lich su hoat dong');
    }

    return await TaskActivity.create({
      taskId,
      userId,
      action,
      details
    });
  } catch (error) {
    // Loi ghi lich su khong lam that bai nghiep vu chinh
    console.error(
      'E4 - Khong ghi duoc lich su hoat dong:',
      error.message
    );

    return null;
  }
}

module.exports = { logTaskActivity };
