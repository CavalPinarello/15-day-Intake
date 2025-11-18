/**
 * Database Adapter
 * Supports both SQLite (development) and PostgreSQL (production)
 */

const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

// Detect environment
const isProduction = process.env.NODE_ENV === 'production';
const usePostgres = process.env.DATABASE_URL || process.env.POSTGRES_URL;

let db = null;
let dbType = 'sqlite';

/**
 * Get database connection
 */
function getDatabase() {
  if (db) {
    return db;
  }

  if (usePostgres) {
    // PostgreSQL connection (production)
    dbType = 'postgres';
    const { Pool } = require('pg');
    
    const pool = new Pool({
      connectionString: process.env.DATABASE_URL || process.env.POSTGRES_URL,
      ssl: isProduction ? { rejectUnauthorized: false } : false
    });

    // Create a compatible interface
    db = {
      type: 'postgres',
      pool: pool,
      // SQLite-compatible methods
      run: (query, params, callback) => {
        pool.query(query, params || [], (err, result) => {
          if (callback) {
            if (err) {
              callback(err);
            } else {
              callback(null, { lastID: result.insertId || result.rows[0]?.id, changes: result.rowCount });
            }
          }
        });
      },
      get: (query, params, callback) => {
        pool.query(query, params || [], (err, result) => {
          if (callback) {
            if (err) {
              callback(err, null);
            } else {
              callback(null, result.rows[0] || null);
            }
          }
        });
      },
      all: (query, params, callback) => {
        pool.query(query, params || [], (err, result) => {
          if (callback) {
            if (err) {
              callback(err, null);
            } else {
              callback(null, result.rows || []);
            }
          }
        });
      },
      serialize: (callback) => {
        // PostgreSQL doesn't need serialization, just run callback
        callback();
      },
      close: (callback) => {
        pool.end(callback);
      }
    };

    console.log('Connected to PostgreSQL database');
  } else {
    // SQLite connection (development)
    dbType = 'sqlite';
    const dbDir = __dirname;
    
    if (!fs.existsSync(dbDir)) {
      fs.mkdirSync(dbDir, { recursive: true });
    }

    const DB_PATH = path.join(dbDir, 'zoe.db');
    db = new sqlite3.Database(DB_PATH, (err) => {
      if (err) {
        console.error('Error opening SQLite database:', err);
      } else {
        console.log('Connected to SQLite database');
      }
    });
  }

  return db;
}

/**
 * Execute a query (works with both SQLite and PostgreSQL)
 */
function query(sql, params = []) {
  return new Promise((resolve, reject) => {
    const database = getDatabase();
    
    if (dbType === 'postgres') {
      database.pool.query(sql, params, (err, result) => {
        if (err) {
          reject(err);
        } else {
          resolve(result.rows);
        }
      });
    } else {
      database.all(sql, params, (err, rows) => {
        if (err) {
          reject(err);
        } else {
          resolve(rows || []);
        }
      });
    }
  });
}

/**
 * Execute a query and return single row
 */
function queryOne(sql, params = []) {
  return new Promise((resolve, reject) => {
    const database = getDatabase();
    
    if (dbType === 'postgres') {
      database.pool.query(sql, params, (err, result) => {
        if (err) {
          reject(err);
        } else {
          resolve(result.rows[0] || null);
        }
      });
    } else {
      database.get(sql, params, (err, row) => {
        if (err) {
          reject(err);
        } else {
          resolve(row || null);
        }
      });
    }
  });
}

/**
 * Execute a query and return result metadata
 */
function execute(sql, params = []) {
  return new Promise((resolve, reject) => {
    const database = getDatabase();
    
    if (dbType === 'postgres') {
      database.pool.query(sql, params, (err, result) => {
        if (err) {
          reject(err);
        } else {
          resolve({
            lastID: result.insertId || result.rows[0]?.id,
            changes: result.rowCount,
            rows: result.rows
          });
        }
      });
    } else {
      database.run(sql, params, function(err) {
        if (err) {
          reject(err);
        } else {
          resolve({
            lastID: this.lastID,
            changes: this.changes
          });
        }
      });
    }
  });
}

/**
 * Convert SQLite SQL to PostgreSQL SQL
 */
function convertSQL(sql) {
  if (dbType === 'postgres') {
    // Replace SQLite-specific syntax with PostgreSQL
    return sql
      .replace(/INTEGER PRIMARY KEY AUTOINCREMENT/g, 'SERIAL PRIMARY KEY')
      .replace(/INTEGER PRIMARY KEY/g, 'SERIAL PRIMARY KEY')
      .replace(/DATETIME/g, 'TIMESTAMP')
      .replace(/CURRENT_TIMESTAMP/g, 'NOW()')
      .replace(/TEXT/g, 'VARCHAR')
      .replace(/BOOLEAN/g, 'BOOLEAN')
      .replace(/REAL/g, 'DOUBLE PRECISION')
      .replace(/UNIQUE\(/g, 'UNIQUE (')
      .replace(/ON CONFLICT\(([^)]+)\) DO UPDATE SET/g, 'ON CONFLICT ($1) DO UPDATE SET');
  }
  return sql;
}

/**
 * Get database type
 */
function getDatabaseType() {
  return dbType;
}

module.exports = {
  getDatabase,
  query,
  queryOne,
  execute,
  convertSQL,
  getDatabaseType
};




