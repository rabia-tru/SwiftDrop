# 🚀 SwiftDrop Email Service Setup Guide

## Email: bia407493@gmail.com

---

## ⚡ Quick Setup (5 Minutes)

### Step 1: Install Dependencies
```bash
npm install nodemailer express body-parser cors
```

### Step 2: Get Google App Password

1. **Go to Google Account Settings**
   - Visit: https://myaccount.google.com/security
   - Login with `bia407493@gmail.com`

2. **Enable 2-Step Verification**
   - Click "2-Step Verification"
   - Turn it ON if not already enabled

3. **Generate App Password**
   - Scroll down to "App passwords"
   - Click "App passwords"
   - Select app: "Mail"
   - Select device: "Other (Custom name)"
   - Type: "SwiftDrop"
   - Click "Generate"
   - **COPY the 16-digit password** (looks like: `abcd efgh ijkl mnop`)

4. **Update backend_email_service.js**
   - Open `backend_email_service.js`
   - Line 29: Replace `YOUR_APP_PASSWORD` with the copied password
   ```javascript
   pass: 'abcd efgh ijkl mnop' // Your actual app password
   ```

### Step 3: Start the Server
```bash
node backend_email_service.js
```

### Step 4: Test Email
Open browser and visit:
```
http://localhost:3000/api/auth/test-email
```

You should receive a test email at `bia407493@gmail.com`!

---

## 📧 API Endpoints

### 1. **Forgot Password**
```bash
POST http://localhost:3000/api/auth/forgot-password
Content-Type: application/json

{
  "email": "user@example.com",
  "role": "rider"
}
```

**Response:**
```json
{
  "message": "Reset code sent to your email",
  "email": "user@example.com",
  "debug_code": "123456"
}
```

**Email will be sent** with a 6-digit code!

---

### 2. **Reset Password**
```bash
POST http://localhost:3000/api/auth/reset-password
Content-Type: application/json

{
  "email": "user@example.com",
  "token": "123456",
  "newPassword": "newpass123",
  "role": "rider"
}
```

**Response:**
```json
{
  "message": "Password reset successful",
  "email": "user@example.com"
}
```

---

### 3. **Test Email** (Quick Test)
```bash
GET http://localhost:3000/api/auth/test-email
```

Sends test email to `bia407493@gmail.com`

---

### 4. **Health Check**
```bash
GET http://localhost:3000/api/health
```

---

### 5. **Debug Codes** (Development Only)
```bash
GET http://localhost:3000/api/auth/debug-codes
```

Shows all active reset codes

---

## 🎨 Email Template Preview

The email looks like this:

```
┌─────────────────────────────────────┐
│      🚀 SwiftDrop                   │
│      Fast Food Delivery             │
├─────────────────────────────────────┤
│                                     │
│  Password Reset Request             │
│                                     │
│  You requested to reset your        │
│  password. Use the code below:      │
│                                     │
│  ╔═══════════════════╗              │
│  ║                   ║              │
│  ║    1 2 3 4 5 6    ║  (Orange)   │
│  ║                   ║              │
│  ║  Valid 15 minutes ║              │
│  ╚═══════════════════╝              │
│                                     │
│  ⚠️ Security Notice:                │
│  • Don't share this code            │
│  • SwiftDrop never asks via call    │
│                                     │
├─────────────────────────────────────┤
│  © 2024 SwiftDrop                   │
└─────────────────────────────────────┘
```

---

## 🔧 Configuration

### Email Settings (Customizable)

In `backend_email_service.js`:

```javascript
// Change sender name
from: 'SwiftDrop <bia407493@gmail.com>'

// Change code expiry (default: 15 minutes)
const expiryTime = Date.now() + 15 * 60 * 1000;

// Change code length (default: 6 digits)
const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
```

---

## 🧪 Testing Guide

### Test 1: Send Email
```bash
# Terminal 1: Start server
node backend_email_service.js

# Terminal 2: Test endpoint
curl http://localhost:3000/api/auth/test-email
```

**Expected:** Email received at `bia407493@gmail.com`

---

### Test 2: Forgot Password Flow
```bash
# Request reset code
curl -X POST http://localhost:3000/api/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","role":"rider"}'

# Response will include debug_code
# Use that code to reset password

curl -X POST http://localhost:3000/api/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","token":"123456","newPassword":"newpass123","role":"rider"}'
```

---

### Test 3: From Flutter App
1. Start backend: `node backend_email_service.js`
2. Update app config: `lib/config/app_config.dart`
   ```dart
   static const String apiBaseUrl = 'http://192.168.54.240:3000/api';
   ```
3. Run app and click "Forgot Password"
4. Enter email and check inbox!

---

## 📱 Connect to Flutter App

### Update API URL (if needed):

In `lib/config/app_config.dart`:
```dart
// For USB debugging
static const String apiBaseUrl = 'http://127.0.0.1:3000/api';

// For WiFi (replace with your PC IP)
static const String apiBaseUrl = 'http://192.168.1.100:3000/api';
```

### ADB Reverse (USB):
```bash
adb reverse tcp:3000 tcp:3000
```

Now the app will send requests to your backend!

---

## ⚠️ Common Issues & Solutions

### Issue 1: "Invalid credentials"
**Solution:** Check Google App Password is correct
- Make sure you copied the full 16-digit password
- No spaces in the password string

### Issue 2: "Less secure app access"
**Solution:** Use App Password instead
- Regular Gmail password won't work
- Must use App Password from Google

### Issue 3: Email not received
**Solution:** 
- Check spam folder
- Verify email sent in terminal logs
- Test with `test-email` endpoint first

### Issue 4: "Connection refused"
**Solution:** 
- Make sure backend is running
- Check firewall isn't blocking port 3000
- Try `http://localhost:3000/api/health`

---

## 🎯 Production Checklist

Before deploying to production:

- [ ] Remove `debug_code` from response
- [ ] Use environment variables for credentials
- [ ] Store codes in database (not in-memory)
- [ ] Add rate limiting (prevent spam)
- [ ] Use HTTPS
- [ ] Add email verification
- [ ] Log all password reset attempts
- [ ] Add CAPTCHA to prevent bots

---

## 🔐 Security Notes

1. **App Password**: Keep it secret, never commit to Git
2. **Environment Variables**: Use `.env` file
   ```bash
   EMAIL_USER=bia407493@gmail.com
   EMAIL_PASS=your_app_password
   ```
3. **Rate Limiting**: Max 3 requests per hour per email
4. **Code Expiry**: Codes expire in 15 minutes
5. **One-Time Use**: Codes are deleted after use

---

## 📊 Server Logs

When server is running, you'll see:
```
✅ Email sent successfully: <message-id>
📧 Password reset requested for: user@example.com (rider)
🔑 Password reset attempt for: user@example.com
✅ Password reset successful for user@example.com
🗑️ Expired code removed for user@example.com
```

---

## 🚀 What's Working Now

- ✅ Email service configured with `bia407493@gmail.com`
- ✅ Beautiful HTML email templates
- ✅ 6-digit reset codes
- ✅ 15-minute expiry
- ✅ Test endpoints
- ✅ Debug tools
- ✅ Error handling
- ✅ Automatic cleanup

---

## 📞 Support

If you face any issues:
1. Check terminal logs for errors
2. Test with `/api/auth/test-email`
3. Verify Google App Password is correct
4. Check spam folder for emails
5. Try different email addresses

---

## ✨ Next Steps

1. Get Google App Password
2. Update `backend_email_service.js` line 29
3. Run `node backend_email_service.js`
4. Test with `/api/auth/test-email`
5. Try forgot password in app!

**Email service ab kaam karega!** 🎉
