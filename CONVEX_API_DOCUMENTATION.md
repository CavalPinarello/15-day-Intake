# Convex Database & API Documentation

## Overview

This document provides comprehensive documentation for the ZOE Sleep Platform's Convex database and API. The system is built on Convex, a real-time backend platform that provides automatic API generation from your database schema and functions.

**Base URL**: Your Convex deployment URL (e.g., `https://your-project.convex.cloud`)

**Authentication**: The system uses JWT tokens with refresh tokens stored in the database. Authentication is handled through the `auth` module.

---

## Table of Contents

1. [Database Schema](#database-schema)
2. [API Modules](#api-modules)
3. [Function Reference](#function-reference)
4. [Data Types & Conventions](#data-types--conventions)
5. [Usage Examples](#usage-examples)
6. [Integration Guide](#integration-guide)

---

## Database Schema

The database consists of 30+ tables organized into 5 main components:

### Core Tables

#### `users`
User accounts and authentication data.

**Fields:**
- `username` (string) - Unique username
- `password_hash` (string) - Hashed password
- `email` (optional string) - User email
- `current_day` (number) - Current day in onboarding (1-15)
- `started_at` (number) - Unix timestamp when user started
- `last_accessed` (number) - Unix timestamp of last access
- `created_at` (number) - Unix timestamp of account creation
- `apple_health_connected` (optional boolean) - HealthKit connection status
- `onboarding_completed` (optional boolean) - Onboarding completion flag
- `onboarding_completed_at` (optional number) - Completion timestamp
- `email_verified` (optional boolean) - Email verification status
- `email_verification_token` (optional string) - Verification token
- `email_verification_expires` (optional number) - Token expiration
- `password_reset_token` (optional string) - Password reset token
- `password_reset_expires` (optional number) - Reset token expiration
- `oauth_provider` (optional union) - OAuth provider ("google" | "apple")
- `oauth_id` (optional string) - External OAuth user ID
- `profile_picture` (optional string) - Profile picture URL

**Indexes:**
- `by_username` - Lookup by username
- `by_email` - Lookup by email
- `by_onboarding` - Filter by onboarding status
- `by_oauth` - OAuth provider lookup
- `by_verification_token` - Email verification lookup
- `by_reset_token` - Password reset lookup

---

### Component 1: 14-Day Onboarding Journey

#### `days`
Day definitions for the onboarding journey.

**Fields:**
- `day_number` (number) - Day number (1-15)
- `title` (string) - Day title
- `description` (optional string) - Day description
- `theme_color` (optional string) - Theme color hex code
- `background_image` (optional string) - Background image URL
- `created_at` (number) - Creation timestamp

**Indexes:**
- `by_day_number` - Lookup by day number

#### `questions`
Questions associated with days.

**Fields:**
- `day_id` (Id<"days">) - Reference to day
- `question_text` (string) - Question text
- `question_type` (string) - Question type (e.g., "text", "number", "select")
- `options` (optional string) - JSON string of options
- `order_index` (number) - Display order
- `required` (boolean) - Whether question is required
- `conditional_logic` (optional string) - JSON string of conditional logic
- `created_at` (number) - Creation timestamp

**Indexes:**
- `by_day` - Questions for a day
- `by_day_order` - Questions ordered by day and order_index

#### `responses`
User responses to questions.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `question_id` (Id<"questions">) - Reference to question
- `day_id` (Id<"days">) - Reference to day
- `response_value` (optional string) - Response value
- `response_data` (optional string) - JSON string of additional data
- `created_at` (number) - Creation timestamp
- `updated_at` (number) - Last update timestamp

**Indexes:**
- `by_user` - All responses for a user
- `by_user_day` - Responses for user and day
- `by_question` - All responses for a question
- `by_user_question` - Specific user response to question

#### `user_progress`
User progress tracking for days.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `day_id` (Id<"days">) - Reference to day
- `completed` (boolean) - Completion status
- `completed_at` (optional number) - Completion timestamp
- `created_at` (number) - Creation timestamp

**Indexes:**
- `by_user` - Progress for a user
- `by_user_day` - Progress for user and day
- `by_day` - All users' progress for a day

#### `onboarding_insights`
AI-generated insights for users.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `day_id` (Id<"days">) - Reference to day
- `insight_type` (string) - Type: "personalized", "fact", "action"
- `insight_text` (string) - Insight text
- `generated_at` (number) - Generation timestamp

**Indexes:**
- `by_user` - Insights for a user
- `by_user_day` - Insights for user and day
- `by_user_day_type` - Filtered by type

---

### Component 2: Daily App Use

#### `daily_checkins`
Daily morning/evening check-ins.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `checkin_date` (string) - ISO date string (YYYY-MM-DD)
- `checkin_type` (union) - "morning" | "evening"
- `completed` (boolean) - Completion status
- `completed_at` (optional number) - Completion timestamp
- `data_json` (optional string) - JSON string of check-in data
- `created_at` (number) - Creation timestamp

**Indexes:**
- `by_user` - Check-ins for a user
- `by_user_date` - Check-ins for user and date
- `by_user_type` - Check-ins by type
- `by_user_date_type` - Combined filter

#### `checkin_responses`
Individual responses within check-ins.

**Fields:**
- `checkin_id` (Id<"daily_checkins">) - Reference to check-in
- `question_key` (string) - Question identifier
- `response_value` (optional string) - Response value
- `response_data` (optional string) - JSON string of additional data
- `created_at` (number) - Creation timestamp

**Indexes:**
- `by_checkin` - Responses for a check-in
- `by_checkin_key` - Specific response by key

#### `user_preferences`
User preferences and settings.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `notification_enabled` (boolean) - Notification preference
- `notification_time` (string) - Notification time (HH:MM)
- `quiet_hours_start` (string) - Quiet hours start (HH:MM)
- `quiet_hours_end` (string) - Quiet hours end (HH:MM)
- `timezone` (string) - User timezone
- `apple_health_sync_enabled` (boolean) - HealthKit sync preference
- `daily_reminder_enabled` (boolean) - Daily reminder preference
- `updated_at` (number) - Last update timestamp

**Indexes:**
- `by_user` - Preferences for a user

---

### Component 3: Full Sleep Report

#### `sleep_reports`
Generated sleep reports.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `generated_at` (number) - Generation timestamp
- `overall_score` (optional number) - Overall sleep score
- `archetype` (optional string) - Sleep archetype
- `report_data_json` (optional string) - JSON string of report data
- `pdf_url` (optional string) - PDF report URL

**Indexes:**
- `by_user` - Reports for a user
- `by_user_generated` - Reports ordered by generation time

#### `report_sections`
Sections within sleep reports.

**Fields:**
- `report_id` (Id<"sleep_reports">) - Reference to report
- `section_num` (number) - Section number
- `name` (string) - Section name
- `score` (optional number) - Section score
- `strengths_json` (optional string) - JSON string of strengths
- `issues_json` (optional string) - JSON string of issues
- `findings_json` (optional string) - JSON string of findings

**Indexes:**
- `by_report` - Sections for a report
- `by_report_section` - Specific section

#### `report_roadmap`
Roadmaps associated with reports.

**Fields:**
- `report_id` (Id<"sleep_reports">) - Reference to report
- `quarterly_milestones_json` (optional string) - JSON string of milestones
- `monthly_tasks_json` (optional string) - JSON string of tasks

**Indexes:**
- `by_report` - Roadmap for a report

---

### Component 4: Coach Dashboard

#### `coaches`
Coach/physician accounts.

**Fields:**
- `email` (string) - Coach email
- `name` (string) - Coach name
- `role` (optional string) - Coach role
- `permissions_json` (optional string) - JSON string of permissions
- `created_at` (number) - Creation timestamp

**Indexes:**
- `by_email` - Lookup by email

#### `customer_coach_assignments`
Assignments of users to coaches.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `coach_id` (Id<"coaches">) - Reference to coach
- `assigned_at` (number) - Assignment timestamp
- `status` (string) - Status: "active", "inactive", etc.

**Indexes:**
- `by_user` - Assignments for a user
- `by_coach` - Assignments for a coach
- `by_coach_status` - Filtered by status
- `by_user_coach` - Specific assignment

#### `alerts`
Alerts for coaches about users.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `coach_id` (optional Id<"coaches">) - Reference to coach
- `alert_type` (string) - Alert type
- `severity` (string) - Severity: "low", "medium", "high", "critical"
- `message` (string) - Alert message
- `data_json` (optional string) - JSON string of alert data
- `resolved` (boolean) - Resolution status
- `created_at` (number) - Creation timestamp
- `resolved_at` (optional number) - Resolution timestamp

**Indexes:**
- `by_user` - Alerts for a user
- `by_coach` - Alerts for a coach
- `by_user_coach_resolved` - Filtered alerts
- `by_resolved` - Filter by resolution status

#### `messages`
Messages between users and coaches.

**Fields:**
- `from_user_id` (optional Id<"users">) - Sender (null for coach messages)
- `to_user_id` (Id<"users">) - Recipient
- `message_text` (string) - Message content
- `read_at` (optional number) - Read timestamp
- `created_at` (number) - Creation timestamp

**Indexes:**
- `by_from_user` - Messages from a user
- `by_to_user` - Messages to a user
- `by_users` - Conversation between users
- `by_created` - Messages ordered by creation time

---

### Component 5: Supporting Systems

#### `refresh_tokens`
JWT refresh tokens.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `token` (string) - Token string
- `expires_at` (number) - Expiration timestamp
- `created_at` (number) - Creation timestamp
- `revoked` (boolean) - Revocation status

**Indexes:**
- `by_user` - Tokens for a user
- `by_token` - Lookup by token
- `by_user_revoked` - Filter by revocation status

#### Health Data Tables

##### `user_sleep_data`
Daily sleep metrics.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `date` (string) - ISO date string (YYYY-MM-DD)
- `in_bed_time` (optional number) - Unix timestamp
- `asleep_time` (optional number) - Unix timestamp
- `wake_time` (optional number) - Unix timestamp
- `total_sleep_mins` (optional number) - Total sleep minutes
- `sleep_efficiency` (optional number) - Sleep efficiency percentage
- `deep_sleep_mins` (optional number) - Deep sleep minutes
- `light_sleep_mins` (optional number) - Light sleep minutes
- `rem_sleep_mins` (optional number) - REM sleep minutes
- `awake_mins` (optional number) - Awake minutes
- `interruptions_count` (optional number) - Number of interruptions
- `sleep_latency_mins` (optional number) - Sleep latency minutes
- `synced_at` (number) - Sync timestamp

**Indexes:**
- `by_user` - Sleep data for a user
- `by_user_date` - Sleep data for user and date
- `by_date` - Sleep data for a date

##### `user_sleep_stages`
Detailed sleep stage data.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `date` (string) - ISO date string
- `start_time` (number) - Stage start timestamp
- `end_time` (number) - Stage end timestamp
- `stage` (string) - Stage: "deep", "light", "rem", "awake"
- `duration_mins` (optional number) - Duration in minutes

**Indexes:**
- `by_user` - Stages for a user
- `by_user_date` - Stages for user and date
- `by_date` - Stages for a date

##### `user_heart_rate`
Heart rate data.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `date` (string) - ISO date string
- `resting_hr` (optional number) - Resting heart rate
- `avg_hr` (optional number) - Average heart rate
- `hrv_morning` (optional number) - Morning HRV
- `hrv_avg` (optional number) - Average HRV
- `synced_at` (number) - Sync timestamp

**Indexes:**
- `by_user` - Heart rate data for a user
- `by_user_date` - Heart rate for user and date

##### `user_activity`
Activity data.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `date` (string) - ISO date string
- `steps` (optional number) - Step count
- `active_mins` (optional number) - Active minutes
- `exercise_mins` (optional number) - Exercise minutes
- `calories_burned` (optional number) - Calories burned
- `synced_at` (number) - Sync timestamp

**Indexes:**
- `by_user` - Activity for a user
- `by_user_date` - Activity for user and date

##### `user_workouts`
Workout data.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `date` (string) - ISO date string
- `workout_type` (optional string) - Type of workout
- `start_time` (optional number) - Start timestamp
- `duration_mins` (optional number) - Duration in minutes
- `avg_hr` (optional number) - Average heart rate
- `max_hr` (optional number) - Maximum heart rate
- `calories` (optional number) - Calories burned
- `distance_km` (optional number) - Distance in kilometers
- `intensity_zones_json` (optional string) - JSON string of intensity zones

**Indexes:**
- `by_user` - Workouts for a user
- `by_user_date` - Workouts for user and date
- `by_date` - Workouts for a date

##### `user_baselines`
Calculated baseline metrics.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `metric_name` (string) - Metric name
- `baseline_value` (number) - Baseline value
- `calculated_at` (number) - Calculation timestamp
- `period_days` (number) - Period used for calculation

**Indexes:**
- `by_user` - Baselines for a user
- `by_user_metric` - Specific baseline

#### Intervention Tables

##### `interventions`
Intervention library.

**Fields:**
- `name` (string) - Intervention name
- `type` (optional string) - Intervention type
- `category` (optional string) - Category
- `evidence_score` (optional number) - Evidence score
- `recommended_duration_weeks` (optional number) - Recommended duration
- `min_duration` (optional number) - Minimum duration
- `max_duration` (optional number) - Maximum duration
- `recommended_frequency` (optional string) - Recommended frequency
- `available_frequencies_json` (optional string) - JSON string of frequencies
- `duration_impact_json` (optional string) - JSON string of duration impact
- `safety_rating` (optional number) - Safety rating
- `contraindications_json` (optional string) - JSON string of contraindications
- `interactions_json` (optional string) - JSON string of interactions
- `primary_benefit` (optional string) - Primary benefit description
- `instructions_text` (string) - Instructions text
- `created_by_coach_id` (optional Id<"coaches">) - Creator coach
- `status` (string) - Status: "active", "archived", "draft"
- `version` (number) - Version number
- `created_at` (number) - Creation timestamp
- `updated_at` (number) - Update timestamp

**Indexes:**
- `by_status` - Filter by status
- `by_category` - Filter by category
- `by_coach` - Filter by creator

##### `user_interventions`
User-specific intervention assignments.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `intervention_id` (Id<"interventions">) - Reference to intervention
- `assigned_by_coach_id` (optional Id<"coaches">) - Assigning coach
- `start_date` (string) - Start date (ISO format)
- `end_date` (optional string) - End date (ISO format)
- `frequency` (optional string) - Frequency
- `schedule_json` (optional string) - JSON string of schedule
- `dosage` (optional string) - Dosage information
- `timing` (optional string) - Timing information
- `form` (optional string) - Form (e.g., "pill", "liquid")
- `custom_instructions` (optional string) - Custom instructions
- `status` (string) - Status: "active", "completed", "cancelled"
- `assigned_at` (number) - Assignment timestamp

**Indexes:**
- `by_user` - Interventions for a user
- `by_user_status` - Filtered by status
- `by_intervention` - All users for an intervention
- `by_coach` - Interventions assigned by coach

##### `intervention_compliance`
Compliance tracking for interventions.

**Fields:**
- `user_intervention_id` (Id<"user_interventions">) - Reference to assignment
- `scheduled_date` (string) - Scheduled date (ISO format)
- `completed` (boolean) - Completion status
- `completed_at` (optional number) - Completion timestamp
- `note_text` (optional string) - Compliance note

**Indexes:**
- `by_intervention` - Compliance for an intervention
- `by_intervention_date` - Specific date compliance
- `by_date` - Compliance for a date

##### `intervention_user_notes`
User notes about interventions.

**Fields:**
- `user_intervention_id` (Id<"user_interventions">) - Reference to assignment
- `note_text` (string) - Note text
- `mood_rating` (optional number) - Mood rating
- `created_at` (number) - Creation timestamp

**Indexes:**
- `by_intervention` - Notes for an intervention
- `by_created` - Notes ordered by creation time

##### `intervention_coach_notes`
Coach notes about interventions.

**Fields:**
- `user_intervention_id` (Id<"user_interventions">) - Reference to assignment
- `coach_id` (Id<"coaches">) - Reference to coach
- `note_text` (string) - Note text
- `tags_json` (optional string) - JSON string of tags
- `created_at` (number) - Creation timestamp

**Indexes:**
- `by_intervention` - Notes for an intervention
- `by_coach` - Notes by coach

##### `intervention_schedule`
Scheduling information for interventions.

**Fields:**
- `user_intervention_id` (Id<"user_interventions">) - Reference to assignment
- `scheduled_time` (string) - Scheduled time (HH:MM)
- `scheduled_days` (string) - JSON array string of days
- `timezone` (string) - Timezone
- `created_at` (number) - Creation timestamp

**Indexes:**
- `by_intervention` - Schedule for an intervention

#### Metrics & Analytics

##### `user_metrics_summary`
Daily metrics summary.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `metric_date` (string) - Date (ISO format)
- `sleep_score` (optional number) - Sleep score
- `activity_score` (optional number) - Activity score
- `compliance_score` (optional number) - Compliance score
- `overall_score` (optional number) - Overall score
- `calculated_at` (number) - Calculation timestamp

**Indexes:**
- `by_user` - Metrics for a user
- `by_user_date` - Metrics for user and date
- `by_date` - Metrics for a date

---

### Assessment System Tables

#### `assessment_questions`
Master question library.

**Fields:**
- `question_id` (string) - Text ID (e.g., "D1", "D2", "ISI1")
- `question_text` (string) - Question text
- `pillar` (string) - Pillar category
- `tier` (string) - Tier level
- `question_type` (string) - Question type
- `options_json` (optional string) - JSON string of options
- `estimated_time` (optional number) - Estimated time in seconds
- `trigger` (optional string) - Trigger condition
- `notes` (optional string) - JSON string of notes

**Indexes:**
- `by_question_id` - Lookup by question ID
- `by_pillar_tier` - Filter by pillar and tier

#### `assessment_modules`
Assessment modules.

**Fields:**
- `module_id` (string) - Text ID
- `name` (string) - Module name
- `description` (optional string) - Module description
- `pillar` (string) - Pillar category
- `tier` (string) - Tier level
- `module_type` (string) - Type: "CORE", "GATEWAY", "EXPANSION"
- `estimated_minutes` (optional number) - Estimated minutes
- `default_day_number` (optional number) - Default day assignment
- `repeat_interval` (optional number) - Repeat interval

**Indexes:**
- `by_module_id` - Lookup by module ID
- `by_pillar_tier` - Filter by pillar and tier
- `by_type` - Filter by module type

#### `module_questions`
Questions within modules.

**Fields:**
- `module_id` (string) - Reference to module
- `question_id` (string) - Reference to question
- `order_index` (number) - Display order

**Indexes:**
- `by_module` - Questions for a module
- `by_module_order` - Questions ordered
- `by_question` - Modules containing a question

#### `day_modules`
Module assignments to days.

**Fields:**
- `day_number` (number) - Day number (1-15)
- `module_id` (string) - Reference to module
- `order_index` (number) - Display order

**Indexes:**
- `by_day` - Modules for a day
- `by_day_order` - Modules ordered
- `by_module` - Days containing a module

#### `module_gateways`
Gateway conditions for modules.

**Fields:**
- `gateway_id` (string) - Text ID
- `name` (string) - Gateway name
- `description` (optional string) - Gateway description
- `condition_json` (string) - JSON string of condition
- `target_modules_json` (string) - JSON array string of target modules
- `trigger_question_ids_json` (string) - JSON array string of trigger questions
- `created_at` (number) - Creation timestamp

**Indexes:**
- `by_gateway_id` - Lookup by gateway ID

#### `user_gateway_states`
User gateway trigger states.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `gateway_id` (string) - Reference to gateway
- `triggered` (boolean) - Trigger status
- `triggered_at` (optional number) - Trigger timestamp
- `last_evaluated_at` (number) - Last evaluation timestamp
- `evaluation_data_json` (optional string) - JSON string of evaluation data

**Indexes:**
- `by_user` - States for a user
- `by_user_gateway` - Specific gateway state
- `by_gateway` - All users for a gateway

#### `user_assessment_responses`
User responses to assessment questions.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `question_id` (string) - Reference to question
- `response_value` (optional string) - Response value
- `day_number` (optional number) - Day when answered
- `created_at` (number) - Creation timestamp
- `updated_at` (number) - Update timestamp

**Indexes:**
- `by_user` - Responses for a user
- `by_user_question` - Specific response
- `by_user_day` - Responses for user and day
- `by_question` - All responses for a question

#### `sleep_diary_questions`
Sleep diary question definitions.

**Fields:**
- `id` (string) - Text ID (primary key)
- `question_text` (string) - Question text
- `question_type` (string) - Question type
- `options_json` (optional string) - JSON string of options
- `group_key` (optional string) - Group identifier
- `help_text` (optional string) - Help text
- `condition_json` (optional string) - JSON string of condition
- `estimated_time` (optional number) - Estimated time in seconds

**Indexes:**
- `by_question_id` - Lookup by question ID
- `by_group` - Filter by group

---

### Physician Dashboard Tables

#### `physician_notes`
Notes added by physicians.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `day_number` (optional number) - Associated day
- `note_text` (string) - Note content
- `created_at` (number) - Creation timestamp
- `updated_at` (number) - Update timestamp
- `physician_id` (optional string) - Physician identifier

**Indexes:**
- `by_user` - Notes for a user
- `by_user_day` - Notes for user and day

#### `patient_review_status`
Patient review workflow status.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `status` (string) - Status: "intake_in_progress", "pending_review", "under_review", "interventions_prepared", "interventions_active"
- `reviewed_by_physician_id` (optional string) - Reviewing physician
- `review_started_at` (optional number) - Review start timestamp
- `review_completed_at` (optional number) - Review completion timestamp
- `updated_at` (number) - Last update timestamp

**Indexes:**
- `by_user` - Status for a user
- `by_status` - Filter by status

#### `questionnaire_scores`
Calculated questionnaire scores.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `questionnaire_name` (string) - Questionnaire name (e.g., "ISI", "PSQI", "ESS")
- `score` (number) - Calculated score
- `max_score` (optional number) - Maximum possible score
- `category` (optional string) - Score category
- `interpretation` (optional string) - Score interpretation
- `calculated_at` (number) - Calculation timestamp
- `calculation_metadata_json` (optional string) - JSON string of metadata

**Indexes:**
- `by_user` - Scores for a user
- `by_user_questionnaire` - Specific questionnaire score

#### `patient_visible_fields`
Field visibility configuration for patients.

**Fields:**
- `user_id` (Id<"users">) - Reference to user
- `field_config_json` (string) - JSON string of field visibility settings
- `updated_at` (number) - Last update timestamp
- `updated_by_physician_id` (optional string) - Updating physician

**Indexes:**
- `by_user` - Configuration for a user

---

## API Modules

The API is organized into 7 modules:

1. **`users`** - User management
2. **`auth`** - Authentication and authorization
3. **`days`** - Day management
4. **`questions`** - Question management
5. **`responses`** - Response handling
6. **`assessment`** - Assessment system
7. **`physician`** - Physician dashboard
8. **`llm`** - LLM-powered analysis (actions only)

---

## Function Reference

### Module: `users`

#### Queries

##### `getUserByUsername`
Get user by username.

**Arguments:**
```typescript
{
  username: string
}
```

**Returns:** User document or null

##### `getUserById`
Get user by ID.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** User document or null

##### `getUserByEmail`
Get user by email.

**Arguments:**
```typescript
{
  email: string
}
```

**Returns:** User document or null

##### `getAllUsers`
Get all users (admin only).

**Arguments:** None

**Returns:** Array of user documents

#### Mutations

##### `createUser`
Create a new user.

**Arguments:**
```typescript
{
  username: string
  password_hash: string
  email?: string
  current_day?: number
}
```

**Returns:** `Id<"users">`

##### `updateUser`
Update user fields.

**Arguments:**
```typescript
{
  userId: Id<"users">
  updates: {
    current_day?: number
    last_accessed?: number
    email?: string
    onboarding_completed?: boolean
    onboarding_completed_at?: number
  }
}
```

**Returns:** void

##### `deleteAllUsers`
Delete all users (testing/admin only).

**Arguments:** None

**Returns:** `{ deleted: number, message: string }`

---

### Module: `auth`

#### Queries

##### `getUserForLogin`
Get user for login (includes password hash).

**Arguments:**
```typescript
{
  username: string
}
```

**Returns:** User document or null

##### `getUserByUsernameOrEmail`
Get user by username or email.

**Arguments:**
```typescript
{
  identifier: string
}
```

**Returns:** User document or null

##### `getRefreshToken`
Get refresh token data.

**Arguments:**
```typescript
{
  token: string
}
```

**Returns:** Token document with user data or null

##### `getUserByVerificationToken`
Get user by email verification token.

**Arguments:**
```typescript
{
  token: string
}
```

**Returns:** User document or null

##### `getUserByEmail`
Get user by email.

**Arguments:**
```typescript
{
  email: string
}
```

**Returns:** User document or null

##### `getUserByPasswordResetToken`
Get user by password reset token.

**Arguments:**
```typescript
{
  token: string
}
```

**Returns:** User document or null

#### Mutations

##### `registerUser`
Register a new user.

**Arguments:**
```typescript
{
  username: string
  password_hash: string
  email: string
  email_verification_token?: string
  email_verification_expires?: number
}
```

**Returns:** `Id<"users">`

**Throws:** Error if username or email already exists

##### `updateUserLastAccessed`
Update user's last accessed timestamp.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** void

##### `storeRefreshToken`
Store a refresh token.

**Arguments:**
```typescript
{
  user_id: Id<"users">
  token: string
  expires_at: number
}
```

**Returns:** `Id<"refresh_tokens">`

##### `revokeRefreshToken`
Revoke a refresh token.

**Arguments:**
```typescript
{
  token: string
  userId: Id<"users">
}
```

**Returns:** void

##### `verifyUserEmail`
Verify user email.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** void

##### `setPasswordResetToken`
Set password reset token.

**Arguments:**
```typescript
{
  userId: Id<"users">
  resetToken: string
  resetExpires: number
}
```

**Returns:** void

##### `updateUserPassword`
Update user password.

**Arguments:**
```typescript
{
  userId: Id<"users">
  password_hash: string
}
```

**Returns:** void

##### `clearPasswordResetToken`
Clear password reset token.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** void

---

### Module: `days`

#### Queries

##### `getAllDays`
Get all days ordered by day number.

**Arguments:** None

**Returns:** Array of day documents

##### `getDayByNumber`
Get day by day number.

**Arguments:**
```typescript
{
  dayNumber: number
}
```

**Returns:** Day document or null

##### `getDayById`
Get day by ID.

**Arguments:**
```typescript
{
  dayId: Id<"days">
}
```

**Returns:** Day document or null

#### Mutations

##### `createDay`
Create a new day.

**Arguments:**
```typescript
{
  day_number: number
  title: string
  description?: string
  theme_color?: string
  background_image?: string
}
```

**Returns:** `Id<"days">`

##### `updateDay`
Update day fields.

**Arguments:**
```typescript
{
  dayId: Id<"days">
  updates: {
    title?: string
    description?: string
    theme_color?: string
    background_image?: string
  }
}
```

**Returns:** void

---

### Module: `questions`

#### Queries

##### `getQuestionsByDay`
Get questions for a day, ordered by order_index.

**Arguments:**
```typescript
{
  dayId: Id<"days">
}
```

**Returns:** Array of question documents

##### `getQuestionById`
Get question by ID.

**Arguments:**
```typescript
{
  questionId: Id<"questions">
}
```

**Returns:** Question document or null

#### Mutations

##### `createQuestion`
Create a new question.

**Arguments:**
```typescript
{
  day_id: Id<"days">
  question_text: string
  question_type: string
  options?: string  // JSON string
  order_index: number
  required?: boolean
  conditional_logic?: string  // JSON string
}
```

**Returns:** `Id<"questions">`

##### `updateQuestion`
Update question fields.

**Arguments:**
```typescript
{
  questionId: Id<"questions">
  updates: {
    question_text?: string
    question_type?: string
    options?: string
    order_index?: number
    required?: boolean
    conditional_logic?: string
  }
}
```

**Returns:** void

##### `deleteQuestion`
Delete a question.

**Arguments:**
```typescript
{
  questionId: Id<"questions">
}
```

**Returns:** void

##### `reorderQuestions`
Reorder questions for a day.

**Arguments:**
```typescript
{
  dayId: Id<"days">
  questionIds: Id<"questions">[]
}
```

**Returns:** void

---

### Module: `responses`

#### Queries

##### `getUserDayResponses`
Get user responses for a day with question details.

**Arguments:**
```typescript
{
  userId: Id<"users">
  dayId: Id<"days">
}
```

**Returns:** Array of response documents with question details

#### Mutations

##### `saveResponse`
Save or update a user response.

**Arguments:**
```typescript
{
  user_id: Id<"users">
  question_id: Id<"questions">
  day_id: Id<"days">
  response_value?: string
  response_data?: string  // JSON string
}
```

**Returns:** `Id<"responses">`

##### `markDayCompleted`
Mark a day as completed for a user.

**Arguments:**
```typescript
{
  userId: Id<"users">
  dayId: Id<"days">
}
```

**Returns:** void

---

### Module: `assessment`

#### Queries

##### Assessment Questions

##### `getMasterQuestions`
Get all master assessment questions.

**Arguments:** None

**Returns:** Array of assessment question documents

##### `getAssessmentQuestionById`
Get assessment question by ID.

**Arguments:**
```typescript
{
  questionId: string  // e.g., "D1", "ISI1"
}
```

**Returns:** Assessment question document or null

##### Assessment Modules

##### `getModules`
Get all assessment modules.

**Arguments:** None

**Returns:** Array of module documents

##### `getModuleById`
Get module by ID.

**Arguments:**
```typescript
{
  moduleId: string
}
```

**Returns:** Module document or null

##### `getModuleWithQuestions`
Get module with all its questions.

**Arguments:**
```typescript
{
  moduleId: string
}
```

**Returns:** Module document with questions array or null

##### Module Questions

##### `getModuleQuestions`
Get questions for a module, ordered.

**Arguments:**
```typescript
{
  moduleId: string
}
```

**Returns:** Array of module question documents

##### Day Modules

##### `getDayAssignments`
Get all day-to-module assignments.

**Arguments:** None

**Returns:** Object mapping day numbers to module arrays

##### User Assessment Responses

##### `getUserResponses`
Get all user responses as a map.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** `Record<string, string>` - Map of question_id to response_value

##### `getUserName`
Get user's name from D1 response.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** string or null

##### `getAllUserNames`
Get all user names (for admin).

**Arguments:** None

**Returns:** `Record<number, string | null>` - Map of user IDs to names

##### Gateway States

##### `getUserGatewayStates`
Get user gateway states.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** `Record<string, object>` - Map of gateway_id to state object

##### Sleep Diary Questions

##### `getSleepDiaryQuestions`
Get all sleep diary questions.

**Arguments:** None

**Returns:** Array of sleep diary question documents

#### Mutations

##### Assessment Questions

##### `updateAssessmentQuestion`
Update an assessment question.

**Arguments:**
```typescript
{
  questionId: string
  updates: {
    question_text?: string
    question_type?: string
    options_json?: string
    estimated_time?: number
    trigger?: string
  }
}
```

**Returns:** void

##### Module Questions

##### `reorderModuleQuestions`
Reorder questions within a module.

**Arguments:**
```typescript
{
  moduleId: string
  questionIds: string[]
}
```

**Returns:** void

##### Day Modules

##### `assignModuleToDay`
Assign a module to a day.

**Arguments:**
```typescript
{
  dayNumber: number
  moduleId: string
  orderIndex?: number
}
```

**Returns:** void

**Throws:** Error if module already assigned

##### `removeModuleFromDay`
Remove a module from a day.

**Arguments:**
```typescript
{
  dayNumber: number
  moduleId: string
}
```

**Returns:** void

##### `reorderDayModules`
Reorder modules for a day.

**Arguments:**
```typescript
{
  dayNumber: number
  moduleIds: string[]
}
```

**Returns:** void

##### User Assessment Responses

##### `saveAssessmentResponse`
Save or update an assessment response.

**Arguments:**
```typescript
{
  userId: Id<"users">
  questionId: string
  responseValue?: string
  dayNumber?: number
}
```

**Returns:** `Id<"user_assessment_responses">`

##### Gateway States

##### `saveGatewayState`
Save or update a gateway state.

**Arguments:**
```typescript
{
  userId: Id<"users">
  gatewayId: string
  triggered: boolean
  triggeredAt?: number
  evaluationDataJson?: string
}
```

**Returns:** void

---

### Module: `physician`

#### Queries

##### `getAllPatientsWithProgress`
Get all patients with progress and review status.

**Arguments:**
```typescript
{
  statusFilter?: string  // Filter by review status
  searchTerm?: string    // Search by name or username
}
```

**Returns:** Array of patient objects with progress data

##### `getPatientDetails`
Get comprehensive patient details.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** Patient details object with demographics, review status, etc.

##### `getPatientDayData`
Get all responses and notes for a specific day.

**Arguments:**
```typescript
{
  userId: Id<"users">
  dayNumber: number
}
```

**Returns:** Object with responses and notes arrays

##### `getPhysicianNotes`
Get all physician notes for a patient.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** Array of physician note documents

##### `getQuestionnaireScores`
Get all calculated questionnaire scores for a patient.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** Array of questionnaire score documents

##### `getPatientVisibleFields`
Get patient visible field configuration.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** Field configuration object or null

##### `getPatientResponsesByDay`
Get all responses grouped by day.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** Object with days array

##### `getPatientInterventions`
Get active interventions for a patient.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** Array of user intervention documents

##### `getAllInterventions`
Get all available interventions library.

**Arguments:** None

**Returns:** Array of intervention documents

#### Mutations

##### `savePhysicianNote`
Save or update a physician note.

**Arguments:**
```typescript
{
  userId: Id<"users">
  dayNumber?: number
  noteText: string
  physicianId?: string
}
```

**Returns:** `Id<"physician_notes">`

##### `updatePatientReviewStatus`
Update patient review status.

**Arguments:**
```typescript
{
  userId: Id<"users">
  status: string  // "intake_in_progress", "pending_review", "under_review", "interventions_prepared", "interventions_active"
  physicianId?: string
}
```

**Returns:** void

##### `saveQuestionnaireScore`
Save a calculated questionnaire score.

**Arguments:**
```typescript
{
  userId: Id<"users">
  questionnaireName: string
  score: number
  maxScore?: number
  category?: string
  interpretation?: string
  calculationMetadata?: string
}
```

**Returns:** `Id<"questionnaire_scores">`

##### `updatePatientVisibleFields`
Update patient visible fields configuration.

**Arguments:**
```typescript
{
  userId: Id<"users">
  fieldConfig: string  // JSON string
  physicianId?: string
}
```

**Returns:** void

##### `createInterventionForPatient`
Create a new intervention for a patient.

**Arguments:**
```typescript
{
  userId: Id<"users">
  interventionId: Id<"interventions">
  startDate: string  // ISO date string
  endDate?: string   // ISO date string
  frequency?: string
  dosage?: string
  timing?: string
  customInstructions?: string
  physicianId?: string
}
```

**Returns:** `Id<"user_interventions">`

##### `activateInterventions`
Activate all draft interventions for a patient.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:** void

##### `deletePhysicianNote`
Delete a physician note.

**Arguments:**
```typescript
{
  noteId: Id<"physician_notes">
}
```

**Returns:** void

##### `updateUserIntervention`
Update an existing user intervention.

**Arguments:**
```typescript
{
  interventionId: Id<"user_interventions">
  updates: {
    start_date?: string
    end_date?: string
    frequency?: string
    dosage?: string
    timing?: string
    custom_instructions?: string
    status?: string
  }
}
```

**Returns:** void

##### `deleteUserIntervention`
Delete a user intervention.

**Arguments:**
```typescript
{
  interventionId: Id<"user_interventions">
}
```

**Returns:** void

---

### Module: `llm`

This module contains actions (not queries/mutations) that use OpenAI for analysis.

#### Actions

##### `analyzePatientResponses`
Analyze patient responses using LLM.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:**
```typescript
{
  summary: string
  riskFactors: string[]
  recommendations: string[]
}
```

##### `calculateStandardizedScore`
Calculate standardized questionnaire score (ISI, PSQI, ESS).

**Arguments:**
```typescript
{
  userId: Id<"users">
  questionnaireName: string  // "ISI", "PSQI", "ESS"
}
```

**Returns:**
```typescript
{
  score: number
  maxScore: number
  category: string
  interpretation: string
}
```

##### `generateInterventionRecommendations`
Generate intervention recommendations based on patient data.

**Arguments:**
```typescript
{
  userId: Id<"users">
}
```

**Returns:**
```typescript
Array<{
  interventionName: string
  rationale: string
  priority: string  // "high", "medium", "low"
}>
```

---

## Data Types & Conventions

### ID Types

Convex uses strongly-typed IDs. When working with TypeScript, use the `Id` type:

```typescript
import { Id } from "./_generated/dataModel";

const userId: Id<"users"> = "...";
const dayId: Id<"days"> = "...";
```

### Timestamps

All timestamps are Unix timestamps (milliseconds since epoch) as `number` type.

### Date Strings

Date strings use ISO format: `YYYY-MM-DD` (e.g., "2024-01-15").

### Time Strings

Time strings use format: `HH:MM` (e.g., "09:30", "22:00").

### JSON Fields

Many fields store JSON as strings. Parse them when reading:

```typescript
const options = JSON.parse(question.options || "[]");
const data = JSON.parse(response.response_data || "{}");
```

### Optional Fields

Fields marked as `optional` may be `undefined` or `null`. Always check before use.

### System Fields

All documents automatically include:
- `_id` - Document ID (type: `Id<"tableName">`)
- `_creationTime` - Creation timestamp (type: `number`)

---

## Usage Examples

### Setting Up Convex Client

```typescript
import { ConvexReactClient } from "convex/react";
import { api } from "./convex/_generated/api";

const convex = new ConvexReactClient(process.env.NEXT_PUBLIC_CONVEX_URL!);

// Use in React components
function MyComponent() {
  const user = useQuery(api.users.getUserById, { userId: "..." });
  // ...
}
```

### Authentication Flow

```typescript
// 1. Register user
const userId = await convex.mutation(api.auth.registerUser, {
  username: "john_doe",
  password_hash: hashedPassword,
  email: "john@example.com",
});

// 2. Login (get user, verify password client-side)
const user = await convex.query(api.auth.getUserForLogin, {
  username: "john_doe",
});

// 3. Store refresh token
const tokenId = await convex.mutation(api.auth.storeRefreshToken, {
  user_id: userId,
  token: refreshToken,
  expires_at: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 days
});
```

### Getting Day Data

```typescript
// Get day by number
const day = await convex.query(api.days.getDayByNumber, {
  dayNumber: 1,
});

// Get questions for day
const questions = await convex.query(api.questions.getQuestionsByDay, {
  dayId: day._id,
});

// Get user responses for day
const responses = await convex.query(api.responses.getUserDayResponses, {
  userId: currentUserId,
  dayId: day._id,
});
```

### Saving Assessment Response

```typescript
// Save response
const responseId = await convex.mutation(api.assessment.saveAssessmentResponse, {
  userId: currentUserId,
  questionId: "D1",
  responseValue: "John Doe",
  dayNumber: 1,
});

// Get all user responses
const allResponses = await convex.query(api.assessment.getUserResponses, {
  userId: currentUserId,
});
// Returns: { "D1": "John Doe", "D2": "1990-01-01", ... }
```

### Physician Dashboard

```typescript
// Get all patients
const patients = await convex.query(api.physician.getAllPatientsWithProgress, {
  statusFilter: "pending_review",
  searchTerm: "John",
});

// Get patient details
const patientDetails = await convex.query(api.physician.getPatientDetails, {
  userId: patientId,
});

// Get day data
const dayData = await convex.query(api.physician.getPatientDayData, {
  userId: patientId,
  dayNumber: 1,
});

// Save physician note
const noteId = await convex.mutation(api.physician.savePhysicianNote, {
  userId: patientId,
  dayNumber: 1,
  noteText: "Patient shows signs of insomnia",
  physicianId: "physician_123",
});

// Update review status
await convex.mutation(api.physician.updatePatientReviewStatus, {
  userId: patientId,
  status: "under_review",
  physicianId: "physician_123",
});
```

### Using LLM Actions

```typescript
// Analyze patient responses
const analysis = await convex.action(api.llm.analyzePatientResponses, {
  userId: patientId,
});
// Returns: { summary, riskFactors, recommendations }

// Calculate questionnaire score
const score = await convex.action(api.llm.calculateStandardizedScore, {
  userId: patientId,
  questionnaireName: "ISI",
});
// Returns: { score, maxScore, category, interpretation }

// Generate intervention recommendations
const recommendations = await convex.action(
  api.llm.generateInterventionRecommendations,
  { userId: patientId }
);
// Returns: Array of intervention recommendations
```

---

## Integration Guide

### 1. Install Convex

```bash
npm install convex
```

### 2. Initialize Convex

```bash
npx convex dev
```

This will:
- Create a `convex/` directory
- Generate API types
- Set up your deployment

### 3. Configure Environment Variables

```env
NEXT_PUBLIC_CONVEX_URL=https://your-project.convex.cloud
CONVEX_DEPLOY_KEY=your-deploy-key
```

### 4. Set Up Client

```typescript
// lib/convex.ts
import { ConvexReactClient } from "convex/react";

export const convex = new ConvexReactClient(
  process.env.NEXT_PUBLIC_CONVEX_URL!
);
```

### 5. Use in Components

```typescript
import { useQuery, useMutation } from "convex/react";
import { api } from "../convex/_generated/api";

function MyComponent() {
  const user = useQuery(api.users.getUserById, {
    userId: currentUserId,
  });

  const updateUser = useMutation(api.users.updateUser);

  // ...
}
```

### 6. Error Handling

```typescript
try {
  const result = await convex.mutation(api.users.updateUser, {
    userId,
    updates: { current_day: 2 },
  });
} catch (error) {
  console.error("Error updating user:", error);
  // Handle error
}
```

### 7. Real-time Subscriptions

Convex queries automatically subscribe to real-time updates:

```typescript
// This will automatically re-render when the user data changes
const user = useQuery(api.users.getUserById, { userId });
```

---

## Important Notes

1. **Authentication**: The system uses JWT tokens. Password hashing should be done client-side before calling `registerUser` or `updateUserPassword`.

2. **Real-time Updates**: All queries are real-time by default. Data updates automatically propagate to subscribed clients.

3. **Type Safety**: Use the generated `api` object for full TypeScript type safety.

4. **Indexes**: Always use indexes when querying. Check the schema for available indexes.

5. **JSON Fields**: Many fields store JSON as strings. Always parse them when reading and stringify when writing.

6. **Timestamps**: All timestamps are Unix timestamps in milliseconds.

7. **Date Format**: Dates are stored as ISO strings (`YYYY-MM-DD`).

8. **Actions vs Mutations**: Use `actions` for external API calls (like OpenAI). Use `mutations` for database operations.

9. **Error Handling**: Always wrap API calls in try-catch blocks.

10. **Rate Limiting**: Be aware of Convex's rate limits. Use pagination for large datasets.

---

## Support & Resources

- **Convex Documentation**: https://docs.convex.dev
- **Convex Discord**: https://convex.dev/community
- **TypeScript Types**: Generated in `convex/_generated/api.d.ts`

---

## Changelog

### Version 1.0.0
- Initial API documentation
- Complete schema documentation
- All function references
- Usage examples

---

**Last Updated**: 2024-01-15
**Maintained By**: ZOE Sleep Platform Team

