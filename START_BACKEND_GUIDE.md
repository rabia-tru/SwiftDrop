# SwiftDrop Backend Setup Guide

## Problem: Backend Server Down

Agar app mein "Server is not running" ya connection errors aa rahe hain, toh backend server start karna hoga.

## Solution 1: USB Debugging Ke Saath (Recommended)

### Step 1: Backend Server Start Karo

```bash
# Backend folder mein jao
cd path/to/backend

# Dependencies install karo (pehli baar)
npm install

# Server start karo
npm start
```

### Step 2: ADB Reverse Setup Karo

Phone ko USB se connect karo aur yeh command run karo:

```bash
adb reverse tcp:3000 tcp:3000
```

Ab app `127.0.0.1:3000` par backend access kar sakta hai!

---

## Solution 2: WiFi Se Connect (Alternative)

Agar USB debugging nahi kar sakte, toh WiFi use karo:

### Step 1: Apne PC Ka IP Address Nikalo

**Windows:**
```bash
ipconfig
```
`IPv4 Address` dekho (jaise: `192.168.1.100`)

**Mac/Linux:**
```bash
ifconfig | grep inet
```

### Step 2: App Config Update Karo

`lib/config/app_config.dart` file mein:

```dart
static const String apiBaseUrl = 'http://YOUR_PC_IP:3000/api';
// Example: 'http://192.168.1.100:3000/api'
```

### Step 3: Backend Server Start Karo

Backend must listen on `0.0.0.0` (all interfaces), not just `localhost`:

```javascript
// server.js
app.listen(3000, '0.0.0.0', () => {
  console.log('Server running on port 3000');
});
```

### Step 4: Firewall Allow Karo

**Windows Firewall:**
1. Control Panel → Windows Defender Firewall
2. Advanced Settings → Inbound Rules
3. New Rule → Port → TCP → 3000 → Allow

---

## Solution 3: Mock Data Use Karo (Testing Ke Liye)

Agar abhi backend nahi hai, toh app mock data ke saath kaam karega:

- Customer app: Empty restaurant list dikhegi
- Rider app: No orders dikhega
- Login/Register: Error message aayega

App crash nahi hoga - graceful error handling hai!

---

## Backend Start Hone Ki Verification

Browser mein check karo:
- `http://localhost:3000` - Homepage dikhe
- `http://localhost:3000/api/health` - Health check response

---

## Common Issues

### 1. "EADDRINUSE" Error
Port already use ho raha hai:
```bash
# Windows
netstat -ano | findstr :3000
taskkill /PID <PID> /F

# Mac/Linux
lsof -ti:3000 | xargs kill -9
```

### 2. "Connection Refused"
- Backend server running nahi hai - start karo
- Firewall block kar raha hai - allow karo
- Wrong IP address - check karo

### 3. "No route to host"
- Phone aur PC same WiFi network par nahi hain
- Firewall port 3000 block kar raha hai

---

## Quick Test Commands

```bash
# Backend server check karo
curl http://localhost:3000/api/health

# ADB reverse check karo (phone se)
adb shell
curl http://127.0.0.1:3000/api/health

# WiFi connection check karo (phone se browser)
http://YOUR_PC_IP:3000
```

---

## Need Backend Code?

Agar aapke paas backend code nahi hai, toh main ek simple Node.js/Express backend bana sakta hoon with:
- Authentication (Login/Register)
- Order Management
- WebSocket Tracking
- Restaurant/Menu APIs
- Background Service Endpoints

Batao agar backend code chahiye!
