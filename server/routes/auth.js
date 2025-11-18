const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { getDatabase: getUnifiedDatabase } = require('../database/db');
const { 
  generateAccessToken, 
  generateRefreshToken, 
  verifyRefreshToken,
  extractTokenFromHeader 
} = require('../utils/jwt');
const { authenticateToken } = require('../middleware/auth');
const { body, validationResult } = require('express-validator');
const emailService = require('../utils/emailService');
const ConvexAdapter = require('../database/convexAdapter');

const router = express.Router();

// Login with JWT tokens
router.post('/login', [
  body('username').trim().notEmpty().withMessage('Username or email is required'),
  body('password').notEmpty().withMessage('Password is required')
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const { username, password } = req.body;
    const db = await getUnifiedDatabase();

    // Get user for login - try username or email in the current DB first
    let user = null;
    if (db.getUserByUsernameOrEmail) {
      try {
        user = await db.getUserByUsernameOrEmail(username);
      } catch (e) {
        console.error('Error querying primary DB for user:', e);
      }
    } else if (db.loginUser) {
      // Fallback to username-only login
      try {
        user = await db.loginUser(username, password);
      } catch (e) {
        console.error('Error using loginUser on primary DB:', e);
      }
    }

    // If not found, try Convex directly (users may have been registered via Convex)
    if (!user) {
      try {
        const convex = new ConvexAdapter();
        const convexUser = await convex.getUserByUsernameOrEmail(username);
        if (convexUser) {
          user = convexUser;
        }
      } catch (convexErr) {
        console.error('Error querying Convex for user:', convexErr);
      }
    }
    
    if (!user) {
      console.log(`❌ Login failed: User/Email '${username}' not found`);
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Check if password_hash exists
    if (!user.password_hash) {
      console.error(`❌ Login failed: User '${username}' found but password_hash is missing`);
      console.error('User object keys:', Object.keys(user));
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Compare password (bcrypt comparison done server-side)
    const isValid = bcrypt.compareSync(password, user.password_hash);
    if (!isValid) {
      console.log(`❌ Login failed: Invalid password for user '${username}'`);
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    console.log(`✅ Login successful for user '${username}' (ID: ${user.id || user._id})`);

    // Generate tokens (use numeric ID for JWT compatibility)
    const numericId = typeof user.id === 'string' ? parseInt(user.id, 10) : user.id;
    const safeUserId = Number.isFinite(numericId) ? numericId : (typeof user.id === 'number' ? user.id : 0);
    const accessToken = generateAccessToken(safeUserId, user.username);
    const refreshToken = generateRefreshToken(safeUserId, user.username);

    // Store refresh token in Convex
    const expiresAt = Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60); // 7 days in Unix timestamp
    try {
      // Try storing via current DB first; prefer _id if available else numeric id
      const tokenUserId = user._id || user.id || safeUserId;
      if (db.storeRefreshToken) {
        await db.storeRefreshToken(tokenUserId, refreshToken, expiresAt);
      }
    } catch (err) {
      console.error('Error storing refresh token:', err);
      // Continue even if refresh token storage fails
    }

    // Update last accessed
    try {
      await db.updateUserLastAccessed(user._id);
    } catch (err) {
      console.error('Error updating last accessed:', err);
    }

    // Return user data (without password hash) and tokens
    const { password_hash, _id, ...userData } = user;
    
    // Ensure role is included (default to "patient" if not set)
    if (!userData.role) {
      userData.role = "patient";
    }
    
    res.json({
      success: true,
      user: userData,
      accessToken,
      refreshToken
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Register new user
router.post('/register', [
  body('username').trim().isLength({ min: 3 }).withMessage('Username must be at least 3 characters'),
  body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
    .withMessage('Password must contain uppercase, lowercase, number, and special character'),
  body('email').isEmail().withMessage('Valid email is required')
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const { username, password, email, skipEmailVerification = false } = req.body;
    const db = await getUnifiedDatabase();

    // Generate verification token only if email verification is not skipped
    let verificationToken = null;
    let verificationExpires = null;
    if (!skipEmailVerification) {
      verificationToken = crypto.randomBytes(32).toString('hex');
      verificationExpires = Date.now() + 24 * 60 * 60 * 1000; // 24 hours
    }

    // Hash password with bcrypt (12 rounds for security)
    const passwordHash = bcrypt.hashSync(password, 12);

    // Register user in Convex
    let userId;
    try {
      userId = await db.registerUser({
        username,
        password_hash: passwordHash,
        email,
        email_verification_token: verificationToken || undefined,
        email_verification_expires: verificationExpires || undefined,
      });
    } catch (err) {
      if (err.message.includes('already exists')) {
        return res.status(409).json({ error: err.message });
      }
      throw err;
    }

    // Get the created user to return user data
    const user = await db.getUserById(userId);
    if (!user) {
      return res.status(500).json({ error: 'Failed to retrieve created user' });
    }

    // If email verification is skipped, mark email as verified automatically
    if (skipEmailVerification) {
      try {
        await db.verifyUserEmail(user._id);
        console.log(`✅ Email verification skipped - user ${username} marked as verified`);
      } catch (verifyErr) {
        console.error('Failed to mark email as verified:', verifyErr);
      }
    }

    // Send verification email only if not skipped (don't block registration if email fails)
    let emailWarning = null;
    if (!skipEmailVerification && verificationToken) {
      try {
        const emailResult = await emailService.sendVerificationEmail(email, username, verificationToken);
        if (emailResult.success) {
          console.log(`✅ Verification email sent to ${email}`);
        } else {
          const errorMsg = emailResult.error || emailResult.message || 'Unknown error';
          console.warn(`⚠️ Failed to send verification email to ${email}:`, errorMsg);
          
          // Check if it's a Resend test mode limitation
          if (errorMsg.includes('only send testing emails to your own email address')) {
            emailWarning = 'Email verification was not sent. Resend test mode only allows sending to verified email addresses. For production, verify a domain at resend.com/domains.';
          } else {
            emailWarning = `Email verification failed: ${errorMsg}`;
          }
        }
      } catch (emailError) {
        console.error('Failed to send verification email:', emailError);
        emailWarning = 'Email verification failed. Please contact support.';
      }
    }

    // Generate tokens (use numeric ID for JWT compatibility)
    const numericId = user.id;
    const accessToken = generateAccessToken(numericId, username);
    const refreshToken = generateRefreshToken(numericId, username);

    // Store refresh token
    const expiresAt = Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60); // 7 days in Unix timestamp
    try {
      await db.storeRefreshToken(user._id, refreshToken, expiresAt);
    } catch (err) {
      console.error('Error storing refresh token:', err);
    }

    // Return user data and tokens
    const { password_hash, _id, ...userData } = user;
    let successMessage = 'Account created successfully!';
    if (skipEmailVerification) {
      successMessage += ' Email verification skipped.';
    } else if (emailWarning) {
      successMessage += ` ${emailWarning}`;
    } else {
      successMessage += ' Please check your email to verify your account.';
    }
    
    res.status(201).json({
      success: true,
      user: userData,
      accessToken,
      refreshToken,
      message: successMessage,
      emailWarning: emailWarning || null
    });
  } catch (err) {
    console.error('Registration error:', err);
    res.status(500).json({ error: 'Failed to create user' });
  }
});

// Refresh access token
router.post('/refresh', async (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(400).json({ error: 'Refresh token required' });
  }

  try {
    // Verify refresh token
    const decoded = verifyRefreshToken(refreshToken);
    const db = await getUnifiedDatabase();

    // Check if token exists and is valid in Convex
    const tokenData = await db.getRefreshToken(refreshToken);

    if (!tokenData || !tokenData.user) {
      return res.status(403).json({ error: 'Invalid or expired refresh token' });
    }

    // Verify user ID matches (getRefreshToken already converts to numeric id)
    if (!tokenData.user.id || tokenData.user.id !== decoded.userId) {
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
  } catch (error) {
    console.error('Refresh token error:', error);
    return res.status(403).json({ error: 'Invalid refresh token' });
  }
});

// Logout - revoke refresh token
router.post('/logout', authenticateToken, async (req, res) => {
  const refreshToken = req.body.refreshToken;
  const db = await getUnifiedDatabase();

  // Revoke refresh token if provided
  if (refreshToken) {
    try {
      // Get user to find Convex ID
      const user = await db.getUserById(req.user.userId);
      if (user && user._id) {
        await db.revokeRefreshToken(refreshToken, user._id);
      }
    } catch (err) {
      console.error('Error revoking refresh token:', err);
    }
  }

  res.json({ success: true, message: 'Logged out successfully' });
});

// Get current user (requires authentication)
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const db = await getUnifiedDatabase();
    const user = await db.getUserById(req.user.userId);
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Remove sensitive fields
    const { password_hash, _id, ...userData } = user;
    res.json({ user: userData });
  } catch (err) {
    console.error('Get user error:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Legacy endpoint for backward compatibility (deprecated)
router.get('/me-legacy', async (req, res) => {
  const userId = req.query.userId;
  
  if (!userId) {
    return res.status(400).json({ error: 'User ID is required' });
  }

  try {
    const db = await getUnifiedDatabase();
    const user = await db.getUserById(parseInt(userId, 10));
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const { password_hash, _id, ...userData } = user;
    res.json({ user: userData });
  } catch (err) {
    console.error('Get user error:', err);
    res.status(500).json({ error: 'Database error' });
  }
});

// Verify email endpoint
router.get('/verify-email', async (req, res) => {
  const { token } = req.query;
  
  if (!token) {
    return res.status(400).json({ error: 'Verification token is required' });
  }

  try {
    const db = await getUnifiedDatabase();
    
    // Find user by verification token
    const user = await db.getUserByVerificationToken(token);
    
    if (!user) {
      return res.status(400).json({ error: 'Invalid verification token' });
    }

    // Check if token is expired
    if (user.email_verification_expires && user.email_verification_expires < Date.now()) {
      return res.status(400).json({ error: 'Verification token has expired' });
    }

    // Verify email
    await db.verifyUserEmail(user._id);
    
    // Send welcome email
    try {
      await emailService.sendWelcomeEmail(user.email, user.username);
    } catch (emailError) {
      console.error('Failed to send welcome email:', emailError);
    }

    res.json({ 
      success: true, 
      message: 'Email verified successfully' 
    });
  } catch (err) {
    console.error('Email verification error:', err);
    res.status(500).json({ error: 'Failed to verify email' });
  }
});

// Request password reset
router.post('/forgot-password', [
  body('email').isEmail().withMessage('Valid email is required')
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const { email } = req.body;
    const db = await getUnifiedDatabase();
    
    const user = await db.getUserByEmail(email);
    
    // Don't reveal if user exists (security best practice)
    if (!user) {
      return res.json({ 
        success: true, 
        message: 'If that email exists, a password reset link has been sent.' 
      });
    }

    // Generate reset token
    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetExpires = Date.now() + 60 * 60 * 1000; // 1 hour

    await db.setPasswordResetToken(user._id, resetToken, resetExpires);

    // Send reset email
    try {
      await emailService.sendPasswordResetEmail(user.email, user.username, resetToken);
    } catch (emailError) {
      console.error('Failed to send password reset email:', emailError);
    }

    res.json({ 
      success: true, 
      message: 'If that email exists, a password reset link has been sent.' 
    });
  } catch (err) {
    console.error('Password reset request error:', err);
    res.status(500).json({ error: 'Failed to process password reset request' });
  }
});

// Reset password with token
router.post('/reset-password', [
  body('token').notEmpty().withMessage('Reset token is required'),
  body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
    .withMessage('Password must contain uppercase, lowercase, number, and special character')
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const { token, password } = req.body;
    const db = await getUnifiedDatabase();
    
    const user = await db.getUserByPasswordResetToken(token);
    
    if (!user || (user.password_reset_expires && user.password_reset_expires < Date.now())) {
      return res.status(400).json({ error: 'Invalid or expired reset token' });
    }

    // Update password
    const passwordHash = bcrypt.hashSync(password, 12);
    await db.updateUserPassword(user._id, passwordHash);
    await db.clearPasswordResetToken(user._id);

    // Send confirmation email
    try {
      await emailService.sendAccountUpdateEmail(user.email, user.username, 'password');
    } catch (emailError) {
      console.error('Failed to send password update email:', emailError);
    }

    res.json({ success: true, message: 'Password reset successfully' });
  } catch (err) {
    console.error('Password reset error:', err);
    res.status(500).json({ error: 'Failed to reset password' });
  }
});

module.exports = router;
