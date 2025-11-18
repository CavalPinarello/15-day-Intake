# Complete Database Schema Documentation

## Overview

This document describes the complete database schema that integrates all 5 components of the ZOE Sleep Platform.

## Component Integration

- **Component 1**: 14-Day Onboarding Journey
- **Component 2**: Daily App Use
- **Component 3**: Full Sleep Report
- **Component 4**: Coach Dashboard
- **Component 5**: Supporting Systems

---

## Core Tables

### users
Primary user accounts table.

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  email TEXT,
  current_day INTEGER DEFAULT 1,
  started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_accessed DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  apple_health_connected BOOLEAN DEFAULT 0,
  onboarding_completed BOOLEAN DEFAULT 0,
  onboarding_completed_at DATETIME
);
```

**Indexes:**
- `idx_users_email` on `email`
- `idx_users_onboarding` on `onboarding_completed, current_day`

---

## Component 1: 14-Day Onboarding Journey

### days
14-day journey structure.

```sql
CREATE TABLE days (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  day_number INTEGER NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT,
  theme_color TEXT,
  background_image TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### questions
Questions for each day (84 total across 14 days).

```sql
CREATE TABLE questions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  day_id INTEGER NOT NULL,
  question_text TEXT NOT NULL,
  question_type TEXT NOT NULL,
  options TEXT,  -- JSON
  order_index INTEGER NOT NULL,
  required BOOLEAN DEFAULT 1,
  conditional_logic TEXT,  -- JSON
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (day_id) REFERENCES days(id) ON DELETE CASCADE
);
```

### responses
User responses to questions.

```sql
CREATE TABLE responses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,
  day_id INTEGER NOT NULL,
  response_value TEXT,
  response_data TEXT,  -- JSON
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE,
  FOREIGN KEY (day_id) REFERENCES days(id) ON DELETE CASCADE,
  UNIQUE(user_id, question_id)
);
```

**Indexes:**
- `idx_responses_user_day` on `user_id, day_id`

### user_progress
Tracks user progress through the 14-day journey.

```sql
CREATE TABLE user_progress (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  day_id INTEGER NOT NULL,
  completed BOOLEAN DEFAULT 0,
  completed_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (day_id) REFERENCES days(id) ON DELETE CASCADE,
  UNIQUE(user_id, day_id)
);
```

**Indexes:**
- `idx_user_progress_user_day` on `user_id, day_id`

### onboarding_insights
Generated insights for each day (42 total: 3 per day × 14 days).

```sql
CREATE TABLE onboarding_insights (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  day_id INTEGER NOT NULL,
  insight_type TEXT NOT NULL,  -- 'personalized', 'fact', 'action'
  insight_text TEXT NOT NULL,
  generated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (day_id) REFERENCES days(id) ON DELETE CASCADE,
  UNIQUE(user_id, day_id, insight_type)
);
```

**Indexes:**
- `idx_onboarding_insights_user_day` on `user_id, day_id`

---

## Component 2: Daily App Use

### daily_checkins
Morning and evening check-ins.

```sql
CREATE TABLE daily_checkins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  checkin_date DATE NOT NULL,
  checkin_type TEXT NOT NULL CHECK(checkin_type IN ('morning', 'evening')),
  completed BOOLEAN DEFAULT 0,
  completed_at DATETIME,
  data_json TEXT,  -- JSON
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, checkin_date, checkin_type)
);
```

**Indexes:**
- `idx_checkins_user_date` on `user_id, checkin_date`
- `idx_checkins_user_type` on `user_id, checkin_type`

### checkin_responses
Responses to daily check-in questions.

```sql
CREATE TABLE checkin_responses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  checkin_id INTEGER NOT NULL,
  question_key TEXT NOT NULL,
  response_value TEXT,
  response_data TEXT,  -- JSON
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (checkin_id) REFERENCES daily_checkins(id) ON DELETE CASCADE,
  UNIQUE(checkin_id, question_key)
);
```

### user_preferences
User preferences and settings.

```sql
CREATE TABLE user_preferences (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL UNIQUE,
  notification_enabled BOOLEAN DEFAULT 1,
  notification_time TEXT DEFAULT '08:00',
  quiet_hours_start TEXT DEFAULT '22:00',
  quiet_hours_end TEXT DEFAULT '07:00',
  timezone TEXT DEFAULT 'UTC',
  apple_health_sync_enabled BOOLEAN DEFAULT 1,
  daily_reminder_enabled BOOLEAN DEFAULT 1,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

---

## Component 3: Full Sleep Report

### sleep_reports
Generated sleep reports.

```sql
CREATE TABLE sleep_reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  generated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  overall_score INTEGER,
  archetype TEXT,
  report_data_json TEXT,  -- JSON
  pdf_url TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

**Indexes:**
- `idx_reports_user_generated` on `user_id, generated_at`

### report_sections
8 sections per report.

```sql
CREATE TABLE report_sections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  report_id INTEGER NOT NULL,
  section_num INTEGER NOT NULL,
  name TEXT NOT NULL,
  score INTEGER,
  strengths_json TEXT,  -- JSON
  issues_json TEXT,  -- JSON
  findings_json TEXT,  -- JSON
  FOREIGN KEY (report_id) REFERENCES sleep_reports(id) ON DELETE CASCADE,
  UNIQUE(report_id, section_num)
);
```

### report_roadmap
Quarterly milestones and monthly tasks.

```sql
CREATE TABLE report_roadmap (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  report_id INTEGER NOT NULL,
  quarterly_milestones_json TEXT,  -- JSON
  monthly_tasks_json TEXT,  -- JSON
  FOREIGN KEY (report_id) REFERENCES sleep_reports(id) ON DELETE CASCADE,
  UNIQUE(report_id)
);
```

---

## Component 4: Coach Dashboard

### coaches
Coach accounts.

```sql
CREATE TABLE coaches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT,
  permissions_json TEXT,  -- JSON
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### customer_coach_assignments
User-coach relationships.

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

**Indexes:**
- `idx_coach_assignments_coach_status` on `coach_id, status`

### alerts
System alerts for coaches.

```sql
CREATE TABLE alerts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  coach_id INTEGER,
  alert_type TEXT NOT NULL,
  severity TEXT DEFAULT 'medium',
  message TEXT NOT NULL,
  data_json TEXT,  -- JSON
  resolved BOOLEAN DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  resolved_at DATETIME,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (coach_id) REFERENCES coaches(id) ON DELETE SET NULL
);
```

**Indexes:**
- `idx_alerts_user_coach_resolved` on `user_id, coach_id, resolved`

### messages
Coach-user messaging.

```sql
CREATE TABLE messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_user_id INTEGER,
  to_user_id INTEGER NOT NULL,
  message_text TEXT NOT NULL,
  read_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (from_user_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (to_user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

---

## Component 5: Supporting Systems

### Authentication

#### refresh_tokens
JWT refresh tokens.

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

**Indexes:**
- `idx_refresh_tokens_user_id` on `user_id`

### Health Data

#### user_sleep_data
Sleep metrics from Apple Health.

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

**Indexes:**
- `idx_sleep_data_user_date` on `user_id, date`

#### user_sleep_stages
Detailed sleep stage tracking.

```sql
CREATE TABLE user_sleep_stages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  date DATE NOT NULL,
  start_time DATETIME NOT NULL,
  end_time DATETIME NOT NULL,
  stage TEXT NOT NULL,
  duration_mins INTEGER,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

**Indexes:**
- `idx_sleep_stages_user_date` on `user_id, date`

#### user_heart_rate
Heart rate and HRV data.

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

**Indexes:**
- `idx_heart_rate_user_date` on `user_id, date`

#### user_activity
Activity data (steps, exercise, calories).

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

**Indexes:**
- `idx_activity_user_date` on `user_id, date`

#### user_workouts
Workout sessions.

```sql
CREATE TABLE user_workouts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  date DATE NOT NULL,
  workout_type TEXT,
  start_time DATETIME,
  duration_mins INTEGER,
  avg_hr INTEGER,
  max_hr INTEGER,
  calories INTEGER,
  distance_km REAL,
  intensity_zones_json TEXT,  -- JSON
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

**Indexes:**
- `idx_workouts_user_date` on `user_id, date`

#### user_baselines
30-day rolling averages.

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

### Interventions

#### interventions
Intervention library (150+ fields).

```sql
CREATE TABLE interventions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT,
  category TEXT,
  evidence_score INTEGER,
  recommended_duration_weeks INTEGER,
  min_duration INTEGER,
  max_duration INTEGER,
  recommended_frequency TEXT,
  available_frequencies_json TEXT,  -- JSON
  duration_impact_json TEXT,  -- JSON
  safety_rating INTEGER,
  contraindications_json TEXT,  -- JSON
  interactions_json TEXT,  -- JSON
  primary_benefit TEXT,
  instructions_text TEXT,
  created_by_coach_id INTEGER,
  status TEXT DEFAULT 'active',
  version INTEGER DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by_coach_id) REFERENCES coaches(id) ON DELETE SET NULL
);
```

#### user_interventions
Assigned interventions.

```sql
CREATE TABLE user_interventions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  intervention_id INTEGER NOT NULL,
  assigned_by_coach_id INTEGER,
  start_date DATE NOT NULL,
  end_date DATE,
  frequency TEXT,
  schedule_json TEXT,  -- JSON
  dosage TEXT,
  timing TEXT,
  form TEXT,
  custom_instructions TEXT,
  status TEXT DEFAULT 'active',
  assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (intervention_id) REFERENCES interventions(id) ON DELETE CASCADE,
  FOREIGN KEY (assigned_by_coach_id) REFERENCES coaches(id) ON DELETE SET NULL
);
```

**Indexes:**
- `idx_user_interventions_user_status` on `user_id, status`

#### intervention_compliance
Daily compliance tracking.

```sql
CREATE TABLE intervention_compliance (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_intervention_id INTEGER NOT NULL,
  scheduled_date DATE NOT NULL,
  completed BOOLEAN DEFAULT 0,
  completed_at DATETIME,
  note_text TEXT,
  FOREIGN KEY (user_intervention_id) REFERENCES user_interventions(id) ON DELETE CASCADE,
  UNIQUE(user_intervention_id, scheduled_date)
);
```

**Indexes:**
- `idx_compliance_intervention_date` on `user_intervention_id, scheduled_date`

#### intervention_user_notes
User notes on interventions.

```sql
CREATE TABLE intervention_user_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_intervention_id INTEGER NOT NULL,
  note_text TEXT NOT NULL,
  mood_rating INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_intervention_id) REFERENCES user_interventions(id) ON DELETE CASCADE
);
```

#### intervention_coach_notes
Coach internal notes.

```sql
CREATE TABLE intervention_coach_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_intervention_id INTEGER NOT NULL,
  coach_id INTEGER NOT NULL,
  note_text TEXT NOT NULL,
  tags_json TEXT,  -- JSON
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_intervention_id) REFERENCES user_interventions(id) ON DELETE CASCADE,
  FOREIGN KEY (coach_id) REFERENCES coaches(id) ON DELETE CASCADE
);
```

#### intervention_schedule
Intervention scheduling details.

```sql
CREATE TABLE intervention_schedule (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_intervention_id INTEGER NOT NULL,
  scheduled_time TIME NOT NULL,
  scheduled_days TEXT NOT NULL,  -- JSON array of days
  timezone TEXT DEFAULT 'UTC',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_intervention_id) REFERENCES user_interventions(id) ON DELETE CASCADE
);
```

### Metrics & Analytics

#### user_metrics_summary
Aggregated metrics for quick access.

```sql
CREATE TABLE user_metrics_summary (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  metric_date DATE NOT NULL,
  sleep_score REAL,
  activity_score REAL,
  compliance_score REAL,
  overall_score REAL,
  calculated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, metric_date)
);
```

**Indexes:**
- `idx_metrics_summary_user_date` on `user_id, metric_date`

---

## Relationships Diagram

```
users
├── days (1:N via user_progress)
│   ├── questions (1:N)
│   │   └── responses (1:N)
│   └── onboarding_insights (1:N)
├── daily_checkins (1:N)
│   └── checkin_responses (1:N)
├── user_preferences (1:1)
├── user_sleep_data (1:N)
├── user_sleep_stages (1:N)
├── user_heart_rate (1:N)
├── user_activity (1:N)
├── user_workouts (1:N)
├── user_baselines (1:N)
├── user_metrics_summary (1:N)
├── user_interventions (1:N)
│   ├── intervention_compliance (1:N)
│   ├── intervention_user_notes (1:N)
│   ├── intervention_coach_notes (1:N)
│   └── intervention_schedule (1:1)
├── sleep_reports (1:N)
│   ├── report_sections (1:N)
│   └── report_roadmap (1:1)
├── customer_coach_assignments (N:M with coaches)
├── alerts (1:N)
└── messages (1:N)

coaches
├── interventions (1:N)
├── customer_coach_assignments (N:M with users)
├── alerts (1:N)
└── intervention_coach_notes (1:N)
```

---

## Setup Instructions

### Initial Setup

```bash
cd server
npm run setup-db
```

### Verify Database

```bash
npm run verify-db
```

### Manual Setup

The database is automatically initialized when the server starts. To manually trigger setup:

```javascript
const { initDatabase } = require('./database/init');
initDatabase().then(() => {
  console.log('Database setup complete');
});
```

---

## Data Flow

1. **User Registration/Login** → `users` table
2. **Onboarding Journey** → `days` → `questions` → `responses` → `onboarding_insights`
3. **Daily Check-ins** → `daily_checkins` → `checkin_responses`
4. **Health Data Sync** → `user_sleep_data`, `user_heart_rate`, `user_activity`
5. **Interventions** → `interventions` → `user_interventions` → `intervention_compliance`
6. **Sleep Reports** → `sleep_reports` → `report_sections` → `report_roadmap`
7. **Coach Dashboard** → `coaches` → `customer_coach_assignments` → `alerts`

---

## Performance Considerations

- All foreign keys have indexes
- Date-based queries are indexed
- User-based queries are indexed
- JSON fields are used for flexible data storage
- Unique constraints prevent duplicate data

---

## Migration Notes

The schema supports automatic migration:
- New columns are added with `ALTER TABLE` (errors ignored if column exists)
- New tables are created with `CREATE TABLE IF NOT EXISTS`
- Indexes are created with `CREATE INDEX IF NOT EXISTS`

No manual migration scripts needed - the database will automatically upgrade on server start.




