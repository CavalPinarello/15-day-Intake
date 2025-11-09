const express = require('express');
const { getDatabase } = require('../database/init');

const router = express.Router();

// Get user progress
router.get('/:userId/progress', (req, res) => {
  const userId = req.params.userId;
  const db = getDatabase();

  db.all(
    `SELECT up.*, d.day_number, d.title, d.theme_color
     FROM user_progress up
     JOIN days d ON up.day_id = d.id
     WHERE up.user_id = ?
     ORDER BY d.day_number`,
    [userId],
    (err, progress) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }
      res.json({ progress });
    }
  );
});

// Advance user to next day (for testing)
router.post('/:userId/advance-day', (req, res) => {
  const userId = req.params.userId;
  const db = getDatabase();

  db.get('SELECT current_day FROM users WHERE id = ?', [userId], (err, user) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const newDay = Math.min(user.current_day + 1, 14);
    
    db.run(
      'UPDATE users SET current_day = ? WHERE id = ?',
      [newDay, userId],
      (err) => {
        if (err) {
          return res.status(500).json({ error: 'Database error' });
        }

        res.json({ success: true, current_day: newDay });
      }
    );
  });
});

// Set user to specific day (for testing)
router.post('/:userId/set-day', (req, res) => {
  const userId = req.params.userId;
  const { day } = req.body;

  if (!day || day < 1 || day > 14) {
    return res.status(400).json({ error: 'Day must be between 1 and 14' });
  }

  const db = getDatabase();
  db.run(
    'UPDATE users SET current_day = ? WHERE id = ?',
    [day, userId],
    (err) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      res.json({ success: true, current_day: day });
    }
  );
});

module.exports = router;

