'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');

test('D5: failed -> sent -> khong gui trung', async () => {
  const taskId = '6af20046438f5533e05dbe0f';
  const userId = '6af0117a9f38dac360de1e50';

  const task = {
    _id: taskId,
    title: 'D5 MOCK TEST',
    status: 'chua_thuc_hien',
    createdBy: userId,
    assigneeIds: [],
    sharedWith: [],
    dueDate: new Date(Date.now() + 60 * 60 * 1000)
  };

  const user = {
    _id: userId,
    email: 'mock@example.test'
  };

  let reminder = null;
  let emailLog = null;
  let sendCount = 0;
  let notificationCount = 0;

  function makeRecord(data) {
    return {
      ...data,
      async save() {
        return this;
      }
    };
  }

  const fakeTask = {
    find() {
      return {
        sort() {
          return {
            async limit() {
              return [task];
            }
          };
        }
      };
    },

    findById() {
      return {
        select() {
          return {
            async lean() {
              return task;
            }
          };
        }
      };
    }
  };

  const fakeShare = {
    find() {
      return {
        select() {
          return {
            async lean() {
              return [];
            }
          };
        }
      };
    }
  };

  const fakeUser = {
    find() {
      return {
        select() {
          return {
            async lean() {
              return [user];
            }
          };
        }
      };
    }
  };

  const fakeReminder = {
    async create(data) {
      if (reminder) {
        const error = new Error('Duplicate reminder');
        error.code = 11000;
        throw error;
      }

      reminder = makeRecord({
        ...data,
        createdAt: new Date(),
        errorMessage: ''
      });

      return reminder;
    },

    async findOneAndUpdate() {
      if (
        reminder &&
        reminder.status === 'failed' &&
        reminder.attempts < 6
      ) {
        reminder.status = 'pending';
        reminder.errorMessage = '';
        return reminder;
      }

      return null;
    }
  };

  const fakeEmailLog = {
    findOne() {
      return {
        async sort() {
          return emailLog;
        }
      };
    },

    async create(data) {
      emailLog = makeRecord({
        ...data,
        createdAt: new Date(),
        sentAt: null,
        errorMessage: ''
      });

      return emailLog;
    }
  };

  const fakeEmailService = {
    async sendTaskReminderEmail() {
      sendCount++;

      if (sendCount === 1) {
        throw new Error('SIMULATED_SMTP_FAILURE');
      }

      return { accepted: [user.email] };
    }
  };

  const fakeNotificationService = {
    async createNotification() {
      notificationCount++;
      return { success: true };
    }
  };

  const mocks = {
    '../models/Task': fakeTask,
    '../models/TaskShare': fakeShare,
    '../models/TaskReminder': fakeReminder,
    '../models/User': fakeUser,
    '../models/EmailLog': fakeEmailLog,
    './emailService': fakeEmailService,
    './notificationService': fakeNotificationService
  };

  const servicePath = require.resolve(
    '../services/taskReminderService'
  );

  const originalLoad = Module._load;

  try {
    delete require.cache[servicePath];

    Module._load = function(request, parent, isMain) {
      if (
        parent &&
        parent.filename === servicePath &&
        Object.prototype.hasOwnProperty.call(mocks, request)
      ) {
        return mocks[request];
      }

      return originalLoad.apply(this, arguments);
    };

    const { sweepTaskReminders } = require(servicePath);

    // Lan 1: SMTP gia lap bi loi.
    const first = await sweepTaskReminders();

    assert.equal(first.created, 1);
    assert.equal(first.failed, 1);
    assert.equal(reminder.status, 'failed');
    assert.equal(emailLog.status, 'failed');
    assert.equal(sendCount, 1);
    assert.equal(notificationCount, 1);

    // Lan 2: Nhan lai reminder failed va gui thanh cong.
    const second = await sweepTaskReminders();

    assert.equal(second.retried, 1);
    assert.equal(second.sent, 1);
    assert.equal(second.failed, 0);
    assert.equal(reminder.status, 'sent');
    assert.equal(emailLog.status, 'sent');
    assert.equal(reminder.attempts, 2);
    assert.equal(sendCount, 2);
    assert.equal(notificationCount, 1);

    // Lan 3: Da sent thi khong duoc gui lai.
    const third = await sweepTaskReminders();

    assert.equal(third.sent, 0);
    assert.equal(third.skipped, 1);
    assert.equal(sendCount, 2);
    assert.equal(notificationCount, 1);

    console.log('D5 RETRY TEST: PASS');
    console.log('D5 DUPLICATE PREVENTION: PASS');
    console.log('D5 NOTIFICATION DEDUP: PASS');
  } finally {
    Module._load = originalLoad;
    delete require.cache[servicePath];
  }
});
