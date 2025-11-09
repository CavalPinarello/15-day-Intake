# ZOE Sleep Platform - Complete API & Database Documentation

## Table of Contents
1. [Database Schema](#database-schema)
2. [API Endpoints](#api-endpoints)
3. [Authentication](#authentication)
4. [HealthKit Integration](#healthkit-integration)
5. [Examples](#examples)

---

## Database Schema

### Core Tables

#### Users
```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  email TEXT,
  current_day INTEGER DEFAULT 1,
  started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_accessed DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### Refresh Tokens
```sql
CREATE TABLE refresh_tokens (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  token TEXT UNIQUE NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  revoked BOOLEAN DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### Health Data Tables

#### User Sleep Data
```sql
CREATE TABLE user_sleep_data (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  date DATE NOT NULL,
  in_bed_time DATETIME,
  asleep_time DATETIME,
  wake_time DATETIME,
  total_sleep_mins INTEGER,
  sleep_efficiency REAL,
  deep_sleep_mins INTEGER,
  light_sleep_mins INTEGER,
  rem_sleep_mins INTEGER,
  awake_mins INTEGER,
  interruptions_count INTEGER DEFAULT 0,
  sleep_latency_mins INTEGER,
  synced_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, date)
);
```

#### User Heart Rate
```sql
CREATE TABLE user_heart_rate (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  date DATE NOT NULL,
  resting_hr INTEGER,
  avg_hr INTEGER,
  hrv_morning REAL,
  hrv_avg REAL,
  synced_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, date)
);
```

#### User Activity
```sql
CREATE TABLE user_activity (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  date DATE NOT NULL,
  steps INTEGER DEFAULT 0,
  active_mins INTEGER DEFAULT 0,
  exercise_mins INTEGER DEFAULT 0,
  calories_burned INTEGER DEFAULT 0,
  synced_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, date)
);
```

#### User Baselines
```sql
CREATE TABLE user_baselines (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  metric_name TEXT NOT NULL,
  baseline_value REAL NOT NULL,
  calculated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  period_days INTEGER DEFAULT 30,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, metric_name)
);
```

### Interventions Tables

#### Interventions Library
```sql
CREATE TABLE interventions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT,
  category TEXT,
  evidence_score INTEGER,
  recommended_duration_weeks INTEGER,
  safety_rating INTEGER,
  primary_benefit TEXT,
  instructions_text TEXT,
  created_by_coach_id INTEGER,
  status TEXT DEFAULT 'active',
  version INTEGER DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### User Interventions
```sql
CREATE TABLE user_interventions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  intervention_id INTEGER NOT NULL,
  assigned_by_coach_id INTEGER,
  start_date DATE NOT NULL,
  end_date DATE,
  frequency TEXT,
  schedule_json TEXT,
  status TEXT DEFAULT 'active',
  assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (intervention_id) REFERENCES interventions(id) ON DELETE CASCADE
);
```

### Coach Dashboard Tables

#### Coaches
```sql
CREATE TABLE coaches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT,
  permissions_json TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### Customer-Coach Assignments
```sql
CREATE TABLE customer_coach_assignments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  coach_id INTEGER NOT NULL,
  assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  status TEXT DEFAULT 'active',
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (coach_id) REFERENCES coaches(id) ON DELETE CASCADE,
  UNIQUE(user_id, coach_id)
);
```

---

## API Endpoints

### Base URL
```
http://localhost:3001/api
```

### Authentication

All protected endpoints require a JWT access token in the Authorization header:
```
Authorization: Bearer <access_token>
```

---

### Auth Endpoints

#### POST /api/auth/register
Register a new user.

**Request:**
```json
{
  "username": "newuser",
  "password": "SecurePass123!",
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": 1,
    "username": "newuser",
    "email": "user@example.com",
    "current_day": 1
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### POST /api/auth/login
Login and get JWT tokens.

**Request:**
```json
{
  "username": "user1",
  "password": "1"
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": 161,
    "username": "user1",
    "current_day": 1
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### POST /api/auth/refresh
Refresh access token.

**Request:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**
```json
{
  "success": true,
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### GET /api/auth/me
Get current user (requires authentication).

**Response:**
```json
{
  "user": {
    "id": 161,
    "username": "user1",
    "email": null,
    "current_day": 1,
    "started_at": "2025-11-09T10:00:00.000Z",
    "last_accessed": "2025-11-09T16:00:00.000Z"
  }
}
```

---

### Health Data Endpoints

#### POST /api/health/sync
Bulk upload health data from device (Apple Health, etc.).

**Request:**
```json
{
  "sleepData": [
    {
      "date": "2025-11-09",
      "in_bed_time": "2025-11-08T22:00:00Z",
      "asleep_time": "2025-11-08T22:30:00Z",
      "wake_time": "2025-11-09T06:30:00Z",
      "total_sleep_mins": 480,
      "sleep_efficiency": 85.5,
      "deep_sleep_mins": 120,
      "light_sleep_mins": 180,
      "rem_sleep_mins": 90,
      "awake_mins": 90,
      "interruptions_count": 2,
      "sleep_latency_mins": 30
    }
  ],
  "heartRateData": [
    {
      "date": "2025-11-09",
      "resting_hr": 58,
      "avg_hr": 62,
      "hrv_morning": 45.2,
      "hrv_avg": 42.1
    }
  ],
  "activityData": [
    {
      "date": "2025-11-09",
      "steps": 8500,
      "active_mins": 45,
      "exercise_mins": 30,
      "calories_burned": 450
    }
  ],
  "workouts": [
    {
      "date": "2025-11-09",
      "workout_type": "Running",
      "start_time": "2025-11-09T07:00:00Z",
      "duration_mins": 30,
      "avg_hr": 145,
      "max_hr": 165,
      "calories": 300,
      "distance_km": 5.2,
      "intensity_zones": {
        "zone1": 5,
        "zone2": 10,
        "zone3": 10,
        "zone4": 5
      }
    }
  ],
  "sleepStages": [
    {
      "date": "2025-11-09",
      "start_time": "2025-11-08T22:30:00Z",
      "end_time": "2025-11-08T23:30:00Z",
      "stage": "deep",
      "duration_mins": 60
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Health data synced successfully",
  "results": {
    "sleepData": { "inserted": 1, "updated": 0, "errors": [] },
    "heartRateData": { "inserted": 1, "updated": 0, "errors": [] },
    "activityData": { "inserted": 1, "updated": 0, "errors": [] },
    "workouts": { "inserted": 1, "errors": [] },
    "sleepStages": { "inserted": 1, "errors": [] }
  }
}
```

#### GET /api/health/sleep/:date
Get sleep data for a specific date.

**Response:**
```json
{
  "sleepData": {
    "id": 1,
    "user_id": 161,
    "date": "2025-11-09",
    "total_sleep_mins": 480,
    "sleep_efficiency": 85.5,
    "deep_sleep_mins": 120,
    "rem_sleep_mins": 90
  },
  "stages": [
    {
      "id": 1,
      "stage": "deep",
      "start_time": "2025-11-08T22:30:00Z",
      "end_time": "2025-11-08T23:30:00Z",
      "duration_mins": 60
    }
  ]
}
```

#### GET /api/health/sleep
Get sleep data for a date range.

**Query Parameters:**
- `startDate` (optional): ISO 8601 date
- `endDate` (optional): ISO 8601 date
- `limit` (optional): Number of records (default: 30, max: 100)

**Example:**
```
GET /api/health/sleep?startDate=2025-11-01&endDate=2025-11-09&limit=30
```

#### GET /api/health/summary
Get comprehensive health summary.

**Query Parameters:**
- `startDate` (optional): ISO 8601 date
- `endDate` (optional): ISO 8601 date

**Response:**
```json
{
  "period": {
    "start": "2025-10-01",
    "end": "2025-11-09"
  },
  "sleep": {
    "avg_sleep_mins": 465.5,
    "avg_efficiency": 84.2,
    "avg_deep_sleep": 115.3,
    "avg_rem_sleep": 88.7,
    "days_count": 30
  },
  "activity": {
    "avg_steps": 8250.5,
    "avg_active_mins": 42.3,
    "avg_exercise_mins": 28.5,
    "total_calories": 13500
  },
  "heartRate": {
    "avg_resting_hr": 58.2,
    "avg_hrv": 43.5
  }
}
```

---

### Intervention Endpoints

#### GET /api/user/interventions/active
Get user's active interventions.

**Response:**
```json
{
  "interventions": [
    {
      "id": 1,
      "intervention_id": 5,
      "intervention_name": "Evening Meditation",
      "intervention_type": "mindfulness",
      "start_date": "2025-11-01",
      "frequency": "daily",
      "schedule_json": {
        "time": "20:00",
        "days": ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
      },
      "status": "active"
    }
  ]
}
```

#### POST /api/user/interventions/:id/complete
Mark intervention task as completed.

**Request:**
```json
{
  "scheduled_date": "2025-11-09",
  "note": "Completed 10-minute meditation"
}
```

#### POST /api/user/interventions/:id/note
Add user note to intervention.

**Request:**
```json
{
  "note_text": "Feeling more relaxed after meditation",
  "mood_rating": 8
}
```

---

### Coach Endpoints

#### GET /api/coach/customers
Get list of coach's customers.

**Response:**
```json
{
  "customers": [
    {
      "id": 161,
      "username": "user1",
      "email": "user1@example.com",
      "current_day": 5,
      "assigned_at": "2025-11-01T10:00:00Z"
    }
  ]
}
```

#### GET /api/coach/customers/:id/health-stats
Get customer health statistics.

**Query Parameters:**
- `days` (optional): Number of days to analyze (default: 30, max: 365)

**Response:**
```json
{
  "period": {
    "days": 30,
    "startDate": "2025-10-01"
  },
  "sleep": {
    "avg_sleep_mins": 465.5,
    "avg_efficiency": 84.2
  },
  "activity": {
    "avg_steps": 8250.5,
    "total_calories": 13500
  },
  "compliance": {
    "total_tasks": 30,
    "completed_tasks": 25
  }
}
```

#### POST /api/coach/interventions/assign
Assign intervention to user.

**Request:**
```json
{
  "user_id": 161,
  "intervention_id": 5,
  "start_date": "2025-11-10",
  "end_date": "2025-12-10",
  "frequency": "daily",
  "schedule_json": {
    "time": "20:00"
  },
  "custom_instructions": "Focus on deep breathing"
}
```

---

## HealthKit Integration

### iOS Setup

#### 1. Enable HealthKit Capability

1. Open your Xcode project
2. Select your target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add "HealthKit"

#### 2. Add Info.plist Entries

Add to `Info.plist`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>We need access to your health data to provide personalized sleep insights.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>We need to update your health data to track your sleep progress.</string>
```

#### 3. Request Authorization

```swift
import HealthKit

class HealthKitManager {
    let healthStore = HKHealthStore()
    
    // Request authorization for read access
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        // Define data types to read
        let readTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            if let error = error {
                print("HealthKit authorization error: \(error.localizedDescription)")
                return
            }
            
            if success {
                print("HealthKit authorization granted")
                self.fetchSleepData()
            }
        }
    }
    
    // Fetch sleep data
    func fetchSleepData() {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -90, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        ) { query, samples, error in
            guard let samples = samples as? [HKCategorySample] else {
                if let error = error {
                    print("Error fetching sleep data: \(error.localizedDescription)")
                }
                return
            }
            
            self.processSleepSamples(samples)
        }
        
        healthStore.execute(query)
    }
    
    // Process sleep samples
    func processSleepSamples(_ samples: [HKCategorySample]) {
        var sleepData: [String: Any] = [:]
        var sleepStages: [[String: Any]] = []
        
        for sample in samples {
            let dateFormatter = ISO8601DateFormatter()
            let dateKey = dateFormatter.string(from: sample.startDate).prefix(10) // YYYY-MM-DD
            
            let value = sample.value
            let stage: String
            
            switch value {
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                stage = "light"
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                stage = "light"
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                stage = "deep"
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                stage = "rem"
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                stage = "awake"
            default:
                stage = "unknown"
            }
            
            let duration = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60) // minutes
            
            sleepStages.append([
                "date": String(dateKey),
                "start_time": dateFormatter.string(from: sample.startDate),
                "end_time": dateFormatter.string(from: sample.endDate),
                "stage": stage,
                "duration_mins": duration
            ])
        }
        
        // Group by date and calculate totals
        let grouped = Dictionary(grouping: sleepStages) { $0["date"] as! String }
        
        for (date, stages) in grouped {
            let totalMins = stages.reduce(0) { $0 + ($1["duration_mins"] as! Int) }
            let deepMins = stages.filter { $0["stage"] as! String == "deep" }
                .reduce(0) { $0 + ($1["duration_mins"] as! Int) }
            let remMins = stages.filter { $0["stage"] as! String == "rem" }
                .reduce(0) { $0 + ($1["duration_mins"] as! Int) }
            let lightMins = stages.filter { $0["stage"] as! String == "light" }
                .reduce(0) { $0 + ($1["duration_mins"] as! Int) }
            let awakeMins = stages.filter { $0["stage"] as! String == "awake" }
                .reduce(0) { $0 + ($1["duration_mins"] as! Int) }
            
            // Find in-bed and wake times
            let sortedStages = stages.sorted { 
                ($0["start_time"] as! String) < ($1["start_time"] as! String) 
            }
            let inBedTime = sortedStages.first?["start_time"] as? String
            let wakeTime = sortedStages.last?["end_time"] as? String
            
            sleepData[date] = [
                "date": date,
                "in_bed_time": inBedTime,
                "wake_time": wakeTime,
                "total_sleep_mins": totalMins - awakeMins,
                "sleep_efficiency": Double(totalMins - awakeMins) / Double(totalMins) * 100,
                "deep_sleep_mins": deepMins,
                "light_sleep_mins": lightMins,
                "rem_sleep_mins": remMins,
                "awake_mins": awakeMins
            ]
        }
        
        // Send to API
        self.syncToAPI(sleepData: Array(sleepData.values), sleepStages: sleepStages)
    }
    
    // Sync data to backend API
    func syncToAPI(sleepData: [[String: Any]], sleepStages: [[String: Any]]) {
        guard let accessToken = UserDefaults.standard.string(forKey: "accessToken") else {
            print("No access token found")
            return
        }
        
        let url = URL(string: "http://localhost:3001/api/health/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "sleepData": sleepData,
            "sleepStages": sleepStages
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Sync error: \(error.localizedDescription)")
                return
            }
            
            if let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Sync successful: \(json)")
                }
            }
        }.resume()
    }
    
    // Fetch heart rate data
    func fetchHeartRateData() {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        ) { query, samples, error in
            guard let samples = samples as? [HKQuantitySample] else {
                if let error = error {
                    print("Error fetching heart rate: \(error.localizedDescription)")
                }
                return
            }
            
            self.processHeartRateSamples(samples)
        }
        
        healthStore.execute(query)
    }
    
    func processHeartRateSamples(_ samples: [HKQuantitySample]) {
        var heartRateData: [String: [Double]] = [:]
        
        for sample in samples {
            let dateFormatter = ISO8601DateFormatter()
            let dateKey = dateFormatter.string(from: sample.startDate).prefix(10)
            let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
            
            if heartRateData[String(dateKey)] == nil {
                heartRateData[String(dateKey)] = []
            }
            heartRateData[String(dateKey)]?.append(heartRate)
        }
        
        var processedData: [[String: Any]] = []
        for (date, rates) in heartRateData {
            let avgHR = rates.reduce(0, +) / Double(rates.count)
            let restingHR = rates.filter { $0 < 100 }.reduce(0, +) / Double(rates.filter { $0 < 100 }.count)
            
            processedData.append([
                "date": date,
                "resting_hr": Int(restingHR),
                "avg_hr": Int(avgHR)
            ])
        }
        
        // Send to API
        self.syncHeartRateToAPI(heartRateData: processedData)
    }
    
    func syncHeartRateToAPI(heartRateData: [[String: Any]]) {
        guard let accessToken = UserDefaults.standard.string(forKey: "accessToken") else {
            return
        }
        
        let url = URL(string: "http://localhost:3001/api/health/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "heartRateData": heartRateData
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Heart rate sync error: \(error.localizedDescription)")
            }
        }.resume()
    }
}
```

### Usage Example

```swift
// In your ViewController or AppDelegate
let healthKitManager = HealthKitManager()
healthKitManager.requestAuthorization()

// Fetch data periodically (e.g., daily at 6 AM)
// Use background fetch or local notifications to trigger sync
```

---

## Examples

### Complete Workflow Example

```bash
# 1. Register/Login
TOKEN=$(curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user1","password":"1"}' | jq -r '.accessToken')

# 2. Sync health data
curl -X POST http://localhost:3001/api/health/sync \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sleepData": [{
      "date": "2025-11-09",
      "total_sleep_mins": 480,
      "sleep_efficiency": 85.5,
      "deep_sleep_mins": 120,
      "rem_sleep_mins": 90
    }],
    "activityData": [{
      "date": "2025-11-09",
      "steps": 8500,
      "active_mins": 45
    }]
  }'

# 3. Get health summary
curl http://localhost:3001/api/health/summary?startDate=2025-11-01&endDate=2025-11-09 \
  -H "Authorization: Bearer $TOKEN"

# 4. Get active interventions
curl http://localhost:3001/api/user/interventions/active \
  -H "Authorization: Bearer $TOKEN"

# 5. Complete intervention task
curl -X POST http://localhost:3001/api/user/interventions/1/complete \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "scheduled_date": "2025-11-09",
    "note": "Completed meditation"
  }'
```

---

## Database Queries

### Useful SQL Queries

```sql
-- Get user's sleep data for last 30 days
SELECT * FROM user_sleep_data
WHERE user_id = 161 AND date >= date('now', '-30 days')
ORDER BY date DESC;

-- Calculate average sleep efficiency
SELECT AVG(sleep_efficiency) as avg_efficiency
FROM user_sleep_data
WHERE user_id = 161 AND date >= date('now', '-30 days');

-- Get intervention compliance rate
SELECT 
  COUNT(*) as total_tasks,
  SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) as completed,
  ROUND(SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as compliance_rate
FROM intervention_compliance ic
JOIN user_interventions ui ON ic.user_intervention_id = ui.id
WHERE ui.user_id = 161 AND ic.scheduled_date >= date('now', '-30 days');

-- Get coach's customers with recent activity
SELECT 
  u.id,
  u.username,
  u.last_accessed,
  COUNT(DISTINCT usd.date) as days_with_sleep_data
FROM customer_coach_assignments cca
JOIN users u ON cca.user_id = u.id
LEFT JOIN user_sleep_data usd ON u.id = usd.user_id AND usd.date >= date('now', '-7 days')
WHERE cca.coach_id = 1 AND cca.status = 'active'
GROUP BY u.id, u.username, u.last_accessed;
```

---

## Error Handling

All endpoints return standard error responses:

```json
{
  "error": "Error message here"
}
```

Common HTTP status codes:
- `200` - Success
- `201` - Created
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (access denied)
- `404` - Not Found
- `500` - Internal Server Error

---

## Rate Limiting

- General endpoints: 100 requests per 15 minutes per IP
- Auth endpoints: 5 requests per 15 minutes per IP

Rate limit headers:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1636473600
```

