
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

const Task = require('../models/Task');
const User = require('../models/User');
const TaskShare = require('../models/TaskShare');

const router = express.Router();

// Xac thuc JWT - tuong thich Module A, B, C1 va C2
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
// C3 - Chia se cong viec cho mot hoac nhieu nguoi
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
        id => typeof id === 'string' &&
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

    // Khong cho phep chia se cho chinh minh
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

    // Dam bao tat ca tai khoan deu ton tai
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
        } else {
          alreadyShared++;
        }
      } catch (error) {
        // Hai yeu cau dong thoi co the cung tao
        // ban ghi. Unique index ngan chia se trung.
        if (error.code === 11000) {
          alreadyShared++;
        } else {
          throw error;
        }
      }
    }

    // Khong thay doi assigneeIds,
    // primaryAssigneeId hoac assignedTo cua C1/C2.

    const shares = await TaskShare.find({
      taskId: task._id,
      userId: { $in: uniqueIds }
    })
      .populate('userId', '_id fullName email')
      .select('taskId userId permission sharedBy createdAt')
      .lean();

    return res.status(200).json({
      message: 'Chia se cong viec thanh cong',
      taskId: task._id,
      added,
      alreadyShared,
      total: shares.length,
      shares
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
// C4 - Cap nhat quyen viewer / editor
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

    // Chi nguoi tao cong viec moi duoc cap quyen.
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen'
      });
    }

    // Chi cap nhat nguoi da duoc chia se.
    const share = await TaskShare.findOneAndUpdate(
      {
        taskId: task._id,
        userId: targetUserId
      },
      {
        $set: { permission }
      },
      {
        new: true,
        runValidators: true
      }
    );

    if (!share) {
      return res.status(404).json({
        message: 'Nguoi dung chua duoc chia se cong viec'
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
// C4 - Lay danh sach nguoi duoc chia se
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

    // Chi nguoi tao duoc xem danh sach quan ly quyen.
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
module.exports = router;
