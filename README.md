# SwiftDrop 🚀

A complete food-delivery platform with a **Flutter mobile app** (Customer + Rider) and a **NestJS backend** with a business portal for restaurants. Built as a foodpanda-style ordering & live-tracking experience.

## ✨ Features

### 🛍 Customer
- Browse restaurants & menus with images, categories and search
- Cart with quantity control and delete confirmations
- Place orders and track them live on a map
- Real-time order status updates over WebSocket
- Chat with the rider, rate orders after delivery
- Forgot-password via email OTP

### 🏍 Rider
- Accept/reject assigned orders with confirmation dialogs
- Full status flow: `assigned → accepted → picked_up → in_transit → delivered`
- Background GPS location streaming for live tracking
- Earnings dashboard, referral & QR features

### 🏪 Business (Restaurant)
- Own portal inside the same app: dashboard, menu manager (add/edit items with images), incoming orders
- Accept orders ("Preparing 🔥"), which auto-assign the nearest online rider — or broadcast to the rider fleet until one comes online
- Live "new order" notifications

## 🛠 Tech Stack

| Layer      | Technology |
|------------|------------|
| Mobile app | Flutter (Dart), Provider, flutter_map, socket_io_client, geolocator, flutter_background_service |
| Backend    | NestJS 11, TypeORM, PostgreSQL, Socket.IO, JWT + Passport, bcrypt, Nodemailer |
| Realtime   | WebSocket (Socket.IO) for order events, rider location & chat |

## 📁 Project Structure

```
├── lib/                  # Flutter app (all roles: customer, rider, business)
│   ├── screens/          # 38 screens (splash, onboarding, home, orders, tracking…)
│   ├── services/         # API client, WebSocket, cart, auth services
│   └── widgets/          # Shared UI components
├── backend/              # NestJS API
│   └── src/
│       ├── auth/         # JWT auth, register/login, forgot/reset password
│       ├── orders/       # Order lifecycle + status transitions
│       ├── riders/       # Rider status, location, auto-assignment
│       ├── businesses/   # Business portal endpoints
│       └── location/     # GPS ping storage & retrieval
└── backend/seed-*.sql/js # Seed data (restaurants, menus, users)
```

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK** ≥ 3.35 (Dart ≥ 3.12)
- **Node.js** ≥ 18 & npm
- **PostgreSQL** ≥ 14
- An Android device/emulator (Android 5.0+)

### 1. Database

Create the database:

```sql
CREATE DATABASE delivery_tracker;
```

### 2. Backend setup

```bash
cd backend
npm install
```

Create `backend/.env` (see `.env.example`):

```env
NODE_ENV=development
PORT=3000

DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=your_postgres_password
DB_NAME=delivery_tracker

JWT_SECRET=change-this-to-a-long-random-string

# Optional — enables real reset emails (Gmail App Password)
SMTP_USER=your@gmail.com
SMTP_PASS=your_16_char_app_password
```

Tables auto-create on first start (TypeORM synchronize). Seed demo data (restaurants, menus, test users):

```bash
node seed-restaurants.js          # basic catalog
# or
psql -U postgres -d delivery_tracker -f seed-foodpanda-style.sql
```

Start the API:

```bash
npm run build
npm run start:prod     # serves on http://localhost:3000
# or for development:
npm run start:dev
```

### 3. Flutter app setup

Point the app at your backend machine's LAN IP in `lib/config/app_config.dart`:

```dart
static const String apiBaseUrl = 'http://<YOUR-PC-IP>:3000/api';
```

> Phone and PC must be on the **same Wi-Fi network**. Run `ipconfig` (Windows) / `ifconfig` (Mac/Linux) to find the PC's IP.

Then:

```bash
flutter pub get
flutter run                # debug
# or build a release APK:
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

## 👤 Test Roles

The app has a role-selection landing screen — **Customer**, **Rider**, **Business**, each with its own login/register flow (rider registration includes document upload). Create accounts via the register screens, or use accounts from the seed files.

## 🔄 Order Lifecycle

```
Customer orders → PENDING → Business accepts (Preparing) → rider auto-assigned
→ ASSIGNED → rider accepts → ACCEPTED → picked up → PICKED_UP
→ in transit → IN_TRANSIT → delivered → DELIVERED ✅
```

- The backend validates every status transition (no skipping steps).
- If no rider is online when the business accepts, the order broadcasts to the whole rider fleet; the first rider to come online gets it auto-assigned (FIFO).
- Rider GPS pings are stored (`location_logs`) so customers see live position on the map.

## 🔐 Security Notes

- All secrets (DB password, JWT secret, SMTP credentials) load from `backend/.env`, which is **gitignored** — never commit real credentials.
- Passwords are bcrypt-hashed; API routes are JWT-protected.
- Password-reset codes expire after 15 minutes. If SMTP isn't configured, the code is returned as a `_devCode` field for development only.

## 📄 License

Private/educational project — all rights reserved.
