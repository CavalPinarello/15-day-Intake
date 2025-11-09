const express = require('express');
const { getDatabase } = require('../database/init');

const router = express.Router();

function dbAll(db, sql, params = []) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) {
        reject(err);
      } else {
        resolve(rows);
      }
    });
  });
}

function dbGet(db, sql, params = []) {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => {
      if (err) {
        reject(err);
      } else {
        resolve(row);
      }
    });
  });
}

function mapQuestion(row) {
  let notes = null;
  if (row.notes) {
    try {
      const parsed = JSON.parse(row.notes);
      if (Array.isArray(parsed)) {
        notes = parsed.filter((entry) => entry && entry.trim() && entry.trim() !== '---');
        if (notes.length === 0) {
          notes = null;
        }
      }
    } catch (err) {
      notes = [row.notes];
    }
  }

  return {
    id: row.question_id,
    text: row.question_text,
    pillar: row.pillar,
    tier: row.tier,
    type: row.question_type,
    options: row.options_json ? JSON.parse(row.options_json) : null,
    estimatedMinutes: row.estimated_time,
    trigger: row.trigger || null,
    notes,
  };
}

async function getModuleDetails(db, moduleId) {
  const moduleRow = await dbGet(
    db,
    `SELECT module_id, name, description, pillar, tier, module_type, estimated_minutes, default_day_number, repeat_interval
     FROM assessment_modules
     WHERE module_id = ?`,
    [moduleId],
  );

  if (!moduleRow) {
    return null;
  }

  const questionRows = await dbAll(
    db,
    `SELECT q.*
     FROM module_questions mq
     JOIN assessment_questions q ON q.question_id = mq.question_id
     WHERE mq.module_id = ?
     ORDER BY mq.order_index ASC`,
    [moduleId],
  );

  return {
    moduleId: moduleRow.module_id,
    name: moduleRow.name,
    description: moduleRow.description,
    pillar: moduleRow.pillar,
    tier: moduleRow.tier,
    moduleType: moduleRow.module_type,
    estimatedMinutes: moduleRow.estimated_minutes,
    defaultDayNumber: moduleRow.default_day_number,
    repeatInterval: moduleRow.repeat_interval,
    questions: questionRows.map(mapQuestion),
  };
}

async function getDiaryQuestions(db) {
  const rows = await dbAll(
    db,
    `SELECT id, question_text, question_type, options_json, group_key, help_text, condition_json, estimated_time
     FROM sleep_diary_questions
     ORDER BY rowid ASC`,
  );

  return rows.map((row) => ({
    id: row.id,
    text: row.question_text,
    type: row.question_type,
    options: row.options_json ? JSON.parse(row.options_json) : null,
    group: row.group_key || null,
    helpText: row.help_text || null,
    condition: row.condition_json ? JSON.parse(row.condition_json) : null,
    estimatedMinutes: row.estimated_time || null,
  }));
}

async function getDaySchedule(db, dayNumber) {
  const moduleRows = await dbAll(
    db,
    `SELECT dm.day_number, dm.order_index AS schedule_order, m.*
     FROM day_modules dm
     JOIN assessment_modules m ON m.module_id = dm.module_id
     WHERE dm.day_number = ?
     ORDER BY dm.order_index ASC`,
    [dayNumber],
  );

  if (moduleRows.length === 0) {
    return null;
  }

  const modules = [];
  for (const row of moduleRows) {
    const module = await getModuleDetails(db, row.module_id);
    if (module) {
      modules.push({
        ...module,
        scheduleOrder: row.schedule_order,
      });
    }
  }

  const diaryQuestions = await getDiaryQuestions(db);

  return {
    dayNumber,
    modules,
    diary: diaryQuestions.length
      ? {
          moduleId: 'diary_daily',
          name: 'Daily Sleep Diary',
          estimatedMinutes: diaryQuestions.reduce(
            (sum, q) => sum + (q.estimatedMinutes || 0),
            0,
          ),
          questions: diaryQuestions,
        }
      : null,
  };
}

router.get('/modules', async (req, res) => {
  try {
    const db = getDatabase();
    const modules = await dbAll(
      db,
      `SELECT module_id, name, description, pillar, tier, module_type, estimated_minutes, default_day_number, repeat_interval
       FROM assessment_modules
       ORDER BY tier ASC, pillar ASC`,
    );

    res.json({
      modules: modules.map((mod) => ({
        moduleId: mod.module_id,
        name: mod.name,
        description: mod.description,
        pillar: mod.pillar,
        tier: mod.tier,
        moduleType: mod.module_type,
        estimatedMinutes: mod.estimated_minutes,
        defaultDayNumber: mod.default_day_number,
        repeatInterval: mod.repeat_interval,
      })),
    });
  } catch (err) {
    console.error('Error fetching modules', err);
    res.status(500).json({ error: 'Database error' });
  }
});

router.get('/modules/:moduleId', async (req, res) => {
  try {
    const db = getDatabase();
    const module = await getModuleDetails(db, req.params.moduleId);
    if (!module) {
      return res.status(404).json({ error: 'Module not found' });
    }
    res.json({ module });
  } catch (err) {
    console.error('Error fetching module', err);
    res.status(500).json({ error: 'Database error' });
  }
});

router.get('/day/:dayNumber', async (req, res) => {
  const dayNumber = parseInt(req.params.dayNumber, 10);
  if (Number.isNaN(dayNumber)) {
    return res.status(400).json({ error: 'Invalid day number' });
  }

  try {
    const db = getDatabase();
    const schedule = await getDaySchedule(db, dayNumber);
    if (!schedule) {
      return res.status(404).json({ error: 'Day plan not found' });
    }
    res.json(schedule);
  } catch (err) {
    console.error('Error fetching day schedule', err);
    res.status(500).json({ error: 'Database error' });
  }
});

router.get('/user/:userId/day/:dayNumber?', async (req, res) => {
  const userId = parseInt(req.params.userId, 10);
  if (Number.isNaN(userId)) {
    return res.status(400).json({ error: 'Invalid user id' });
  }

  let dayNumber = req.params.dayNumber
    ? parseInt(req.params.dayNumber, 10)
    : null;

  try {
    const db = getDatabase();
    const user = await dbGet(
      db,
      'SELECT id, username, current_day FROM users WHERE id = ?',
      [userId],
    );

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (dayNumber === null || Number.isNaN(dayNumber)) {
      dayNumber = user.current_day;
    }

    const schedule = await getDaySchedule(db, dayNumber);
    if (!schedule) {
      return res.status(404).json({ error: 'Day plan not found' });
    }

    const availableDays = await dbAll(
      db,
      'SELECT DISTINCT day_number FROM day_modules ORDER BY day_number ASC',
    );

    res.json({
      user: {
        id: user.id,
        username: user.username,
        currentDay: user.current_day,
      },
      day: schedule,
      availableDays: availableDays.map((row) => row.day_number),
    });
  } catch (err) {
    console.error('Error fetching user schedule', err);
    res.status(500).json({ error: 'Database error' });
  }
});

router.get('/diary', async (req, res) => {
  try {
    const db = getDatabase();
    const questions = await getDiaryQuestions(db);
    res.json({ moduleId: 'diary_daily', questions });
  } catch (err) {
    console.error('Error fetching diary', err);
    res.status(500).json({ error: 'Database error' });
  }
});

module.exports = router;

