# Quick Reference Guide

## Authentication Flow

```bash
# 1. Login
TOKEN=$(curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user1","password":"1"}' | jq -r '.accessToken')

# 2. Use token in requests
curl http://localhost:3001/api/auth/me \
  -H "Authorization: Bearer $TOKEN"
```

## Health Data Sync

```bash
curl -X POST http://localhost:3001/api/health/sync \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sleepData": [{"date": "2025-11-09", "total_sleep_mins": 480}],
    "activityData": [{"date": "2025-11-09", "steps": 8500}]
  }'
```

## Database Access

```bash
# Access SQLite database
sqlite3 server/database/zoe.db

# Useful queries
SELECT * FROM users;
SELECT * FROM user_sleep_data WHERE user_id = 161;
SELECT * FROM user_interventions WHERE user_id = 161;
```

## HealthKit Swift Code

```swift
// Request authorization
let healthStore = HKHealthStore()
let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
healthStore.requestAuthorization(toShare: nil, read: [sleepType]) { success, error in
    // Fetch data
}
```

## Common Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/auth/login` | POST | Login |
| `/api/auth/me` | GET | Get current user |
| `/api/health/sync` | POST | Sync health data |
| `/api/health/sleep/:date` | GET | Get sleep for date |
| `/api/health/summary` | GET | Get health summary |
| `/api/user/interventions/active` | GET | Get active interventions |
| `/api/coach/customers` | GET | Get coach's customers |

## Environment Variables

Create `.env` file in `server/`:

```
JWT_SECRET=your-secret-key-change-in-production
JWT_REFRESH_SECRET=your-refresh-secret-key-change-in-production
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
PORT=3001
```

