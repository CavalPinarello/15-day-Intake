const express = require('express');
const bcrypt = require('bcryptjs');
const { getDatabase } = require('../database/init');
const { 
  generateAccessToken, 
  generateRefreshToken, 
  verifyRefreshToken,
  extractTokenFromHeader 
} = require('../utils/jwt');
const { authenticateToken } = require('../middleware/auth');
const { body, validationResult } = require('express-validator');

const router = express.Router();

// Login with JWT tokens
router.post('/login', [
  body('username').trim().notEmpty().withMessage('Username is required'),
  body('password').notEmpty().withMessage('Password is required')
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const { username, password } = req.body;
  const db = getDatabase();

  db.get(
    'SELECT * FROM users WHERE username = ?',
    [username],
    (err, user) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      if (!user) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      const isValid = bcrypt.compareSync(password, user.password_hash);
      if (!isValid) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      // Generate tokens
      const accessToken = generateAccessToken(user.id, user.username);
      const refreshToken = generateRefreshToken(user.id, user.username);

      // Store refresh token in database
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 7); // 7 days

      db.run(
        'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES (?, ?, ?)',
        [user.id, refreshToken, expiresAt.toISOString()],
        (err) => {
          if (err) {
            console.error('Error storing refresh token:', err);
            // Continue even if refresh token storage fails
          }

          // Update last accessed
          db.run(
            'UPDATE users SET last_accessed = CURRENT_TIMESTAMP WHERE id = ?',
            [user.id],
            () => {}
          );

          // Return user data (without password hash) and tokens
          const { password_hash, ...userData } = user;
          res.json({
            success: true,
            user: userData,
            accessToken,
            refreshToken
          });
        }
      );
    }
  );
});

// Register new user
router.post('/register', [
  body('username').trim().isLength({ min: 3 }).withMessage('Username must be at least 3 characters'),
  body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
    .withMessage('Password must contain uppercase, lowercase, number, and special character'),
  body('email').optional().isEmail().withMessage('Invalid email format')
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const { username, password, email } = req.body;
  const db = getDatabase();

  // Check if username already exists
  db.get(
    'SELECT id FROM users WHERE username = ?',
    [username],
    (err, existing) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      if (existing) {
        return res.status(409).json({ error: 'Username already exists' });
      }

      // Hash password with bcrypt (12 rounds for security)
      const passwordHash = bcrypt.hashSync(password, 12);

      // Insert new user
      db.run(
        'INSERT INTO users (username, password_hash, email) VALUES (?, ?, ?)',
        [username, passwordHash, email || null],
        function(err) {
          if (err) {
            return res.status(500).json({ error: 'Failed to create user' });
          }

          const userId = this.lastID;

          // Generate tokens
          const accessToken = generateAccessToken(userId, username);
          const refreshToken = generateRefreshToken(userId, username);

          // Store refresh token
          const expiresAt = new Date();
          expiresAt.setDate(expiresAt.getDate() + 7);

          db.run(
            'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES (?, ?, ?)',
            [userId, refreshToken, expiresAt.toISOString()],
            (err) => {
              if (err) {
                console.error('Error storing refresh token:', err);
              }

              // Return user data and tokens
              res.status(201).json({
                success: true,
                user: {
                  id: userId,
                  username,
                  email: email || null,
                  current_day: 1,
                  started_at: new Date().toISOString()
                },
                accessToken,
                refreshToken
              });
            }
          );
        }
      );
    }
  );
});

// Refresh access token
router.post('/refresh', (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(400).json({ error: 'Refresh token required' });
  }

  try {
    // Verify refresh token
    const decoded = verifyRefreshToken(refreshToken);
    const db = getDatabase();

    // Check if token exists and is valid in database
    db.get(
      `SELECT rt.*, u.username 
       FROM refresh_tokens rt 
       JOIN users u ON rt.user_id = u.id 
       WHERE rt.token = ? AND rt.revoked = 0 AND rt.expires_at > datetime('now')`,
      [refreshToken],
      (err, tokenData) => {
        if (err) {
          return res.status(500).json({ error: 'Database error' });
        }

        if (!tokenData) {
          return res.status(403).json({ error: 'Invalid or expired refresh token' });
        }

        // Verify user ID matches
        if (tokenData.user_id !== decoded.userId) {
          return res.status(403).json({ error: 'Token mismatch' });
        }

        // Generate new access token
        const newAccessToken = generateAccessToken(decoded.userId, decoded.username);

        // Optionally rotate refresh token (for better security)
        // For now, we'll keep the same refresh token
        // In production, you might want to generate a new refresh token and revoke the old one

        res.json({
          success: true,
          accessToken: newAccessToken
        });
      }
    );
  } catch (error) {
    return res.status(403).json({ error: 'Invalid refresh token' });
  }
});

// Logout - revoke refresh token
router.post('/logout', authenticateToken, (req, res) => {
  const authHeader = req.headers['authorization'];
  const refreshToken = req.body.refreshToken;
  const db = getDatabase();

  // Revoke refresh token if provided
  if (refreshToken) {
    db.run(
      'UPDATE refresh_tokens SET revoked = 1 WHERE token = ? AND user_id = ?',
      [refreshToken, req.user.userId],
      (err) => {
        if (err) {
          console.error('Error revoking refresh token:', err);
        }
      }
    );
  }

  res.json({ success: true, message: 'Logged out successfully' });
});

// Get current user (requires authentication)
router.get('/me', authenticateToken, (req, res) => {
  const db = getDatabase();
  
  db.get(
    'SELECT id, username, email, current_day, started_at, last_accessed, created_at FROM users WHERE id = ?',
    [req.user.userId],
    (err, user) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      res.json({ user });
    }
  );
});

// Legacy endpoint for backward compatibility (deprecated)
router.get('/me-legacy', (req, res) => {
  const userId = req.query.userId;
  
  if (!userId) {
    return res.status(400).json({ error: 'User ID is required' });
  }

  const db = getDatabase();
  db.get(
    'SELECT id, username, current_day, started_at, last_accessed FROM users WHERE id = ?',
    [userId],
    (err, user) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      res.json({ user });
    }
  );
});

module.exports = router;
