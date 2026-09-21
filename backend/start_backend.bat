@echo off
cd /d C:\Users\rabia\Downloads\rider_app\backend
set PORT=3000
set DB_HOST=127.0.0.1
set DB_PORT=5432
set DB_USERNAME=postgres
set DB_PASSWORD=your_postgres_password
set DB_NAME=delivery_tracker
set JWT_SECRET=change-this-to-a-random-secret
node dist/main.js
