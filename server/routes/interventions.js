const express = require('express');
const { getDatabase } = require('../database/init');
const { authenticateToken } = require('../middleware/auth');
const { body, validationResult, query, param } = require('express-validator');

const router = express.Router();

// All intervention routes require authentication
router.use(authenticateToken);

/**
 * USER ENDPOINTS
 */

/**
 * GET /api/user/interventions/active
 * Get user's active interventions
 */
router.get('/user/interventions/active', (req, res) => {
  const userId = req.user.userId;
  const db = getDatabase();

  db.all(`
    SELECT 
      ui.*,
      i.name as intervention_name,
      i.type as intervention_type,
      i.category,
      i.primary_benefit,
      i.instructions_text
    FROM user_interventions ui
    JOIN interventions i ON ui.intervention_id = i.id
    WHERE ui.user_id = ? AND ui.status = 'active'
    ORDER BY ui.assigned_at DESC
  `, [userId], (err, interventions) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    // Parse JSON fields
    const parsed = (interventions || []).map(int => ({
      ...int,
      schedule_json: int.schedule_json ? JSON.parse(int.schedule_json) : null
    }));

    res.json({ interventions: parsed });
  });
});

/**
 * GET /api/user/interventions/past
 * Get user's past/completed interventions
 */
router.get('/user/interventions/past', [
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt()
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const userId = req.user.userId;
  const limit = req.query.limit || 20;
  const db = getDatabase();

  db.all(`
    SELECT 
      ui.*,
      i.name as intervention_name,
      i.type as intervention_type,
      i.category
    FROM user_interventions ui
    JOIN interventions i ON ui.intervention_id = i.id
    WHERE ui.user_id = ? AND ui.status != 'active'
    ORDER BY ui.assigned_at DESC
    LIMIT ?
  `, [userId, limit], (err, interventions) => {
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

/**
 * GET /api/user/interventions/:id
 * Get specific intervention details
 */
router.get('/user/interventions/:id', [
  param('id').isInt()
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const userId = req.user.userId;
  const interventionId = req.params.id;
  const db = getDatabase();

  db.get(`
    SELECT 
      ui.*,
      i.*,
      i.name as intervention_name
    FROM user_interventions ui
    JOIN interventions i ON ui.intervention_id = i.id
    WHERE ui.id = ? AND ui.user_id = ?
  `, [interventionId, userId], (err, intervention) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    if (!intervention) {
      return res.status(404).json({ error: 'Intervention not found' });
    }

    // Get compliance data
    db.all(`
      SELECT * FROM intervention_compliance
      WHERE user_intervention_id = ?
      ORDER BY scheduled_date DESC
      LIMIT 30
    `, [interventionId], (err, compliance) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      // Get user notes
      db.all(`
        SELECT * FROM intervention_user_notes
        WHERE user_intervention_id = ?
        ORDER BY created_at DESC
      `, [interventionId], (err, notes) => {
        if (err) {
          return res.status(500).json({ error: 'Database error' });
        }

        // Parse JSON fields
        const parsed = {
          ...intervention,
          schedule_json: intervention.schedule_json ? JSON.parse(intervention.schedule_json) : null,
          available_frequencies_json: intervention.available_frequencies_json ? JSON.parse(intervention.available_frequencies_json) : null,
          duration_impact_json: intervention.duration_impact_json ? JSON.parse(intervention.duration_impact_json) : null,
          contraindications_json: intervention.contraindications_json ? JSON.parse(intervention.contraindications_json) : null,
          interactions_json: intervention.interactions_json ? JSON.parse(intervention.interactions_json) : null,
          compliance: compliance || [],
          notes: notes || []
        };

        res.json({ intervention: parsed });
      });
    });
  });
});

/**
 * POST /api/user/interventions/:id/complete
 * Mark intervention task as completed
 */
router.post('/user/interventions/:id/complete', [
  param('id').isInt(),
  body('scheduled_date').isISO8601().withMessage('Valid date required'),
  body('note').optional().isString()
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const userId = req.user.userId;
  const interventionId = req.params.id;
  const { scheduled_date, note } = req.body;
  const db = getDatabase();

  // Verify intervention belongs to user
  db.get(`
    SELECT id FROM user_interventions
    WHERE id = ? AND user_id = ?
  `, [interventionId, userId], (err, intervention) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    if (!intervention) {
      return res.status(404).json({ error: 'Intervention not found' });
    }

    // Update or insert compliance record
    db.run(`
      INSERT INTO intervention_compliance (
        user_intervention_id, scheduled_date, completed, completed_at, note_text
      ) VALUES (?, ?, 1, CURRENT_TIMESTAMP, ?)
      ON CONFLICT(user_intervention_id, scheduled_date) DO UPDATE SET
        completed = 1,
        completed_at = CURRENT_TIMESTAMP,
        note_text = excluded.note_text
    `, [interventionId, scheduled_date, note || null], function(err) {
      if (err) {
        return res.status(500).json({ error: 'Failed to record completion' });
      }

      res.json({
        success: true,
        message: 'Intervention task completed',
        compliance_id: this.lastID
      });
    });
  });
});

/**
 * POST /api/user/interventions/:id/note
 * Add user note to intervention
 */
router.post('/user/interventions/:id/note', [
  param('id').isInt(),
  body('note_text').notEmpty().withMessage('Note text is required'),
  body('mood_rating').optional().isInt({ min: 1, max: 10 })
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const userId = req.user.userId;
  const interventionId = req.params.id;
  const { note_text, mood_rating } = req.body;
  const db = getDatabase();

  // Verify intervention belongs to user
  db.get(`
    SELECT id FROM user_interventions
    WHERE id = ? AND user_id = ?
  `, [interventionId, userId], (err, intervention) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    if (!intervention) {
      return res.status(404).json({ error: 'Intervention not found' });
    }

    db.run(`
      INSERT INTO intervention_user_notes (
        user_intervention_id, note_text, mood_rating
      ) VALUES (?, ?, ?)
    `, [interventionId, note_text, mood_rating || null], function(err) {
      if (err) {
        return res.status(500).json({ error: 'Failed to save note' });
      }

      res.json({
        success: true,
        message: 'Note saved',
        note_id: this.lastID
      });
    });
  });
});

/**
 * COACH ENDPOINTS
 */

/**
 * GET /api/coach/interventions/library
 * Get intervention library (for coaches)
 */
router.get('/coach/interventions/library', [
  query('category').optional().isString(),
  query('status').optional().isIn(['active', 'archived', 'draft'])
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const { category, status = 'active' } = req.query;
  const db = getDatabase();

  let query = 'SELECT * FROM interventions WHERE status = ?';
  const params = [status];

  if (category) {
    query += ' AND category = ?';
    params.push(category);
  }

  query += ' ORDER BY name';

  db.all(query, params, (err, interventions) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    // Parse JSON fields
    const parsed = (interventions || []).map(int => ({
      ...int,
      available_frequencies_json: int.available_frequencies_json ? JSON.parse(int.available_frequencies_json) : null,
      duration_impact_json: int.duration_impact_json ? JSON.parse(int.duration_impact_json) : null,
      contraindications_json: int.contraindications_json ? JSON.parse(int.contraindications_json) : null,
      interactions_json: int.interactions_json ? JSON.parse(int.interactions_json) : null
    }));

    res.json({ interventions: parsed });
  });
});

/**
 * POST /api/coach/interventions
 * Create new intervention (coach only)
 */
router.post('/coach/interventions', [
  body('name').notEmpty().withMessage('Name is required'),
  body('type').optional().isString(),
  body('category').optional().isString(),
  body('instructions_text').notEmpty().withMessage('Instructions are required')
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  // TODO: Verify user is a coach
  const coachId = req.user.userId; // For now, using userId
  const db = getDatabase();

  const {
    name, type, category, evidence_score, recommended_duration_weeks,
    min_duration, max_duration, recommended_frequency, available_frequencies_json,
    duration_impact_json, safety_rating, contraindications_json,
    interactions_json, primary_benefit, instructions_text
  } = req.body;

  db.run(`
    INSERT INTO interventions (
      name, type, category, evidence_score, recommended_duration_weeks,
      min_duration, max_duration, recommended_frequency, available_frequencies_json,
      duration_impact_json, safety_rating, contraindications_json,
      interactions_json, primary_benefit, instructions_text, created_by_coach_id
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `, [
    name, type || null, category || null, evidence_score || null,
    recommended_duration_weeks || null, min_duration || null, max_duration || null,
    recommended_frequency || null,
    available_frequencies_json ? JSON.stringify(available_frequencies_json) : null,
    duration_impact_json ? JSON.stringify(duration_impact_json) : null,
    safety_rating || null,
    contraindications_json ? JSON.stringify(contraindications_json) : null,
    interactions_json ? JSON.stringify(interactions_json) : null,
    primary_benefit || null, instructions_text, coachId
  ], function(err) {
    if (err) {
      return res.status(500).json({ error: 'Failed to create intervention' });
    }

    res.status(201).json({
      success: true,
      message: 'Intervention created',
      intervention_id: this.lastID
    });
  });
});

/**
 * POST /api/coach/interventions/assign
 * Assign intervention to user
 */
router.post('/coach/interventions/assign', [
  body('user_id').isInt().withMessage('User ID is required'),
  body('intervention_id').isInt().withMessage('Intervention ID is required'),
  body('start_date').isISO8601().withMessage('Start date is required'),
  body('frequency').notEmpty().withMessage('Frequency is required')
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const coachId = req.user.userId;
  const { user_id, intervention_id, start_date, end_date, frequency, schedule_json, dosage, timing, form, custom_instructions } = req.body;
  const db = getDatabase();

  db.run(`
    INSERT INTO user_interventions (
      user_id, intervention_id, assigned_by_coach_id, start_date, end_date,
      frequency, schedule_json, dosage, timing, form, custom_instructions
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `, [
    user_id, intervention_id, coachId, start_date, end_date || null,
    frequency, schedule_json ? JSON.stringify(schedule_json) : null,
    dosage || null, timing || null, form || null, custom_instructions || null
  ], function(err) {
    if (err) {
      return res.status(500).json({ error: 'Failed to assign intervention' });
    }

    res.status(201).json({
      success: true,
      message: 'Intervention assigned',
      user_intervention_id: this.lastID
    });
  });
});

module.exports = router;

