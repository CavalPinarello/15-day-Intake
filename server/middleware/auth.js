const { verifyAccessToken, extractTokenFromHeader } = require('../utils/jwt');
const { getDatabase } = require('../database/init');

/**
 * Authentication middleware - verifies JWT access token
 */
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = extractTokenFromHeader(authHeader);

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const decoded = verifyAccessToken(token);
    
    // Attach user info to request
    req.user = {
      userId: decoded.userId,
      username: decoded.username
    };
    
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid or expired access token' });
  }
}

/**
 * Optional authentication - doesn't fail if no token, but attaches user if valid token exists
 */
function optionalAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = extractTokenFromHeader(authHeader);

  if (token) {
    try {
      const decoded = verifyAccessToken(token);
      req.user = {
        userId: decoded.userId,
        username: decoded.username
      };
    } catch (error) {
      // Token invalid, but continue without user
      req.user = null;
    }
  }
  
  next();
}

/**
 * Verify user exists in database (for additional security)
 */
function verifyUserExists(req, res, next) {
  if (!req.user || !req.user.userId) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  const db = getDatabase();
  db.get(
    'SELECT id, username FROM users WHERE id = ?',
    [req.user.userId],
    (err, user) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      if (!user) {
        return res.status(401).json({ error: 'User not found' });
      }

      // Update user info with fresh data from DB
      req.user = {
        userId: user.id,
        username: user.username
      };

      next();
    }
  );
}

module.exports = {
  authenticateToken,
  optionalAuth,
  verifyUserExists
};

