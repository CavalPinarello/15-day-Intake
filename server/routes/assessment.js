const express = require('express');
const { getDatabase: getUnifiedDatabase } = require('../database/db');
const { getDatabase: getSQLiteDatabase } = require('../database/init'); // Keep for backward compatibility
const { evaluateGateways, getTriggeredModules } = require('../utils/gatewayEvaluator');
const { parseTrigger } = require('../utils/conditionParser');

const router = express.Router();

/**
 * Evaluate and store gateway states for a user
 */
async function evaluateAndStoreGatewayStates(db, userId) {
  try {
    const responses = await getUserResponses(db, userId);
    const gatewayResults = evaluateGateways(userId, responses);

    // Store gateway states in database
    for (const gatewayId in gatewayResults) {
      const result = gatewayResults[gatewayId];
      
      // Check if record exists
      const existing = await dbGet(db, `
        SELECT id FROM user_gateway_states
        WHERE user_id = ? AND gateway_id = ?
      `, [userId, gatewayId]);

      if (existing) {
        // Update existing record
        await new Promise((resolve, reject) => {
          db.run(`
            UPDATE user_gateway_states
            SET triggered = ?,
                triggered_at = CASE WHEN ? = 1 THEN COALESCE(triggered_at, CURRENT_TIMESTAMP) ELSE triggered_at END,
                last_evaluated_at = CURRENT_TIMESTAMP,
                evaluation_data_json = ?
            WHERE user_id = ? AND gateway_id = ?
          `, [
            result.triggered ? 1 : 0,
            result.triggered ? 1 : 0,
            JSON.stringify(result.evaluationData || {}),
            userId,
            gatewayId
          ], (err) => {
            if (err) reject(err);
            else resolve();
          });
        });
      } else {
        // Insert new record
        await new Promise((resolve, reject) => {
          db.run(`
            INSERT INTO user_gateway_states (user_id, gateway_id, triggered, triggered_at, last_evaluated_at, evaluation_data_json)
            VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, ?)
          `, [
            userId,
            gatewayId,
            result.triggered ? 1 : 0,
            result.triggered ? new Date().toISOString() : null,
            JSON.stringify(result.evaluationData || {})
          ], (err) => {
            if (err) reject(err);
            else resolve();
          });
        });
      }
    }

    return gatewayResults;
  } catch (err) {
    console.error('Error evaluating and storing gateway states:', err);
    throw err;
  }
}

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

  // Parse trigger string to condition object
  let condition = null;
  if (row.trigger) {
    condition = parseTrigger(row.trigger, row.question_id);
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
    condition: condition,
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

  return rows.map((row) => {
    const parsedOptions = row.options_json ? JSON.parse(row.options_json) : null;
    const question = {
      id: row.id,
      text: row.question_text,
      type: row.question_type,
      options: parsedOptions,
      group: row.group_key || null,
      helpText: row.help_text || null,
      condition: row.condition_json ? JSON.parse(row.condition_json) : null,
      estimatedMinutes: row.estimated_time || null,
    };

    // Extract all fields from options if they exist
    if (parsedOptions && typeof parsedOptions === 'object') {
      // Number picker fields
      if (parsedOptions.min !== undefined) question.min = parsedOptions.min;
      if (parsedOptions.max !== undefined) question.max = parsedOptions.max;
      if (parsedOptions.defaultValue !== undefined) question.defaultValue = parsedOptions.defaultValue;
      if (parsedOptions.specialValue !== undefined) question.specialValue = parsedOptions.specialValue;
      if (parsedOptions.specialLabel !== undefined) question.specialLabel = parsedOptions.specialLabel;
      if (parsedOptions.unit !== undefined) question.unit = parsedOptions.unit;
      // Scale fields
      if (parsedOptions.scaleMin !== undefined) question.scaleMin = parsedOptions.scaleMin;
      if (parsedOptions.scaleMax !== undefined) question.scaleMax = parsedOptions.scaleMax;
      if (parsedOptions.scaleMinLabel !== undefined) question.scaleMinLabel = parsedOptions.scaleMinLabel;
      if (parsedOptions.scaleMaxLabel !== undefined) question.scaleMaxLabel = parsedOptions.scaleMaxLabel;
    }

    return question;
  });
}

/**
 * Get user responses for assessment questions
 */
async function getUserResponses(db, userId) {
  try {
    const tableExists = await dbGet(db, `
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name='user_assessment_responses'
    `);

    if (!tableExists) {
      return {};
    }

    const responses = await dbAll(db, `
      SELECT question_id, response_value
      FROM user_assessment_responses
      WHERE user_id = ?
      ORDER BY updated_at DESC
    `, [userId]);

    // Convert to object, taking the latest response for each question
    const responseMap = {};
    for (const row of responses) {
      if (!responseMap.hasOwnProperty(row.question_id)) {
        responseMap[row.question_id] = row.response_value;
      }
    }

    return responseMap;
  } catch (err) {
    console.error('Error getting user responses:', err);
    return {};
  }
}

/**
 * Get user gateway states from database
 */
async function getUserGatewayStates(db, userId) {
  try {
    const tableExists = await dbGet(db, `
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name='user_gateway_states'
    `);

    if (!tableExists) {
      return {};
    }

    const states = await dbAll(db, `
      SELECT gateway_id, triggered, triggered_at, evaluation_data_json
      FROM user_gateway_states
      WHERE user_id = ?
    `, [userId]);

    const stateMap = {};
    for (const row of states) {
      stateMap[row.gateway_id] = {
        triggered: Boolean(row.triggered),
        triggeredAt: row.triggered_at,
        evaluationData: row.evaluation_data_json ? JSON.parse(row.evaluation_data_json) : null
      };
    }

    return stateMap;
  } catch (err) {
    console.error('Error getting user gateway states:', err);
    return {};
  }
}

/**
 * Get triggered modules for a user based on gateway states
 */
async function getTriggeredModulesForUser(db, userId) {
  const responses = await getUserResponses(db, userId);
  return getTriggeredModules(userId, responses);
}

async function getDaySchedule(db, dayNumber, userId = null) {
  // For days 1-8, return static CORE modules
  if (dayNumber >= 1 && dayNumber <= 8) {
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

  // For days 9-15, dynamically determine expansion modules based on gateway states
  if (dayNumber >= 9 && dayNumber <= 15 && userId) {
    try {
      const triggeredModules = await getTriggeredModulesForUser(db, userId);
      
      if (triggeredModules.length === 0) {
        // No expansion modules triggered, return empty schedule
        const diaryQuestions = await getDiaryQuestions(db);
        return {
          dayNumber,
          modules: [],
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

      // Map day numbers 9-15 to triggered modules
      // Distribute modules across days, cycling through if needed
      const moduleIndex = (dayNumber - 9) % triggeredModules.length;
      const moduleId = triggeredModules[moduleIndex];

      const module = await getModuleDetails(db, moduleId);
      if (!module) {
        const diaryQuestions = await getDiaryQuestions(db);
        return {
          dayNumber,
          modules: [],
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

      const diaryQuestions = await getDiaryQuestions(db);

      return {
        dayNumber,
        modules: [{
          ...module,
          scheduleOrder: 0,
        }],
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
    } catch (err) {
      console.error('Error getting dynamic day schedule:', err);
      // Fallback to empty schedule
      const diaryQuestions = await getDiaryQuestions(db);
      return {
        dayNumber,
        modules: [],
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
  }

  // For days > 15 or no userId, return null
  return null;
}

router.get('/modules', async (req, res) => {
  try {
    const db = await getUnifiedDatabase();
    
    // Use unified interface if available
    if (db.getModules) {
      const modules = await db.getModules();
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
      return;
    }
    
    // Fallback to SQLite
    const sqliteDb = getSQLiteDatabase();
    const modules = await dbAll(
      sqliteDb,
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

// Get user's current day assessment (explicit route for /current)
router.get('/user/:userId/day/current', async (req, res) => {
  const userId = parseInt(req.params.userId, 10);
  if (Number.isNaN(userId)) {
    return res.status(400).json({ error: 'Invalid user id' });
  }

  try {
    // Use unified database interface to support both SQLite and Convex
    const db = await getUnifiedDatabase();
    
    // Get user using unified interface
    let user = null;
    if (db.getUserById) {
      user = await db.getUserById(userId);
    } else {
      // Fallback to SQLite if unified interface not available
      const sqliteDb = getSQLiteDatabase();
      user = await dbGet(
        sqliteDb,
        'SELECT id, username, current_day FROM users WHERE id = ?',
        [userId],
      );
    }

    if (!user) {
      console.error(`User not found: userId=${userId}`);
      // Log available users for debugging (try both databases)
      try {
        if (db.getAllUserNames) {
          const namesResult = await db.getAllUserNames();
          console.error('Available users (from unified DB):', Object.keys(namesResult.names || {}).length, 'users');
        }
        // Also try SQLite for comparison
        const sqliteDb = getSQLiteDatabase();
        const allUsers = await dbAll(sqliteDb, 'SELECT id, username FROM users ORDER BY id LIMIT 20');
        console.error('Available users in SQLite:', allUsers.map(u => `${u.id}:${u.username}`).join(', '));
      } catch (logErr) {
        console.error('Error logging users:', logErr);
      }
      return res.status(404).json({ error: `User not found: userId=${userId}. Please log in again.` });
    }

    const dayNumber = user.current_day || 1;

    // Get day schedule - use SQLite for now since Convex database is empty
    // Need SQLite for getDaySchedule function
    const sqliteDb = getSQLiteDatabase();
    const schedule = await getDaySchedule(sqliteDb, dayNumber, userId);
    if (!schedule) {
      return res.status(404).json({ error: 'Day plan not found' });
    }

    // Get available days from SQLite
    const days = await dbAll(sqliteDb, 'SELECT DISTINCT day_number FROM day_modules ORDER BY day_number ASC');
    const availableDays = days.map((row) => row.day_number);

    res.json({
      user: {
        id: user.id || user._id,
        username: user.username,
        currentDay: user.current_day,
      },
      day: schedule,
      availableDays,
    });
  } catch (err) {
    console.error('Error fetching user schedule', err);
    console.error('Error stack:', err.stack);
    res.status(500).json({ error: 'Database error', message: err.message });
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

// Save assessment response
router.post('/user/:userId/response', async (req, res) => {
  const userId = parseInt(req.params.userId, 10);
  if (Number.isNaN(userId)) {
    return res.status(400).json({ error: 'Invalid user id' });
  }

  const { question_id, response_value, day_number } = req.body;
  
  if (!question_id || response_value === undefined || !day_number) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    // Use SQLite directly for now (Convex adapter needs more work)
    const db = getSQLiteDatabase();
    
    // Check if table exists, create if not
    await dbAll(db, `
      CREATE TABLE IF NOT EXISTS user_assessment_responses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        question_id TEXT NOT NULL,
        response_value TEXT,
        day_number INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, question_id, day_number),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    `).catch(() => {}); // Ignore if table already exists

    // Insert or update response (SQLite syntax)
    // First try to update
    const updateResult = await new Promise((resolve) => {
      db.run(`
        UPDATE user_assessment_responses
        SET response_value = ?, updated_at = CURRENT_TIMESTAMP
        WHERE user_id = ? AND question_id = ? AND day_number = ?
      `, [response_value, userId, question_id, day_number], function(err) {
        if (err) {
          resolve({ changes: 0, err });
        } else {
          resolve({ changes: this.changes, err: null });
        }
      });
    });

    // If no rows were updated, insert new record
    if (updateResult.changes === 0) {
      await new Promise((resolve, reject) => {
        db.run(`
          INSERT INTO user_assessment_responses (user_id, question_id, response_value, day_number, updated_at)
          VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
        `, [userId, question_id, response_value, day_number], function(err) {
          if (err) {
            // If it's a unique constraint violation, try update again
            if (err.message.includes('UNIQUE constraint')) {
              db.run(`
                UPDATE user_assessment_responses
                SET response_value = ?, updated_at = CURRENT_TIMESTAMP
                WHERE user_id = ? AND question_id = ? AND day_number = ?
              `, [response_value, userId, question_id, day_number], (updateErr) => {
                if (updateErr) reject(updateErr);
                else resolve();
              });
            } else {
              reject(err);
            }
          } else {
            resolve();
          }
        });
      });
    }

    // Re-evaluate gateway states after saving response
    // This ensures gateway states are up-to-date for dynamic day scheduling
    try {
      await evaluateAndStoreGatewayStates(db, userId);
    } catch (gatewayErr) {
      console.error('Error evaluating gateway states after response save:', gatewayErr);
      // Don't fail the request if gateway evaluation fails
    }

    res.json({ success: true });
  } catch (err) {
    console.error('Error saving assessment response', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Get user's name from D1 response
router.get('/user/:userId/name', async (req, res) => {
  const userId = parseInt(req.params.userId, 10);
  if (Number.isNaN(userId)) {
    return res.status(400).json({ error: 'Invalid user id' });
  }

  try {
    const db = getDatabase();
    
    // Check if table exists first
    const tableExists = await dbGet(db, `
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name='user_assessment_responses'
    `);

    if (!tableExists) {
      return res.json({ name: null });
    }

    const response = await dbGet(db, `
      SELECT response_value 
      FROM user_assessment_responses 
      WHERE user_id = ? AND question_id = 'D1'
      ORDER BY updated_at DESC
      LIMIT 1
    `, [userId]);

    res.json({ name: response?.response_value || null });
  } catch (err) {
    console.error('Error fetching user name', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Get all user names for quick login display
router.get('/users/names', async (req, res) => {
  try {
    console.log('GET /api/assessment/users/names - Request received');
    const db = await getUnifiedDatabase();
    
    if (!db) {
      console.error('Database not available');
      return res.status(500).json({ error: 'Database not available' });
    }
    
    // Use unified interface if available
    if (db.getAllUserNames) {
      const result = await db.getAllUserNames();
      console.log('Returning names from unified interface:', result.names || result);
      return res.json({ names: result.names || result });
    }
    
    // Fallback to SQLite for backward compatibility
    const sqliteDb = getSQLiteDatabase();
    const tableExists = await dbGet(sqliteDb, `
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name='user_assessment_responses'
    `);

    if (!tableExists) {
      console.log('user_assessment_responses table does not exist, returning empty names');
      return res.json({ names: {} });
    }

    const responses = await dbAll(sqliteDb, `
      SELECT DISTINCT u.id, u.username, 
             (SELECT r.response_value 
              FROM user_assessment_responses r 
              WHERE r.user_id = u.id AND r.question_id = 'D1' 
              ORDER BY r.updated_at DESC 
              LIMIT 1) as name
      FROM users u
      WHERE u.username LIKE 'user%'
      ORDER BY u.id
    `);

    console.log(`Found ${responses.length} users with user% username pattern`);

    const names = {};
    responses.forEach((row) => {
      const userId = parseInt(row.id, 10);
      if (!isNaN(userId)) {
        names[userId] = row.name || null;
      }
    });

    console.log('Returning names:', names);
    res.json({ names });
  } catch (err) {
    console.error('Error fetching user names:', err);
    console.error('Error stack:', err.stack);
    res.status(500).json({ error: 'Database error', message: err.message });
  }
});

// Endpoint to manually evaluate gateway states for a user
router.post('/user/:userId/evaluate-gateways', async (req, res) => {
  const userId = parseInt(req.params.userId, 10);
  if (Number.isNaN(userId)) {
    return res.status(400).json({ error: 'Invalid user id' });
  }

  try {
    const db = getDatabase();
    const gatewayResults = await evaluateAndStoreGatewayStates(db, userId);
    
    res.json({
      success: true,
      gatewayResults,
      triggeredModules: await getTriggeredModulesForUser(db, userId)
    });
  } catch (err) {
    console.error('Error evaluating gateway states', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Get gateway states for a user
router.get('/user/:userId/gateway-states', async (req, res) => {
  const userId = parseInt(req.params.userId, 10);
  if (Number.isNaN(userId)) {
    return res.status(400).json({ error: 'Invalid user id' });
  }

  try {
    const db = getDatabase();
    const gatewayStates = await getUserGatewayStates(db, userId);
    const triggeredModules = await getTriggeredModulesForUser(db, userId);
    
    res.json({
      gatewayStates,
      triggeredModules
    });
  } catch (err) {
    console.error('Error getting gateway states', err);
    res.status(500).json({ error: 'Database error' });
  }
});

module.exports = router;

