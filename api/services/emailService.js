const nodemailer = require('nodemailer');

// Gui email qua Mailtrap SMTP. Dung chung cho D1 va D2.
async function sendTaskEmail({ to, subject, text }) {
  const host = process.env.MAILTRAP_HOST;
  const port = Number(process.env.MAILTRAP_PORT || 2525);
  const user = process.env.MAILTRAP_USER;
  const pass = process.env.MAILTRAP_PASS;

  if (!host || !user || !pass) {
    throw new Error('Chua cau hinh Mailtrap SMTP trong .env');
  }

  if (typeof to !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to)) {
    throw new Error('Email nguoi nhan khong hop le');
  }

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
    connectionTimeout: 15000,
    greetingTimeout: 15000,
    socketTimeout: 20000
  });

  const result = await transporter.sendMail({
    from: process.env.MAILTRAP_FROM || 'taskmanager@example.com',
    to,
    subject,
    text
  });

  // Bao ve khong danh dau sent neu SMTP khong chap nhan nguoi nhan.
  if (!Array.isArray(result.accepted) || result.accepted.length === 0) {
    throw new Error('SMTP khong chap nhan nguoi nhan email');
  }

  return result;
}

// D1 - Giu nguyen giao dien ham de assignmentRoutes.js tiep tuc hoat dong.
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

// D2 - Email loi moi chia se cong viec (quyen viewer mac dinh cua C3).
async function sendShareInvitationEmail({ to, taskTitle, permission = 'viewer' }) {
  const role = permission === 'editor' ? 'chinh sua' : 'xem';
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


// D3 - Gui email khi han hoan thanh hoac thong tin quan trong thay doi.
async function sendTaskUpdateEmail({ to, taskTitle, changedDetails }) {
  if (typeof taskTitle !== 'string' || !taskTitle.trim()) {
    throw new Error('Ten cong viec khong hop le');
  }
  if (!Array.isArray(changedDetails) || changedDetails.length === 0 ||
      !changedDetails.every(detail => typeof detail === 'string' && detail.trim())) {
    throw new Error('Danh sach thay doi khong hop le');
  }
  return sendTaskEmail({
    to,
    subject: 'TaskManager - Cap nhat thong tin quan trong cua cong viec',
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

module.exports = {
  sendAssignmentEmail,
  sendShareInvitationEmail,
  sendTaskUpdateEmail
};
