const express = require('express');
const { getDatabase } = require('../database/init');

const router = express.Router();

// Helper functions for database queries
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

function dbRun(db, sql, params = []) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function(err) {
      if (err) {
        reject(err);
      } else {
        resolve({ lastID: this.lastID, changes: this.changes });
      }
    });
  });
}

// Get all questions for a day (for admin)
router.get('/days/:dayId/questions', (req, res) => {
  const dayId = req.params.dayId;
  const db = getDatabase();

  db.all(
    `SELECT q.*, d.day_number, d.title as day_title
     FROM questions q
     JOIN days d ON q.day_id = d.id
     WHERE q.day_id = ?
     ORDER BY q.order_index ASC`,
    [dayId],
    (err, questions) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      const questionsWithParsedOptions = questions.map(q => ({
        ...q,
        options: q.options ? JSON.parse(q.options) : null,
        conditional_logic: q.conditional_logic ? JSON.parse(q.conditional_logic) : null
      }));

      res.json({ questions: questionsWithParsedOptions });
    }
  );
});

// Reorder questions (update order_index)
router.post('/days/:dayId/questions/reorder', (req, res) => {
  const dayId = req.params.dayId;
  const { question_ids } = req.body; // Array of question IDs in new order

  if (!Array.isArray(question_ids)) {
    return res.status(400).json({ error: 'question_ids must be an array' });
  }

  const db = getDatabase();
  const updates = question_ids.map((questionId, index) => {
    return new Promise((resolve, reject) => {
      db.run(
        'UPDATE questions SET order_index = ? WHERE id = ? AND day_id = ?',
        [index, questionId, dayId],
        (err) => {
          if (err) reject(err);
          else resolve();
        }
      );
    });
  });

  Promise.all(updates)
    .then(() => {
      res.json({ success: true });
    })
    .catch((err) => {
      res.status(500).json({ error: 'Database error' });
    });
});

// Update question (legacy questions table)
router.put('/questions/:questionId', (req, res) => {
  const questionId = req.params.questionId;
  const { question_text, question_type, options, order_index, required, conditional_logic } = req.body;

  const db = getDatabase();
  db.run(
    `UPDATE questions 
     SET question_text = ?, question_type = ?, options = ?, order_index = ?, required = ?, conditional_logic = ?
     WHERE id = ?`,
    [
      question_text,
      question_type,
      options ? JSON.stringify(options) : null,
      order_index,
      required !== undefined ? required : 1,
      conditional_logic ? JSON.stringify(conditional_logic) : null,
      questionId
    ],
    (err) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      res.json({ success: true });
    }
  );
});

// Update assessment question (from assessment_questions table)
router.put('/assessment-questions/:questionId', async (req, res) => {
  try {
    const questionId = req.params.questionId;
    const { text, type, estimatedMinutes, options, trigger } = req.body;

    const db = getDatabase();
    
    await dbRun(
      db,
      `UPDATE assessment_questions 
       SET question_text = ?, 
           question_type = COALESCE(?, question_type),
           options_json = ?,
           estimated_time = COALESCE(?, estimated_time),
           trigger = COALESCE(?, trigger)
       WHERE question_id = ?`,
      [
        text || null,
        type || null,
        options ? JSON.stringify(options) : null,
        estimatedMinutes || null,
        trigger || null,
        questionId
      ]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Error updating assessment question:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Reorder questions within a module for a specific day
router.post('/days/:dayNumber/questions/reorder', async (req, res) => {
  try {
    const dayNumber = parseInt(req.params.dayNumber, 10);
    const { questionIds, moduleId } = req.body; // Array of question IDs in new order

    console.log(`Reordering questions for day ${dayNumber}, module ${moduleId}:`, questionIds);

    if (!Array.isArray(questionIds) || isNaN(dayNumber)) {
      return res.status(400).json({ error: 'Invalid request: questionIds must be an array' });
    }

    if (!moduleId) {
      return res.status(400).json({ error: 'moduleId is required for reordering' });
    }

    const db = getDatabase();

    // Verify all questions exist in the module
    const existingQuestions = await dbAll(
      db,
      'SELECT question_id FROM module_questions WHERE module_id = ?',
      [moduleId]
    );
    const existingQuestionIds = new Set(existingQuestions.map(q => q.question_id));
    const missingQuestions = questionIds.filter(qId => !existingQuestionIds.has(qId));
    
    if (missingQuestions.length > 0) {
      console.warn(`Some questions not found in module ${moduleId}:`, missingQuestions);
      // Continue anyway - we'll only update questions that exist
    }

    // Filter to only questions that exist in this module
    const validQuestionIds = questionIds.filter(qId => existingQuestionIds.has(qId));
    
    if (validQuestionIds.length === 0) {
      return res.status(400).json({ error: 'No valid questions found in module' });
    }

    // Use a transaction to avoid primary key conflicts
    // The table has PRIMARY KEY (module_id, order_index), so we can't just UPDATE
    // Strategy: Delete and reinsert to avoid primary key conflicts
    // This is cleaner than trying to update in place with negative numbers
    
    return new Promise((resolve) => {
      db.serialize(() => {
        db.run('BEGIN TRANSACTION', (beginErr) => {
          if (beginErr) {
            console.error('Error beginning transaction:', beginErr);
            return res.status(500).json({ error: 'Database error: failed to begin transaction' });
          }

          // Get current order_index values for the questions we're reordering
          db.all(
            'SELECT question_id, order_index FROM module_questions WHERE module_id = ? AND question_id IN (' + validQuestionIds.map(() => '?').join(',') + ')',
            [moduleId, ...validQuestionIds],
            (selectErr, existingRows) => {
              if (selectErr) {
                db.run('ROLLBACK', () => {});
                console.error('Error selecting existing questions:', selectErr);
                return res.status(500).json({ error: 'Database error: failed to select questions' });
              }

              // Create a map of question_id to old order_index
              const oldOrderMap = new Map();
              existingRows.forEach(row => {
                oldOrderMap.set(row.question_id, row.order_index);
              });

              // Verify we have all questions
              const missing = validQuestionIds.filter(qId => !oldOrderMap.has(qId));
              if (missing.length > 0) {
                db.run('ROLLBACK', () => {});
                return res.status(400).json({ error: `Questions not found in module: ${missing.join(', ')}` });
              }

              // Delete existing rows for these questions
              const deletePlaceholders = validQuestionIds.map(() => '?').join(',');
              db.run(
                `DELETE FROM module_questions WHERE module_id = ? AND question_id IN (${deletePlaceholders})`,
                [moduleId, ...validQuestionIds],
                function(deleteErr) {
                  if (deleteErr) {
                    db.run('ROLLBACK', () => {});
                    console.error('Error deleting questions:', deleteErr);
                    return res.status(500).json({ error: 'Database error: failed to delete questions' });
                  }

                  // Insert questions with new order
                  let insertCount = 0;
                  let insertErrors = [];

                  validQuestionIds.forEach((questionId, index) => {
                    db.run(
                      'INSERT INTO module_questions (module_id, question_id, order_index) VALUES (?, ?, ?)',
                      [moduleId, questionId, index],
                      function(insertErr) {
                        if (insertErr) {
                          console.error(`Error inserting question ${questionId}:`, insertErr);
                          insertErrors.push({ questionId, error: insertErr });
                        }
                        insertCount++;

                        // When all inserts are done
                        if (insertCount === validQuestionIds.length) {
                          if (insertErrors.length > 0) {
                            db.run('ROLLBACK', () => {});
                            return res.status(500).json({ 
                              error: `Database error: failed to insert questions: ${insertErrors[0].error.message}`,
                              details: insertErrors
                            });
                          }

                          // Commit transaction
                          db.run('COMMIT', (commitErr) => {
                            if (commitErr) {
                              console.error('Error committing transaction:', commitErr);
                              db.run('ROLLBACK', () => {});
                              return res.status(500).json({ error: 'Database error: failed to commit transaction' });
                            }
                            console.log(`Successfully reordered ${validQuestionIds.length} questions for module ${moduleId}`);
                            res.json({ success: true, reorderedCount: validQuestionIds.length });
                          });
                        }
                      }
                    );
                  });
                }
              );
            }
          );
        });
      });
    });
  } catch (err) {
    console.error('Error reordering questions:', err);
    res.status(500).json({ error: `Database error: ${err.message || 'Unknown error'}` });
  }
});

// Create question
router.post('/days/:dayId/questions', (req, res) => {
  const dayId = req.params.dayId;
  const { question_text, question_type, options, order_index, required, conditional_logic } = req.body;

  if (!question_text || !question_type || order_index === undefined) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const db = getDatabase();
  db.run(
    `INSERT INTO questions (day_id, question_text, question_type, options, order_index, required, conditional_logic)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      dayId,
      question_text,
      question_type,
      options ? JSON.stringify(options) : null,
      order_index,
      required !== undefined ? required : 1,
      conditional_logic ? JSON.stringify(conditional_logic) : null
    ],
    function(err) {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      res.json({
        success: true,
        question: {
          id: this.lastID,
          day_id: dayId,
          question_text,
          question_type,
          options: options || null,
          order_index,
          required,
          conditional_logic: conditional_logic || null
        }
      });
    }
  );
});

// Delete question
router.delete('/questions/:questionId', (req, res) => {
  const questionId = req.params.questionId;
  const db = getDatabase();

  db.run('DELETE FROM questions WHERE id = ?', [questionId], (err) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    res.json({ success: true });
  });
});

// Get all master questions (from assessment_questions table)
router.get('/master-questions', async (req, res) => {
  try {
    const db = getDatabase();
    const questions = await dbAll(
      db,
      `SELECT question_id, question_text, pillar, tier, question_type, options_json, estimated_time, trigger, notes
       FROM assessment_questions
       ORDER BY pillar ASC, tier ASC, question_id ASC`
    );

    const questionsWithParsed = questions.map(q => ({
      id: q.question_id,
      text: q.question_text,
      pillar: q.pillar,
      tier: q.tier,
      type: q.question_type,
      options: q.options_json ? JSON.parse(q.options_json) : null,
      estimatedMinutes: q.estimated_time,
      trigger: q.trigger,
      notes: q.notes ? JSON.parse(q.notes) : null,
    }));

    res.json({ questions: questionsWithParsed });
  } catch (err) {
    console.error('Error fetching master questions:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Get all modules/expansion packs
router.get('/modules', async (req, res) => {
  try {
    const db = getDatabase();
    const modules = await dbAll(
      db,
      `SELECT module_id, name, description, pillar, tier, module_type, estimated_minutes, default_day_number, repeat_interval
       FROM assessment_modules
       ORDER BY tier ASC, pillar ASC, name ASC`
    );

    // Get questions for each module
    const modulesWithQuestions = await Promise.all(
      modules.map(async (mod) => {
        const questionIds = await dbAll(
          db,
          `SELECT question_id, order_index
           FROM module_questions
           WHERE module_id = ?
           ORDER BY order_index ASC`,
          [mod.module_id]
        );

        return {
          moduleId: mod.module_id,
          name: mod.name,
          description: mod.description,
          pillar: mod.pillar,
          tier: mod.tier,
          moduleType: mod.module_type,
          estimatedMinutes: mod.estimated_minutes,
          defaultDayNumber: mod.default_day_number,
          repeatInterval: mod.repeat_interval,
          questionIds: questionIds.map(q => q.question_id),
        };
      })
    );

    res.json({ modules: modulesWithQuestions });
  } catch (err) {
    console.error('Error fetching modules:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Get day assignments (which modules are assigned to which days)
router.get('/day-assignments', async (req, res) => {
  try {
    const db = getDatabase();
    const assignments = await dbAll(
      db,
      `SELECT dm.day_number, dm.module_id, dm.order_index, am.name as module_name, am.pillar, am.tier, am.module_type, am.estimated_minutes
       FROM day_modules dm
       JOIN assessment_modules am ON dm.module_id = am.module_id
       ORDER BY dm.day_number ASC, dm.order_index ASC`
    );

    // Group by day number
    const dayAssignments = {};
    assignments.forEach(assign => {
      if (!dayAssignments[assign.day_number]) {
        dayAssignments[assign.day_number] = [];
      }
      dayAssignments[assign.day_number].push({
        moduleId: assign.module_id,
        moduleName: assign.module_name,
        pillar: assign.pillar,
        tier: assign.tier,
        moduleType: assign.module_type,
        estimatedMinutes: assign.estimated_minutes,
        orderIndex: assign.order_index,
      });
    });

    res.json({ dayAssignments });
  } catch (err) {
    console.error('Error fetching day assignments:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Assign module to a day
router.post('/days/:dayNumber/modules', async (req, res) => {
  try {
    const dayNumber = parseInt(req.params.dayNumber, 10);
    const { moduleId, orderIndex } = req.body;

    if (!moduleId || isNaN(dayNumber)) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const db = getDatabase();

    // Check if module is already assigned to this day
    const existing = await dbGet(
      db,
      'SELECT * FROM day_modules WHERE day_number = ? AND module_id = ?',
      [dayNumber, moduleId]
    );

    if (existing) {
      return res.status(400).json({ error: 'Module already assigned to this day' });
    }

    // Get the next order index if not provided
    let order = orderIndex;
    if (order === undefined) {
      const maxOrder = await dbGet(
        db,
        'SELECT MAX(order_index) as max_order FROM day_modules WHERE day_number = ?',
        [dayNumber]
      );
      order = (maxOrder?.max_order ?? -1) + 1;
    }

    await dbRun(
      db,
      'INSERT INTO day_modules (day_number, module_id, order_index) VALUES (?, ?, ?)',
      [dayNumber, moduleId, order]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Error assigning module to day:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Remove module from a day
router.delete('/days/:dayNumber/modules/:moduleId', async (req, res) => {
  try {
    const dayNumber = parseInt(req.params.dayNumber, 10);
    const { moduleId } = req.params;

    if (!moduleId || isNaN(dayNumber)) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const db = getDatabase();
    await dbRun(
      db,
      'DELETE FROM day_modules WHERE day_number = ? AND module_id = ?',
      [dayNumber, moduleId]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Error removing module from day:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Reorder modules for a day
router.post('/days/:dayNumber/modules/reorder', async (req, res) => {
  try {
    const dayNumber = parseInt(req.params.dayNumber, 10);
    const { moduleIds } = req.body; // Array of module IDs in new order

    if (!Array.isArray(moduleIds) || isNaN(dayNumber)) {
      return res.status(400).json({ error: 'Invalid request' });
    }

    const db = getDatabase();

    // Update order indices
    await Promise.all(
      moduleIds.map((moduleId, index) =>
        dbRun(
          db,
          'UPDATE day_modules SET order_index = ? WHERE day_number = ? AND module_id = ?',
          [index, dayNumber, moduleId]
        )
      )
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Error reordering modules:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

module.exports = router;

