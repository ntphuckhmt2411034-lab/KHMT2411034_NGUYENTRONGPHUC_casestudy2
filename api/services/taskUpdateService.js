'use strict';
const mongoose = require('mongoose');
const TaskShare = require('../models/TaskShare');
const User = require('../models/User');
const EmailLog = require('../models/EmailLog');
const { createNotification } = require('./notificationService');
const { sendTaskUpdateEmail } = require('./emailService');

const names = {
  title: 'Ten cong viec',
  description: 'Mo ta',
  priority: 'Muc do uu tien',
  dueDate: 'Han hoan thanh',
  startDate: 'Ngay bat dau'
};
function normalized(field, value) {
  if (field === 'dueDate' || field === 'startDate') {
    if (value === null || value === undefined || value === '') return null;
    const parsed = value instanceof Date ? value : new Date(value);
    return Number.isNaN(parsed.getTime()) ? String(value) : parsed.toISOString();
  }
  return value == null ? '' : String(value);
}
function formatValue(field, value) {
  if (field === 'dueDate' || field === 'startDate') {
    if (!value) return '(Khong co)';
    return new Date(value).toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' });
  }
  return value ? String(value) : '(Trong)';
}

async function notifyImportantTaskUpdate({ task, oldValues, actorId }) {
  const changed = Object.keys(oldValues).filter(field =>
    Object.prototype.hasOwnProperty.call(names, field) &&
    normalized(field, oldValues[field]) !== normalized(field, task[field])
  );
  if (changed.length === 0) return { changed: [], recipients: 0, accepted: 0, failed: 0 };

  const shared = await TaskShare.find({ taskId: task._id }).select('userId').lean();
  const recipients = new Set([
    String(task.createdBy),
    ...(task.assigneeIds || []).map(String),
    ...(task.sharedWith || []).map(String),
    ...(task.assignedTo ? [String(task.assignedTo)] : []),
    ...shared.map(s => String(s.userId))
  ]);
  recipients.delete(String(actorId));

  const ids = [...recipients].filter(mongoose.isValidObjectId);
  if (ids.length === 0) return { changed, recipients: 0, accepted: 0, failed: 0 };
  const users = await User.find({ _id: { $in: ids } }).select('_id email').lean();
  const changedDetails = changed.map(field =>
    names[field] + ': ' + formatValue(field, oldValues[field]) + ' -> ' + formatValue(field, task[field])
  );
  const subject = 'TaskManager - Cap nhat thong tin quan trong cua cong viec';
  const results = await Promise.allSettled(users.map(async user => {
    try {
      await createNotification({
        userId: user._id, taskId: task._id, type: 'task_updated',
        title: 'Cong viec co thay doi quan trong',
        message: 'Cong viec "' + task.title + '" da thay doi: ' + changed.map(x => names[x]).join(', ')
      });
    } catch (error) {
      console.error('D3 - Loi tao Notification:', error.message);
    }
    let log = null;
    try {
      log = await EmailLog.create({
        taskId: task._id, recipientEmail: user.email,
        eventType: 'task_updated', subject,
        status: 'pending', attempts: 1
      });
    } catch (error) {
      console.error('D3 - Loi tao EmailLog:', error.message);
    }
    try {
      await sendTaskUpdateEmail({ to: user.email, taskTitle: task.title, changedDetails });
      if (log) {
        log.status = 'sent'; log.sentAt = new Date(); log.errorMessage = '';
        try { await log.save(); } catch (err) { console.error('D3 - Loi cap nhat sent:', err.message); }
      }
      return true;
    } catch (error) {
      if (log) {
        log.status = 'failed'; log.errorMessage = String(error.message || error).slice(0, 500);
        try { await log.save(); } catch (err) { console.error('D3 - Loi cap nhat failed:', err.message); }
      }
      console.error('D3 - Gui email that bai:', error.message);
      return false;
    }
  }));
  let accepted = 0;
  for (const result of results) {
    if (result.status === 'fulfilled' && result.value === true) accepted++;
  }
  const summary = { changed, recipients: users.length, accepted, failed: users.length - accepted };
  console.log('D3 - Ket qua gui email:', summary);
  return summary;
}
module.exports = { notifyImportantTaskUpdate };
