# Backend Email Setup Guide - SwiftDrop

## ⚠️ Problem: Forgot Password Email Not Sending

The app's forgot password feature is **working correctly on frontend**, but emails are not being received. This is a **backend configuration issue**.

---

## Backend Requirements

Your backend needs to implement these endpoints:

### 1. **POST `/api/auth/forgot-password`**
Request:
```json
{
  "email": "user@example.com",
  "role": "rider" // or "customer" or "business"
}
```

Response (Success):
```json
{
  "message": "Reset code sent to your email",
  "email": "user@example.com"
}
```

**What it should do:**
- Generate a 6-digit random code (e.g., "123456")
- Store this code in database with expiry (15 minutes recommended)
- Send email to user with the reset code
- Return success message

---

### 2. **POST `/api/auth/reset-password`**
Request:
```json
{
  "email": "user@example.com",
  "token": "123456",
  "newPassword": "newpass123",
  "role": "rider"
}
```

Response (Success):
```json
{
  "message": "Password reset successful"
}
```

**What it should do:**
- Verify the code matches and hasn't expired
- Hash the new password
- Update user's password in database
- Delete/invalidate the reset code
- Return success message

---

## Email Service Setup (Backend)

Your backend needs an **email sending service**. Here are the most common options:

### Option 1: **Nodemailer with Gmail** (Free, Easy)
```javascript
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'your-email@gmail.com',
    pass: 'your-app-password' // Generate from Google Account settings
  }
});

async function sendResetCode(email, code) {
  await transporter.sendMail({
    from: 'SwiftDrop <your-email@gmail.com>',
    to: email,
    subject: 'Password Reset Code - SwiftDrop',
    html: `
      <h2>Password Reset Request</h2>
      <p>Your password reset code is:</p>
      <h1 style="color: #FF5722; letter-spacing: 5px;">${code}</h1>
      <p>This code will expire in 15 minutes.</p>
      <p>If you didn't request this, please ignore this email.</p>
    `
  });
}
```

**Gmail App Password Setup:**
1. Go to Google Account settings
2. Security → 2-Step Verification (enable it)
3. App Passwords → Generate new password
4. Use that password in your code

---

### Option 2: **SendGrid** (Reliable, Free tier available)
```javascript
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

async function sendResetCode(email, code) {
  await sgMail.send({
    to: email,
    from: 'noreply@swiftdrop.com', // Must be verified in SendGrid
    subject: 'Password Reset Code - SwiftDrop',
    html: `
      <h2>Password Reset Request</h2>
      <p>Your password reset code is:</p>
      <h1 style="color: #FF5722; letter-spacing: 5px;">${code}</h1>
      <p>This code will expire in 15 minutes.</p>
    `
  });
}
```

**SendGrid Setup:**
1. Sign up at sendgrid.com
2. Create API key
3. Verify sender email
4. Use API key in your backend

---

### Option 3: **AWS SES** (Production-ready, cost-effective)
```javascript
const AWS = require('aws-sdk');
const ses = new AWS.SES({ region: 'us-east-1' });

async function sendResetCode(email, code) {
  const params = {
    Source: 'noreply@swiftdrop.com',
    Destination: { ToAddresses: [email] },
    Message: {
      Subject: { Data: 'Password Reset Code - SwiftDrop' },
      Body: {
        Html: {
          Data: `
            <h2>Password Reset Request</h2>
            <p>Your password reset code is:</p>
            <h1 style="color: #FF5722; letter-spacing: 5px;">${code}</h1>
            <p>This code will expire in 15 minutes.</p>
          `
        }
      }
    }
  };
  await ses.sendEmail(params).promise();
}
```

---

## Sample Backend Implementation (Node.js/Express)

```javascript
// forgot-password endpoint
app.post('/api/auth/forgot-password', async (req, res) => {
  try {
    const { email, role } = req.body;
    
    // Find user
    const user = await User.findOne({ email, role });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Generate 6-digit code
    const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Save code with expiry (15 minutes)
    user.resetCode = resetCode;
    user.resetCodeExpiry = Date.now() + 15 * 60 * 1000;
    await user.save();
    
    // Send email
    await sendResetCode(email, resetCode);
    
    res.json({ message: 'Reset code sent to your email' });
  } catch (error) {
    console.error('Forgot password error:', error);
    res.status(500).json({ message: 'Failed to send reset code' });
  }
});

// reset-password endpoint
app.post('/api/auth/reset-password', async (req, res) => {
  try {
    const { email, token, newPassword, role } = req.body;
    
    // Find user
    const user = await User.findOne({ email, role });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Verify code
    if (user.resetCode !== token) {
      return res.status(400).json({ message: 'Invalid reset code' });
    }
    
    // Check expiry
    if (Date.now() > user.resetCodeExpiry) {
      return res.status(400).json({ message: 'Reset code has expired' });
    }
    
    // Hash new password
    const bcrypt = require('bcrypt');
    user.password = await bcrypt.hash(newPassword, 10);
    
    // Clear reset code
    user.resetCode = undefined;
    user.resetCodeExpiry = undefined;
    await user.save();
    
    res.json({ message: 'Password reset successful' });
  } catch (error) {
    console.error('Reset password error:', error);
    res.status(500).json({ message: 'Failed to reset password' });
  }
});
```

---

## Testing

1. **Test email sending separately:**
   ```bash
   curl -X POST http://localhost:3000/api/auth/forgot-password \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com","role":"rider"}'
   ```

2. **Check backend logs** for email sending errors

3. **Verify email arrives** (check spam folder too)

4. **Test reset endpoint** with the received code

---

## Common Issues

### ❌ Email not sending
- **Check:** Email service credentials are correct
- **Check:** Sender email is verified (for SendGrid/SES)
- **Check:** Gmail "Less secure app access" or use App Password
- **Check:** Backend logs for error messages

### ❌ Code expired
- Increase expiry time (currently 15 minutes)
- Make sure server time is correct

### ❌ Email goes to spam
- Use a verified domain
- Add SPF/DKIM records to your domain
- Use reputable email service (SendGrid, AWS SES)

---

## Frontend Status ✅

The frontend implementation is **complete** and includes:
- ✅ Forgot password dialog with email input
- ✅ 6-digit code input
- ✅ New password input
- ✅ API calls to backend endpoints
- ✅ Error handling
- ✅ Success messages
- ✅ User guidance (check spam folder notice)

**The issue is purely on the backend side - email service needs to be configured.**

---

## Need Help?

If you need help setting up the backend email service:
1. Share which backend framework you're using (Node.js, Django, Laravel, etc.)
2. Share any error messages from backend logs
3. Choose an email service provider from the options above
