const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

// Ensure database directory exists
const dbDir = __dirname;
if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

const DB_PATH = path.join(dbDir, 'zoe.db');

let db = null;

function getDatabase() {
  if (!db) {
    db = new sqlite3.Database(DB_PATH, (err) => {
      if (err) {
        console.error('Error opening database:', err);
      } else {
        console.log('Connected to SQLite database');
      }
    });
  }
  return db;
}

function initDatabase() {
  return new Promise((resolve, reject) => {
    const database = getDatabase();

    // Create users table
    database.run(`
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        email TEXT,
        current_day INTEGER DEFAULT 1,
        started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_accessed DATETIME DEFAULT CURRENT_TIMESTAMP,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `, (err) => {
      if (err) {
        console.error('Error creating users table:', err);
        reject(err);
        return;
      }

      // Add email column if it doesn't exist (for migrations)
      database.run(`
        ALTER TABLE users ADD COLUMN email TEXT
      `, (err) => {
        // Ignore error if column already exists
        if (err && !err.message.includes('duplicate column')) {
          console.warn('Warning: Could not add email column:', err.message);
        }
      });

      // Create days table
      database.run(`
        CREATE TABLE IF NOT EXISTS days (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          day_number INTEGER NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          theme_color TEXT,
          background_image TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(day_number)
        )
      `, (err) => {
        if (err) {
          console.error('Error creating days table:', err);
          reject(err);
          return;
        }

        // Create questions table
        database.run(`
          CREATE TABLE IF NOT EXISTS questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            day_id INTEGER NOT NULL,
            question_text TEXT NOT NULL,
            question_type TEXT NOT NULL,
            options TEXT,
            order_index INTEGER NOT NULL,
            required BOOLEAN DEFAULT 1,
            conditional_logic TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (day_id) REFERENCES days(id) ON DELETE CASCADE
          )
        `, (err) => {
          if (err) {
            console.error('Error creating questions table:', err);
            reject(err);
            return;
          }

          // Create responses table
          database.run(`
            CREATE TABLE IF NOT EXISTS responses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL,
              question_id INTEGER NOT NULL,
              day_id INTEGER NOT NULL,
              response_value TEXT,
              response_data TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
              FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE,
              FOREIGN KEY (day_id) REFERENCES days(id) ON DELETE CASCADE,
              UNIQUE(user_id, question_id)
            )
          `, (err) => {
            if (err) {
              console.error('Error creating responses table:', err);
              reject(err);
              return;
            }

            // Create user_progress table
            database.run(`
              CREATE TABLE IF NOT EXISTS user_progress (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                day_id INTEGER NOT NULL,
                completed BOOLEAN DEFAULT 0,
                completed_at DATETIME,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (day_id) REFERENCES days(id) ON DELETE CASCADE,
                UNIQUE(user_id, day_id)
              )
            `, (err) => {
              if (err) {
                console.error('Error creating user_progress table:', err);
                reject(err);
                return;
              }

          // Create assessment tables
          database.run(`
            CREATE TABLE IF NOT EXISTS assessment_questions (
              question_id TEXT PRIMARY KEY,
              question_text TEXT NOT NULL,
              pillar TEXT,
              tier TEXT,
              question_type TEXT,
              options_json TEXT,
              estimated_time REAL,
              trigger TEXT,
              notes TEXT
            )
          `, (err) => {
            if (err) {
              console.error('Error creating assessment_questions table:', err);
              reject(err);
              return;
            }

            database.run(`
              CREATE TABLE IF NOT EXISTS assessment_modules (
                module_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                pillar TEXT,
                tier TEXT,
                module_type TEXT,
                estimated_minutes REAL,
                default_day_number INTEGER,
                repeat_interval INTEGER
              )
            `, (err) => {
              if (err) {
                console.error('Error creating assessment_modules table:', err);
                reject(err);
                return;
              }

              database.run(`
                CREATE TABLE IF NOT EXISTS module_questions (
                  module_id TEXT NOT NULL,
                  question_id TEXT NOT NULL,
                  order_index INTEGER NOT NULL,
                  PRIMARY KEY (module_id, order_index),
                  UNIQUE(module_id, question_id),
                  FOREIGN KEY(module_id) REFERENCES assessment_modules(module_id) ON DELETE CASCADE,
                  FOREIGN KEY(question_id) REFERENCES assessment_questions(question_id) ON DELETE CASCADE
                )
              `, (err) => {
                if (err) {
                  console.error('Error creating module_questions table:', err);
                  reject(err);
                  return;
                }

                database.run(`
                  CREATE TABLE IF NOT EXISTS day_modules (
                    day_number INTEGER NOT NULL,
                    module_id TEXT NOT NULL,
                    order_index INTEGER NOT NULL,
                    PRIMARY KEY(day_number, module_id),
                    FOREIGN KEY(module_id) REFERENCES assessment_modules(module_id) ON DELETE CASCADE
                  )
                `, (err) => {
                  if (err) {
                    console.error('Error creating day_modules table:', err);
                    reject(err);
                    return;
                  }

                  database.run(`
                    CREATE TABLE IF NOT EXISTS module_gateways (
                      id INTEGER PRIMARY KEY AUTOINCREMENT,
                      gateway_question_id TEXT NOT NULL,
                      condition TEXT NOT NULL,
                      target_module_id TEXT NOT NULL,
                      FOREIGN KEY(gateway_question_id) REFERENCES assessment_questions(question_id),
                      FOREIGN KEY(target_module_id) REFERENCES assessment_modules(module_id)
                    )
                  `, (err) => {
                    if (err) {
                      console.error('Error creating module_gateways table:', err);
                      reject(err);
                      return;
                    }

                    database.run(`
                      CREATE TABLE IF NOT EXISTS sleep_diary_questions (
                        id TEXT PRIMARY KEY,
                        question_text TEXT NOT NULL,
                        question_type TEXT NOT NULL,
                        options_json TEXT,
                        group_key TEXT,
                        help_text TEXT,
                        condition_json TEXT,
                        estimated_time REAL
                      )
                    `, (err) => {
                      if (err) {
                        console.error('Error creating sleep_diary_questions table:', err);
                        reject(err);
                        return;
                      }

                      // Create refresh_tokens table for JWT refresh token rotation
                      database.run(`
                        CREATE TABLE IF NOT EXISTS refresh_tokens (
                          id INTEGER PRIMARY KEY AUTOINCREMENT,
                          user_id INTEGER NOT NULL,
                          token TEXT UNIQUE NOT NULL,
                          expires_at DATETIME NOT NULL,
                          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                          revoked BOOLEAN DEFAULT 0,
                          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                      `, (err) => {
                        if (err) {
                          console.error('Error creating refresh_tokens table:', err);
                          reject(err);
                          return;
                        }

                        // Create index for faster lookups
                        database.run(`
                          CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id)
                        `, (err) => {
                          if (err) {
                            console.error('Error creating refresh_tokens index:', err);
                          }

                          // Create health data tables
                          createHealthDataTables(database, (err) => {
                            if (err) {
                              reject(err);
                              return;
                            }

                            // Create interventions tables
                            createInterventionsTables(database, (err) => {
                              if (err) {
                                reject(err);
                                return;
                              }

                              // Create coach dashboard tables
                              createCoachDashboardTables(database, (err) => {
                                if (err) {
                                  reject(err);
                                  return;
                                }

                                // Create sleep report tables
                                createSleepReportTables(database, (err) => {
                                  if (err) {
                                    reject(err);
                                    return;
                                  }

                                  initializeAssessmentData(database)
                                    .then(() => initializeDefaultData(database))
                                    .then(resolve)
                                    .catch(reject);
                                });
                              });
                            });
                          });
                        });
                      });
                    });
                  });
                });
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

// Health Data Storage Tables
function createHealthDataTables(database, callback) {
  // Apple Health Sleep Data
  database.run(`
    CREATE TABLE IF NOT EXISTS user_sleep_data (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      date DATE NOT NULL,
      in_bed_time DATETIME,
      asleep_time DATETIME,
      wake_time DATETIME,
      total_sleep_mins INTEGER,
      sleep_efficiency REAL,
      deep_sleep_mins INTEGER,
      light_sleep_mins INTEGER,
      rem_sleep_mins INTEGER,
      awake_mins INTEGER,
      interruptions_count INTEGER DEFAULT 0,
      sleep_latency_mins INTEGER,
      synced_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(user_id, date)
    )
  `, (err) => {
    if (err) {
      callback(err);
      return;
    }

    // Sleep Stages (detailed)
    database.run(`
      CREATE TABLE IF NOT EXISTS user_sleep_stages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        date DATE NOT NULL,
        start_time DATETIME NOT NULL,
        end_time DATETIME NOT NULL,
        stage TEXT NOT NULL,
        duration_mins INTEGER,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    `, (err) => {
      if (err) {
        callback(err);
        return;
      }

      // Heart Rate Data
      database.run(`
        CREATE TABLE IF NOT EXISTS user_heart_rate (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          date DATE NOT NULL,
          resting_hr INTEGER,
          avg_hr INTEGER,
          hrv_morning REAL,
          hrv_avg REAL,
          synced_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          UNIQUE(user_id, date)
        )
      `, (err) => {
        if (err) {
          callback(err);
          return;
        }

        // Activity Data
        database.run(`
          CREATE TABLE IF NOT EXISTS user_activity (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            date DATE NOT NULL,
            steps INTEGER DEFAULT 0,
            active_mins INTEGER DEFAULT 0,
            exercise_mins INTEGER DEFAULT 0,
            calories_burned INTEGER DEFAULT 0,
            synced_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            UNIQUE(user_id, date)
          )
        `, (err) => {
          if (err) {
            callback(err);
            return;
          }

          // Workouts
          database.run(`
            CREATE TABLE IF NOT EXISTS user_workouts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL,
              date DATE NOT NULL,
              workout_type TEXT,
              start_time DATETIME,
              duration_mins INTEGER,
              avg_hr INTEGER,
              max_hr INTEGER,
              calories INTEGER,
              distance_km REAL,
              intensity_zones_json TEXT,
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
          `, (err) => {
            if (err) {
              callback(err);
              return;
            }

            // Baselines (30-day rolling averages)
            database.run(`
              CREATE TABLE IF NOT EXISTS user_baselines (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                metric_name TEXT NOT NULL,
                baseline_value REAL NOT NULL,
                calculated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                period_days INTEGER DEFAULT 30,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                UNIQUE(user_id, metric_name)
              )
            `, (err) => {
              if (err) {
                callback(err);
                return;
              }

              // Create indexes for health data
              database.run(`CREATE INDEX IF NOT EXISTS idx_sleep_data_user_date ON user_sleep_data(user_id, date)`);
              database.run(`CREATE INDEX IF NOT EXISTS idx_sleep_stages_user_date ON user_sleep_stages(user_id, date)`);
              database.run(`CREATE INDEX IF NOT EXISTS idx_heart_rate_user_date ON user_heart_rate(user_id, date)`);
              database.run(`CREATE INDEX IF NOT EXISTS idx_activity_user_date ON user_activity(user_id, date)`);
              database.run(`CREATE INDEX IF NOT EXISTS idx_workouts_user_date ON user_workouts(user_id, date)`);

              callback(null);
            });
          });
        });
      });
    });
  });
}

// Interventions System Tables
function createInterventionsTables(database, callback) {
  // Intervention Library
  database.run(`
    CREATE TABLE IF NOT EXISTS interventions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT,
      category TEXT,
      evidence_score INTEGER,
      recommended_duration_weeks INTEGER,
      min_duration INTEGER,
      max_duration INTEGER,
      recommended_frequency TEXT,
      available_frequencies_json TEXT,
      duration_impact_json TEXT,
      safety_rating INTEGER,
      contraindications_json TEXT,
      interactions_json TEXT,
      primary_benefit TEXT,
      instructions_text TEXT,
      created_by_coach_id INTEGER,
      status TEXT DEFAULT 'active',
      version INTEGER DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (created_by_coach_id) REFERENCES coaches(id) ON DELETE SET NULL
    )
  `, (err) => {
    if (err) {
      callback(err);
      return;
    }

    // Assigned Interventions
    database.run(`
      CREATE TABLE IF NOT EXISTS user_interventions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        intervention_id INTEGER NOT NULL,
        assigned_by_coach_id INTEGER,
        start_date DATE NOT NULL,
        end_date DATE,
        frequency TEXT,
        schedule_json TEXT,
        dosage TEXT,
        timing TEXT,
        form TEXT,
        custom_instructions TEXT,
        status TEXT DEFAULT 'active',
        assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (intervention_id) REFERENCES interventions(id) ON DELETE CASCADE,
        FOREIGN KEY (assigned_by_coach_id) REFERENCES coaches(id) ON DELETE SET NULL
      )
    `, (err) => {
      if (err) {
        callback(err);
        return;
      }

      // Compliance Tracking
      database.run(`
        CREATE TABLE IF NOT EXISTS intervention_compliance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_intervention_id INTEGER NOT NULL,
          scheduled_date DATE NOT NULL,
          completed BOOLEAN DEFAULT 0,
          completed_at DATETIME,
          note_text TEXT,
          FOREIGN KEY (user_intervention_id) REFERENCES user_interventions(id) ON DELETE CASCADE,
          UNIQUE(user_intervention_id, scheduled_date)
        )
      `, (err) => {
        if (err) {
          callback(err);
          return;
        }

        // User Notes on Interventions
        database.run(`
          CREATE TABLE IF NOT EXISTS intervention_user_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_intervention_id INTEGER NOT NULL,
            note_text TEXT NOT NULL,
            mood_rating INTEGER,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_intervention_id) REFERENCES user_interventions(id) ON DELETE CASCADE
          )
        `, (err) => {
          if (err) {
            callback(err);
            return;
          }

          // Coach Notes (internal)
          database.run(`
            CREATE TABLE IF NOT EXISTS intervention_coach_notes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_intervention_id INTEGER NOT NULL,
              coach_id INTEGER NOT NULL,
              note_text TEXT NOT NULL,
              tags_json TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (user_intervention_id) REFERENCES user_interventions(id) ON DELETE CASCADE,
              FOREIGN KEY (coach_id) REFERENCES coaches(id) ON DELETE CASCADE
            )
          `, (err) => {
            if (err) {
              callback(err);
              return;
            }

            // Create indexes
            database.run(`CREATE INDEX IF NOT EXISTS idx_user_interventions_user ON user_interventions(user_id, status)`);
            database.run(`CREATE INDEX IF NOT EXISTS idx_compliance_intervention_date ON intervention_compliance(user_intervention_id, scheduled_date)`);

            callback(null);
          });
        });
      });
    });
  });
}

// Coach Dashboard Tables
function createCoachDashboardTables(database, callback) {
  // Coaches
  database.run(`
    CREATE TABLE IF NOT EXISTS coaches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      role TEXT,
      permissions_json TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `, (err) => {
    if (err) {
      callback(err);
      return;
    }

    // Customer-Coach Assignment
    database.run(`
      CREATE TABLE IF NOT EXISTS customer_coach_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        coach_id INTEGER NOT NULL,
        assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        status TEXT DEFAULT 'active',
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (coach_id) REFERENCES coaches(id) ON DELETE CASCADE,
        UNIQUE(user_id, coach_id)
      )
    `, (err) => {
      if (err) {
        callback(err);
        return;
      }

      // Alerts
      database.run(`
        CREATE TABLE IF NOT EXISTS alerts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          coach_id INTEGER,
          alert_type TEXT NOT NULL,
          severity TEXT DEFAULT 'medium',
          message TEXT NOT NULL,
          data_json TEXT,
          resolved BOOLEAN DEFAULT 0,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          resolved_at DATETIME,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY (coach_id) REFERENCES coaches(id) ON DELETE SET NULL
        )
      `, (err) => {
        if (err) {
          callback(err);
          return;
        }

        // Messages
        database.run(`
          CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_user_id INTEGER,
            to_user_id INTEGER NOT NULL,
            message_text TEXT NOT NULL,
            read_at DATETIME,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (from_user_id) REFERENCES users(id) ON DELETE SET NULL,
            FOREIGN KEY (to_user_id) REFERENCES users(id) ON DELETE CASCADE
          )
        `, (err) => {
          if (err) {
            callback(err);
            return;
          }

          // Create indexes
          database.run(`CREATE INDEX IF NOT EXISTS idx_coach_assignments_coach ON customer_coach_assignments(coach_id, status)`);
          database.run(`CREATE INDEX IF NOT EXISTS idx_alerts_user_coach ON alerts(user_id, coach_id, resolved)`);
          database.run(`CREATE INDEX IF NOT EXISTS idx_messages_users ON messages(from_user_id, to_user_id, created_at)`);

          callback(null);
        });
      });
    });
  });
}

// Sleep Report Tables
function createSleepReportTables(database, callback) {
  // Sleep Reports
  database.run(`
    CREATE TABLE IF NOT EXISTS sleep_reports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      generated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      overall_score INTEGER,
      archetype TEXT,
      report_data_json TEXT,
      pdf_url TEXT,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `, (err) => {
    if (err) {
      callback(err);
      return;
    }

    // Report Sections
    database.run(`
      CREATE TABLE IF NOT EXISTS report_sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        section_num INTEGER NOT NULL,
        name TEXT NOT NULL,
        score INTEGER,
        strengths_json TEXT,
        issues_json TEXT,
        findings_json TEXT,
        FOREIGN KEY (report_id) REFERENCES sleep_reports(id) ON DELETE CASCADE,
        UNIQUE(report_id, section_num)
      )
    `, (err) => {
      if (err) {
        callback(err);
        return;
      }

      // Report Roadmap
      database.run(`
        CREATE TABLE IF NOT EXISTS report_roadmap (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          report_id INTEGER NOT NULL,
          quarterly_milestones_json TEXT,
          monthly_tasks_json TEXT,
          FOREIGN KEY (report_id) REFERENCES sleep_reports(id) ON DELETE CASCADE,
          UNIQUE(report_id)
        )
      `, (err) => {
        if (err) {
          callback(err);
          return;
        }

        // Create indexes
        database.run(`CREATE INDEX IF NOT EXISTS idx_reports_user ON sleep_reports(user_id, generated_at)`);
        database.run(`CREATE INDEX IF NOT EXISTS idx_report_sections_report ON report_sections(report_id)`);

        callback(null);
      });
    });
  });
}

async function initializeDefaultData(database) {
  return new Promise((resolve, reject) => {
    // Create hard-coded users (user1-user10 with password "1")
    const bcrypt = require('bcryptjs');
    const passwordHash = bcrypt.hashSync('1', 12); // Use 12 rounds for better security

    database.run('DELETE FROM users', (err) => {
      if (err) {
        console.error('Error clearing users:', err);
      }

      const userPromises = [];
      for (let i = 1; i <= 10; i++) {
        userPromises.push(
          new Promise((res, rej) => {
            database.run(
              'INSERT OR IGNORE INTO users (username, password_hash) VALUES (?, ?)',
              [`user${i}`, passwordHash],
              (err) => {
                if (err) rej(err);
                else res();
              }
            );
          })
        );
      }

      Promise.all(userPromises).then(() => {
        console.log('Created 10 default users (user1-user10)');

        // Initialize 14 days
        initializeDays(database).then(resolve).catch(reject);
      }).catch(reject);
    });
  });
}

function initializeDays(database) {
  return new Promise((resolve, reject) => {
    // Don't delete days - just ensure they exist
    // This prevents day IDs from changing
    const days = [
      { number: 1, title: 'Welcome to Your Sleep Journey', description: 'Let\'s get started!', theme: '#4F46E5' },
      { number: 2, title: 'Understanding Your Sleep Patterns', description: 'Tell us about your sleep', theme: '#7C3AED' },
      { number: 3, title: 'Sleep Environment', description: 'Your bedroom matters', theme: '#EC4899' },
      { number: 4, title: 'Daily Routines', description: 'Building healthy habits', theme: '#F59E0B' },
      { number: 5, title: 'Stress & Relaxation', description: 'Managing your mind', theme: '#10B981' },
      { number: 6, title: 'Nutrition & Sleep', description: 'Food and rest connection', theme: '#3B82F6' },
      { number: 7, title: 'Exercise & Activity', description: 'Movement for better sleep', theme: '#8B5CF6' },
      { number: 8, title: 'Sleep Quality Assessment', description: 'How are you feeling?', theme: '#EF4444' },
      { number: 9, title: 'Advanced Techniques', description: 'Next-level strategies', theme: '#06B6D4' },
      { number: 10, title: 'Tracking Progress', description: 'See how far you\'ve come', theme: '#84CC16' },
      { number: 11, title: 'Optimizing Your Routine', description: 'Fine-tuning your approach', theme: '#F97316' },
      { number: 12, title: 'Long-term Habits', description: 'Building sustainability', theme: '#14B8A6' },
      { number: 13, title: 'Reflection & Insights', description: 'What you\'ve learned', theme: '#6366F1' },
      { number: 14, title: 'Your Sleep Transformation', description: 'Celebrating your journey', theme: '#A855F7' },
    ];

    const dayPromises = days.map(day =>
      new Promise((res, rej) => {
        // Check if day already exists
        database.get(
          'SELECT id FROM days WHERE day_number = ?',
          [day.number],
          (err, existing) => {
            if (err) {
              rej(err);
              return;
            }

            if (existing) {
              // Day exists, update it if needed
              database.run(
                'UPDATE days SET title = ?, description = ?, theme_color = ? WHERE day_number = ?',
                [day.title, day.description, day.theme, day.number],
                (err) => {
                  if (err) rej(err);
                  else res();
                }
              );
            } else {
              // Day doesn't exist, insert it
              database.run(
                'INSERT INTO days (day_number, title, description, theme_color) VALUES (?, ?, ?, ?)',
                [day.number, day.title, day.description, day.theme],
                (err) => {
                  if (err) rej(err);
                  else res();
                }
              );
            }
          }
        );
      })
    );

    Promise.all(dayPromises).then(() => {
      console.log('Initialized 14 days (preserved existing day IDs)');
      resolve();
    }).catch(reject);
  });
}

function initializeAssessmentData(database) {
  return new Promise((resolve, reject) => {
    const dataDir = path.resolve(__dirname, '..', '..', 'data');
    const questionsPath = path.join(dataDir, 'sleep360_questions.json');
    const modulesPath = path.join(dataDir, 'assessment_modules.json');
    const dayPlanPath = path.join(dataDir, 'default_day_plan.json');
    const diaryPath = path.join(dataDir, 'sleep_diary_questions.json');

    if (!fs.existsSync(questionsPath) || !fs.existsSync(modulesPath) || !fs.existsSync(dayPlanPath)) {
      console.warn('Assessment data files not found. Skipping assessment initialization.');
      resolve();
      return;
    }

    database.get('SELECT COUNT(*) as count FROM assessment_questions', (err, row) => {
      if (err) {
        reject(err);
        return;
      }

      if (row && row.count > 0) {
        resolve();
        return;
      }

        const questions = JSON.parse(fs.readFileSync(questionsPath, 'utf8'));
        const modules = JSON.parse(fs.readFileSync(modulesPath, 'utf8'));
        const dayPlan = JSON.parse(fs.readFileSync(dayPlanPath, 'utf8'));
      const diaryQuestions = fs.existsSync(diaryPath) ? JSON.parse(fs.readFileSync(diaryPath, 'utf8')) : [];

      database.serialize(() => {
        const questionStmt = database.prepare(`
          INSERT INTO assessment_questions (question_id, question_text, pillar, tier, question_type, options_json, estimated_time, trigger, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);

        questions.forEach((q) => {
          questionStmt.run(
            q.id,
            q.text,
            q.pillar,
            q.tier,
            q.scaleType || null,
            q.options ? JSON.stringify(q.options) : null,
            q.timeMinutes || null,
            q.trigger || null,
            q.notes ? JSON.stringify(q.notes) : null
          );
        });

        questionStmt.finalize();

        const dayLookup = new Map();
        dayPlan.forEach((entry, index) => {
          if (!dayLookup.has(entry.moduleId)) {
            dayLookup.set(entry.moduleId, entry.dayNumber);
          }
        });

        const moduleStmt = database.prepare(`
          INSERT INTO assessment_modules (module_id, name, description, pillar, tier, module_type, estimated_minutes, default_day_number, repeat_interval)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);

        modules.forEach((mod) => {
          moduleStmt.run(
            mod.moduleId,
            mod.name,
            mod.description,
            mod.pillar,
            mod.tier,
            mod.moduleType,
            mod.estimatedMinutes || null,
            dayLookup.get(mod.moduleId) || null,
            null
          );
        });

        // Add diary module
        if (diaryQuestions.length > 0) {
          moduleStmt.run(
            'diary_daily',
            'Daily Sleep Diary',
            'Morning diary questions for tracking sleep (Stanford Sleep Diary).',
            'Sleep Diary',
            'CORE',
            'diary',
            diaryQuestions.reduce((sum, q) => sum + (q.estimatedMinutes || 0.3), 0),
            null,
            1
          );
        }

        moduleStmt.finalize();

        const moduleQuestionStmt = database.prepare(`
          INSERT INTO module_questions (module_id, question_id, order_index)
          VALUES (?, ?, ?)
        `);

        modules.forEach((mod) => {
          mod.questionIds.forEach((questionId, index) => {
            moduleQuestionStmt.run(mod.moduleId, questionId, index);
          });
        });

        moduleQuestionStmt.finalize();

        const dayModuleStmt = database.prepare(`
          INSERT INTO day_modules (day_number, module_id, order_index)
          VALUES (?, ?, ?)
        `);

        const dayOrderMap = new Map();
        dayPlan.forEach((entry) => {
          const key = entry.dayNumber;
          const position = dayOrderMap.get(key) || 0;
          dayModuleStmt.run(entry.dayNumber, entry.moduleId, position);
          dayOrderMap.set(key, position + 1);
        });

        dayModuleStmt.finalize();

        if (diaryQuestions.length > 0) {
          const diaryStmt = database.prepare(`
            INSERT INTO sleep_diary_questions (id, question_text, question_type, options_json, group_key, help_text, condition_json, estimated_time)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          `);

          diaryQuestions.forEach((q) => {
            diaryStmt.run(
              q.id,
              q.text,
              q.type,
              q.options ? JSON.stringify(q.options) : null,
              q.group || null,
              q.helpText || null,
              q.condition ? JSON.stringify(q.condition) : null,
              q.estimatedMinutes || null
            );
          });

          diaryStmt.finalize();
        }

        console.log('Assessment data initialized');
        resolve();
      });
    });
  });
}

module.exports = { getDatabase, initDatabase };

