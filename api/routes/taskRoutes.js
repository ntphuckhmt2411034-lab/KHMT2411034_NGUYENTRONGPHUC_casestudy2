
const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');

// D3 - Thong bao khi thong tin quan trong thay doi.
const {
  notifyImportantTaskUpdate
} = require('../services/taskUpdateService');

// D4 - Thong bao khi cong viec hoan thanh.
const {
  notifyTaskCompleted
} = require('../services/taskCompletionService');

const router = express.Router();

// Xac thuc nguoi dung bang JWT
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
// D4 - Ham xu ly gui email khi cong viec hoan thanh
// Dung chung cho PUT va PATCH status.
// =====================================================
async function processTaskCompletion({
  task,
  previousStatus,
  actorId
}) {
  const d4 = {
    triggered: false,
    recipients: 0,
    accepted: 0,
    failed: 0
  };

  // Chi gui khi trang thai vua chuyen sang hoan thanh.
  if (
    previousStatus === 'da_hoan_thanh' ||
    task.status !== 'da_hoan_thanh'
  ) {
    console.log('D4 - Khong co chuyen trang thai sang hoan thanh');
    return d4;
  }

  try {
    const result = await notifyTaskCompleted({
      task,
      actorId
    });

    return {
      ...result,
      triggered: true
    };
  } catch (error) {
    console.error(
      'D4 - Loi xu ly thong bao hoan thanh:',
      error.message
    );

    return {
      ...d4,
      triggered: true,
      warning: 'notification_error'
    };
  }
}

// =====================================================
// B1 + C3 - Xem danh sach cong viec
// GET /api/tasks
// =====================================================
router.get('/', requireAuth, async (req, res) => {
  try {
    const userId = req.userId;

    // C3: Tim cac cong viec da chia se cho nguoi dang nhap
    const shares = await TaskShare.find({
      userId
    })
      .select('taskId permission')
      .lean();

    const sharedTaskIds = shares.map(share => share.taskId);

    const sharePermissions = new Map(
      shares.map(share => [
        share.taskId.toString(),
        share.permission
      ])
    );

    // Giu cac quyen xem cu va bo sung task_shares
    const tasks = await Task.find({
      $or: [
        { createdBy: userId },
        { assignedTo: userId },
        { assigneeIds: userId },
        { sharedWith: userId },
        { _id: { $in: sharedTaskIds } }
      ]
    })
      .sort({ createdAt: -1 })
      .lean();

    // C3: Tra thong tin quyen chia se de Flutter phan loai
    const resultTasks = tasks.map(task => ({
      ...task,
      sharePermission:
        sharePermissions.get(task._id.toString()) ?? null
    }));

    return res.status(200).json({
      message: 'Lay danh sach cong viec thanh cong',
      total: resultTasks.length,
      tasks: resultTasks
    });

  } catch (error) {
    console.error('Loi lay danh sach:', error.message);

    return res.status(500).json({
      message: 'Khong the lay danh sach cong viec'
    });
  }
});

// =====================================================
// B2.1 + C3 - Xem chi tiet cong viec
// GET /api/tasks/:id
// =====================================================
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    // C3: Kiem tra nguoi dang nhap co duoc chia se khong
    const share = await TaskShare.findOne({
      taskId,
      userId: req.userId
    })
      .select('permission')
      .lean();

    const accessConditions = {
      _id: taskId
    };

    if (!share) {
      accessConditions.$or = [
        { createdBy: req.userId },
        { assignedTo: req.userId },
        { assigneeIds: req.userId },
        { sharedWith: req.userId }
      ];
    }

    const task = await Task.findOne(accessConditions).lean();

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen truy cap'
      });
    }

    return res.status(200).json({
      message: 'Lay chi tiet cong viec thanh cong',
      task: {
        ...task,
        sharePermission: share?.permission ?? null
      }
    });

  } catch (error) {
    console.error('Loi xem chi tiet cong viec:', error.message);

    return res.status(500).json({
      message: 'Khong the lay chi tiet cong viec'
    });
  }
});

// =====================================================
// B2.2 - Tao cong viec moi
// POST /api/tasks
// =====================================================
router.post('/', requireAuth, async (req, res) => {
  try {
    const {
      title,
      description,
      status,
      priority,
      startDate,
      dueDate
    } = req.body || {};

    if (typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({
        message: 'Vui long nhap ten cong viec'
      });
    }

    if (
      description !== undefined &&
      typeof description !== 'string'
    ) {
      return res.status(400).json({
        message: 'Mo ta khong hop le'
      });
    }

    const validStatuses = [
      'chua_thuc_hien',
      'dang_thuc_hien',
      'da_hoan_thanh'
    ];

    if (
      status !== undefined &&
      !validStatuses.includes(status)
    ) {
      return res.status(400).json({
        message: 'Trang thai khong hop le'
      });
    }

    const validPriorities = [
      'thap',
      'trung_binh',
      'cao'
    ];

    if (
      priority !== undefined &&
      !validPriorities.includes(priority)
    ) {
      return res.status(400).json({
        message: 'Do uu tien khong hop le'
      });
    }

    function parseDate(value) {
      if (
        value === undefined ||
        value === null ||
        value === ''
      ) {
        return null;
      }

      if (typeof value !== 'string') {
        return new Date(NaN);
      }

      return new Date(value);
    }

    const parsedStartDate = parseDate(startDate);
    const parsedDueDate = parseDate(dueDate);

    if (
      (parsedStartDate &&
        Number.isNaN(parsedStartDate.getTime())) ||
      (parsedDueDate &&
        Number.isNaN(parsedDueDate.getTime()))
    ) {
      return res.status(400).json({
        message: 'Ngay thang khong hop le'
      });
    }

    if (
      parsedStartDate &&
      parsedDueDate &&
      parsedDueDate < parsedStartDate
    ) {
      return res.status(400).json({
        message: 'Han hoan thanh khong duoc truoc ngay bat dau'
      });
    }

    const task = await Task.create({
      title: title.trim(),
      description: description ?? '',
      status: status ?? 'chua_thuc_hien',
      priority: priority ?? 'trung_binh',
      startDate: parsedStartDate,
      dueDate: parsedDueDate,
      createdBy: req.userId
    });

    return res.status(201).json({
      message: 'Tao cong viec thanh cong',
      task
    });

  } catch (error) {
    console.error('Loi tao cong viec:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu cong viec khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the tao cong viec'
    });
  }
});

/**
 * B2.3 + D3 + D4 - Chinh sua cong viec
 * PUT /api/tasks/:id
 */
router.put('/:id', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    // C4: Nguoi tao hoac editor duoc sua.
    const task = await Task.findById(taskId);

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec'
      });
    }

    const isCreator = task.createdBy.toString() === req.userId;

    if (!isCreator) {
      const editorShare = await TaskShare.findOne({
        taskId: task._id,
        userId: req.userId,
        permission: 'editor'
      });

      if (!editorShare) {
        return res.status(403).json({
          message: 'Ban khong co quyen chinh sua cong viec'
        });
      }
    }

    // D3 - Luu cac gia tri quan trong truoc khi sua.
    const previousImportant = {
      title: task.title,
      description: task.description || '',
      priority: task.priority,
      dueDate: task.dueDate
        ? task.dueDate.toISOString()
        : null,
      startDate: task.startDate
        ? task.startDate.toISOString()
        : null
    };

    // D4 - Luu trang thai cu truoc khi cap nhat.
    const previousStatus = task.status;

    const body = req.body;

    if (
      !body ||
      typeof body !== 'object' ||
      Array.isArray(body)
    ) {
      return res.status(400).json({
        message: 'Du lieu cap nhat khong hop le'
      });
    }

    const allowedFields = [
      'title',
      'description',
      'status',
      'priority',
      'startDate',
      'dueDate'
    ];

    const fields = Object.keys(body);

    if (
      fields.length === 0 ||
      fields.some(field => !allowedFields.includes(field))
    ) {
      return res.status(400).json({
        message: 'Truong cap nhat khong hop le'
      });
    }

    if (body.title !== undefined) {
      if (
        typeof body.title !== 'string' ||
        !body.title.trim()
      ) {
        return res.status(400).json({
          message: 'Ten cong viec khong hop le'
        });
      }

      task.title = body.title.trim();
    }

    if (body.description !== undefined) {
      if (typeof body.description !== 'string') {
        return res.status(400).json({
          message: 'Mo ta khong hop le'
        });
      }

      task.description = body.description;
    }

    if (body.status !== undefined) {
      const validStatuses = [
        'chua_thuc_hien',
        'dang_thuc_hien',
        'da_hoan_thanh'
      ];

      if (!validStatuses.includes(body.status)) {
        return res.status(400).json({
          message: 'Trang thai khong hop le'
        });
      }

      task.status = body.status;
    }

    if (body.priority !== undefined) {
      const validPriorities = [
        'thap',
        'trung_binh',
        'cao'
      ];

      if (!validPriorities.includes(body.priority)) {
        return res.status(400).json({
          message: 'Do uu tien khong hop le'
        });
      }

      task.priority = body.priority;
    }

    function parseDate(value) {
      if (value === null || value === '') {
        return null;
      }

      if (typeof value !== 'string') {
        return new Date(NaN);
      }

      return new Date(value);
    }

    if (body.startDate !== undefined) {
      const date = parseDate(body.startDate);

      if (date && Number.isNaN(date.getTime())) {
        return res.status(400).json({
          message: 'Ngay bat dau khong hop le'
        });
      }

      task.startDate = date;
    }

    if (body.dueDate !== undefined) {
      const date = parseDate(body.dueDate);

      if (date && Number.isNaN(date.getTime())) {
        return res.status(400).json({
          message: 'Han hoan thanh khong hop le'
        });
      }

      task.dueDate = date;
    }

    if (
      task.startDate &&
      task.dueDate &&
      task.dueDate < task.startDate
    ) {
      return res.status(400).json({
        message: 'Han hoan thanh khong duoc truoc ngay bat dau'
      });
    }

    // Luu cong viec truoc khi gui thong bao.
    await task.save();

    // =================================================
    // D3 - Thong bao khi thong tin quan trong thay doi
    // =================================================
    let d3 = {
      changed: [],
      recipients: 0,
      accepted: 0,
      failed: 0
    };

    try {
      d3 = await notifyImportantTaskUpdate({
        task,
        oldValues: previousImportant,
        actorId: req.userId
      });
    } catch (d3Error) {
      console.error(
        'D3 - Loi xu ly thong bao:',
        d3Error.message
      );

      d3 = {
        changed: [],
        recipients: 0,
        accepted: 0,
        failed: 0,
        warning: 'notification_error'
      };
    }

    // =================================================
    // D4 - Thong bao khi cong viec chuyen sang hoan thanh
    // =================================================
    const d4 = await processTaskCompletion({
      task,
      previousStatus,
      actorId: req.userId
    });

    return res.status(200).json({
      message: 'Cap nhat cong viec thanh cong',
      task,
      d3,
      d4
    });

  } catch (error) {
    console.error('Loi cap nhat cong viec:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu cap nhat khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the cap nhat cong viec'
    });
  }
});

/**
 * B2.4 - Xoa cong viec
 * DELETE /api/tasks/:id
 */
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const taskId = req.params.id;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID cong viec khong hop le'
      });
    }

    const task = await Task.findOneAndDelete({
      _id: taskId,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec hoac khong co quyen xoa'
      });
    }

    return res.status(200).json({
      message: 'Xoa cong viec thanh cong',
      taskId: task._id
    });

  } catch (error) {
    console.error('Loi xoa cong viec:', error.message);

    return res.status(500).json({
      message: 'Khong the xoa cong viec'
    });
  }
});

/**
 * B3 + D4 - Cap nhat trang thai cong viec
 * PATCH /api/tasks/:id/status
 */
router.patch('/:id/status', requireAuth, async (req, res) => {
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
      !Object.prototype.hasOwnProperty.call(body, 'status')
    ) {
      return res.status(400).json({
        message: 'Chi duoc cap nhat truong status'
      });
    }

    const validStatuses = [
      'chua_thuc_hien',
      'dang_thuc_hien',
      'da_hoan_thanh'
    ];

    if (!validStatuses.includes(body.status)) {
      return res.status(400).json({
        message: 'Trang thai cong viec khong hop le'
      });
    }

    // C3 viewer khong duoc doi trang thai
    // C4: Chi nguoi tao hoac editor duoc cap nhat.
    const task = await Task.findById(taskId);

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec'
      });
    }

    const isCreator = task.createdBy.toString() === req.userId;

    if (!isCreator) {
      const editorShare = await TaskShare.findOne({
        taskId: task._id,
        userId: req.userId,
        permission: 'editor'
      });

      if (!editorShare) {
        return res.status(403).json({
          message: 'Ban khong co quyen cap nhat cong viec'
        });
      }
    }

    // D4 - Ghi nho trang thai truoc khi cap nhat.
    const previousStatus = task.status;

    task.status = body.status;
    await task.save();

    // D4 - Gui thong bao neu vua hoan thanh.
    const d4 = await processTaskCompletion({
      task,
      previousStatus,
      actorId: req.userId
    });

    return res.status(200).json({
      message: 'Cap nhat trang thai thanh cong',
      task,
      d4
    });

  } catch (error) {
    console.error('Loi cap nhat trang thai:', error.message);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu cong viec khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the cap nhat trang thai'
    });
  }
});

/**
 * B4 - Cap nhat do uu tien cong viec
 * PATCH /api/tasks/:id/priority
 */
router.patch('/:id/priority', requireAuth, async (req, res) => {
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
      !Object.prototype.hasOwnProperty.call(body, 'priority')
    ) {
      return res.status(400).json({
        message: 'Chi duoc cap nhat truong priority'
      });
    }

    const validPriorities = ['thap', 'trung_binh', 'cao'];

    if (!validPriorities.includes(body.priority)) {
      return res.status(400).json({
        message: 'Do uu tien khong hop le'
      });
    }

    // C4: Chi nguoi tao hoac editor duoc cap nhat.
    const task = await Task.findById(taskId);

    if (!task) {
      return res.status(404).json({
        message: 'Khong tim thay cong viec'
      });
    }

    const isCreator = task.createdBy.toString() === req.userId;

    if (!isCreator) {
      const editorShare = await TaskShare.findOne({
        taskId: task._id,
        userId: req.userId,
        permission: 'editor'
      });

      if (!editorShare) {
        return res.status(403).json({
          message: 'Ban khong co quyen cap nhat cong viec'
        });
      }
    }

    const oldPriority = task.priority;

    task.priority = body.priority;
    await task.save();

    // D3 - Thong bao khi do uu tien thay doi.
    let d3 = {
      changed: [],
      recipients: 0,
      accepted: 0,
      failed: 0
    };

    if (oldPriority !== task.priority) {
      try {
        d3 = await notifyImportantTaskUpdate({
          task,
          oldValues: {
            priority: oldPriority
          },
          actorId: req.userId
        });
      } catch (d3Error) {
        console.error(
          'D3 - Loi thong bao thay doi uu tien:',
          d3Error.message
        );

        d3 = {
          changed: ['priority'],
          recipients: 0,
          accepted: 0,
          failed: 0,
          warning: 'notification_error'
        };
      }
    }

    return res.status(200).json({
      message: 'Cap nhat do uu tien thanh cong',
      task,
      d3
    });

  } catch (error) {
    console.error(
      'Loi cap nhat do uu tien:',
      error.message
    );

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: 'Du lieu cong viec khong hop le'
      });
    }

    return res.status(500).json({
      message: 'Khong the cap nhat do uu tien'
    });
  }
});

module.exports = router;
