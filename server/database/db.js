/**
 * Unified Database Interface
 * Supports both SQLite (development) and Convex (production)
 */

const USE_CONVEX = process.env.USE_CONVEX === 'true' || process.env.NODE_ENV === 'production';

let dbAdapter = null;

async function getDatabase() {
  if (!dbAdapter) {
    if (USE_CONVEX) {
      console.log('Using Convex database');
      const { getConvexAdapter } = require('./convexAdapter');
      dbAdapter = getConvexAdapter();
    } else {
      console.log('Using SQLite database');
      const { getDatabase: getSQLiteDatabase } = require('./init');
      dbAdapter = getSQLiteDatabase();
      // Wrap SQLite in a promise-based interface for consistency
      dbAdapter = wrapSQLite(dbAdapter);
    }
  }
  return dbAdapter;
}

/**
 * Wrap SQLite database to provide async/promise-based interface
 */
function wrapSQLite(sqliteDb) {
  return {
    // User operations
    async getUserByUsername(username) {
      return new Promise((resolve, reject) => {
        sqliteDb.get('SELECT * FROM users WHERE username = ?', [username], (err, row) => {
          if (err) reject(err);
          else resolve(row);
        });
      });
    },

    async getUserById(userId) {
      return new Promise((resolve, reject) => {
        sqliteDb.get('SELECT * FROM users WHERE id = ?', [userId], (err, row) => {
          if (err) reject(err);
          else resolve(row);
        });
      });
    },

    async createUser(userData) {
      return new Promise((resolve, reject) => {
        sqliteDb.run(
          'INSERT INTO users (username, password_hash, email, current_day) VALUES (?, ?, ?, ?)',
          [userData.username, userData.password_hash, userData.email || null, userData.current_day || 1],
          function(err) {
            if (err) reject(err);
            else resolve({ lastID: this.lastID, changes: this.changes });
          }
        );
      });
    },

    async loginUser(username, password) {
      // Get user for login (password comparison done server-side)
      return new Promise((resolve, reject) => {
        sqliteDb.get('SELECT * FROM users WHERE username = ?', [username], (err, user) => {
          if (err) reject(err);
          else resolve(user);
        });
      });
    },

    async getUserByUsernameOrEmail(identifier) {
      // Try username first, then email
      return new Promise((resolve, reject) => {
        sqliteDb.get('SELECT * FROM users WHERE username = ? OR email = ?', [identifier, identifier], (err, user) => {
          if (err) reject(err);
          else resolve(user);
        });
      });
    },

    async registerUser(userData) {
      // Check if username exists first
      const existing = await new Promise((resolve, reject) => {
        sqliteDb.get('SELECT id FROM users WHERE username = ?', [userData.username], (err, row) => {
          if (err) reject(err);
          else resolve(row);
        });
      });

      if (existing) {
        throw new Error('Username already exists');
      }

      // Check if email exists
      if (userData.email) {
        const existingEmail = await new Promise((resolve, reject) => {
          sqliteDb.get('SELECT id FROM users WHERE email = ?', [userData.email], (err, row) => {
            if (err) reject(err);
            else resolve(row);
          });
        });

        if (existingEmail) {
          throw new Error('Email already exists');
        }
      }

      // Insert user
      return new Promise((resolve, reject) => {
        sqliteDb.run(
          'INSERT INTO users (username, password_hash, email, current_day) VALUES (?, ?, ?, ?)',
          [userData.username, userData.password_hash, userData.email || null, 1],
          function(err) {
            if (err) reject(err);
            else resolve(this.lastID);
          }
        );
      });
    },

    async updateUserLastAccessed(userId) {
      return new Promise((resolve, reject) => {
        sqliteDb.run(
          'UPDATE users SET last_accessed = CURRENT_TIMESTAMP WHERE id = ?',
          [userId],
          function(err) {
            if (err) reject(err);
            else resolve({ changes: this.changes });
          }
        );
      });
    },

    async storeRefreshToken(userId, token, expiresAt) {
      // expiresAt is Unix timestamp, convert to ISO string for SQLite
      const expiresAtISO = new Date(expiresAt * 1000).toISOString();
      return new Promise((resolve, reject) => {
        sqliteDb.run(
          'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES (?, ?, ?)',
          [userId, token, expiresAtISO],
          function(err) {
            if (err) reject(err);
            else resolve({ lastID: this.lastID, changes: this.changes });
          }
        );
      });
    },

    async getRefreshToken(token) {
      return new Promise((resolve, reject) => {
        sqliteDb.get(
          `SELECT rt.*, u.* 
           FROM refresh_tokens rt 
           JOIN users u ON rt.user_id = u.id 
           WHERE rt.token = ? AND rt.revoked = 0 AND rt.expires_at > datetime('now')`,
          [token],
          (err, row) => {
            if (err) reject(err);
            else {
              if (row) {
                const { password_hash, ...user } = row;
                resolve({
                  ...row,
                  user,
                });
              } else {
                resolve(null);
              }
            }
          }
        );
      });
    },

    async revokeRefreshToken(token, userId) {
      return new Promise((resolve, reject) => {
        sqliteDb.run(
          'UPDATE refresh_tokens SET revoked = 1 WHERE token = ? AND user_id = ?',
          [token, userId],
          function(err) {
            if (err) reject(err);
            else resolve({ changes: this.changes });
          }
        );
      });
    },

    async updateUser(userId, updates) {
      const fields = [];
      const values = [];
      
      if (updates.current_day !== undefined) {
        fields.push('current_day = ?');
        values.push(updates.current_day);
      }
      if (updates.last_accessed !== undefined) {
        fields.push('last_accessed = CURRENT_TIMESTAMP');
      }
      if (updates.email !== undefined) {
        fields.push('email = ?');
        values.push(updates.email);
      }

      if (fields.length === 0) return { changes: 0 };

      values.push(userId);
      return new Promise((resolve, reject) => {
        sqliteDb.run(
          `UPDATE users SET ${fields.join(', ')} WHERE id = ?`,
          values,
          function(err) {
            if (err) reject(err);
            else resolve({ changes: this.changes });
          }
        );
      });
    },

    // Day operations
    async getAllDays() {
      return new Promise((resolve, reject) => {
        sqliteDb.all('SELECT * FROM days ORDER BY day_number', [], (err, rows) => {
          if (err) reject(err);
          else resolve(rows);
        });
      });
    },

    async getDayByNumber(dayNumber) {
      return new Promise((resolve, reject) => {
        sqliteDb.get('SELECT * FROM days WHERE day_number = ?', [dayNumber], (err, row) => {
          if (err) reject(err);
          else resolve(row);
        });
      });
    },

    // Question operations
    async getQuestionsByDay(dayId) {
      return new Promise((resolve, reject) => {
        sqliteDb.all(
          'SELECT * FROM questions WHERE day_id = ? ORDER BY order_index ASC',
          [dayId],
          (err, rows) => {
            if (err) reject(err);
            else {
              const questions = rows.map(q => ({
                ...q,
                options: q.options ? JSON.parse(q.options) : null,
                conditional_logic: q.conditional_logic ? JSON.parse(q.conditional_logic) : null,
              }));
              resolve(questions);
            }
          }
        );
      });
    },

    // Assessment operations
    async getMasterQuestions() {
      return new Promise((resolve, reject) => {
        sqliteDb.all(
          'SELECT question_id, question_text, pillar, tier, question_type, options_json, estimated_time, trigger, notes FROM assessment_questions ORDER BY pillar ASC, tier ASC, question_id ASC',
          [],
          (err, rows) => {
            if (err) reject(err);
            else resolve(rows);
          }
        );
      });
    },

    async getModules() {
      return new Promise((resolve, reject) => {
        sqliteDb.all(
          'SELECT module_id, name, description, pillar, tier, module_type, estimated_minutes, default_day_number, repeat_interval FROM assessment_modules ORDER BY tier ASC, pillar ASC, name ASC',
          [],
          (err, rows) => {
            if (err) reject(err);
            else resolve(rows);
          }
        );
      });
    },

    async getDayAssignments() {
      return new Promise((resolve, reject) => {
        sqliteDb.all(
          `SELECT dm.day_number, dm.module_id, dm.order_index, am.name as module_name, am.pillar, am.tier, am.module_type, am.estimated_minutes
           FROM day_modules dm
           JOIN assessment_modules am ON dm.module_id = am.module_id
           ORDER BY dm.day_number ASC, dm.order_index ASC`,
          [],
          (err, rows) => {
            if (err) reject(err);
            else {
              const dayAssignments = {};
              rows.forEach(assign => {
                if (!dayAssignments[assign.day_number]) {
                  dayAssignments[assign.day_number] = [];
                }
                dayAssignments[assign.day_number].push({
                  moduleId: assign.module_id,
                  moduleName: assign.module_name,
                  pillar: assign.pillar,
                  tier: assign.tier,
                  moduleType: assign.module_type,
                  estimatedMinutes: assign.estimated_minutes,
                  orderIndex: assign.order_index,
                });
              });
              resolve(dayAssignments);
            }
          }
        );
      });
    },

    async getAllUserNames() {
      return new Promise((resolve, reject) => {
        sqliteDb.all(
          `SELECT DISTINCT u.id, u.username, 
           (SELECT r.response_value 
            FROM user_assessment_responses r 
            WHERE r.user_id = u.id AND r.question_id = 'D1' 
            ORDER BY r.updated_at DESC 
            LIMIT 1) as name
           FROM users u
           WHERE u.username LIKE 'user%'
           ORDER BY u.id`,
          [],
          (err, rows) => {
            if (err) reject(err);
            else {
              const names = {};
              rows.forEach(row => {
                const userId = parseInt(row.id, 10);
                if (!isNaN(userId)) {
                  names[userId] = row.name || null;
                }
              });
              resolve({ names });
            }
          }
        );
      });
    },

    // Keep SQLite methods for backward compatibility
    get: function(sql, params, callback) {
      if (callback) {
        sqliteDb.get(sql, params, callback);
      } else {
        return new Promise((resolve, reject) => {
          sqliteDb.get(sql, params, (err, row) => {
            if (err) reject(err);
            else resolve(row);
          });
        });
      }
    },

    all: function(sql, params, callback) {
      if (callback) {
        sqliteDb.all(sql, params, callback);
      } else {
        return new Promise((resolve, reject) => {
          sqliteDb.all(sql, params, (err, rows) => {
            if (err) reject(err);
            else resolve(rows);
          });
        });
      }
    },

    run: function(sql, params, callback) {
      if (callback) {
        sqliteDb.run(sql, params, callback);
      } else {
        return new Promise((resolve, reject) => {
          sqliteDb.run(sql, params, function(err) {
            if (err) reject(err);
            else resolve({ lastID: this.lastID, changes: this.changes });
          });
        });
      }
    },
  };
}

module.exports = {
  getDatabase,
  USE_CONVEX,
};

