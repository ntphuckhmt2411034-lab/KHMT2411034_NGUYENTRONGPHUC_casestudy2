
const nodemailer = require('nodemailer');

// D1 - Gui email thong bao khi giao cong viec moi
async function sendAssignmentEmail({ to, taskTitle }) {
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

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: {
      user,
      pass
    },
    connectionTimeout: 15000,
    greetingTimeout: 15000,
    socketTimeout: 20000
  });

  const result = await transporter.sendMail({
    from: process.env.MAILTRAP_FROM || 'taskmanager@example.com',
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

  return result;
}

module.exports = {
  sendAssignmentEmail
};
