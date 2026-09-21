/**
 * SwiftDrop - Complete Email Service for Password Reset
 * Email: bia407493@gmail.com
 * 
 * SETUP INSTRUCTIONS:
 * 1. npm install nodemailer express body-parser cors
 * 2. Get Google App Password:
 *    - Go to: https://myaccount.google.com/security
 *    - Enable 2-Step Verification
 *    - Go to App Passwords → Generate new password
 *    - Copy password and paste below
 * 3. node backend_email_service.js
 */

const express = require('express');
const nodemailer = require('nodemailer');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(bodyParser.json());

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// EMAIL CONFIGURATION
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// IMPORTANT: Replace 'YOUR_APP_PASSWORD' with the Google App Password
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.SMTP_USER || 'your-email@gmail.com',
    pass: process.env.SMTP_PASS || 'YOUR_APP_PASSWORD' // Google App Password (env var recommended)
  }
});

// In-memory storage for reset codes (use database in production)
const resetCodes = new Map();

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// HELPER FUNCTION: Send Email
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

async function sendResetCodeEmail(recipientEmail, resetCode) {
  const mailOptions = {
    from: 'SwiftDrop <bia407493@gmail.com>',
    to: recipientEmail,
    subject: '🔐 Password Reset Code - SwiftDrop',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px; }
          .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 16px; padding: 40px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
          .header { text-align: center; margin-bottom: 30px; }
          .logo { font-size: 32px; font-weight: 900; color: #FF5722; letter-spacing: 1px; }
          .code-container { background: linear-gradient(135deg, #FF5722, #FF8A50); border-radius: 12px; padding: 30px; text-align: center; margin: 30px 0; }
          .code { font-size: 48px; font-weight: 900; color: white; letter-spacing: 10px; margin: 0; }
          .info { color: #666; font-size: 14px; line-height: 1.6; margin: 20px 0; }
          .warning { background: #FFF3E0; border-left: 4px solid #FF9800; padding: 15px; border-radius: 8px; margin: 20px 0; }
          .footer { text-align: center; color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div class="logo">🚀 SwiftDrop</div>
            <p style="color: #666; margin: 10px 0 0 0;">Fast Food Delivery</p>
          </div>
          
          <h2 style="color: #333; margin-bottom: 20px;">Password Reset Request</h2>
          
          <p class="info">
            You requested to reset your password for your SwiftDrop account. 
            Use the code below to complete the reset process.
          </p>
          
          <div class="code-container">
            <p style="color: white; margin: 0 0 10px 0; font-size: 14px; opacity: 0.9;">Your Reset Code</p>
            <p class="code">${resetCode}</p>
            <p style="color: white; margin: 10px 0 0 0; font-size: 12px; opacity: 0.8;">Valid for 15 minutes</p>
          </div>
          
          <p class="info">
            Enter this code in the SwiftDrop app to reset your password.
          </p>
          
          <div class="warning">
            <strong>⚠️ Security Notice:</strong><br>
            • Do not share this code with anyone<br>
            • SwiftDrop will never ask for this code via call or SMS<br>
            • If you didn't request this, please ignore this email
          </div>
          
          <div class="footer">
            <p>This is an automated message from SwiftDrop</p>
            <p>© 2024 SwiftDrop. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    `
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log('✅ Email sent successfully:', info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('❌ Email sending failed:', error);
    throw error;
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// API ENDPOINTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'SwiftDrop Email Service Running',
    email: 'bia407493@gmail.com',
    timestamp: new Date().toISOString()
  });
});

// POST /api/auth/forgot-password
app.post('/api/auth/forgot-password', async (req, res) => {
  try {
    const { email, role } = req.body;

    if (!email) {
      return res.status(400).json({ message: 'Email is required' });
    }

    console.log(`📧 Password reset requested for: ${email} (${role || 'unknown'})`);

    // Generate 6-digit code
    const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Store code with 15-minute expiry
    const expiryTime = Date.now() + 15 * 60 * 1000; // 15 minutes
    resetCodes.set(email, {
      code: resetCode,
      expiry: expiryTime,
      role: role || 'rider'
    });

    // Send email
    await sendResetCodeEmail(email, resetCode);

    // Clean up expired codes
    setTimeout(() => {
      if (resetCodes.has(email)) {
        const stored = resetCodes.get(email);
        if (stored.code === resetCode) {
          resetCodes.delete(email);
          console.log(`🗑️ Expired code removed for ${email}`);
        }
      }
    }, 15 * 60 * 1000);

    console.log(`✅ Reset code sent to ${email}: ${resetCode}`);

    res.json({
      message: 'Reset code sent to your email',
      email: email,
      // ⚠️ Remove this in production (for testing only)
      debug_code: resetCode
    });

  } catch (error) {
    console.error('❌ Forgot password error:', error);
    res.status(500).json({ 
      message: 'Failed to send reset code. Please check email configuration.',
      error: error.message 
    });
  }
});

// POST /api/auth/reset-password
app.post('/api/auth/reset-password', async (req, res) => {
  try {
    const { email, token, newPassword, role } = req.body;

    if (!email || !token || !newPassword) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    console.log(`🔑 Password reset attempt for: ${email}`);

    // Check if code exists
    if (!resetCodes.has(email)) {
      return res.status(400).json({ message: 'No reset code found. Please request a new one.' });
    }

    const stored = resetCodes.get(email);

    // Verify code
    if (stored.code !== token) {
      return res.status(400).json({ message: 'Invalid reset code' });
    }

    // Check expiry
    if (Date.now() > stored.expiry) {
      resetCodes.delete(email);
      return res.status(400).json({ message: 'Reset code has expired. Please request a new one.' });
    }

    // Verify role matches (optional)
    if (role && stored.role !== role) {
      return res.status(400).json({ message: 'Role mismatch' });
    }

    // ⚠️ TODO: Update password in your database
    // Example: await User.updateOne({ email }, { password: hashedPassword });
    console.log(`✅ Password reset successful for ${email}`);
    console.log(`   New password: ${newPassword} (remember to hash this!)`);

    // Remove used code
    resetCodes.delete(email);

    res.json({ 
      message: 'Password reset successful',
      email: email
    });

  } catch (error) {
    console.error('❌ Reset password error:', error);
    res.status(500).json({ 
      message: 'Failed to reset password',
      error: error.message 
    });
  }
});

// GET /api/auth/test-email - Test endpoint
app.get('/api/auth/test-email', async (req, res) => {
  try {
    const testCode = '123456';
    await sendResetCodeEmail('bia407493@gmail.com', testCode);
    res.json({ 
      message: 'Test email sent successfully!',
      recipient: 'bia407493@gmail.com',
      code: testCode
    });
  } catch (error) {
    res.status(500).json({ 
      message: 'Failed to send test email',
      error: error.message 
    });
  }
});

// Debug endpoint - View stored codes
app.get('/api/auth/debug-codes', (req, res) => {
  const codes = Array.from(resetCodes.entries()).map(([email, data]) => ({
    email,
    code: data.code,
    expiresIn: Math.round((data.expiry - Date.now()) / 1000) + ' seconds',
    role: data.role
  }));
  res.json({ count: codes.length, codes });
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// START SERVER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log('\n' + '━'.repeat(60));
  console.log('🚀 SwiftDrop Email Service Started!');
  console.log('━'.repeat(60));
  console.log(`📧 Sending emails from: bia407493@gmail.com`);
  console.log(`🌐 Server running on: http://localhost:${PORT}`);
  console.log(`💊 Health check: http://localhost:${PORT}/api/health`);
  console.log(`🧪 Test email: http://localhost:${PORT}/api/auth/test-email`);
  console.log('━'.repeat(60));
  console.log('\n⚠️  IMPORTANT: Update YOUR_APP_PASSWORD in code!\n');
  console.log('📖 Get App Password:');
  console.log('   1. Go to: https://myaccount.google.com/security');
  console.log('   2. Enable 2-Step Verification');
  console.log('   3. App Passwords → Generate');
  console.log('   4. Copy password → Paste in code (line 29)\n');
  console.log('━'.repeat(60) + '\n');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('⏹️  Shutting down gracefully...');
  process.exit(0);
});
