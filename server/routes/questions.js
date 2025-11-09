const express = require('express');
const { getDatabase } = require('../database/init');

const router = express.Router();

// Get all questions for a day
router.get('/day/:dayId', (req, res) => {
  const dayId = req.params.dayId;
  const db = getDatabase();

  db.all(
    `SELECT * FROM questions 
     WHERE day_id = ? 
     ORDER BY order_index ASC`,
    [dayId],
    (err, questions) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      const questionsWithParsedOptions = questions.map(q => ({
        ...q,
        options: q.options ? JSON.parse(q.options) : null
      }));

      res.json({ questions: questionsWithParsedOptions });
    }
  );
});

// Create question
router.post('/', (req, res) => {
  const { day_id, question_text, question_type, options, order_index, required, conditional_logic } = req.body;

  if (!day_id || !question_text || !question_type || order_index === undefined) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const db = getDatabase();
  db.run(
    `INSERT INTO questions (day_id, question_text, question_type, options, order_index, required, conditional_logic)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      day_id,
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
          day_id,
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

// Update question
router.put('/:questionId', (req, res) => {
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

// Delete question
router.delete('/:questionId', (req, res) => {
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

