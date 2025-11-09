const express = require('express');
const { getDatabase } = require('../database/init');

const router = express.Router();

// Save response
router.post('/', (req, res) => {
  const { user_id, question_id, day_id, response_value, response_data } = req.body;

  if (!user_id || !question_id || !day_id) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const db = getDatabase();
  db.run(
    `INSERT OR REPLACE INTO responses (user_id, question_id, day_id, response_value, response_data, updated_at)
     VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
    [
      user_id,
      question_id,
      day_id,
      response_value,
      response_data ? JSON.stringify(response_data) : null
    ],
    function(err) {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      res.json({ success: true, response_id: this.lastID });
    }
  );
});

// Get user responses for a day
router.get('/user/:userId/day/:dayId', (req, res) => {
  const userId = req.params.userId;
  const dayId = req.params.dayId;
  const db = getDatabase();

  db.all(
    `SELECT r.*, q.question_text, q.question_type
     FROM responses r
     JOIN questions q ON r.question_id = q.id
     WHERE r.user_id = ? AND r.day_id = ?
     ORDER BY q.order_index`,
    [userId, dayId],
    (err, responses) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      const responsesWithParsedData = responses.map(r => ({
        ...r,
        response_data: r.response_data ? JSON.parse(r.response_data) : null
      }));

      res.json({ responses: responsesWithParsedData });
    }
  );
});

// Mark day as completed
router.post('/user/:userId/day/:dayId/complete', (req, res) => {
  const userId = req.params.userId;
  const dayId = req.params.dayId;
  const db = getDatabase();

  db.run(
    `INSERT OR REPLACE INTO user_progress (user_id, day_id, completed, completed_at)
     VALUES (?, ?, 1, CURRENT_TIMESTAMP)`,
    [userId, dayId],
    (err) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      // Check if all questions are answered
      db.get(
        `SELECT COUNT(*) as total, 
         (SELECT COUNT(*) FROM responses WHERE user_id = ? AND day_id = ?) as answered
         FROM questions WHERE day_id = ?`,
        [userId, dayId, dayId],
        (err, result) => {
          if (err) {
            return res.status(500).json({ error: 'Database error' });
          }

          res.json({
            success: true,
            completed: result.answered >= result.total
          });
        }
      );
    }
  );
});

module.exports = router;

