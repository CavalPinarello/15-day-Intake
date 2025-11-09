const express = require('express');
const { getDatabase } = require('../database/init');
const { authenticateToken } = require('../middleware/auth');
const { body, validationResult, query, param } = require('express-validator');

const router = express.Router();

// All coach routes require authentication
router.use(authenticateToken);

/**
 * GET /api/coach/customers
 * Get list of coach's customers
 */
router.get('/coach/customers', (req, res) => {
  const coachId = req.user.userId; // TODO: Verify user is actually a coach
  const db = getDatabase();

  db.all(`
    SELECT 
      u.id,
      u.username,
      u.email,
      u.current_day,
      u.started_at,
      u.last_accessed,
      cca.assigned_at,
      cca.status
    FROM customer_coach_assignments cca
    JOIN users u ON cca.user_id = u.id
    WHERE cca.coach_id = ? AND cca.status = 'active'
    ORDER BY cca.assigned_at DESC
  `, [coachId], (err, customers) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    res.json({ customers: customers || [] });
  });
});

/**
 * GET /api/coach/customers/:id/profile
 * Get customer profile
 */
router.get('/coach/customers/:id/profile', [
  param('id').isInt()
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const coachId = req.user.userId;
  const customerId = req.params.id;
  const db = getDatabase();

  // Verify coach has access to this customer
  db.get(`
    SELECT * FROM customer_coach_assignments
    WHERE user_id = ? AND coach_id = ? AND status = 'active'
  `, [customerId, coachId], (err, assignment) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    if (!assignment) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Get user profile
    db.get(`
      SELECT id, username, email, current_day, started_at, last_accessed, created_at
      FROM users
      WHERE id = ?
    `, [customerId], (err, profile) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      res.json({ profile });
    });
  });
});

/**
 * GET /api/coach/customers/:id/health-stats
 * Get customer health statistics
 */
router.get('/coach/customers/:id/health-stats', [
  param('id').isInt(),
  query('days').optional().isInt({ min: 1, max: 365 }).toInt()
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const coachId = req.user.userId;
  const customerId = req.params.id;
  const days = req.query.days || 30;
  const db = getDatabase();

  // Verify access
  db.get(`
    SELECT * FROM customer_coach_assignments
    WHERE user_id = ? AND coach_id = ? AND status = 'active'
  `, [customerId, coachId], (err, assignment) => {
    if (err || !assignment) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    const startDateStr = startDate.toISOString().split('T')[0];

    // Get sleep stats
    db.get(`
      SELECT 
        AVG(total_sleep_mins) as avg_sleep_mins,
        AVG(sleep_efficiency) as avg_efficiency,
        AVG(deep_sleep_mins) as avg_deep_sleep,
        COUNT(*) as days_with_data
      FROM user_sleep_data
      WHERE user_id = ? AND date >= ?
    `, [customerId, startDateStr], (err, sleepStats) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      // Get activity stats
      db.get(`
        SELECT 
          AVG(steps) as avg_steps,
          AVG(active_mins) as avg_active_mins,
          SUM(calories_burned) as total_calories
        FROM user_activity
        WHERE user_id = ? AND date >= ?
      `, [customerId, startDateStr], (err, activityStats) => {
        if (err) {
          return res.status(500).json({ error: 'Database error' });
        }

        // Get intervention compliance
        db.get(`
          SELECT 
            COUNT(*) as total_tasks,
            SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) as completed_tasks
          FROM intervention_compliance ic
          JOIN user_interventions ui ON ic.user_intervention_id = ui.id
          WHERE ui.user_id = ? AND ic.scheduled_date >= ?
        `, [customerId, startDateStr], (err, complianceStats) => {
          if (err) {
            return res.status(500).json({ error: 'Database error' });
          }

          res.json({
            period: { days, startDate: startDateStr },
            sleep: sleepStats || {},
            activity: activityStats || {},
            compliance: complianceStats || {}
          });
        });
      });
    });
  });
});

/**
 * GET /api/coach/customers/:id/interventions
 * Get customer's interventions
 */
router.get('/coach/customers/:id/interventions', [
  param('id').isInt()
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const coachId = req.user.userId;
  const customerId = req.params.id;
  const db = getDatabase();

  // Verify access
  db.get(`
    SELECT * FROM customer_coach_assignments
    WHERE user_id = ? AND coach_id = ? AND status = 'active'
  `, [customerId, coachId], (err, assignment) => {
    if (err || !assignment) {
      return res.status(403).json({ error: 'Access denied' });
    }

    db.all(`
      SELECT 
        ui.*,
        i.name as intervention_name,
        i.type as intervention_type,
        i.category
      FROM user_interventions ui
      JOIN interventions i ON ui.intervention_id = i.id
      WHERE ui.user_id = ?
      ORDER BY ui.assigned_at DESC
    `, [customerId], (err, interventions) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      const parsed = (interventions || []).map(int => ({
        ...int,
        schedule_json: int.schedule_json ? JSON.parse(int.schedule_json) : null
      }));

      res.json({ interventions: parsed });
    });
  });
});

/**
 * GET /api/coach/alerts
 * Get alerts for coach
 */
router.get('/coach/alerts', [
  query('resolved').optional().isBoolean().toBoolean(),
  query('severity').optional().isIn(['low', 'medium', 'high', 'critical'])
], (req, res) => {
  const coachId = req.user.userId;
  const { resolved, severity } = req.query;
  const db = getDatabase();

  let query = `
    SELECT a.*, u.username, u.email
    FROM alerts a
    JOIN users u ON a.user_id = u.id
    WHERE a.coach_id = ?
  `;
  const params = [coachId];

  if (resolved !== undefined) {
    query += ' AND a.resolved = ?';
    params.push(resolved ? 1 : 0);
  }

  if (severity) {
    query += ' AND a.severity = ?';
    params.push(severity);
  }

  query += ' ORDER BY a.created_at DESC LIMIT 50';

  db.all(query, params, (err, alerts) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    const parsed = (alerts || []).map(alert => ({
      ...alert,
      data_json: alert.data_json ? JSON.parse(alert.data_json) : null
    }));

    res.json({ alerts: parsed });
  });
});

/**
 * POST /api/coach/notes
 * Add coach note (for interventions or general)
 */
router.post('/coach/notes', [
  body('user_intervention_id').optional().isInt(),
  body('note_text').notEmpty().withMessage('Note text is required'),
  body('tags').optional().isArray()
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const coachId = req.user.userId;
  const { user_intervention_id, note_text, tags } = req.body;
  const db = getDatabase();

  if (user_intervention_id) {
    // Add note to intervention
    db.run(`
      INSERT INTO intervention_coach_notes (
        user_intervention_id, coach_id, note_text, tags_json
      ) VALUES (?, ?, ?, ?)
    `, [user_intervention_id, coachId, note_text, tags ? JSON.stringify(tags) : null], function(err) {
      if (err) {
        return res.status(500).json({ error: 'Failed to save note' });
      }

      res.json({
        success: true,
        message: 'Note saved',
        note_id: this.lastID
      });
    });
  } else {
    // General note (could be stored in a separate table)
    res.status(400).json({ error: 'user_intervention_id is required' });
  }
});

module.exports = router;

