const { Resend } = require('resend');
const path = require('path');
// Ensure dotenv is loaded - try multiple paths
const envPath1 = path.join(__dirname, '../.env');
const envPath2 = path.join(process.cwd(), '.env');
require('dotenv').config({ path: envPath1 });
if (!process.env.RESEND_API_KEY) {
  require('dotenv').config({ path: envPath2 });
}

// Initialize Resend client (will be null if API key is missing)
let resend = null;
try {
  const apiKey = process.env.RESEND_API_KEY;
  if (apiKey) {
    resend = new Resend(apiKey);
    console.log('Resend initialized successfully');
  } else {
    console.warn('RESEND_API_KEY not found in environment variables. Email functionality will be disabled.');
  }
} catch (err) {
  console.error('Failed to initialize Resend:', err);
}

const FROM_EMAIL = process.env.RESEND_FROM_EMAIL || 'onboarding@resend.dev';
const FRONTEND_URL = process.env.FRONTEND_URL || 'http://localhost:3000';

/**
 * Send email verification email
 */
async function sendVerificationEmail(email, username, verificationToken) {
  if (!resend) {
    console.warn('Resend not initialized. Skipping verification email.');
    return { success: false, message: 'Email service not configured' };
  }

  const verificationLink = `${FRONTEND_URL}/verify-email?token=${verificationToken}`;
  
  try {
    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: email,
      subject: 'Verify your ZOE Sleep Journey account',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .button { 
              display: inline-block; 
              padding: 12px 24px; 
              background-color: #4F46E5; 
              color: white; 
              text-decoration: none; 
              border-radius: 6px; 
              margin: 20px 0;
            }
            .footer { margin-top: 30px; font-size: 12px; color: #666; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Welcome to ZOE Sleep Journey!</h1>
            <p>Hi ${username},</p>
            <p>Thank you for creating an account. Please verify your email address by clicking the button below:</p>
            <a href="${verificationLink}" class="button">Verify Email Address</a>
            <p>Or copy and paste this link into your browser:</p>
            <p style="word-break: break-all; color: #4F46E5;">${verificationLink}</p>
            <p>This link will expire in 24 hours.</p>
            <p>If you didn't create this account, you can safely ignore this email.</p>
            <div class="footer">
              <p>Best regards,<br>The ZOE Team</p>
            </div>
          </div>
        </body>
        </html>
      `,
    });

    if (error) {
      console.error('Resend error:', JSON.stringify(error, null, 2));
      // Don't throw - return error info instead
      return { 
        success: false, 
        error: error.message || 'Failed to send email',
        details: error 
      };
    }

    console.log('✅ Verification email sent successfully. Message ID:', data?.id);
    return { success: true, messageId: data?.id };
  } catch (error) {
    console.error('Failed to send verification email:', error.message || error);
    // Don't throw - allow registration to continue even if email fails
    return { 
      success: false, 
      error: error.message || 'Failed to send email' 
    };
  }
}

/**
 * Send welcome email (after verification)
 */
async function sendWelcomeEmail(email, username) {
  if (!resend) {
    console.warn('Resend not initialized. Skipping welcome email.');
    return { success: false, message: 'Email service not configured' };
  }

  try {
    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: email,
      subject: 'Welcome to ZOE Sleep Journey!',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .button { 
              display: inline-block; 
              padding: 12px 24px; 
              background-color: #4F46E5; 
              color: white; 
              text-decoration: none; 
              border-radius: 6px; 
              margin: 20px 0;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Your account is verified!</h1>
            <p>Hi ${username},</p>
            <p>Your email has been verified successfully. You're all set to start your 14-day sleep journey!</p>
            <a href="${FRONTEND_URL}/journey" class="button">Start Your Journey</a>
            <p>We're excited to help you improve your sleep quality.</p>
            <div style="margin-top: 30px; font-size: 12px; color: #666;">
              <p>Best regards,<br>The ZOE Team</p>
            </div>
          </div>
        </body>
        </html>
      `,
    });

    if (error) throw error;
    return { success: true, messageId: data?.id };
  } catch (error) {
    console.error('Failed to send welcome email:', error);
    throw error;
  }
}

/**
 * Send password reset email
 */
async function sendPasswordResetEmail(email, username, resetToken) {
  if (!resend) {
    console.warn('Resend not initialized. Skipping password reset email.');
    return { success: false, message: 'Email service not configured' };
  }

  const resetLink = `${FRONTEND_URL}/reset-password?token=${resetToken}`;
  
  try {
    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: email,
      subject: 'Reset your ZOE Sleep Journey password',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .button { 
              display: inline-block; 
              padding: 12px 24px; 
              background-color: #DC2626; 
              color: white; 
              text-decoration: none; 
              border-radius: 6px; 
              margin: 20px 0;
            }
            .warning { color: #DC2626; font-weight: bold; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Password Reset Request</h1>
            <p>Hi ${username},</p>
            <p>We received a request to reset your password. Click the button below to create a new password:</p>
            <a href="${resetLink}" class="button">Reset Password</a>
            <p>Or copy and paste this link:</p>
            <p style="word-break: break-all; color: #4F46E5;">${resetLink}</p>
            <p class="warning">This link will expire in 1 hour.</p>
            <p>If you didn't request a password reset, please ignore this email. Your password will remain unchanged.</p>
            <div style="margin-top: 30px; font-size: 12px; color: #666;">
              <p>Best regards,<br>The ZOE Team</p>
            </div>
          </div>
        </body>
        </html>
      `,
    });

    if (error) throw error;
    return { success: true, messageId: data?.id };
  } catch (error) {
    console.error('Failed to send password reset email:', error);
    throw error;
  }
}

/**
 * Send account update notification
 */
async function sendAccountUpdateEmail(email, username, updateType) {
  if (!resend) {
    console.warn('Resend not initialized. Skipping account update email.');
    return { success: false, message: 'Email service not configured' };
  }

  const updateMessages = {
    email: 'Your email address has been updated.',
    password: 'Your password has been changed successfully.',
    profile: 'Your profile has been updated.',
  };

  try {
    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: email,
      subject: 'Your ZOE account has been updated',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .alert { 
              background-color: #FEF3C7; 
              border-left: 4px solid #F59E0B; 
              padding: 12px; 
              margin: 20px 0;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Account Update</h1>
            <p>Hi ${username},</p>
            <div class="alert">
              <p><strong>${updateMessages[updateType] || 'Your account has been updated.'}</strong></p>
            </div>
            <p>If you didn't make this change, please contact us immediately.</p>
            <div style="margin-top: 30px; font-size: 12px; color: #666;">
              <p>Best regards,<br>The ZOE Team</p>
            </div>
          </div>
        </body>
        </html>
      `,
    });

    if (error) throw error;
    return { success: true, messageId: data?.id };
  } catch (error) {
    console.error('Failed to send account update email:', error);
    throw error;
  }
}

module.exports = {
  sendVerificationEmail,
  sendWelcomeEmail,
  sendPasswordResetEmail,
  sendAccountUpdateEmail,
};

