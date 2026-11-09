
'use strict';

const mongoose = require('mongoose');

const taskReminderSchema = new mongoose.Schema({
  taskId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Task',
    required: true,
    index: true
  },

  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },

  // Han hoan thanh tai thoi diem gui nhac.
  dueDate: {
    type: Date,
    required: true
  },

  // Nhac truoc bao nhieu gio, mac dinh 24 gio.
  reminderHours: {
    type: Number,
    required: true,
    default: 24,
    min: 1
  },

  status: {
    type: String,
    enum: ['pending', 'sent', 'failed'],
    default: 'pending'
  },

  attempts: {
    type: Number,
    default: 0
  },

  sentAt: {
    type: Date,
    default: null
  },

  errorMessage: {
    type: String,
    default: ''
  }
}, {
  timestamps: true
});

// Moi nguoi chi co mot ban ghi nhac cho tung han va moc gio.
taskReminderSchema.index(
  {
    taskId: 1,
    userId: 1,
    dueDate: 1,
    reminderHours: 1
  },
  {
    unique: true,
    name: 'D5_unique_task_user_due_reminder'
  }
);

module.exports = mongoose.models.TaskReminder ||
  mongoose.model('TaskReminder', taskReminderSchema);
