const express = require('express');
const { getDatabase } = require('../database/init');
const { authenticateToken } = require('../middleware/auth');
const { body, validationResult, query } = require('express-validator');

const router = express.Router();

// All health routes require authentication
router.use(authenticateToken);

/**
 * POST /api/health/sync
 * Bulk upload health data from device (Apple Health, etc.)
 */
router.post('/sync', [
  body('sleepData').optional().isArray(),
  body('heartRateData').optional().isArray(),
  body('activityData').optional().isArray(),
  body('workouts').optional().isArray(),
  body('sleepStages').optional().isArray()
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const { sleepData, heartRateData, activityData, workouts, sleepStages } = req.body;
  const userId = req.user.userId;
  const db = getDatabase();
  const results = {
    sleepData: { inserted: 0, updated: 0, errors: [] },
    heartRateData: { inserted: 0, updated: 0, errors: [] },
    activityData: { inserted: 0, updated: 0, errors: [] },
    workouts: { inserted: 0, errors: [] },
    sleepStages: { inserted: 0, errors: [] }
  };

  // Process sleep data
  if (sleepData && Array.isArray(sleepData)) {
    sleepData.forEach((data) => {
      db.run(`
        INSERT INTO user_sleep_data (
          user_id, date, in_bed_time, asleep_time, wake_time,
          total_sleep_mins, sleep_efficiency, deep_sleep_mins,
          light_sleep_mins, rem_sleep_mins, awake_mins,
          interruptions_count, sleep_latency_mins
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id, date) DO UPDATE SET
          in_bed_time = excluded.in_bed_time,
          asleep_time = excluded.asleep_time,
          wake_time = excluded.wake_time,
          total_sleep_mins = excluded.total_sleep_mins,
          sleep_efficiency = excluded.sleep_efficiency,
          deep_sleep_mins = excluded.deep_sleep_mins,
          light_sleep_mins = excluded.light_sleep_mins,
          rem_sleep_mins = excluded.rem_sleep_mins,
          awake_mins = excluded.awake_mins,
          interruptions_count = excluded.interruptions_count,
          sleep_latency_mins = excluded.sleep_latency_mins,
          synced_at = CURRENT_TIMESTAMP
      `, [
        userId, data.date, data.in_bed_time, data.asleep_time, data.wake_time,
        data.total_sleep_mins, data.sleep_efficiency, data.deep_sleep_mins,
        data.light_sleep_mins, data.rem_sleep_mins, data.awake_mins,
        data.interruptions_count || 0, data.sleep_latency_mins
      ], function(err) {
        if (err) {
          results.sleepData.errors.push({ date: data.date, error: err.message });
        } else {
          if (this.changes === 0) {
            results.sleepData.updated++;
          } else {
            results.sleepData.inserted++;
          }
        }
      });
    });
  }

  // Process heart rate data
  if (heartRateData && Array.isArray(heartRateData)) {
    heartRateData.forEach((data) => {
      db.run(`
        INSERT INTO user_heart_rate (
          user_id, date, resting_hr, avg_hr, hrv_morning, hrv_avg
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id, date) DO UPDATE SET
          resting_hr = excluded.resting_hr,
          avg_hr = excluded.avg_hr,
          hrv_morning = excluded.hrv_morning,
          hrv_avg = excluded.hrv_avg,
          synced_at = CURRENT_TIMESTAMP
      `, [
        userId, data.date, data.resting_hr, data.avg_hr,
        data.hrv_morning, data.hrv_avg
      ], function(err) {
        if (err) {
          results.heartRateData.errors.push({ date: data.date, error: err.message });
        } else {
          if (this.changes === 0) {
            results.heartRateData.updated++;
          } else {
            results.heartRateData.inserted++;
          }
        }
      });
    });
  }

  // Process activity data
  if (activityData && Array.isArray(activityData)) {
    activityData.forEach((data) => {
      db.run(`
        INSERT INTO user_activity (
          user_id, date, steps, active_mins, exercise_mins, calories_burned
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id, date) DO UPDATE SET
          steps = excluded.steps,
          active_mins = excluded.active_mins,
          exercise_mins = excluded.exercise_mins,
          calories_burned = excluded.calories_burned,
          synced_at = CURRENT_TIMESTAMP
      `, [
        userId, data.date, data.steps || 0, data.active_mins || 0,
        data.exercise_mins || 0, data.calories_burned || 0
      ], function(err) {
        if (err) {
          results.activityData.errors.push({ date: data.date, error: err.message });
        } else {
          if (this.changes === 0) {
            results.activityData.updated++;
          } else {
            results.activityData.inserted++;
          }
        }
      });
    });
  }

  // Process workouts
  if (workouts && Array.isArray(workouts)) {
    workouts.forEach((workout) => {
      db.run(`
        INSERT INTO user_workouts (
          user_id, date, workout_type, start_time, duration_mins,
          avg_hr, max_hr, calories, distance_km, intensity_zones_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        userId, workout.date, workout.workout_type, workout.start_time,
        workout.duration_mins, workout.avg_hr, workout.max_hr,
        workout.calories, workout.distance_km,
        workout.intensity_zones ? JSON.stringify(workout.intensity_zones) : null
      ], function(err) {
        if (err) {
          results.workouts.errors.push({ date: workout.date, error: err.message });
        } else {
          results.workouts.inserted++;
        }
      });
    });
  }

  // Process sleep stages
  if (sleepStages && Array.isArray(sleepStages)) {
    sleepStages.forEach((stage) => {
      db.run(`
        INSERT INTO user_sleep_stages (
          user_id, date, start_time, end_time, stage, duration_mins
        ) VALUES (?, ?, ?, ?, ?, ?)
      `, [
        userId, stage.date, stage.start_time, stage.end_time,
        stage.stage, stage.duration_mins
      ], function(err) {
        if (err) {
          results.sleepStages.errors.push({ date: stage.date, error: err.message });
        } else {
          results.sleepStages.inserted++;
        }
      });
    });
  }

  // Wait a bit for async operations to complete
  setTimeout(() => {
    res.json({
      success: true,
      message: 'Health data synced successfully',
      results
    });
  }, 500);
});

/**
 * GET /api/health/sleep/:date
 * Get sleep data for a specific date
 */
router.get('/sleep/:date', (req, res) => {
  const { date } = req.params;
  const userId = req.user.userId;
  const db = getDatabase();

  db.get(`
    SELECT * FROM user_sleep_data
    WHERE user_id = ? AND date = ?
  `, [userId, date], (err, sleepData) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    if (!sleepData) {
      return res.status(404).json({ error: 'Sleep data not found for this date' });
    }

    // Get sleep stages for this date
    db.all(`
      SELECT * FROM user_sleep_stages
      WHERE user_id = ? AND date = ?
      ORDER BY start_time
    `, [userId, date], (err, stages) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      res.json({
        sleepData,
        stages: stages || []
      });
    });
  });
});

/**
 * GET /api/health/sleep
 * Get sleep data for a date range
 */
router.get('/sleep', [
  query('startDate').optional().isISO8601(),
  query('endDate').optional().isISO8601(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt()
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const userId = req.user.userId;
  const { startDate, endDate, limit = 30 } = req.query;
  const db = getDatabase();

  let query = 'SELECT * FROM user_sleep_data WHERE user_id = ?';
  const params = [userId];

  if (startDate) {
    query += ' AND date >= ?';
    params.push(startDate);
  }
  if (endDate) {
    query += ' AND date <= ?';
    params.push(endDate);
  }

  query += ' ORDER BY date DESC LIMIT ?';
  params.push(limit);

  db.all(query, params, (err, sleepData) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    res.json({ sleepData: sleepData || [] });
  });
});

/**
 * GET /api/health/activity/:date
 * Get activity data for a specific date
 */
router.get('/activity/:date', (req, res) => {
  const { date } = req.params;
  const userId = req.user.userId;
  const db = getDatabase();

  db.get(`
    SELECT * FROM user_activity
    WHERE user_id = ? AND date = ?
  `, [userId, date], (err, activity) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    if (!activity) {
      return res.status(404).json({ error: 'Activity data not found for this date' });
    }

    res.json({ activity });
  });
});

/**
 * GET /api/health/activity
 * Get activity data for a date range
 */
router.get('/activity', [
  query('startDate').optional().isISO8601(),
  query('endDate').optional().isISO8601(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt()
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const userId = req.user.userId;
  const { startDate, endDate, limit = 30 } = req.query;
  const db = getDatabase();

  let query = 'SELECT * FROM user_activity WHERE user_id = ?';
  const params = [userId];

  if (startDate) {
    query += ' AND date >= ?';
    params.push(startDate);
  }
  if (endDate) {
    query += ' AND date <= ?';
    params.push(endDate);
  }

  query += ' ORDER BY date DESC LIMIT ?';
  params.push(limit);

  db.all(query, params, (err, activity) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    res.json({ activity: activity || [] });
  });
});

/**
 * GET /api/health/baselines
 * Get calculated baselines (30-day rolling averages)
 */
router.get('/baselines', (req, res) => {
  const userId = req.user.userId;
  const db = getDatabase();

  db.all(`
    SELECT * FROM user_baselines
    WHERE user_id = ?
    ORDER BY metric_name
  `, [userId], (err, baselines) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    res.json({ baselines: baselines || [] });
  });
});

/**
 * GET /api/health/workouts
 * Get workouts for a date range
 */
router.get('/workouts', [
  query('startDate').optional().isISO8601(),
  query('endDate').optional().isISO8601(),
  query('limit').optional().isInt({ min: 1, max: 100 }).toInt()
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const userId = req.user.userId;
  const { startDate, endDate, limit = 30 } = req.query;
  const db = getDatabase();

  let query = 'SELECT * FROM user_workouts WHERE user_id = ?';
  const params = [userId];

  if (startDate) {
    query += ' AND date >= ?';
    params.push(startDate);
  }
  if (endDate) {
    query += ' AND date <= ?';
    params.push(endDate);
  }

  query += ' ORDER BY date DESC, start_time DESC LIMIT ?';
  params.push(limit);

  db.all(query, params, (err, workouts) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    // Parse JSON fields
    const parsedWorkouts = (workouts || []).map(workout => ({
      ...workout,
      intensity_zones: workout.intensity_zones_json ? JSON.parse(workout.intensity_zones_json) : null
    }));

    res.json({ workouts: parsedWorkouts });
  });
});

/**
 * GET /api/health/summary
 * Get health summary for a date range
 */
router.get('/summary', [
  query('startDate').optional().isISO8601(),
  query('endDate').optional().isISO8601()
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const userId = req.user.userId;
  const { startDate, endDate } = req.query;
  const db = getDatabase();

  const start = startDate || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
  const end = endDate || new Date().toISOString().split('T')[0];

  // Get sleep summary
  db.get(`
    SELECT 
      AVG(total_sleep_mins) as avg_sleep_mins,
      AVG(sleep_efficiency) as avg_efficiency,
      AVG(deep_sleep_mins) as avg_deep_sleep,
      AVG(rem_sleep_mins) as avg_rem_sleep,
      COUNT(*) as days_count
    FROM user_sleep_data
    WHERE user_id = ? AND date >= ? AND date <= ?
  `, [userId, start, end], (err, sleepSummary) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    // Get activity summary
    db.get(`
      SELECT 
        AVG(steps) as avg_steps,
        AVG(active_mins) as avg_active_mins,
        AVG(exercise_mins) as avg_exercise_mins,
        SUM(calories_burned) as total_calories
      FROM user_activity
      WHERE user_id = ? AND date >= ? AND date <= ?
    `, [userId, start, end], (err, activitySummary) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      // Get heart rate summary
      db.get(`
        SELECT 
          AVG(resting_hr) as avg_resting_hr,
          AVG(hrv_morning) as avg_hrv
        FROM user_heart_rate
        WHERE user_id = ? AND date >= ? AND date <= ?
      `, [userId, start, end], (err, heartRateSummary) => {
        if (err) {
          return res.status(500).json({ error: 'Database error' });
        }

        res.json({
          period: { start, end },
          sleep: sleepSummary || {},
          activity: activitySummary || {},
          heartRate: heartRateSummary || {}
        });
      });
    });
  });
});

module.exports = router;

