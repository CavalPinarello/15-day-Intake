const express = require('express');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { getDatabase: getUnifiedDatabase } = require('../database/db');
const { generateAccessToken, generateRefreshToken } = require('../utils/jwt');

const router = express.Router();

// Apple Sign In endpoint
router.post('/apple', async (req, res) => {
  try {
    const { idToken, nonce, firstName, lastName, email, userIdentifier } = req.body;

    if (!idToken || !nonce || !userIdentifier) {
      return res.status(400).json({ 
        success: false, 
        error: 'Missing required Apple Sign In parameters' 
      });
    }

    // In a production app, you would verify the Apple ID token here
    // For now, we'll create/get the user based on Apple ID
    
    const db = await getUnifiedDatabase();
    
    // Check if user exists with Apple ID
    let user = null;
    const appleId = userIdentifier;
    
    // Try to find user by Apple ID or email
    if (db.getUserByAppleId) {
      try {
        user = await db.getUserByAppleId(appleId);
      } catch (e) {
        console.log('No getUserByAppleId method available');
      }
    }
    
    // If no user found and email provided, try to find by email
    if (!user && email && db.getUserByEmail) {
      try {
        user = await db.getUserByEmail(email);
        // Link Apple ID to existing user
        if (user && db.linkAppleId) {
          await db.linkAppleId(user.id, appleId);
        }
      } catch (e) {
        console.log('No getUserByEmail method available');
      }
    }
    
    // Create new user if none exists
    if (!user) {
      const username = `apple_${appleId.substring(0, 10)}`;
      const newUser = {
        username,
        email: email || null,
        firstName: firstName || null,
        lastName: lastName || null,
        appleId,
        role: 'patient',
        current_day: 1,
        apple_health_connected: 0,
        onboarding_completed: 0
      };
      
      // Create user in database
      if (db.createUserWithAppleId) {
        user = await db.createUserWithAppleId(newUser);
      } else {
        // Fallback: create basic user and store Apple ID separately
        const hashedPassword = crypto.randomBytes(32).toString('hex'); // Random password for Apple users
        if (db.createUser) {
          const userId = await db.createUser(username, hashedPassword, email);
          user = {
            id: userId,
            username,
            email,
            firstName,
            lastName,
            current_day: 1,
            role: 'patient',
            apple_health_connected: 0,
            onboarding_completed: 0,
            created_at: new Date().toISOString(),
            started_at: new Date().toISOString(),
            last_accessed: new Date().toISOString()
          };
        } else {
          throw new Error('Cannot create user');
        }
      }
    } else {
      // Update last accessed time
      if (db.updateLastAccessed) {
        await db.updateLastAccessed(user.id);
      }
    }

    if (!user) {
      return res.status(500).json({ 
        success: false, 
        error: 'Failed to create or retrieve user' 
      });
    }

    // Generate tokens
    const accessToken = generateAccessToken(user.id, user.username);
    const refreshToken = generateRefreshToken(user.id, user.username);

    res.json({
      success: true,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        firstName: user.firstName || firstName,
        lastName: user.lastName || lastName,
        current_day: user.current_day,
        started_at: user.started_at,
        last_accessed: user.last_accessed || new Date().toISOString(),
        created_at: user.created_at,
        apple_health_connected: user.apple_health_connected,
        onboarding_completed: user.onboarding_completed,
        role: user.role || 'patient'
      },
      accessToken,
      refreshToken
    });

  } catch (error) {
    console.error('Apple Sign In error:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Apple Sign In failed' 
    });
  }
});

module.exports = router;