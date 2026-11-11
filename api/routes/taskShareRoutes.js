const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

const Task = require('../models/Task');
const User = require('../models/User');
const TaskShare = require('../models/TaskShare');
const EmailLog = require('../models/EmailLog');
const { sendShareInvitationEmail } = require('../services/emailService');
const { createShareNotification } = require('../services/notificationService');
const { logTaskActivity } = require('../services/taskActivityService');

const router = express.Router();

// =====================================================
// XAC THUC JWT - MODULE A, B VA C
// =====================================================
function requireAuth(req, res, next) {
  const authorization = req.headers.authorization || '';
  const match = /^Bearer\s+(\S+)$/i.exec(authorization);

  if (!match) {
    return res.status(401).json({
      message: 'Vui long dang nhap'
    });
  }

  try {
    if (!process.env.JWT_SECRET) {
      return res.status(500).json({
        message: 'Server chua cau hinh JWT'
      });
    }

    const decoded = jwt.verify(
      match[1],
      process.env.JWT_SECRET,
      { algorithms: ['HS256'] }
    );

    if (
      !decoded ||
      typeof decoded.userId !== 'string' ||
      !mongoose.isValidObjectId(decoded.userId)
    ) {
      return res.status(401).json({
        message: 'Token khong hop le'
      });
    }

    req.userId = decoded.userId;
    next();
  } catch (error) {
    return res.status(401).json({
      message: 'Token khong hop le hoac het han'
    });
  }
}

// =====================================================
// C3 + D2 - CHIA SE CONG VIEC CHO MOT HOAC NHIEU NGUOI
// POST /api/tasks/:id/shares
// Body: { "userIds": ["id1", "id2"] }
// =====================================================
router.post('/:id/shares', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    const body = req.body;

    if (
      !body ||
      typeof body !== 'object' ||
      Array.isArray(body) ||
      Object.keys(body).length !== 1 ||
      !Array.isArray(body.userIds) ||
      body.userIds.length === 0 ||
      body.userIds.length > 50
    ) {
      return res.status(400).json({
        message: 'userIds phai la danh sach tu 1 den 50 tai khoan'
      });
    }

    const userIds = body.userIds;

    if (
      !userIds.every(
        id =>
          typeof id === 'string' &&
          mongoose.isValidObjectId(id)
      )
    ) {
      return res.status(400).json({
        message: 'Danh sach ID nguoi dung khong hop le'
      });
    }

    const uniqueIds = [
      ...new Set(userIds.map(id => id.toLowerCase()))
    ];

    // Khong cho phep chia se cho chinh nguoi tao
    if (uniqueIds.includes(req.userId.toLowerCase())) {
      return res.status(400).json({
        message: 'Khong can chia se cong viec cho nguoi tao'
      });
    }

    // Chi nguoi tao cong viec duoc chia se
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen chia se'
      });
    }

    // Kiem tra tat ca tai khoan ton tai
    const users = await User.find({
      _id: { $in: uniqueIds }
    })
      .select('_id fullName email')
      .lean();

    if (users.length !== uniqueIds.length) {
      return res.status(400).json({
        message: 'Co tai khoan khong ton tai trong he thong'
      });
    }

    let added = 0;
    let alreadyShared = 0;
    const newSharedIds = new Set();

    for (const userId of uniqueIds) {
      try {
        const result = await TaskShare.updateOne(
          { taskId: task._id, userId },
          {
            $setOnInsert: {
              taskId: task._id,
              userId,
              permission: 'viewer',
              sharedBy: req.userId
            }
          },
          { upsert: true }
        );

        if (result.upsertedCount > 0) {
          added++;
          newSharedIds.add(userId);
        } else {
          alreadyShared++;
        }
      } catch (error) {
        if (error.code === 11000) {
          alreadyShared++;
        } else {
          throw error;
        }
      }
    }

    // E4 - Ghi lich su chia se cong viec
    if (newSharedIds.size > 0) {
      await logTaskActivity({
        taskId: task._id,
        userId: req.userId,
        action: 'shared',
        details: {
          sharedWith: [...newSharedIds]
        }
      });
    }

    // Khong thay doi du lieu giao viec cua C1, C2
    const shares = await TaskShare.find({
      taskId: task._id,
      userId: { $in: uniqueIds }
    })
      .populate('userId', '_id fullName email')
      .select('taskId userId permission sharedBy createdAt')
      .lean();

    // D2: Chi xu ly thong bao/email cho nhung user moi duoc chia se.
    // Loi email khong duoc lam that bai nghiep vu C3 da luu vao MongoDB.
    const newUsers = users.filter(user => newSharedIds.has(String(user._id)));
    const emailResults = await Promise.allSettled(newUsers.map(async user => {
      const recipientEmail = user.email;
      const subject = 'TaskManager - Loi moi chia se cong viec';

      try {
        await createShareNotification({
          userId: user._id,
          task,
          permission: 'viewer'
        });
      } catch (notificationError) {
        console.error('D2 - Khong tao duoc Notification:', notificationError.message);
      }

      let emailLog = null;
      try {
        emailLog = await EmailLog.create({
          taskId: task._id,
          recipientEmail,
          eventType: 'task_shared',
          subject,
          status: 'pending',
          attempts: 1
        });
      } catch (logError) {
        console.error('D2 - Khong tao duoc EmailLog:', logError.message);
      }

      try {
        await sendShareInvitationEmail({
          to: recipientEmail,
          taskTitle: task.title,
          permission: 'viewer'
        });

        if (emailLog) {
          try {
            emailLog.status = 'sent';
            emailLog.sentAt = new Date();
            emailLog.errorMessage = '';
            await emailLog.save();
          } catch (logError) {
            console.error('D2 - Khong cap nhat EmailLog sent:', logError.message);
          }
        }
        return { accepted: true };
      } catch (emailError) {
        console.error('D2 - Gui email that bai:', emailError.message);
        if (emailLog) {
          try {
            emailLog.status = 'failed';
            emailLog.errorMessage = String(emailError.message).slice(0, 500);
            await emailLog.save();
          } catch (logError) {
            console.error('D2 - Khong cap nhat EmailLog failed:', logError.message);
          }
        }
        return { accepted: false };
      }
    }));

    const emailsAccepted = emailResults.filter(
      result => result.status === 'fulfilled' && result.value.accepted
    ).length;
    const emailsFailed = newUsers.length - emailsAccepted;
    console.log('D2 - Ket qua gui email:', {
      taskId: String(task._id),
      newShares: newUsers.length,
      emailsAccepted,
      emailsFailed
    });

    return res.status(200).json({
      message: 'Chia se cong viec thanh cong',
      taskId: task._id,
      added,
      alreadyShared,
      total: shares.length,
      shares,
      email: {
        newShares: newUsers.length,
        accepted: emailsAccepted,
        failed: emailsFailed
      }
    });
  } catch (error) {
    console.error('Loi C3 chia se cong viec:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu chia se khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the chia se cong viec'
    });
  }
});

// =====================================================
// C4 - CAP NHAT QUYEN VIEWER / EDITOR
// PATCH /api/tasks/:id/shares/:userId/permission
// Body: { "permission": "viewer" | "editor" }
// =====================================================
router.patch('/:id/shares/:userId/permission', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;
    const targetUserId = req.params.userId;
    const permission = req.body?.permission;

    if (
      !mongoose.isValidObjectId(taskId) ||
      !mongoose.isValidObjectId(targetUserId)
    ) {
      return res.status(400).json({
        message: 'ID khong hop le'
      });
    }

    if (
      !req.body ||
      typeof req.body !== 'object' ||
      Array.isArray(req.body) ||
      Object.keys(req.body).length !== 1 ||
      !['viewer', 'editor'].includes(permission)
    ) {
      return res.status(400).json({
        message: 'Quyen phai la viewer hoac editor'
      });
    }

    // Chi nguoi tao moi duoc thay doi quyen
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen'
      });
    }

    const share = await TaskShare.findOne({
      taskId: task._id,
      userId: targetUserId
    });

    if (!share) {
      return res.status(404).json({
        message: 'Nguoi dung chua duoc chia se cong viec'
      });
    }

    const oldPermission = share.permission;

    share.permission = permission;
    await share.save();

    // E4 - Ghi lich su thay doi quyen chia se
    if (oldPermission !== share.permission) {
      await logTaskActivity({
        taskId: task._id,
        userId: req.userId,
        action: 'share_permission_changed',
        details: {
          targetUserId,
          oldPermission,
          newPermission: share.permission
        }
      });
    }

return res.status(200).json({
      message: 'Cap nhat quyen thanh cong',
      taskId: task._id,
      userId: targetUserId,
      permission: share.permission
    });
  } catch (error) {
    console.error('Loi C4 cap nhat quyen:', error.message);

    return res.status(500).json({
      message: 'Khong the cap nhat quyen chia se'
    });
  }
});

// =====================================================
// C4 / C5 - LAY DANH SACH NGUOI DUOC CHIA SE
// GET /api/tasks/:id/shares
// =====================================================
router.get('/:id/shares', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    // Chi nguoi tao duoc xem danh sach quan ly quyen
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen'
      });
    }

    const shares = await TaskShare.find({
      taskId: task._id
    })
      .populate('userId', '_id fullName email')
      .select('taskId userId permission sharedBy createdAt')
      .sort({ createdAt: -1 })
      .lean();

    return res.status(200).json({
      message: 'Lay danh sach chia se thanh cong',
      taskId: task._id,
      total: shares.length,
      shares
    });
  } catch (error) {
    console.error('Loi lay danh sach chia se:', error.message);

    return res.status(500).json({
      message: 'Khong the lay danh sach chia se'
    });
  }
});

// =====================================================
// C6 - THU HOI QUYEN CHIA SE CONG VIEC
// DELETE /api/tasks/:id/shares/:userId
// Chi nguoi tao cong viec duoc thu hoi quyen
// =====================================================
router.delete('/:id/shares/:userId', requireAuth, async (req, res) => {
  try {
    const { id, userId } = req.params;

    // 1. Kiem tra ID cong viec va nguoi dung
    if (
      !mongoose.isValidObjectId(id) ||
      !mongoose.isValidObjectId(userId)
    ) {
      return res.status(400).json({
        message: 'ID cong viec hoac nguoi dung khong hop le'
      });
    }

    // 2. Chi nguoi tao cong viec moi duoc thu hoi
    const task = await Task.findOne({
      _id: id,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen'
      });
    }

    // 3. Tim va xoa ban ghi chia se
    const removedShare = await TaskShare.findOneAndDelete({
      taskId: task._id,
      userId
    });

    if (!removedShare) {
      return res.status(404).json({
        message: 'Nguoi dung chua duoc chia se cong viec'
      });
    }

    // E4 - Ghi lich su thu hoi quyen chia se
    await logTaskActivity({
      taskId: task._id,
      userId: req.userId,
      action: 'share_revoked',
      details: {
        removedUserId: userId,
        previousPermission: removedShare.permission
      }
    });

    // 4. Tra ve thong bao thanh cong
    return res.status(200).json({
      message: 'Thu hoi quyen chia se thanh cong',
      taskId: task._id,
      removedUserId: userId,
      previousPermission: removedShare.permission
    });
  } catch (error) {
    console.error('Loi C6 thu hoi quyen:', error.message);

    return res.status(500).json({
      message: 'Khong the thu hoi quyen chia se'
    });
  }
});

module.exports = router;




