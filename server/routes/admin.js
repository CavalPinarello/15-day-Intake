const express = require('express');
const { getDatabase } = require('../database/init');

const router = express.Router();

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

// Update question
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

module.exports = router;

