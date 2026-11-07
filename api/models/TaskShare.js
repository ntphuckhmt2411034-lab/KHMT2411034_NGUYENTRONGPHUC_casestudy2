
const mongoose = require('mongoose');

// C3 - Luu thong tin chia se cong viec
const taskShareSchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      required: true,
      index: true
    },

    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true
    },

    // C3 mac dinh chi xem.
    // C4 se bo sung cap quyen editor.
    permission: {
      type: String,
      enum: ['viewer', 'editor'],
      default: 'viewer',
      required: true
    },

    sharedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    }
  },
  {
    timestamps: true,
    collection: 'task_shares'
  }
);

// Moi tai khoan chi co mot ban ghi chia se
// tren moi cong viec.
taskShareSchema.index(
  { taskId: 1, userId: 1 },
  { unique: true }
);

module.exports = mongoose.model('TaskShare', taskShareSchema);
