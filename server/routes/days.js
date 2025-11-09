const express = require('express');
const { getDatabase } = require('../database/init');

const router = express.Router();

// Get all days
router.get('/', (req, res) => {
  const db = getDatabase();
  db.all(
    'SELECT * FROM days ORDER BY day_number',
    [],
    (err, days) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }
      res.json({ days });
    }
  );
});

// Get single day with questions
router.get('/:dayNumber', (req, res) => {
  const dayNumber = req.params.dayNumber;
  const db = getDatabase();

  db.get(
    'SELECT * FROM days WHERE day_number = ?',
    [dayNumber],
    (err, day) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      if (!day) {
        return res.status(404).json({ error: 'Day not found' });
      }

      // Get questions for this day
      db.all(
        `SELECT * FROM questions 
         WHERE day_id = ? 
         ORDER BY order_index ASC`,
        [day.id],
        (err, questions) => {
          if (err) {
            return res.status(500).json({ error: 'Database error' });
          }

          // Parse options JSON for each question
          const questionsWithParsedOptions = questions.map(q => ({
            ...q,
            options: q.options ? JSON.parse(q.options) : null
          }));

          res.json({
            day,
            questions: questionsWithParsedOptions
          });
        }
      );
    }
  );
});

// Get user's current day
router.get('/user/:userId/current', (req, res) => {
  const userId = req.params.userId;
  const db = getDatabase();

  db.get(
    `SELECT u.current_day, d.* 
     FROM users u
     JOIN days d ON u.current_day = d.day_number
     WHERE u.id = ?`,
    [userId],
    (err, result) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      if (!result) {
        return res.status(404).json({ error: 'User or day not found' });
      }

      // Get questions for this day
      db.all(
        `SELECT * FROM questions 
         WHERE day_id = ? 
         ORDER BY order_index ASC`,
        [result.id],
        (err, questions) => {
          if (err) {
            return res.status(500).json({ error: 'Database error' });
          }

          const questionsWithParsedOptions = questions.map(q => ({
            ...q,
            options: q.options ? JSON.parse(q.options) : null
          }));

          res.json({
            day: {
              day_number: result.current_day,
              id: result.id,
              title: result.title,
              description: result.description,
              theme_color: result.theme_color,
              background_image: result.background_image
            },
            questions: questionsWithParsedOptions
          });
        }
      );
    }
  );
});

module.exports = router;

