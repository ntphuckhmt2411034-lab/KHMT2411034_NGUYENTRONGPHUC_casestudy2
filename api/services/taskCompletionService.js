
'use strict';

const mongoose = require('mongoose');

const TaskShare = require('../models/TaskShare');
const User = require('../models/User');
const EmailLog = require('../models/EmailLog');

const {
  createNotification
} = require('./notificationService');

const {
  sendTaskCompletedEmail
} = require('./emailService');

// D4 - Cau hinh gui email qua Mailtrap.
const EMAIL_DELAY_MS = 3000;
const MAX_ATTEMPTS = 3;

// Tam dung truoc khi gui email tiep theo.
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Kiem tra loi gioi han toc do Mailtrap.
function isRateLimitError(error) {
  const message = String(error?.message || '').toLowerCase();

  return (
    message.includes('too many emails per second') ||
    message.includes('rate limit') ||
    message.includes('rate exceeded') ||
    message.includes('throttl')
  );
}

// D4 - Gui email va tu thu lai khi bi gioi han toc do.
async function sendEmailWithRetry({
  to,
  taskTitle,
  log
}) {
  for (
    let attempt = 1;
    attempt <= MAX_ATTEMPTS;
    attempt++
  ) {
    try {
      if (log) {
        log.attempts = attempt;
        await log.save();
      }

      await sendTaskCompletedEmail({
        to,
        taskTitle
      });

      if (log) {
        log.status = 'sent';
        log.sentAt = new Date();
        log.errorMessage = '';
        await log.save();
      }

      console.log(
        `D4 - Email sent: ${to}, attempt ${attempt}`
      );

      return true;

    } catch (error) {
      console.error(
        `D4 - Email error: ${to}, attempt ${attempt}:`,
        error.message
      );

      // Chi thu lai neu loi do gioi han toc do.
      const shouldRetry =
        isRateLimitError(error) &&
        attempt < MAX_ATTEMPTS;

      if (!shouldRetry) {
        if (log) {
          try {
            log.status = 'failed';
            log.errorMessage = String(
              error.message
            ).slice(0, 500);

            await log.save();
          } catch (logError) {
            console.error(
              'D4 - Loi luu EmailLog:',
              logError.message
            );
          }
        }

        return false;
      }

      // Thoi gian cho tang dan: 3s, 6s.
      const retryDelay = EMAIL_DELAY_MS * attempt;

      console.log(
        `D4 - Rate limit, retry after ${retryDelay}ms`
      );

      await sleep(retryDelay);
    }
  }

  return false;
}

// D4 - Thong bao khi cong viec vua hoan thanh.
async function notifyTaskCompleted({ task, actorId }) {
  const result = {
    completed: true,
    recipients: 0,
    accepted: 0,
    failed: 0
  };

  if (!task || task.status !== 'da_hoan_thanh') {
    console.log('D4 - Cong viec chua hoan thanh');

    return {
      ...result,
      completed: false
    };
  }

  // Lay cac thanh vien duoc chia se cong viec.
  const shares = await TaskShare.find({
    taskId: task._id
  })
    .select('userId')
    .lean();

  // Lay nguoi tao, nguoi duoc giao va nguoi duoc chia se.
  const recipientIds = new Set([
    String(task.createdBy),

    ...(task.assigneeIds || []).map(String),

    ...(task.assignedTo
      ? [String(task.assignedTo)]
      : []),

    ...shares.map(share => String(share.userId))
  ]);

  // Khong gui cho nguoi vua danh dau hoan thanh.
  recipientIds.delete(String(actorId));

  const ids = [...recipientIds].filter(id =>
    mongoose.isValidObjectId(id)
  );

  if (ids.length === 0) {
    console.log('D4 - Khong co nguoi nhan');
    return result;
  }

  const users = await User.find({
    _id: { $in: ids }
  })
    .select('_id email')
    .lean();

  result.recipients = users.length;

  // Gui tuan tu, khong gui dong thoi.
  for (let index = 0; index < users.length; index++) {
    const user = users[index];

    // Tao Notification mot lan cho moi nguoi.
    try {
      await createNotification({
        userId: user._id,
        taskId: task._id,
        type: 'task_completed',
        title: 'Cong viec da hoan thanh',
        message: `Cong viec "${task.title}" da hoan thanh.`
      });
    } catch (error) {
      console.error(
        'D4 - Loi tao Notification:',
        error.message
      );
    }

    let log = null;

    // Tao EmailLog mot lan, retry khong tao them log.
    try {
      log = await EmailLog.create({
        taskId: task._id,
        recipientEmail: user.email,
        eventType: 'task_completed',
        subject: 'TaskManager - Cong viec da hoan thanh',
        status: 'pending',
        attempts: 0
      });
    } catch (error) {
      console.error(
        'D4 - Loi tao EmailLog:',
        error.message
      );

      // Khong gui neu khong the luu lich su.
      result.failed++;
      continue;
    }

    // Cach nhau 3 giay giua cac nguoi nhan.
    if (index > 0) {
      await sleep(EMAIL_DELAY_MS);
    }

    const success = await sendEmailWithRetry({
      to: user.email,
      taskTitle: task.title,
      log
    });

    if (success) {
      result.accepted++;
    } else {
      result.failed++;
    }
  }

  console.log('D4 - Ket qua gui email:', result);

  return result;
}

module.exports = {
  notifyTaskCompleted
};
