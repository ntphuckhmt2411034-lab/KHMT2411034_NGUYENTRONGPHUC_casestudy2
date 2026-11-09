const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

const Task = require('../models/Task');
const User = require('../models/User');
const { sendAssignmentEmail } = require('../services/emailService');
const EmailLog = require('../models/EmailLog');
const { createAssignmentNotification } = require('../services/notificationService');

const router = express.Router();

// =====================================================
// XAC THUC JWT - TUONG THICH MODULE A VA B
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
// C5 - XEM DANH SACH NGUOI DUOC GIAO
// GET /api/tasks/:id/assignees
// =====================================================
router.get('/:id/assignees', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    // Chi nguoi tao duoc xem day du danh sach thanh vien
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.userId
    })
      .select('assignedTo assigneeIds primaryAssigneeId')
      .lean();

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen'
      });
    }

    // Gop du lieu moi va du lieu cu Module B
    const ids = [
      ...new Set([
        ...(task.assigneeIds || []).map(value =>
          value.toString()
        ),
        ...(task.assignedTo
          ? [task.assignedTo.toString()]
          : [])
      ])
    ];

    const assignees = await User.find({
      _id: { $in: ids }
    })
      .select('_id fullName email')
      .lean();

    const primaryId = task.primaryAssigneeId
      ? task.primaryAssigneeId.toString()
      : null;

    // Nguoi phu trach chinh hien thi dau tien
    assignees.sort((a, b) => {
      if (a._id.toString() === primaryId) return -1;
      if (b._id.toString() === primaryId) return 1;

      return (a.fullName || '').localeCompare(
        b.fullName || ''
      );
    });

    return res.status(200).json({
      message: 'Lay danh sach nguoi duoc giao thanh cong',
      taskId: task._id,
      total: assignees.length,
      primaryAssigneeId: primaryId,
      assignees
    });
  } catch (error) {
    console.error(
      'Loi C5 lay danh sach nguoi duoc giao:',
      error.message
    );

    return res.status(500).json({
      message: 'Khong the lay danh sach nguoi duoc giao'
    });
  }
});

// =====================================================
// C1 + D1 - GIAO CONG VIEC VA GUI EMAIL
// POST /api/tasks/:id/assignees
// Body: { "assigneeIds": ["userId1", "userId2"] }
// =====================================================
router.post('/:id/assignees', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;
    const body = req.body;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    if (
      !body ||
      typeof body !== 'object' ||
      Array.isArray(body) ||
      Object.keys(body).length !== 1 ||
      !Array.isArray(body.assigneeIds) ||
      body.assigneeIds.length === 0 ||
      body.assigneeIds.length > 50
    ) {
      return res.status(400).json({
        message: 'Danh sach nguoi duoc giao khong hop le'
      });
    }

    const ids = body.assigneeIds;

    if (
      ids.some(
        id =>
          typeof id !== 'string' ||
          !mongoose.isValidObjectId(id)
      )
    ) {
      return res.status(400).json({
        message: 'Co ID nguoi dung khong hop le'
      });
    }

    const uniqueIds = [
      ...new Set(ids.map(id => id.toLowerCase()))
    ];

    if (uniqueIds.length !== ids.length) {
      return res.status(400).json({
        message: 'Danh sach co nguoi dung trung lap'
      });
    }

    if (uniqueIds.includes(req.userId.toLowerCase())) {
      return res.status(400).json({
        message: 'Khong the giao viec cho chinh minh'
      });
    }

    // Chi nguoi tao moi duoc giao viec
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen giao'
      });
    }

    // Kiem tra tat ca tai khoan nhan viec
    const users = await User.find({
      _id: { $in: uniqueIds }
    })
      .select('_id fullName email')
      .lean();

    if (users.length !== uniqueIds.length) {
      return res.status(400).json({
        message: 'Mot hoac nhieu tai khoan khong ton tai'
      });
    }

    // Giu lai danh sach duoc giao truoc do
    const existingIds = (task.assigneeIds || [])
      .map(id => id.toString().toLowerCase());

    // Tuong thich Module B
    if (task.assignedTo) {
      existingIds.push(
        task.assignedTo.toString().toLowerCase()
      );
    }

    // D1 - Xac dinh nguoi MOI duoc giao viec
    const existingIdSet = new Set(existingIds);

    const newAssignees = users.filter(user =>
      !existingIdSet.has(
        user._id.toString().toLowerCase()
      )
    );

    const mergedIds = [
      ...new Set([...existingIds, ...uniqueIds])
    ];

    task.assigneeIds = mergedIds;

    // Luu vao MongoDB truoc khi gui email
    await task.save();

    // D1 - Tao thong bao va luu lich su email cho nguoi moi duoc giao.
    // Loi thong bao/email khong duoc lam that bai viec giao cong viec.
    let emailsAccepted = 0;
    let emailsFailed = 0;

    if (newAssignees.length > 0) {
      const emailResults = await Promise.allSettled(
        newAssignees.map(async user => {
          try {
            await createAssignmentNotification({
              userId: user._id,
              task
            });
          } catch (notificationError) {
            console.error(
              'D1 - Khong luu duoc notification:',
              notificationError.message
            );
          }

          let emailLog = null;
          try {
            emailLog = await EmailLog.create({
              taskId: task._id,
              recipientEmail: user.email,
              eventType: 'task_assigned',
              subject: 'TaskManager - Ban duoc giao cong viec moi',
              status: 'pending',
              attempts: 1
            });
          } catch (logError) {
            console.error('D1 - Khong tao duoc EmailLog:', logError.message);
          }

          try {
            const result = await sendAssignmentEmail({
              to: user.email,
              taskTitle: task.title
            });

            // 'sent' o day la Brevo DA TIEP NHAN, khong phai delivered.
            if (emailLog) {
              try {
                emailLog.status = 'sent';
                emailLog.sentAt = new Date();
                emailLog.errorMessage = '';
                await emailLog.save();
              } catch (logError) {
                console.error('D1 - Khong cap nhat EmailLog sent:', logError.message);
              }
            }
            return result;
          } catch (sendError) {
            if (emailLog) {
              try {
                emailLog.status = 'failed';
                emailLog.errorMessage = String(
                  sendError.message || 'Gui email that bai'
                ).slice(0, 500);
                await emailLog.save();
              } catch (logError) {
                console.error('D1 - Khong cap nhat EmailLog failed:', logError.message);
              }
            }
            throw sendError;
          }
        })
      );

      emailResults.forEach(result => {
        if (result.status === 'fulfilled') {
          emailsAccepted += 1;
        } else {
          emailsFailed += 1;
          console.error(
            'D1 - Gui email that bai:',
            result.reason?.message || 'Unknown error'
          );
        }
      });

      console.log('D1 - Ket qua gui email:', {
        taskId: task._id.toString(),
        newAssignees: newAssignees.length,
        emailsAccepted,
        emailsFailed
      });
    }

    // Lay danh sach thanh vien sau khi giao viec
    const assignees = await User.find({
      _id: { $in: mergedIds }
    })
      .select('_id fullName email')
      .lean();

    return res.status(200).json({
      message: 'Giao cong viec thanh cong',
      taskId: task._id,
      total: assignees.length,
      assignees,
      email: {
        newAssignees: newAssignees.length,
        accepted: emailsAccepted,
        failed: emailsFailed
      }
    });
  } catch (error) {
    console.error('Loi giao cong viec:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu giao viec khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the giao cong viec'
    });
  }
});

// =====================================================
// C2 - CHI DINH NGUOI PHU TRACH CHINH
// PATCH /api/tasks/:id/assignees/:userId
// Body: { "isPrimary": true }
// =====================================================
router.patch('/:id/assignees/:userId', requireAuth, async (req, res) => {
  try {
    const { id, userId } = req.params;

    if (
      !mongoose.isValidObjectId(id) ||
      !mongoose.isValidObjectId(userId)
    ) {
      return res.status(400).json({
        message: 'ID cong viec hoac nguoi dung khong hop le'
      });
    }

    if (
      !req.body ||
      req.body.isPrimary !== true ||
      Object.keys(req.body).length !== 1
    ) {
      return res.status(400).json({
        message: 'Yeu cau isPrimary phai bang true'
      });
    }

    // Chi nguoi tao cong viec duoc chi dinh
    const task = await Task.findOne({
      _id: id,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen'
      });
    }

    const assignedIds = (task.assigneeIds || [])
      .map(value => value.toString().toLowerCase());

    // Tuong thich du lieu Module B
    if (task.assignedTo) {
      assignedIds.push(
        task.assignedTo.toString().toLowerCase()
      );
    }

    if (!assignedIds.includes(userId.toLowerCase())) {
      return res.status(400).json({
        message: 'Nguoi duoc chon chua duoc giao cong viec'
      });
    }

    const user = await User.findById(userId)
      .select('_id fullName email')
      .lean();

    if (!user) {
      return res.status(404).json({
        message: 'Nguoi dung khong ton tai'
      });
    }

    task.primaryAssigneeId = user._id;
    await task.save();

    return res.status(200).json({
      message: 'Chi dinh nguoi phu trach chinh thanh cong',
      taskId: task._id,
      primaryAssigneeId: task.primaryAssigneeId,
      primaryAssignee: user
    });
  } catch (error) {
    console.error('Loi C2:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu chi dinh khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the chi dinh nguoi phu trach chinh'
    });
  }
});

// =====================================================
// C6 - HUY GIAO VIEC CHO MOT THANH VIEN
// DELETE /api/tasks/:id/assignees/:userId
// =====================================================
router.delete('/:id/assignees/:userId', requireAuth, async (req, res) => {
  try {
    const { id, userId } = req.params;

    // 1. Kiem tra ID
    if (
      !mongoose.isValidObjectId(id) ||
      !mongoose.isValidObjectId(userId)
    ) {
      return res.status(400).json({
        message: 'ID cong viec hoac nguoi dung khong hop le'
      });
    }

    // 2. Chi nguoi tao cong viec moi duoc huy giao viec
    const task = await Task.findOne({
      _id: id,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen'
      });
    }

    const targetId = userId.toLowerCase();

    // 3. Gom danh sach duoc giao hien tai
    const currentIds = [
      ...(task.assigneeIds || []).map(value =>
        value.toString().toLowerCase()
      ),
      ...(task.assignedTo
        ? [task.assignedTo.toString().toLowerCase()]
        : [])
    ];

    const uniqueCurrentIds = [...new Set(currentIds)];

    // 4. Kiem tra thanh vien co duoc giao viec khong
    if (!uniqueCurrentIds.includes(targetId)) {
      return res.status(404).json({
        message: 'Nguoi dung chua duoc giao cong viec'
      });
    }

    // 5. Xoa thanh vien khoi danh sach
    const remainingIds = uniqueCurrentIds.filter(
      value => value !== targetId
    );

    task.assigneeIds = remainingIds;

    // 6. Xoa du lieu giao viec cu neu trung thanh vien
    if (
      task.assignedTo &&
      task.assignedTo.toString().toLowerCase() === targetId
    ) {
      task.assignedTo = null;
    }

    // 7. Neu la nguoi phu trach chinh, xoa vai tro chinh
    if (
      task.primaryAssigneeId &&
      task.primaryAssigneeId.toString().toLowerCase() === targetId
    ) {
      task.primaryAssigneeId = null;
    }

    // 8. Luu vao MongoDB
    await task.save();

    // 9. Tra ve ket qua
    return res.status(200).json({
      message: 'Huy giao viec thanh cong',
      taskId: task._id,
      removedUserId: userId,
      total: remainingIds.length,
      assigneeIds: task.assigneeIds,
      primaryAssigneeId: task.primaryAssigneeId
    });
  } catch (error) {
    console.error('Loi C6 huy giao viec:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu huy giao viec khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the huy giao viec'
    });
  }
});

module.exports = router;
