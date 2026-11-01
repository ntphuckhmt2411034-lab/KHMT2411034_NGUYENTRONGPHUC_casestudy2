const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: [true, 'Vui lòng nhập tên công việc'],
      trim: true,
    },

    description: {
      type: String,
      default: '',
      trim: true,
    },

    status: {
      type: String,
      enum: ['chua_thuc_hien', 'dang_thuc_hien', 'da_hoan_thanh'],
      default: 'chua_thuc_hien',
    },

    priority: {
      type: String,
      enum: ['thap', 'trung_binh', 'cao'],
      default: 'trung_binh',
    },

    startDate: {
      type: Date,
      default: null,
    },

    dueDate: {
      type: Date,
      default: null,
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },

    assignedTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },

    sharedWith: [{
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    }],
  },
  {
    timestamps: true,
  }
);

taskSchema.pre('validate', function () {
  if (this.startDate && this.dueDate && this.dueDate < this.startDate) {
    this.invalidate(
      'dueDate',
      'Hạn hoàn thành không được trước ngày bắt đầu'
    );
  }
});

module.exports = mongoose.model('Task', taskSchema);
