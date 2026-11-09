
'use strict';

const mongoose = require('mongoose');

const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const TaskReminder = require('../models/TaskReminder');
const User = require('../models/User');
const EmailLog = require('../models/EmailLog');

const {
  createNotification
} = require('./notificationService');

const {
  sendTaskReminderEmail
} = require('./emailService');

// D5 - Cau hinh nhac viec
const REMINDER_HOURS = 24;
const EMAIL_DELAY_MS = 3000;

// Toi da 3 lan gui trong mot dot quet.
const MAX_ATTEMPTS_PER_RUN = 3;

// Toi da 6 lan gui cho moi nguoi, moi han.
const MAX_TOTAL_ATTEMPTS = 6;

let isRunning = false;

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function isRateLimitError(error) {
  const message = String(
    error?.message || ''
  ).toLowerCase();

  return (
    message.includes('too many emails per second') ||
    message.includes('rate limit') ||
    message.includes('rate exceeded') ||
    message.includes('throttl')
  );
}

// D5 - Lay danh sach nguoi lien quan.
async function getReminderRecipients(task) {
  const shares = await TaskShare.find({
    taskId: task._id
  })
    .select('userId')
    .lean();

  const ids = new Set([
    String(task.createdBy),

    ...(task.assigneeIds || []).map(String),

    ...(task.assignedTo
      ? [String(task.assignedTo)]
      : []),

    ...(task.primaryAssigneeId
      ? [String(task.primaryAssigneeId)]
      : []),

    ...(task.sharedWith || []).map(String),

    ...shares.map(share => String(share.userId))
  ]);

  const validIds = [...ids].filter(id =>
    mongoose.isValidObjectId(id)
  );

  return User.find({
    _id: { $in: validIds },
    email: {
      $exists: true,
      $nin: [null, '']
    }
  })
    .select('_id email')
    .lean();
}

// D5 - Tao moi hoac nhan lai ban ghi failed.
// Su dung cap nhat co dieu kien de tranh hai
// tien trinh cung nhan mot ban ghi failed.
async function claimReminder(task, user) {
  try {
    const reminder = await TaskReminder.create({
      taskId: task._id,
      userId: user._id,
      dueDate: task.dueDate,
      reminderHours: REMINDER_HOURS,
      status: 'pending',
      attempts: 0
    });

    return {
      reminder,
      isNew: true
    };
  } catch (error) {
    if (error.code !== 11000) {
      throw error;
    }

    // Chi nhan lai ban ghi that bai
    // va chua vuot gioi han so lan gui.
    const reminder = await TaskReminder.findOneAndUpdate(
      {
        taskId: task._id,
        userId: user._id,
        dueDate: task.dueDate,
        reminderHours: REMINDER_HOURS,
        status: 'failed',
        attempts: { $lt: MAX_TOTAL_ATTEMPTS }
      },
      {
        $set: {
          status: 'pending',
          errorMessage: ''
        }
      },
      {
        new: true
      }
    );

    if (!reminder) {
      return null;
    }

    return {
      reminder,
      isNew: false
    };
  }
}

// D5 - Lay lai EmailLog cua lan gui cu.
// Neu chua co, tao moi mot ban ghi.
async function getOrCreateEmailLog({
  task,
  user,
  reminder
}) {
  // Chi lay EmailLog tu luc reminder nay duoc tao.
  // Tranh nham voi email cua han hoan thanh cu.
  const existingLog = await EmailLog.findOne({
    taskId: task._id,
    recipientEmail: user.email.toLowerCase(),
    eventType: 'task_due_reminder',
    createdAt: {
      $gte: new Date(
        reminder.createdAt.getTime() - 1000
      )
    }
  }).sort({ createdAt: -1 });

  if (existingLog) {
    return existingLog;
  }

  return EmailLog.create({
    taskId: task._id,
    recipientEmail: user.email,
    eventType: 'task_due_reminder',
    subject: 'TaskManager - Nhac viec sap den han',
    status: 'pending',
    attempts: reminder.attempts
  });
}

// D5 - Kiem tra cong viec van con can nhac.
async function isTaskStillEligible(task) {
  const current = await Task.findById(task._id)
    .select('status dueDate')
    .lean();

  if (!current || !current.dueDate) {
    return false;
  }

  const now = new Date();

  const cutoff = new Date(
    now.getTime() + REMINDER_HOURS * 60 * 60 * 1000
  );

  return (
    current.status !== 'da_hoan_thanh' &&
    current.dueDate.getTime() ===
      task.dueDate.getTime() &&
    current.dueDate > now &&
    current.dueDate <= cutoff
  );
}

// D5 - Gui email co retry va dem tong so lan.
async function sendReminderWithRetry({
  user,
  task,
  reminder,
  log
}) {
  const remaining =
    MAX_TOTAL_ATTEMPTS - reminder.attempts;

  const allowedAttempts = Math.min(
    MAX_ATTEMPTS_PER_RUN,
    remaining
  );

  for (
    let index = 0;
    index < allowedAttempts;
    index++
  ) {
    // Khong gui neu task da hoan thanh
    // hoac han hoan thanh da thay doi.
    if (!(await isTaskStillEligible(task))) {
      reminder.status = 'failed';
      reminder.errorMessage =
        'Cong viec khong con phu hop de nhac han';

      await reminder.save();

      return false;
    }

    reminder.attempts += 1;
    log.attempts = reminder.attempts;

    await reminder.save();
    await log.save();

    let sendError = null;

    try {
      await sendTaskReminderEmail({
        to: user.email,
        taskTitle: task.title,
        dueDate: task.dueDate,
        reminderHours: REMINDER_HOURS
      });
    } catch (error) {
      sendError = error;
    }

    if (!sendError) {
      reminder.status = 'sent';
      reminder.sentAt = new Date();
      reminder.errorMessage = '';

      log.status = 'sent';
      log.sentAt = new Date();
      log.errorMessage = '';

      await reminder.save();
      await log.save();

      console.log(
        `D5 - Email sent: ${user.email}, ` +
        `attempt ${reminder.attempts}`
      );

      return true;
    }

    const errorMessage = String(
      sendError.message
    ).slice(0, 500);

    console.error(
      `D5 - Email error: ${user.email}, ` +
      `attempt ${reminder.attempts}:`,
      errorMessage
    );

    const canRetryNow =
      isRateLimitError(sendError) &&
      index + 1 < allowedAttempts;

    if (canRetryNow) {
      await sleep(
        EMAIL_DELAY_MS * (index + 1)
      );
      continue;
    }

    reminder.status = 'failed';
    reminder.errorMessage = errorMessage;

    log.status = 'failed';
    log.errorMessage = errorMessage;

    await reminder.save();
    await log.save();

    return false;
  }

  reminder.status = 'failed';
  reminder.errorMessage =
    'Da dat gioi han so lan gui';

  await reminder.save();

  return false;
}

// D5 - Xu ly nhac han cho tung cong viec.
async function remindTask(task, stats) {
  const recipients = await getReminderRecipients(task);

  for (const user of recipients) {
    if (!(await isTaskStillEligible(task))) {
      stats.skipped++;
      continue;
    }

    const claim = await claimReminder(task, user);

    if (!claim) {
      // Da gui thanh cong, dang xu ly,
      // hoac da dat gioi han gui.
      stats.skipped++;
      continue;
    }

    const { reminder, isNew } = claim;

    if (isNew) {
      stats.created++;

      // Notification chi tao o lan dau.
      try {
        await createNotification({
          userId: user._id,
          taskId: task._id,
          type: 'task_due_reminder',
          title: 'Cong viec sap den han',
          message:
            `Cong viec "${task.title}" sap den han hoan thanh.`
        });
      } catch (error) {
        console.error(
          'D5 - Loi tao Notification:',
          error.message
        );
      }
    } else {
      stats.retried++;

      console.log(
        `D5 - Thu gui lai cho ${user.email}`
      );
    }

    let log;

    try {
      log = await getOrCreateEmailLog({
        task,
        user,
        reminder
      });
    } catch (error) {
      reminder.status = 'failed';
      reminder.errorMessage =
        String(error.message).slice(0, 500);

      await reminder.save();

      stats.failed++;

      console.error(
        'D5 - Loi tao EmailLog:',
        error.message
      );

      continue;
    }

    // Gian cach giua cac email.
    await sleep(EMAIL_DELAY_MS);

    try {
      const success = await sendReminderWithRetry({
        user,
        task,
        reminder,
        log
      });

      if (success) {
        stats.sent++;
      } else {
        stats.failed++;
      }
    } catch (error) {
      stats.failed++;

      console.error(
        'D5 - Loi xu ly gui email:',
        error.message
      );

      try {
        reminder.status = 'failed';
        reminder.errorMessage =
          String(error.message).slice(0, 500);

        await reminder.save();
      } catch (saveError) {
        console.error(
          'D5 - Loi cap nhat TaskReminder:',
          saveError.message
        );
      }
    }
  }
}

// D5 - Quet cong viec sap den han.
async function sweepTaskReminders() {
  if (isRunning) {
    console.log('D5 - Bo qua lan quet trung');

    return {
      skippedRun: true
    };
  }

  isRunning = true;

  const stats = {
    tasks: 0,
    created: 0,
    sent: 0,
    failed: 0,
    skipped: 0,
    retried: 0
  };

  try {
    const now = new Date();

    const cutoff = new Date(
      now.getTime() + REMINDER_HOURS * 60 * 60 * 1000
    );

    const tasks = await Task.find({
      status: {
        $in: [
          'chua_thuc_hien',
          'dang_thuc_hien'
        ]
      },
      dueDate: {
        $gt: now,
        $lte: cutoff
      }
    })
      .sort({ dueDate: 1 })
      .limit(100);

    stats.tasks = tasks.length;

    for (const task of tasks) {
      try {
        await remindTask(task, stats);
      } catch (error) {
        stats.failed++;

        console.error(
          `D5 - Loi xu ly task ${task._id}:`,
          error.message
        );
      }
    }

    console.log(
      'D5 - REMINDER SWEEP:',
      stats
    );

    return stats;
  } finally {
    isRunning = false;
  }
}

module.exports = {
  sweepTaskReminders
};
