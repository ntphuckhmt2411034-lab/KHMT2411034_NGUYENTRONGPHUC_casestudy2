
'use strict';

const nodemailer = require('nodemailer');

// D3 fix: gioi han toc do gui email cho Mailtrap SMTP.
// Moi email duoc xu ly lan luot trong mot tien trinh Node.js.
const EMAIL_INTERVAL_MS = 3000;
const RATE_LIMIT_RETRY_DELAY_MS = 6000;
const MAX_RATE_LIMIT_ATTEMPTS = 3;

let emailQueue = Promise.resolve();
let lastSendStartedAt = 0;

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function isRateLimitError(error) {
  const message = String(error && error.message || error || '');

  return (
    /too many emails per second/i.test(message) ||
    /rate.limit/i.test(message) ||
    /too many requests/i.test(message) ||
    (/550\s+5\.7\.0/.test(message) &&
      /too many/i.test(message))
  );
}

function queueEmail(operation) {
  const job = emailQueue.then(operation);

  // Neu mot email loi, hang doi van tiep tuc gui email sau.
  emailQueue = job.then(
    () => undefined,
    () => undefined
  );

  return job;
}

async function waitForSendSlot() {
  const elapsed = Date.now() - lastSendStartedAt;
  const remaining = EMAIL_INTERVAL_MS - elapsed;

  if (remaining > 0) {
    await sleep(remaining);
  }

  lastSendStartedAt = Date.now();
}

async function sendTaskEmail({ to, subject, text }) {
  const host = process.env.MAILTRAP_HOST;
  const port = Number(process.env.MAILTRAP_PORT || 2525);
  const user = process.env.MAILTRAP_USER;
  const pass = process.env.MAILTRAP_PASS;

  if (!host || !user || !pass) {
    throw new Error('Chua cau hinh Mailtrap SMTP trong .env');
  }

  if (
    typeof to !== 'string' ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to)
  ) {
    throw new Error('Email nguoi nhan khong hop le');
  }

  if (typeof subject !== 'string' || !subject.trim()) {
    throw new Error('Tieu de email khong hop le');
  }

  if (typeof text !== 'string' || !text.trim()) {
    throw new Error('Noi dung email khong hop le');
  }

  return queueEmail(async () => {
    for (
      let attempt = 1;
      attempt <= MAX_RATE_LIMIT_ATTEMPTS;
      attempt++
    ) {
      await waitForSendSlot();

      const transporter = nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user, pass },
        connectionTimeout: 15000,
        greetingTimeout: 15000,
        socketTimeout: 20000
      });

      try {
        const result = await transporter.sendMail({
          from:
            process.env.MAILTRAP_FROM ||
            'taskmanager@example.com',
          to,
          subject,
          text
        });

        // Chi xem la thanh cong neu SMTP chap nhan email.
        if (
          !Array.isArray(result.accepted) ||
          result.accepted.length === 0
        ) {
          throw new Error(
            'SMTP khong chap nhan nguoi nhan email'
          );
        }

        console.log(
          `[EMAIL] Gui thanh cong toi ${to} ` +
          `(lan ${attempt})`
        );

        return result;
      } catch (error) {
        if (
          !isRateLimitError(error) ||
          attempt >= MAX_RATE_LIMIT_ATTEMPTS
        ) {
          console.error(
            `[EMAIL] Gui that bai toi ${to}:`,
            error.message
          );

          throw error;
        }

        console.warn(
          `[EMAIL] Mailtrap gioi han toc do. ` +
          `Thu lai ${attempt + 1}/${MAX_RATE_LIMIT_ATTEMPTS}.`
        );

        await sleep(RATE_LIMIT_RETRY_DELAY_MS);
      } finally {
        transporter.close();
      }
    }
  });
}

// D1 - Gui email khi giao cong viec moi.
async function sendAssignmentEmail({ to, taskTitle }) {
  return sendTaskEmail({
    to,
    subject: 'TaskManager - Ban duoc giao cong viec moi',
    text: [
      'Xin chao,',
      '',
      `Ban vua duoc giao cong viec: ${taskTitle}`,
      '',
      'Vui long mo ung dung TaskManager de xem chi tiet.',
      '',
      'TaskManager'
    ].join('\n')
  });
}

// D2 - Gui email khi moi nguoi dung chia se cong viec.
async function sendShareInvitationEmail({
  to,
  taskTitle,
  permission = 'viewer'
}) {
  const role = permission === 'editor'
    ? 'chinh sua'
    : 'xem';

  return sendTaskEmail({
    to,
    subject: 'TaskManager - Loi moi chia se cong viec',
    text: [
      'Xin chao,',
      '',
      `Ban vua duoc moi tham gia cong viec: ${taskTitle}`,
      `Quyen duoc cap: ${role}.`,
      '',
      'Vui long mo ung dung TaskManager de xem chi tiet.',
      '',
      'TaskManager'
    ].join('\n')
  });
}

// D3 - Gui email khi thong tin quan trong thay doi.
async function sendTaskUpdateEmail({
  to,
  taskTitle,
  changedDetails
}) {
  if (
    typeof taskTitle !== 'string' ||
    !taskTitle.trim()
  ) {
    throw new Error('Ten cong viec khong hop le');
  }

  if (
    !Array.isArray(changedDetails) ||
    changedDetails.length === 0 ||
    !changedDetails.every(
      detail =>
        typeof detail === 'string' && detail.trim()
    )
  ) {
    throw new Error('Danh sach thay doi khong hop le');
  }

  return sendTaskEmail({
    to,
    subject:
      'TaskManager - Cap nhat thong tin quan trong cua cong viec',
    text: [
      'Xin chao,',
      '',
      `Cong viec: ${taskTitle}`,
      '',
      'Thong tin vua thay doi:',
      ...changedDetails.map(detail => `- ${detail}`),
      '',
      'Vui long mo ung dung TaskManager de xem chi tiet.',
      '',
      'TaskManager'
    ].join('\n')
  });
}

// D4 - Gui email khi cong viec hoan thanh.
async function sendTaskCompletedEmail({ to, taskTitle }) {
  if (
    typeof taskTitle !== 'string' ||
    !taskTitle.trim()
  ) {
    throw new Error('Ten cong viec khong hop le');
  }

  return sendTaskEmail({
    to,
    subject: 'TaskManager - Cong viec da hoan thanh',
    text: [
      'Xin chao,',
      '',
      `Cong viec "${taskTitle}" da duoc danh dau hoan thanh.`,
      '',
      'Trang thai hien tai: Da hoan thanh.',
      'Vui long mo ung dung TaskManager de xem chi tiet.',
      '',
      'TaskManager'
    ].join('\n')
  });
}

// D5 - Gui email nhac cong viec truoc han hoan thanh.
async function sendTaskReminderEmail({
  to,
  taskTitle,
  dueDate,
  reminderHours = 24
}) {
  if (
    typeof taskTitle !== 'string' ||
    !taskTitle.trim()
  ) {
    throw new Error('Ten cong viec khong hop le');
  }

  const due = new Date(dueDate);

  if (Number.isNaN(due.getTime())) {
    throw new Error('Han hoan thanh khong hop le');
  }

  if (
    !Number.isFinite(reminderHours) ||
    reminderHours <= 0
  ) {
    throw new Error('So gio nhac khong hop le');
  }

  const dueText = due.toLocaleString('vi-VN', {
    timeZone: 'Asia/Ho_Chi_Minh',
    hour12: false
  });

  return sendTaskEmail({
    to,
    subject: 'TaskManager - Nhac viec sap den han',
    text: [
      'Xin chao,',
      '',
      `Cong viec: ${taskTitle}`,
      `Han hoan thanh: ${dueText}`,
      '',
      `Day la thong bao nhac viec trong khoang ${reminderHours} gio truoc han.`,
      '',
      'Vui long kiem tra tien do va hoan thanh cong viec dung han.',
      '',
      'TaskManager'
    ].join('\n')
  });
}

module.exports = {
  sendAssignmentEmail,
  sendShareInvitationEmail,
  sendTaskUpdateEmail,
  sendTaskCompletedEmail,
  sendTaskReminderEmail
};
