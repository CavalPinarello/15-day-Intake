/**
 * Script to reset test users (user1-user10) with predictable IDs
 * This deletes and recreates test users to ensure they have IDs 1-10
 */

const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const bcrypt = require('bcryptjs');

const DB_PATH = path.join(__dirname, '..', 'database', 'zoe.db');

const db = new sqlite3.Database(DB_PATH, (err) => {
  if (err) {
    console.error('Error opening database:', err);
    process.exit(1);
  }
});

console.log('Resetting test users...');

// Delete test users
db.run('DELETE FROM users WHERE username LIKE "user%"', (err) => {
  if (err) {
    console.error('Error deleting test users:', err);
    db.close();
    process.exit(1);
  }

  console.log('Deleted existing test users');

  // Reset the auto-increment sequence
  db.run("DELETE FROM sqlite_sequence WHERE name='users'", (seqErr) => {
    // Ignore errors - sequence might not exist
    
    // Create users sequentially to ensure correct ID assignment
    const passwordHash = bcrypt.hashSync('1', 12);
    
    // Create users one by one to ensure they get IDs 1-10 in order
    const createUsersSequentially = (index) => {
      if (index > 10) {
        // All users created, verify
        console.log('\nAll test users created successfully!');
        console.log('Users should now have IDs 1-10');
        
        db.all('SELECT id, username FROM users WHERE username LIKE "user%" ORDER BY id', (err, users) => {
          if (err) {
            console.error('Error verifying users:', err);
          } else {
            console.log('\nVerified users:');
            users.forEach(u => {
              console.log(`  ${u.username}: ID ${u.id}`);
            });
          }
          
          db.close();
          process.exit(0);
        });
        return;
      }

      db.run(
        'INSERT INTO users (username, password_hash, current_day) VALUES (?, ?, 1)',
        [`user${index}`, passwordHash],
        function(err) {
          if (err) {
            console.error(`Error creating user${index}:`, err);
            db.close();
            process.exit(1);
          } else {
            console.log(`Created user${index} with ID ${this.lastID}`);
            // Create next user
            createUsersSequentially(index + 1);
          }
        }
      );
    };

    // Start creating users from 1
    createUsersSequentially(1);
  });
});

