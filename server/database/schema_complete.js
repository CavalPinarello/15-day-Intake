/**
 * Complete Database Schema Setup
 * Integrates all components: Onboarding, Daily App Use, Sleep Reports, Coach Dashboard, Supporting Systems
 */

const { getDatabase } = require('./init');

/**
 * Add missing fields and tables to integrate all components
 */
function completeSchemaSetup() {
  return new Promise((resolve, reject) => {
    const db = getDatabase();
    
    console.log('Setting up complete database schema...');
    
    // Add missing fields to users table
    db.serialize(() => {
      // Add apple_health_connected field
      db.run(`
        ALTER TABLE users ADD COLUMN apple_health_connected BOOLEAN DEFAULT 0
      `, (err) => {
        if (err && !err.message.includes('duplicate column')) {
          console.warn('Warning: Could not add apple_health_connected:', err.message);
        }
      });
      
      // Add onboarding_completed field
      db.run(`
        ALTER TABLE users ADD COLUMN onboarding_completed BOOLEAN DEFAULT 0
      `, (err) => {
        if (err && !err.message.includes('duplicate column')) {
          console.warn('Warning: Could not add onboarding_completed:', err.message);
        }
      });
      
      // Add onboarding_completed_at field
      db.run(`
        ALTER TABLE users ADD COLUMN onboarding_completed_at DATETIME
      `, (err) => {
        if (err && !err.message.includes('duplicate column')) {
          console.warn('Warning: Could not add onboarding_completed_at:', err.message);
        }
      });
      
      // Create onboarding_insights table (Component 1)
      db.run(`
        CREATE TABLE IF NOT EXISTS onboarding_insights (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          day_id INTEGER NOT NULL,
          insight_type TEXT NOT NULL,
          insight_text TEXT NOT NULL,
          generated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY (day_id) REFERENCES days(id) ON DELETE CASCADE,
          UNIQUE(user_id, day_id, insight_type)
        )
      `, (err) => {
        if (err) {
          console.error('Error creating onboarding_insights:', err);
          reject(err);
          return;
        }
        
        // Create daily_checkins table (Component 2: Daily App Use)
        db.run(`
          CREATE TABLE IF NOT EXISTS daily_checkins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            checkin_date DATE NOT NULL,
            checkin_type TEXT NOT NULL CHECK(checkin_type IN ('morning', 'evening')),
            completed BOOLEAN DEFAULT 0,
            completed_at DATETIME,
            data_json TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            UNIQUE(user_id, checkin_date, checkin_type)
          )
        `, (err) => {
          if (err) {
            console.error('Error creating daily_checkins:', err);
            reject(err);
            return;
          }
          
          // Create checkin_responses table for daily check-in questions
          db.run(`
            CREATE TABLE IF NOT EXISTS checkin_responses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              checkin_id INTEGER NOT NULL,
              question_key TEXT NOT NULL,
              response_value TEXT,
              response_data TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (checkin_id) REFERENCES daily_checkins(id) ON DELETE CASCADE,
              UNIQUE(checkin_id, question_key)
            )
          `, (err) => {
            if (err) {
              console.error('Error creating checkin_responses:', err);
              reject(err);
              return;
            }
            
            // Create user_preferences table
            db.run(`
              CREATE TABLE IF NOT EXISTS user_preferences (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL UNIQUE,
                notification_enabled BOOLEAN DEFAULT 1,
                notification_time TEXT DEFAULT '08:00',
                quiet_hours_start TEXT DEFAULT '22:00',
                quiet_hours_end TEXT DEFAULT '07:00',
                timezone TEXT DEFAULT 'UTC',
                apple_health_sync_enabled BOOLEAN DEFAULT 1,
                daily_reminder_enabled BOOLEAN DEFAULT 1,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
              )
            `, (err) => {
              if (err) {
                console.error('Error creating user_preferences:', err);
                reject(err);
                return;
              }
              
              // Create user_metrics_summary table (for quick access to aggregated data)
              db.run(`
                CREATE TABLE IF NOT EXISTS user_metrics_summary (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  user_id INTEGER NOT NULL,
                  metric_date DATE NOT NULL,
                  sleep_score REAL,
                  activity_score REAL,
                  compliance_score REAL,
                  overall_score REAL,
                  calculated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                  UNIQUE(user_id, metric_date)
                )
              `, (err) => {
                if (err) {
                  console.error('Error creating user_metrics_summary:', err);
                  reject(err);
                  return;
                }
                
                // Create intervention_schedule table for better scheduling
                db.run(`
                  CREATE TABLE IF NOT EXISTS intervention_schedule (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_intervention_id INTEGER NOT NULL,
                    scheduled_time TIME NOT NULL,
                    scheduled_days TEXT NOT NULL,
                    timezone TEXT DEFAULT 'UTC',
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_intervention_id) REFERENCES user_interventions(id) ON DELETE CASCADE
                  )
                `, (err) => {
                  if (err) {
                    console.error('Error creating intervention_schedule:', err);
                    reject(err);
                    return;
                  }
                  
                  // Create indexes for performance
                  createPerformanceIndexes(db, (err) => {
                    if (err) {
                      reject(err);
                      return;
                    }
                    
                    console.log('✓ Complete database schema setup finished');
                    resolve();
                  });
                });
              });
            });
          });
        });
      });
    });
  });
}

/**
 * Create performance indexes
 */
function createPerformanceIndexes(db, callback) {
  const indexes = [
    // User-related indexes
    'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)',
    'CREATE INDEX IF NOT EXISTS idx_users_onboarding ON users(onboarding_completed, current_day)',
    
    // Onboarding indexes
    'CREATE INDEX IF NOT EXISTS idx_onboarding_insights_user_day ON onboarding_insights(user_id, day_id)',
    'CREATE INDEX IF NOT EXISTS idx_responses_user_day ON responses(user_id, day_id)',
    'CREATE INDEX IF NOT EXISTS idx_user_progress_user_day ON user_progress(user_id, day_id)',
    
    // Daily check-ins indexes
    'CREATE INDEX IF NOT EXISTS idx_checkins_user_date ON daily_checkins(user_id, checkin_date)',
    'CREATE INDEX IF NOT EXISTS idx_checkins_user_type ON daily_checkins(user_id, checkin_type)',
    
    // Health data indexes (already created, but ensure they exist)
    'CREATE INDEX IF NOT EXISTS idx_sleep_data_user_date ON user_sleep_data(user_id, date)',
    'CREATE INDEX IF NOT EXISTS idx_heart_rate_user_date ON user_heart_rate(user_id, date)',
    'CREATE INDEX IF NOT EXISTS idx_activity_user_date ON user_activity(user_id, date)',
    
    // Interventions indexes
    'CREATE INDEX IF NOT EXISTS idx_user_interventions_user_status ON user_interventions(user_id, status)',
    'CREATE INDEX IF NOT EXISTS idx_compliance_intervention_date ON intervention_compliance(user_intervention_id, scheduled_date)',
    
    // Coach dashboard indexes
    'CREATE INDEX IF NOT EXISTS idx_coach_assignments_coach_status ON customer_coach_assignments(coach_id, status)',
    'CREATE INDEX IF NOT EXISTS idx_alerts_user_coach_resolved ON alerts(user_id, coach_id, resolved)',
    
    // Reports indexes
    'CREATE INDEX IF NOT EXISTS idx_reports_user_generated ON sleep_reports(user_id, generated_at)',
    
    // Metrics summary index
    'CREATE INDEX IF NOT EXISTS idx_metrics_summary_user_date ON user_metrics_summary(user_id, metric_date)'
  ];
  
  let completed = 0;
  const total = indexes.length;
  
  indexes.forEach((indexSQL) => {
    db.run(indexSQL, (err) => {
      if (err) {
        console.warn(`Warning: Could not create index: ${err.message}`);
      }
      completed++;
      if (completed === total) {
        callback(null);
      }
    });
  });
}

/**
 * Verify database integrity
 */
function verifyDatabaseIntegrity() {
  return new Promise((resolve, reject) => {
    const db = getDatabase();
    
    console.log('Verifying database integrity...');
    
    const requiredTables = [
      'users', 'days', 'questions', 'responses', 'user_progress',
      'refresh_tokens', 'onboarding_insights', 'daily_checkins', 'checkin_responses',
      'user_preferences', 'user_metrics_summary',
      'user_sleep_data', 'user_sleep_stages', 'user_heart_rate', 
      'user_activity', 'user_workouts', 'user_baselines',
      'interventions', 'user_interventions', 'intervention_compliance',
      'intervention_user_notes', 'intervention_coach_notes', 'intervention_schedule',
      'coaches', 'customer_coach_assignments', 'alerts', 'messages',
      'sleep_reports', 'report_sections', 'report_roadmap'
    ];
    
    let verified = 0;
    const total = requiredTables.length;
    
    requiredTables.forEach((tableName) => {
      db.get(`SELECT name FROM sqlite_master WHERE type='table' AND name=?`, [tableName], (err, row) => {
        if (err) {
          console.error(`Error checking table ${tableName}:`, err);
        } else if (!row) {
          console.warn(`⚠ Warning: Table ${tableName} does not exist`);
        } else {
          console.log(`  ✓ Table ${tableName} exists`);
        }
        
        verified++;
        if (verified === total) {
          console.log('✓ Database integrity check completed');
          resolve();
        }
      });
    });
  });
}

module.exports = {
  completeSchemaSetup,
  verifyDatabaseIntegrity,
  createPerformanceIndexes
};




