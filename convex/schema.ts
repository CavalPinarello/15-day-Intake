import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

/**
 * Complete Database Schema for ZOE Sleep Platform
 * Integrates all 5 components
 */
export default defineSchema({
  // ============================================
  // Core Tables
  // ============================================
  
  users: defineTable({
    username: v.string(),
    password_hash: v.string(),
    email: v.optional(v.string()),
    role: v.optional(v.union(v.literal("patient"), v.literal("physician"), v.literal("admin"))), // User role
    current_day: v.number(),
    started_at: v.number(), // Unix timestamp
    last_accessed: v.number(), // Unix timestamp
    created_at: v.number(), // Unix timestamp
    apple_health_connected: v.optional(v.boolean()),
    onboarding_completed: v.optional(v.boolean()),
    onboarding_completed_at: v.optional(v.number()),
    // Profile fields from onboarding
    measurement_system: v.optional(v.string()), // "Metric" or "Imperial"
    height_cm: v.optional(v.number()), // Height in centimeters
    weight_kg: v.optional(v.number()), // Weight in kilograms
    gender: v.optional(v.string()),
    birth_year: v.optional(v.number()),
    full_name: v.optional(v.string()), // User's display name
    // Email verification fields
    email_verified: v.optional(v.boolean()),
    email_verification_token: v.optional(v.string()),
    email_verification_expires: v.optional(v.number()),
    // Password reset fields
    password_reset_token: v.optional(v.string()),
    password_reset_expires: v.optional(v.number()),
    // OAuth fields (for future Google/Apple integration)
    oauth_provider: v.optional(v.union(v.literal("google"), v.literal("apple"), v.literal("clerk"))),
    oauth_id: v.optional(v.string()), // External OAuth user ID
    profile_picture: v.optional(v.string()),
    // Clerk integration (web auth)
    clerk_id: v.optional(v.string()), // Clerk user ID for web authentication
    // Developer mode (for testers)
    developer_mode: v.optional(v.boolean()), // Enables fast-track testing (skip time gates, instant day unlock)
  })
    .index("by_username", ["username"])
    .index("by_email", ["email"])
    .index("by_role", ["role"])
    .index("by_onboarding", ["onboarding_completed", "current_day"])
    .index("by_oauth", ["oauth_provider", "oauth_id"])
    .index("by_verification_token", ["email_verification_token"])
    .index("by_reset_token", ["password_reset_token"])
    .index("by_clerk_id", ["clerk_id"]),

  // ============================================
  // Component 1: 14-Day Onboarding Journey
  // ============================================
  
  days: defineTable({
    day_number: v.number(),
    title: v.string(),
    description: v.optional(v.string()),
    theme_color: v.optional(v.string()),
    background_image: v.optional(v.string()),
    created_at: v.number(),
  })
    .index("by_day_number", ["day_number"]),

  questions: defineTable({
    day_id: v.id("days"),
    question_text: v.string(),
    question_type: v.string(),
    options: v.optional(v.string()), // JSON string
    order_index: v.number(),
    required: v.boolean(),
    conditional_logic: v.optional(v.string()), // JSON string
    created_at: v.number(),
  })
    .index("by_day", ["day_id"])
    .index("by_day_order", ["day_id", "order_index"]),

  responses: defineTable({
    user_id: v.id("users"),
    question_id: v.id("questions"),
    day_id: v.id("days"),
    response_value: v.optional(v.string()),
    response_data: v.optional(v.string()), // JSON string
    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_day", ["user_id", "day_id"])
    .index("by_question", ["question_id"])
    .index("by_user_question", ["user_id", "question_id"]),

  user_progress: defineTable({
    user_id: v.id("users"),
    day_id: v.id("days"),
    completed: v.boolean(),
    completed_at: v.optional(v.number()),
    created_at: v.number(),
    // Section-level completion tracking for cross-device sync
    sleep_log_completed: v.optional(v.boolean()),
    assessment_completed: v.optional(v.boolean()),
    // Expansion pack (same-day deep dive) completion tracking
    expansion_pack_completed: v.optional(v.boolean()),
  })
    .index("by_user", ["user_id"])
    .index("by_user_day", ["user_id", "day_id"])
    .index("by_day", ["day_id"]),

  onboarding_insights: defineTable({
    user_id: v.id("users"),
    day_id: v.id("days"),
    insight_type: v.string(), // 'personalized', 'fact', 'action'
    insight_text: v.string(),
    generated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_day", ["user_id", "day_id"])
    .index("by_user_day_type", ["user_id", "day_id", "insight_type"]),

  // ============================================
  // Component 2: Daily App Use
  // ============================================
  
  daily_checkins: defineTable({
    user_id: v.id("users"),
    checkin_date: v.string(), // ISO date string YYYY-MM-DD
    checkin_type: v.union(v.literal("morning"), v.literal("midday"), v.literal("evening")),
    completed: v.boolean(),
    completed_at: v.optional(v.number()),
    data_json: v.optional(v.string()), // JSON string (legacy)

    // Morning check-in data
    sleep_quality: v.optional(v.number()),      // 1-5 rating
    energy_level: v.optional(v.number()),       // 1-6 rating (Watch: animal icons)
    mood: v.optional(v.number()),               // 1-6 rating (Watch: weather icons)
    focus_level: v.optional(v.number()),        // 1-5 rating (Watch: clarity icons)

    // Midday check-in data
    midday_energy: v.optional(v.number()),      // 1-4 rating
    caffeine_cups: v.optional(v.number()),      // 0-10 cups
    caffeine_last_time: v.optional(v.string()), // HH:MM format
    nap_taken: v.optional(v.boolean()),
    nap_duration_mins: v.optional(v.number()),

    // Evening check-in data
    reflection_text: v.optional(v.string()),
    overall_day_rating: v.optional(v.number()), // 1-5 rating
    tasks_missed_reasons: v.optional(v.string()), // JSON array

    // Metadata
    device_type: v.optional(v.string()),        // "ios", "watch", "web"
    created_at: v.number(),
    updated_at: v.optional(v.number()),
  })
    .index("by_user", ["user_id"])
    .index("by_user_date", ["user_id", "checkin_date"])
    .index("by_user_type", ["user_id", "checkin_type"])
    .index("by_user_date_type", ["user_id", "checkin_date", "checkin_type"]),

  checkin_responses: defineTable({
    checkin_id: v.id("daily_checkins"),
    question_key: v.string(),
    response_value: v.optional(v.string()),
    response_data: v.optional(v.string()), // JSON string
    created_at: v.number(),
  })
    .index("by_checkin", ["checkin_id"])
    .index("by_checkin_key", ["checkin_id", "question_key"]),

  user_preferences: defineTable({
    user_id: v.id("users"),
    notification_enabled: v.boolean(),
    notification_time: v.string(), // HH:MM format
    quiet_hours_start: v.string(), // HH:MM format
    quiet_hours_end: v.string(), // HH:MM format
    timezone: v.string(),
    apple_health_sync_enabled: v.boolean(),
    daily_reminder_enabled: v.boolean(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"]),

  // ============================================
  // Component 3: Full Sleep Report
  // ============================================
  
  sleep_reports: defineTable({
    user_id: v.id("users"),
    generated_at: v.number(),
    overall_score: v.optional(v.number()),
    archetype: v.optional(v.string()),
    report_data_json: v.optional(v.string()), // JSON string
    pdf_url: v.optional(v.string()),
  })
    .index("by_user", ["user_id"])
    .index("by_user_generated", ["user_id", "generated_at"]),

  report_sections: defineTable({
    report_id: v.id("sleep_reports"),
    section_num: v.number(),
    name: v.string(),
    score: v.optional(v.number()),
    strengths_json: v.optional(v.string()), // JSON string
    issues_json: v.optional(v.string()), // JSON string
    findings_json: v.optional(v.string()), // JSON string
  })
    .index("by_report", ["report_id"])
    .index("by_report_section", ["report_id", "section_num"]),

  report_roadmap: defineTable({
    report_id: v.id("sleep_reports"),
    quarterly_milestones_json: v.optional(v.string()), // JSON string
    monthly_tasks_json: v.optional(v.string()), // JSON string
  })
    .index("by_report", ["report_id"]),

  // ============================================
  // Component 4: Coach Dashboard
  // ============================================
  
  coaches: defineTable({
    email: v.string(),
    name: v.string(),
    role: v.optional(v.string()),
    permissions_json: v.optional(v.string()), // JSON string
    created_at: v.number(),
  })
    .index("by_email", ["email"]),

  customer_coach_assignments: defineTable({
    user_id: v.id("users"),
    coach_id: v.id("coaches"),
    assigned_at: v.number(),
    status: v.string(), // 'active', 'inactive', etc.
  })
    .index("by_user", ["user_id"])
    .index("by_coach", ["coach_id"])
    .index("by_coach_status", ["coach_id", "status"])
    .index("by_user_coach", ["user_id", "coach_id"]),

  alerts: defineTable({
    user_id: v.id("users"),
    coach_id: v.optional(v.id("coaches")),
    alert_type: v.string(),
    severity: v.string(), // 'low', 'medium', 'high', 'critical'
    message: v.string(),
    data_json: v.optional(v.string()), // JSON string
    resolved: v.boolean(),
    created_at: v.number(),
    resolved_at: v.optional(v.number()),
  })
    .index("by_user", ["user_id"])
    .index("by_coach", ["coach_id"])
    .index("by_user_coach_resolved", ["user_id", "coach_id", "resolved"])
    .index("by_resolved", ["resolved"]),

  messages: defineTable({
    from_user_id: v.optional(v.id("users")),
    to_user_id: v.id("users"),
    message_text: v.string(),
    read_at: v.optional(v.number()),
    created_at: v.number(),
  })
    .index("by_from_user", ["from_user_id"])
    .index("by_to_user", ["to_user_id"])
    .index("by_users", ["from_user_id", "to_user_id"])
    .index("by_created", ["created_at"]),

  // ============================================
  // Component 5: Supporting Systems
  // ============================================
  
  // Authentication
  refresh_tokens: defineTable({
    user_id: v.id("users"),
    token: v.string(),
    expires_at: v.number(),
    created_at: v.number(),
    revoked: v.boolean(),
  })
    .index("by_user", ["user_id"])
    .index("by_token", ["token"])
    .index("by_user_revoked", ["user_id", "revoked"]),

  // Health Data
  user_sleep_data: defineTable({
    user_id: v.id("users"),
    date: v.string(), // ISO date string YYYY-MM-DD
    in_bed_time: v.optional(v.number()), // Unix timestamp
    asleep_time: v.optional(v.number()), // Unix timestamp
    wake_time: v.optional(v.number()), // Unix timestamp
    total_sleep_mins: v.optional(v.number()),
    sleep_efficiency: v.optional(v.number()),
    deep_sleep_mins: v.optional(v.number()),
    light_sleep_mins: v.optional(v.number()),
    rem_sleep_mins: v.optional(v.number()),
    awake_mins: v.optional(v.number()),
    interruptions_count: v.optional(v.number()),
    sleep_latency_mins: v.optional(v.number()),
    synced_at: v.number(),
    // Source tracking fields
    primary_source: v.optional(v.string()), // "Apple Watch", "Oura", "Fitbit", etc.
    source_bundle_id: v.optional(v.string()), // Bundle ID of the primary source app
    all_sources_json: v.optional(v.string()), // JSON array of all contributing sources
    is_multi_source: v.optional(v.boolean()), // True if data came from multiple sources
  })
    .index("by_user", ["user_id"])
    .index("by_user_date", ["user_id", "date"])
    .index("by_date", ["date"]),

  user_sleep_stages: defineTable({
    user_id: v.id("users"),
    date: v.string(), // ISO date string YYYY-MM-DD
    start_time: v.number(), // Unix timestamp
    end_time: v.number(), // Unix timestamp
    stage: v.string(), // 'deep', 'light', 'rem', 'awake'
    duration_mins: v.optional(v.number()),
  })
    .index("by_user", ["user_id"])
    .index("by_user_date", ["user_id", "date"])
    .index("by_date", ["date"]),

  user_heart_rate: defineTable({
    user_id: v.id("users"),
    date: v.string(), // ISO date string YYYY-MM-DD
    resting_hr: v.optional(v.number()),
    avg_hr: v.optional(v.number()),
    hrv_morning: v.optional(v.number()),
    hrv_avg: v.optional(v.number()),
    synced_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_date", ["user_id", "date"]),

  user_activity: defineTable({
    user_id: v.id("users"),
    date: v.string(), // ISO date string YYYY-MM-DD
    steps: v.optional(v.number()),
    active_mins: v.optional(v.number()),
    exercise_mins: v.optional(v.number()),
    calories_burned: v.optional(v.number()),
    synced_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_date", ["user_id", "date"]),

  user_workouts: defineTable({
    user_id: v.id("users"),
    date: v.string(), // ISO date string YYYY-MM-DD
    workout_type: v.optional(v.string()),
    start_time: v.optional(v.number()), // Unix timestamp
    duration_mins: v.optional(v.number()),
    avg_hr: v.optional(v.number()),
    max_hr: v.optional(v.number()),
    calories: v.optional(v.number()),
    distance_km: v.optional(v.number()),
    intensity_zones_json: v.optional(v.string()), // JSON string
  })
    .index("by_user", ["user_id"])
    .index("by_user_date", ["user_id", "date"])
    .index("by_date", ["date"]),

  user_baselines: defineTable({
    user_id: v.id("users"),
    metric_name: v.string(),
    baseline_value: v.number(),
    calculated_at: v.number(),
    period_days: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_metric", ["user_id", "metric_name"]),

  // ============================================
  // Intervention Library (ZOE Sleep Circadian)
  // ============================================

  // Intervention categories/domains
  intervention_categories: defineTable({
    category_id: v.string(), // e.g., "sleep_timing", "light_dark", "chrononutrition"
    name: v.string(),
    description: v.optional(v.string()),
    icon: v.optional(v.string()), // Icon name for UI
    color: v.optional(v.string()), // Color for UI theming
    order_index: v.number(),
  })
    .index("by_category_id", ["category_id"]),

  // Master intervention library
  interventions: defineTable({
    // Core identification
    intervention_id: v.string(), // Stable ID like "WAKE-ANCHOR-01", "LIGHT-AM-01"
    name: v.string(), // "Fixed Wake-Time Anchor"
    short_name: v.optional(v.string()), // "Wake Anchor" for compact display

    // Categorization
    category: v.string(), // "sleep_timing", "light_dark", "chrononutrition", etc.
    type: v.optional(v.string()), // "behavioral", "environmental", "supplement", "medical"

    // Clinical content
    why_it_works: v.string(), // Scientific rationale
    how_to_apply: v.string(), // Implementation rules/guidelines
    instructions_text: v.string(), // Patient-facing instructions

    // Targeting & phenotypes
    target_phenotypes_json: v.optional(v.string()), // JSON array: ["DSPD", "irregular_rhythm"]
    target_gateways_json: v.optional(v.string()), // JSON array: ["insomnia", "sleep_apnea"]

    // Evidence & safety
    evidence_score: v.optional(v.number()), // 1-5 evidence quality
    safety_rating: v.optional(v.number()), // 1-5 safety rating
    contraindications_json: v.optional(v.string()), // JSON array of contraindication strings
    interactions_json: v.optional(v.string()), // JSON array of interactions with other interventions

    // Dosing/timing configuration
    default_frequency: v.optional(v.string()), // "daily", "twice_daily", "weekly"
    available_frequencies_json: v.optional(v.string()), // JSON array of options
    default_timing: v.optional(v.string()), // "morning", "evening", "pre_bed"
    available_timings_json: v.optional(v.string()), // JSON array
    recommended_duration_weeks: v.optional(v.number()),
    min_duration_days: v.optional(v.number()),
    max_duration_days: v.optional(v.number()),

    // For supplements
    default_dosage: v.optional(v.string()), // "3g", "200-400mg"
    dosage_notes: v.optional(v.string()),

    // Bundle associations
    bundle_ids_json: v.optional(v.string()), // JSON array: ["phase_advance", "metabolic_circadian"]
    is_core_intervention: v.optional(v.boolean()), // True if commonly used
    is_optional_addon: v.optional(v.boolean()), // True if optional enhancement

    // Metadata
    primary_benefit: v.optional(v.string()),
    created_by_coach_id: v.optional(v.id("coaches")),
    status: v.string(), // 'active', 'archived', 'draft'
    version: v.number(),
    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_status", ["status"])
    .index("by_category", ["category"])
    .index("by_intervention_id", ["intervention_id"])
    .index("by_coach", ["created_by_coach_id"]),

  // Intervention bundles (pre-configured treatment packages)
  intervention_bundles: defineTable({
    bundle_id: v.string(), // e.g., "phase_advance_regularity", "cbti_onset"
    name: v.string(), // "Phase Advance + Regularity"
    description: v.string(),
    goal: v.string(), // "advance circadian phase and stabilize amplitude"

    // Target conditions
    target_phenotypes_json: v.string(), // JSON array: ["DSPD", "late_chronotype"]
    target_gateways_json: v.optional(v.string()), // JSON array of gateway IDs

    // Intervention composition
    core_intervention_ids_json: v.string(), // JSON array of intervention_ids (required)
    optional_intervention_ids_json: v.optional(v.string()), // JSON array (add-ons)

    // Configuration
    recommended_count: v.number(), // Recommended number of interventions (6-12)
    min_interventions: v.optional(v.number()),
    max_interventions: v.optional(v.number()),

    // Tracking metrics
    tracking_metrics_json: v.optional(v.string()), // JSON array: ["regularity", "light_timing"]

    status: v.string(),
    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_bundle_id", ["bundle_id"])
    .index("by_status", ["status"]),

  user_interventions: defineTable({
    user_id: v.id("users"),
    intervention_id: v.id("interventions"),
    intervention_string_id: v.optional(v.string()), // e.g., "WAKE-ANCHOR-01" for easier lookup
    assigned_by_coach_id: v.optional(v.id("coaches")),
    assigned_by_physician_id: v.optional(v.string()),

    // Scheduling
    start_date: v.string(), // ISO date string YYYY-MM-DD
    end_date: v.optional(v.string()), // ISO date string YYYY-MM-DD
    frequency: v.optional(v.string()), // "daily", "weekly", "as_needed"
    schedule_json: v.optional(v.string()), // JSON for complex schedules
    days_of_week_json: v.optional(v.string()), // JSON array: ["monday", "wednesday", "friday"]

    // Timing
    timing: v.optional(v.string()), // "morning", "evening", "pre_bed", "post_meal"
    specific_time: v.optional(v.string()), // HH:MM format for reminders
    timing_relative_to: v.optional(v.string()), // "wake", "bed", "meal"
    timing_offset_minutes: v.optional(v.number()), // e.g., -60 = 1 hour before

    // Dosage (for supplements)
    dosage: v.optional(v.string()),
    form: v.optional(v.string()),

    // Instructions
    custom_instructions: v.optional(v.string()),
    patient_instructions: v.optional(v.string()), // Simplified instructions for patient

    // Priority & display
    priority: v.optional(v.number()), // 1-5, higher = more important
    display_order: v.optional(v.number()),

    // Time window for session-based display
    time_window: v.optional(v.string()), // "morning", "afternoon", "evening", "night"

    // Status tracking
    status: v.string(), // 'draft', 'active', 'paused', 'completed', 'cancelled'
    paused_reason: v.optional(v.string()),
    completion_reason: v.optional(v.string()),

    // Timestamps
    assigned_at: v.number(),
    activated_at: v.optional(v.number()),
    paused_at: v.optional(v.number()),
    completed_at: v.optional(v.number()),
  })
    .index("by_user", ["user_id"])
    .index("by_user_status", ["user_id", "status"])
    .index("by_intervention", ["intervention_id"])
    .index("by_coach", ["assigned_by_coach_id"]),

  // Daily tasks generated from interventions (shown in patient app)
  user_daily_tasks: defineTable({
    user_id: v.id("users"),
    user_intervention_id: v.id("user_interventions"),
    intervention_id: v.id("interventions"),

    // Task details
    task_date: v.string(), // YYYY-MM-DD
    task_name: v.string(),
    task_instructions: v.string(),
    timing: v.optional(v.string()), // "morning", "evening", etc.
    scheduled_time: v.optional(v.string()), // HH:MM

    // Time window enforcement (for session-based UI)
    time_window: v.optional(v.string()), // "morning", "afternoon", "evening", "night"
    window_start_hour: v.optional(v.number()), // 5 for 5 AM
    window_end_hour: v.optional(v.number()), // 12 for noon

    // Completion tracking
    status: v.string(), // "pending", "completed", "skipped", "missed"
    completed_at: v.optional(v.number()),
    skipped_at: v.optional(v.number()),
    skipped_reason: v.optional(v.string()),

    // User feedback
    difficulty_rating: v.optional(v.number()), // 1-5
    notes: v.optional(v.string()),

    // Metadata
    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_date", ["user_id", "task_date"])
    .index("by_user_status", ["user_id", "status"])
    .index("by_intervention", ["user_intervention_id"])
    .index("by_date", ["task_date"]),

  intervention_compliance: defineTable({
    user_intervention_id: v.id("user_interventions"),
    scheduled_date: v.string(), // ISO date string YYYY-MM-DD
    completed: v.boolean(),
    completed_at: v.optional(v.number()),
    note_text: v.optional(v.string()),
  })
    .index("by_intervention", ["user_intervention_id"])
    .index("by_intervention_date", ["user_intervention_id", "scheduled_date"])
    .index("by_date", ["scheduled_date"]),

  intervention_user_notes: defineTable({
    user_intervention_id: v.id("user_interventions"),
    note_text: v.string(),
    mood_rating: v.optional(v.number()),
    created_at: v.number(),
  })
    .index("by_intervention", ["user_intervention_id"])
    .index("by_created", ["created_at"]),

  intervention_coach_notes: defineTable({
    user_intervention_id: v.id("user_interventions"),
    coach_id: v.id("coaches"),
    note_text: v.string(),
    tags_json: v.optional(v.string()), // JSON string
    created_at: v.number(),
  })
    .index("by_intervention", ["user_intervention_id"])
    .index("by_coach", ["coach_id"]),

  intervention_schedule: defineTable({
    user_intervention_id: v.id("user_interventions"),
    scheduled_time: v.string(), // HH:MM format
    scheduled_days: v.string(), // JSON array string
    timezone: v.string(),
    created_at: v.number(),
  })
    .index("by_intervention", ["user_intervention_id"]),

  // ============================================
  // Treatment Protocol System
  // Morning/Evening Protocols with Grouped Tasks
  // ============================================

  // Protocol definitions (Morning Protocol, Evening Protocol)
  treatment_protocols: defineTable({
    protocol_id: v.string(),           // "morning_protocol", "evening_protocol"
    name: v.string(),                  // "Morning Protocol"
    description: v.string(),
    time_window: v.string(),           // "morning" or "evening"
    window_start_hour: v.number(),     // 5 for 5 AM
    window_end_hour: v.number(),       // 12 for noon
    icon: v.string(),                  // SF Symbol name
    color: v.string(),                 // Hex color
    order_index: v.number(),
    is_active: v.boolean(),
    created_at: v.number(),
  })
    .index("by_protocol_id", ["protocol_id"])
    .index("by_time_window", ["time_window"]),

  // User protocol assignments (physician assigns protocols to patients)
  user_protocol_assignments: defineTable({
    user_id: v.id("users"),
    protocol_id: v.string(),           // References treatment_protocols.protocol_id
    intervention_ids_json: v.string(), // JSON array of intervention_id strings
    start_date: v.string(),            // YYYY-MM-DD
    end_date: v.optional(v.string()),
    status: v.string(),                // "active", "paused", "completed"
    assigned_by_physician_id: v.optional(v.string()),
    assigned_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_status", ["user_id", "status"])
    .index("by_protocol", ["protocol_id"]),

  // ============================================
  // Adaptive Difficulty System
  // Auto-adjusts task complexity based on compliance
  // ============================================

  intervention_difficulty_settings: defineTable({
    user_intervention_id: v.id("user_interventions"),

    // Current difficulty level
    current_difficulty: v.number(),        // 1-5 (1=easiest, 5=hardest)
    original_difficulty: v.number(),       // Starting difficulty (for reset)

    // Adjustment tracking
    last_adjustment_date: v.optional(v.string()),
    adjustment_reason: v.optional(v.string()),
    adjustment_direction: v.optional(v.string()), // "reduced", "increased", "reset"

    // Rolling compliance metrics
    rolling_7_day_compliance: v.number(),  // 0-100 percentage
    consecutive_low_days: v.number(),      // Days below 50%
    consecutive_high_days: v.number(),     // Days above 90%

    // Physician override
    difficulty_locked: v.boolean(),        // If true, no auto-adjustment
    locked_by_physician_id: v.optional(v.string()),
    locked_at: v.optional(v.number()),
    lock_reason: v.optional(v.string()),

    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_intervention", ["user_intervention_id"])
    .index("by_compliance", ["rolling_7_day_compliance"]),

  // Difficulty adjustment history (audit log)
  difficulty_adjustment_log: defineTable({
    user_intervention_id: v.id("user_interventions"),
    user_id: v.id("users"),
    previous_difficulty: v.number(),
    new_difficulty: v.number(),
    adjustment_type: v.string(),           // "auto_reduce", "auto_increase", "physician_override", "reset"
    reason: v.string(),
    rolling_compliance_at_adjustment: v.number(),
    adjusted_at: v.number(),
    adjusted_by: v.optional(v.string()),   // null for auto, physician_id for manual
  })
    .index("by_user", ["user_id"])
    .index("by_intervention", ["user_intervention_id"])
    .index("by_adjusted_at", ["adjusted_at"]),

  // ============================================
  // Compliance-Outcome Correlation
  // Tracks relationship between compliance and sleep improvement
  // ============================================

  compliance_outcome_correlation: defineTable({
    user_id: v.id("users"),
    computation_date: v.string(),        // YYYY-MM-DD when computed
    period_start: v.string(),            // Analysis period start
    period_end: v.string(),              // Analysis period end

    // Overall compliance metrics
    overall_compliance_pct: v.number(),  // 0-100
    protocol_compliance_json: v.optional(v.string()), // Per-protocol breakdown
    intervention_compliance_json: v.optional(v.string()), // Per-intervention breakdown
    checkin_compliance_pct: v.optional(v.number()),  // Check-in completion rate

    // Questionnaire score changes (before/after)
    isi_score_start: v.optional(v.number()),
    isi_score_end: v.optional(v.number()),
    isi_change: v.optional(v.number()),  // Negative = improvement

    phq9_score_start: v.optional(v.number()),
    phq9_score_end: v.optional(v.number()),
    phq9_change: v.optional(v.number()),

    gad7_score_start: v.optional(v.number()),
    gad7_score_end: v.optional(v.number()),
    gad7_change: v.optional(v.number()),

    // Subjective sleep improvement
    subjective_improvement: v.optional(v.number()), // -2 to +2 (much worse to much better)

    // Objective sleep data (from HealthKit)
    avg_sleep_efficiency_start: v.optional(v.number()),
    avg_sleep_efficiency_end: v.optional(v.number()),
    avg_sleep_duration_start: v.optional(v.number()),  // minutes
    avg_sleep_duration_end: v.optional(v.number()),
    avg_sleep_latency_start: v.optional(v.number()),   // minutes to fall asleep
    avg_sleep_latency_end: v.optional(v.number()),

    // Correlation analysis
    compliance_improvement_correlation: v.optional(v.number()), // -1 to 1 (Pearson)
    correlation_strength: v.optional(v.string()), // "strong", "moderate", "weak", "none"

    created_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_date", ["user_id", "computation_date"]),

  // ============================================
  // Watch Offline Queue
  // Supports offline-first Watch sync
  // ============================================

  watch_offline_queue: defineTable({
    user_id: v.id("users"),
    device_id: v.string(),               // Watch device identifier

    // Action details
    action_type: v.string(),             // "checkin", "task_complete", "task_skip"
    action_data_json: v.string(),        // Full action payload

    // Sync status
    queued_at: v.number(),
    synced_at: v.optional(v.number()),
    sync_status: v.string(),             // "pending", "synced", "failed"
    retry_count: v.number(),
    last_error: v.optional(v.string()),
  })
    .index("by_user", ["user_id"])
    .index("by_device", ["device_id"])
    .index("by_status", ["sync_status"])
    .index("by_user_status", ["user_id", "sync_status"]),

  // Metrics & Analytics
  user_metrics_summary: defineTable({
    user_id: v.id("users"),
    metric_date: v.string(), // ISO date string YYYY-MM-DD
    sleep_score: v.optional(v.number()),
    activity_score: v.optional(v.number()),
    compliance_score: v.optional(v.number()),
    overall_score: v.optional(v.number()),
    calculated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_date", ["user_id", "metric_date"])
    .index("by_date", ["metric_date"]),

  // ============================================
  // Sleep Insights Tables
  // ============================================

  // Pre-computed sleep insights (updated when new data syncs)
  sleep_insights: defineTable({
    user_id: v.id("users"),
    insight_type: v.string(), // "perception_gap", "bedtime_optimal", "weekend_pattern", "sleep_latency"
    insight_key: v.string(), // Unique key for this insight (e.g., "bedtime_optimal_2230")
    insight_title: v.string(), // Short title: "Optimal Bedtime Found"
    insight_text: v.string(), // Full insight: "You fall asleep 18 minutes faster..."
    confidence_score: v.number(), // 0-100 statistical confidence
    data_points: v.number(), // Number of data points used in calculation
    is_actionable: v.boolean(), // True if user can act on this insight
    computed_at: v.number(), // Timestamp when insight was generated
    expires_at: v.optional(v.number()), // Optional expiration timestamp
    metadata_json: v.optional(v.string()), // Additional data for UI (e.g., optimal time, percentage)
  })
    .index("by_user", ["user_id"])
    .index("by_user_type", ["user_id", "insight_type"])
    .index("by_expires", ["expires_at"]),

  // Daily perception gap tracking (subjective vs objective sleep)
  perception_gaps: defineTable({
    user_id: v.id("users"),
    date: v.string(), // YYYY-MM-DD
    // Subjective data (from Sleep Log questionnaire)
    subjective_quality: v.optional(v.number()), // 1-10 rating from SD_SLEEP_QUALITY
    subjective_latency_mins: v.optional(v.number()), // From SD_SLEEP_LATENCY
    subjective_awakenings: v.optional(v.number()), // From SD_AWAKENINGS_COUNT
    // Objective data (from HealthKit)
    objective_total_sleep_mins: v.optional(v.number()),
    objective_efficiency: v.optional(v.number()), // 0-100 percentage
    objective_deep_mins: v.optional(v.number()),
    objective_rem_mins: v.optional(v.number()),
    objective_latency_mins: v.optional(v.number()),
    objective_awakenings: v.optional(v.number()),
    // Computed gap metrics
    gap_score: v.optional(v.number()), // Normalized gap (-100 to +100)
    gap_direction: v.optional(v.string()), // "underestimate", "overestimate", "accurate"
    computed_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_date", ["user_id", "date"])
    .index("by_date", ["date"]),

  // ============================================
  // Assessment System Tables
  // ============================================
  
  assessment_questions: defineTable({
    question_id: v.string(), // Text ID like "D1", "D2", etc.
    question_text: v.string(),
    help_text: v.optional(v.string()), // Helper text shown below question
    pillar: v.string(),
    tier: v.string(),
    
    // Answer Format Configuration (NEW)
    answer_format: v.string(), // One of: time_picker, minutes_scroll, number_scroll, slider_scale, single_select_chips, multi_select_chips, date_picker, number_input, repeating_group
    format_config: v.string(), // JSON string with type-specific configuration
    
    // Legacy fields (kept for backward compatibility)
    question_type: v.optional(v.string()),
    options_json: v.optional(v.string()), // JSON string (deprecated - use format_config)
    
    // Validation & Display
    validation_rules: v.optional(v.string()), // JSON string with validation rules
    conditional_logic: v.optional(v.string()), // JSON string for show/hide logic
    order_index: v.optional(v.number()), // Question ordering within a module
    
    // Metadata
    estimated_time_seconds: v.number(), // Time to answer in seconds
    trigger: v.optional(v.string()),
    notes: v.optional(v.string()), // JSON string
    created_at: v.optional(v.number()),
    updated_at: v.optional(v.number()),
  })
    .index("by_question_id", ["question_id"])
    .index("by_pillar_tier", ["pillar", "tier"])
    .index("by_answer_format", ["answer_format"]),

  assessment_modules: defineTable({
    module_id: v.string(), // Text ID
    name: v.string(),
    description: v.optional(v.string()),
    pillar: v.string(),
    tier: v.string(),
    module_type: v.string(), // 'CORE', 'GATEWAY', 'EXPANSION'
    estimated_minutes: v.optional(v.number()),
    default_day_number: v.optional(v.number()),
    repeat_interval: v.optional(v.number()),
  })
    .index("by_module_id", ["module_id"])
    .index("by_pillar_tier", ["pillar", "tier"])
    .index("by_type", ["module_type"]),

  module_questions: defineTable({
    module_id: v.string(), // References assessment_modules.module_id
    question_id: v.string(), // References assessment_questions.question_id
    order_index: v.number(),
  })
    .index("by_module", ["module_id"])
    .index("by_module_order", ["module_id", "order_index"])
    .index("by_question", ["question_id"]),

  day_modules: defineTable({
    day_number: v.number(),
    module_id: v.string(), // References assessment_modules.module_id
    order_index: v.number(),
  })
    .index("by_day", ["day_number"])
    .index("by_day_order", ["day_number", "order_index"])
    .index("by_module", ["module_id"]),

  module_gateways: defineTable({
    gateway_id: v.string(), // Text ID
    name: v.string(),
    description: v.optional(v.string()),
    condition_json: v.string(), // JSON string
    target_modules_json: v.string(), // JSON array string
    trigger_question_ids_json: v.string(), // JSON array string
    created_at: v.number(),
  })
    .index("by_gateway_id", ["gateway_id"]),

  user_gateway_states: defineTable({
    user_id: v.id("users"),
    gateway_id: v.string(), // References module_gateways.gateway_id
    triggered: v.boolean(),
    triggered_at: v.optional(v.number()),
    last_evaluated_at: v.number(),
    evaluation_data_json: v.optional(v.string()), // JSON string
  })
    .index("by_user", ["user_id"])
    .index("by_user_gateway", ["user_id", "gateway_id"])
    .index("by_gateway", ["gateway_id"]),

  // Dynamic expansion schedule - computed when Day 2 completes
  // Stores the optimal distribution of expansion modules based on triggered gateways
  user_expansion_schedules: defineTable({
    user_id: v.id("users"),
    computed_at: v.number(),
    triggered_gateways: v.array(v.string()), // Gateway IDs that were triggered
    day_assignments: v.array(v.object({
      day_number: v.number(),
      module_ids: v.array(v.string()),
      question_count: v.number(),
      estimated_minutes: v.number(),
      completed: v.optional(v.boolean()),
    })),
    total_expansion_questions: v.number(),
    total_estimated_minutes: v.optional(v.number()),
  })
    .index("by_user", ["user_id"]),

  user_assessment_responses: defineTable({
    user_id: v.id("users"),
    question_id: v.string(), // References assessment_questions.question_id

    // Response storage (use appropriate field based on answer_format)
    response_value: v.optional(v.string()), // For: time_picker, single_select_chips, date_picker (string values)
    response_number: v.optional(v.number()), // For: minutes_scroll, number_scroll, slider_scale, number_input (numeric values)
    response_array: v.optional(v.string()), // For: multi_select_chips (JSON array string)
    response_object: v.optional(v.string()), // For: repeating_group (JSON object string)

    // Metadata
    day_number: v.optional(v.number()),
    answered_in_seconds: v.optional(v.number()), // Track how long user took to answer
    // Derived answer flag - true if this answer was auto-populated from an equivalent question
    // for complete clinical scoring (e.g., SB_1 derived from Q19 snoring answer)
    is_derived: v.optional(v.boolean()),
    // Source question ID when is_derived is true (for audit trail)
    derived_from_question_id: v.optional(v.string()),
    // Response source tracking: "user" (default), "profile" (from onboarding), "derived" (calculated), "healthkit"
    response_source: v.optional(v.string()),
    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_question", ["user_id", "question_id"])
    .index("by_user_day", ["user_id", "day_number"])
    .index("by_user_question_day", ["user_id", "question_id", "day_number"])
    .index("by_question", ["question_id"]),

  sleep_diary_questions: defineTable({
    id: v.string(), // Text ID (primary key)
    question_text: v.string(),
    help_text: v.optional(v.string()),
    group_key: v.optional(v.string()), // Groups related questions (e.g., "bedtime", "awakenings")
    
    // Answer Format Configuration (NEW - matches assessment_questions)
    answer_format: v.string(), // One of: time_picker, minutes_scroll, number_scroll, slider_scale, single_select_chips, multi_select_chips, date_picker, number_input, repeating_group
    format_config: v.string(), // JSON string with type-specific configuration
    
    // Legacy fields (kept for backward compatibility)
    question_type: v.optional(v.string()), // Deprecated - use answer_format
    options_json: v.optional(v.string()), // Deprecated - use format_config
    
    // Validation & Display
    validation_rules: v.optional(v.string()), // JSON string with validation rules
    conditional_logic: v.optional(v.string()), // JSON string for show/hide logic (renamed from condition_json)
    order_index: v.optional(v.number()),
    
    // Metadata
    estimated_time_seconds: v.number(), // Time to answer in seconds
    pillar: v.optional(v.string()), // Map to Sleep 360 pillars
    created_at: v.optional(v.number()),
    updated_at: v.optional(v.number()),
  })
    .index("by_question_id", ["id"])
    .index("by_group", ["group_key"])
    .index("by_answer_format", ["answer_format"]),

  // ============================================
  // Physician Dashboard Tables
  // ============================================

  physician_notes: defineTable({
    user_id: v.id("users"),
    day_number: v.optional(v.number()),
    note_text: v.string(),
    created_at: v.number(),
    updated_at: v.number(),
    physician_id: v.optional(v.string()),
  })
    .index("by_user", ["user_id"])
    .index("by_user_day", ["user_id", "day_number"]),

  patient_review_status: defineTable({
    user_id: v.id("users"),
    status: v.string(), // "intake_in_progress", "pending_review", "under_review", "interventions_prepared", "interventions_active"
    reviewed_by_physician_id: v.optional(v.string()),
    review_started_at: v.optional(v.number()),
    review_completed_at: v.optional(v.number()),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_status", ["status"]),

  questionnaire_scores: defineTable({
    user_id: v.id("users"),
    questionnaire_name: v.string(),
    score: v.number(),
    max_score: v.optional(v.number()),
    category: v.optional(v.string()),
    interpretation: v.optional(v.string()),
    calculated_at: v.number(),
    calculation_metadata_json: v.optional(v.string()),
  })
    .index("by_user", ["user_id"])
    .index("by_user_questionnaire", ["user_id", "questionnaire_name"]),

  patient_visible_fields: defineTable({
    user_id: v.id("users"),
    field_config_json: v.string(), // JSON string of field visibility settings
    updated_at: v.number(),
    updated_by_physician_id: v.optional(v.string()),
  })
    .index("by_user", ["user_id"]),

  // ============================================
  // iOS App Tables
  // ============================================

  // iOS Device Registration (for push notifications)
  ios_devices: defineTable({
    user_id: v.id("users"),
    device_token: v.string(), // APNs device token
    device_id: v.string(), // Unique device identifier
    device_name: v.optional(v.string()), // e.g., "Martin's iPhone"
    device_model: v.optional(v.string()), // e.g., "iPhone 15 Pro"
    os_version: v.optional(v.string()), // e.g., "17.1"
    app_version: v.optional(v.string()), // e.g., "1.0.0"
    push_enabled: v.boolean(),
    last_active_at: v.number(),
    created_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_device_token", ["device_token"])
    .index("by_device_id", ["device_id"]),

  // iOS Sessions (for session management)
  ios_sessions: defineTable({
    user_id: v.id("users"),
    session_token: v.string(), // JWT or session identifier
    device_id: v.string(), // Links to ios_devices
    expires_at: v.number(),
    created_at: v.number(),
    last_refreshed_at: v.number(),
    is_active: v.boolean(),
    ip_address: v.optional(v.string()),
  })
    .index("by_user", ["user_id"])
    .index("by_session_token", ["session_token"])
    .index("by_device", ["device_id"])
    .index("by_user_active", ["user_id", "is_active"]),

  // Apple Sign-In Data
  apple_sign_in: defineTable({
    user_id: v.id("users"),
    apple_user_id: v.string(), // Apple's unique user identifier
    email: v.optional(v.string()), // Only provided on first sign-in
    full_name: v.optional(v.string()), // Only provided on first sign-in
    identity_token_hash: v.optional(v.string()), // Hash of last identity token
    authorization_code_hash: v.optional(v.string()), // Hash of auth code
    real_user_status: v.optional(v.string()), // "likelyReal", "unknown", "unsupported"
    created_at: v.number(),
    last_sign_in_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_apple_user_id", ["apple_user_id"]),

  // iOS App Analytics/Events
  ios_app_events: defineTable({
    user_id: v.optional(v.id("users")), // Optional for pre-auth events
    device_id: v.string(),
    event_type: v.string(), // "app_open", "screen_view", "questionnaire_start", etc.
    event_data: v.optional(v.string()), // JSON string with event-specific data
    screen_name: v.optional(v.string()),
    session_id: v.optional(v.string()),
    timestamp: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_device", ["device_id"])
    .index("by_event_type", ["event_type"])
    .index("by_timestamp", ["timestamp"]),

  // iOS HealthKit Sync Status
  ios_healthkit_sync: defineTable({
    user_id: v.id("users"),
    device_id: v.string(),
    last_sync_at: v.number(),
    sync_status: v.string(), // "success", "partial", "failed", "pending"
    data_types_synced: v.string(), // JSON array of synced HK types
    records_synced: v.number(), // Count of records synced
    error_message: v.optional(v.string()),
    next_sync_scheduled: v.optional(v.number()),
  })
    .index("by_user", ["user_id"])
    .index("by_device", ["device_id"])
    .index("by_user_device", ["user_id", "device_id"]),

  // iOS Notification History
  ios_notifications: defineTable({
    user_id: v.id("users"),
    device_id: v.optional(v.string()),
    notification_type: v.string(), // "reminder", "questionnaire", "insight", "message"
    title: v.string(),
    body: v.string(),
    data_json: v.optional(v.string()), // Additional payload data
    sent_at: v.number(),
    delivered_at: v.optional(v.number()),
    opened_at: v.optional(v.number()),
    status: v.string(), // "pending", "sent", "delivered", "opened", "failed"
  })
    .index("by_user", ["user_id"])
    .index("by_device", ["device_id"])
    .index("by_status", ["status"])
    .index("by_sent_at", ["sent_at"]),

  // iOS Watch Sync State (for watchOS companion app)
  ios_watch_sync: defineTable({
    user_id: v.id("users"),
    watch_device_id: v.string(),
    phone_device_id: v.string(),
    last_sync_at: v.number(),
    questionnaire_progress_json: v.optional(v.string()), // Synced questionnaire state
    health_data_synced: v.boolean(),
    recommendations_synced: v.boolean(),
  })
    .index("by_user", ["user_id"])
    .index("by_watch", ["watch_device_id"])
    .index("by_phone", ["phone_device_id"]),

  // ============================================
  // Watch Garden State (Weekly Flower Visualization)
  // Tracks daily check-in compliance as blooming flowers
  // ============================================

  watch_garden_state: defineTable({
    user_id: v.id("users"),
    week_start_date: v.string(),     // Monday's date YYYY-MM-DD
    days_json: v.string(),           // JSON array of DayFlower objects
    current_streak: v.number(),      // Consecutive days of compliance
    longest_streak: v.number(),      // Personal best streak
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_week", ["user_id", "week_start_date"]),

  // ============================================
  // Physician Master Password System
  // ============================================

  // Stores the hashed master password for physician access
  physician_master_password: defineTable({
    password_hash: v.string(), // SHA256 hash of the master password
    created_at: v.number(),
    updated_at: v.number(),
    created_by: v.optional(v.string()), // Admin who set the password
  }),

  // Tracks active physician sessions (browser-based)
  physician_sessions: defineTable({
    session_token: v.string(), // Random UUID
    created_at: v.number(),
    expires_at: v.number(), // 24 hours from creation
    is_active: v.boolean(),
    ip_address: v.optional(v.string()),
    user_agent: v.optional(v.string()),
  })
    .index("by_session_token", ["session_token"])
    .index("by_active", ["is_active"]),

  // ============================================
  // Cross-Device Question Progress Tracking
  // ============================================

  // Tracks exact question progress for seamless cross-device sync
  questionnaire_session: defineTable({
    user_id: v.id("users"),
    day_number: v.number(),
    section: v.string(), // "sleepLog" or "assessment"
    current_question_index: v.number(), // 0-based index of current question
    total_questions: v.number(), // Total questions in this section
    started_at: v.number(),
    last_updated_at: v.number(),
    last_device: v.string(), // "ios", "watch", "web" - which device last updated
    completed: v.boolean(),
    completed_at: v.optional(v.number()),
  })
    .index("by_user", ["user_id"])
    .index("by_user_day", ["user_id", "day_number"])
    .index("by_user_day_section", ["user_id", "day_number", "section"]),

  // ============================================
  // Gamification System - "Strava for Sleep"
  // ============================================

  // User streaks - tracks daily engagement consistency
  user_streaks: defineTable({
    user_id: v.id("users"),
    current_streak: v.number(), // Current consecutive days
    longest_streak: v.number(), // Personal best
    last_activity_date: v.string(), // YYYY-MM-DD of last activity
    streak_frozen_until: v.optional(v.string()), // Date until streak freeze expires
    freeze_count_this_week: v.number(), // Freezes used this week (max 1)
    week_start_date: v.string(), // YYYY-MM-DD for freeze reset tracking
    total_days_completed: v.number(), // Lifetime count
    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"]),

  // Achievement badges
  user_badges: defineTable({
    user_id: v.id("users"),
    badge_id: v.string(), // e.g., "first_step", "week_warrior", "journey_master"
    badge_name: v.string(), // Display name
    badge_description: v.string(), // Description of how to earn
    badge_category: v.string(), // "journey", "quality", "clinical", "streak"
    badge_icon: v.string(), // Icon name or emoji
    earned_at: v.number(),
    // Progress tracking for in-progress badges
    progress_current: v.optional(v.number()),
    progress_target: v.optional(v.number()),
    is_earned: v.boolean(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_badge", ["user_id", "badge_id"])
    .index("by_category", ["badge_category"]),

  // Badge definitions (master list)
  badge_definitions: defineTable({
    badge_id: v.string(),
    name: v.string(),
    description: v.string(),
    category: v.string(), // "journey", "quality", "clinical", "streak"
    icon: v.string(),
    // Unlock conditions
    unlock_type: v.string(), // "day_complete", "streak_count", "assessment_complete", "behavior"
    unlock_threshold: v.optional(v.number()), // e.g., 7 for "7-day streak"
    unlock_condition_json: v.optional(v.string()), // Complex conditions as JSON
    // Rewards
    xp_reward: v.number(), // XP earned when badge unlocked
    // Display
    rarity: v.string(), // "common", "uncommon", "rare", "epic", "legendary"
    order_index: v.number(),
    is_active: v.boolean(),
    created_at: v.number(),
  })
    .index("by_badge_id", ["badge_id"])
    .index("by_category", ["category"])
    .index("by_rarity", ["rarity"]),

  // XP and level progression
  user_xp: defineTable({
    user_id: v.id("users"),
    total_xp: v.number(), // Lifetime XP
    current_level: v.number(), // 1-5 (Sleep Novice to Sleep Master)
    level_name: v.string(), // "Sleep Novice", "Sleep Student", etc.
    xp_to_next_level: v.number(), // XP needed for next level
    // Weekly XP for challenges
    weekly_xp: v.number(),
    week_start_date: v.string(), // YYYY-MM-DD
    // Breakdown tracking
    xp_from_logs: v.number(),
    xp_from_assessments: v.number(),
    xp_from_streaks: v.number(),
    xp_from_badges: v.number(),
    xp_from_challenges: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_level", ["current_level"]),

  // XP transaction log (for audit and display)
  xp_transactions: defineTable({
    user_id: v.id("users"),
    xp_amount: v.number(), // Positive for earned, negative for spent
    transaction_type: v.string(), // "sleep_log", "assessment", "streak_bonus", "badge_earned", "challenge_complete"
    description: v.string(), // Human-readable description
    reference_id: v.optional(v.string()), // ID of related entity (badge, challenge, etc.)
    created_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_date", ["user_id", "created_at"])
    .index("by_type", ["transaction_type"]),

  // Daily/weekly challenges
  user_challenges: defineTable({
    user_id: v.id("users"),
    challenge_id: v.string(), // e.g., "log_before_9am", "perfect_week"
    challenge_type: v.string(), // "daily", "weekly"
    challenge_name: v.string(),
    challenge_description: v.string(),
    xp_reward: v.number(),
    // Progress
    start_date: v.string(), // YYYY-MM-DD
    end_date: v.string(), // YYYY-MM-DD
    progress_current: v.number(),
    progress_target: v.number(),
    status: v.string(), // "active", "completed", "expired"
    completed_at: v.optional(v.number()),
    created_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_status", ["user_id", "status"])
    .index("by_user_type", ["user_id", "challenge_type"]),

  // Challenge definitions (master list)
  challenge_definitions: defineTable({
    challenge_id: v.string(),
    name: v.string(),
    description: v.string(),
    challenge_type: v.string(), // "daily", "weekly"
    // Requirements
    requirement_type: v.string(), // "log_time", "streak", "completion", "consistency"
    requirement_target: v.number(),
    requirement_config_json: v.optional(v.string()), // Additional config
    // Rewards
    xp_reward: v.number(),
    badge_reward_id: v.optional(v.string()), // Optional badge for challenge completion
    // Availability
    is_active: v.boolean(),
    day_of_week: v.optional(v.number()), // 0-6 for day-specific challenges
    created_at: v.number(),
  })
    .index("by_challenge_id", ["challenge_id"])
    .index("by_type", ["challenge_type"]),

  // ============================================
  // Micro-Cohort System - "People Like You"
  // Dynamic peer groups for personalized comparisons
  // ============================================

  // User's micro-cohort membership (recomputed when user data changes)
  user_cohort_memberships: defineTable({
    user_id: v.id("users"),
    cohort_hash: v.string(), // Hash of cohort dimensions for quick lookup
    // Cohort dimensions
    age_bracket: v.string(), // "20-30", "30-40", "40-50", "50-60", "60+"
    gender: v.optional(v.string()), // "male", "female", "other"
    life_stage: v.optional(v.string()), // "student", "early_career", "parent_young", "parent_teens", "empty_nest", "retired"
    work_pattern: v.optional(v.string()), // "9_to_5", "variable", "shift_work", "remote", "high_stress", "retired"
    primary_gateway: v.optional(v.string()), // Most significant gateway: "insomnia", "apnea", "anxiety", etc.
    chronotype: v.optional(v.string()), // "early_bird", "normal", "night_owl", "irregular"
    activity_level: v.optional(v.string()), // "low", "moderate", "high"
    family_situation: v.optional(v.string()), // "no_kids", "young_children", "teens", "adult_children"
    // Full dimension JSON for flexibility
    cohort_dimensions_json: v.string(), // Complete JSON of all dimensions
    // Cohort metadata
    cohort_size: v.number(), // Number of users in this cohort
    percentile_isi: v.optional(v.number()), // User's ISI percentile within cohort
    percentile_sleep_efficiency: v.optional(v.number()),
    percentile_sleep_duration: v.optional(v.number()),
    percentile_consistency: v.optional(v.number()),
    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_cohort_hash", ["cohort_hash"])
    .index("by_age_gender", ["age_bracket", "gender"])
    .index("by_gateway", ["primary_gateway"])
    .index("by_chronotype", ["chronotype"]),

  // Aggregate statistics for each cohort (computed nightly)
  cohort_aggregate_stats: defineTable({
    cohort_hash: v.string(), // Links to user_cohort_memberships.cohort_hash
    // Cohort identifiers (denormalized for queries)
    age_bracket: v.optional(v.string()),
    gender: v.optional(v.string()),
    primary_gateway: v.optional(v.string()),
    // Stat type and data
    stat_type: v.string(), // "isi_distribution", "sleep_efficiency", "improvement_rate", "intervention_success"
    stat_data_json: v.string(), // JSON with percentiles, averages, distributions
    sample_size: v.number(),
    // Quality metrics
    confidence_level: v.optional(v.number()), // Statistical confidence 0-100
    min_sample_size: v.optional(v.number()), // Minimum needed for valid stats
    // Timestamps
    computed_at: v.number(),
    expires_at: v.optional(v.number()), // When to recompute
  })
    .index("by_cohort_hash", ["cohort_hash"])
    .index("by_cohort_stat", ["cohort_hash", "stat_type"])
    .index("by_stat_type", ["stat_type"])
    .index("by_computed_at", ["computed_at"]),

  // User's personalized sleep narrative and phenotype
  user_sleep_narrative: defineTable({
    user_id: v.id("users"),
    // Sleep phenotype classification
    phenotype: v.string(), // "tired_but_wired", "compensator", "irregular_rhythm", "short_sleeper", etc.
    phenotype_confidence: v.number(), // 0-100 confidence in classification
    phenotype_description: v.string(), // Human-readable explanation of phenotype
    // Key patterns detected
    key_patterns_json: v.string(), // JSON array of detected patterns with evidence
    // Leverage points (what can help this user most)
    leverage_points_json: v.string(), // JSON array of intervention recommendations
    // Full narrative text
    narrative_title: v.string(), // e.g., "The Tired but Wired Sleeper"
    narrative_text: v.string(), // Full personalized narrative (2-3 paragraphs)
    narrative_highlights_json: v.optional(v.string()), // Key bullet points
    // Weekly evolution
    week_number: v.number(), // Which week of the journey this is for
    previous_narrative_id: v.optional(v.id("user_sleep_narrative")), // For tracking changes
    // What changed from last week
    changes_from_last_week_json: v.optional(v.string()),
    // Generation metadata
    data_points_used: v.number(), // How many data points contributed
    generated_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_week", ["user_id", "week_number"])
    .index("by_phenotype", ["phenotype"]),

  // Personalized insight queue for each user
  user_insight_queue: defineTable({
    user_id: v.id("users"),
    insight_id: v.string(), // Unique ID for this insight instance
    // Insight classification
    insight_type: v.string(), // "pattern", "comparison", "education", "prediction", "solidarity", "aha_moment"
    insight_category: v.string(), // "demographic", "gateway", "pattern", "cohort", "anticipation"
    // Content
    insight_title: v.string(), // Short title
    insight_text: v.string(), // Full insight text
    insight_data_json: v.optional(v.string()), // Supporting data (percentiles, comparisons, etc.)
    // Targeting - why this insight was chosen
    targeting_reason: v.string(), // Why this insight is relevant to this user
    targeting_criteria_json: v.optional(v.string()), // Criteria that matched
    // Evidence
    source_citation: v.optional(v.string()), // Scientific source
    evidence_level: v.optional(v.string()), // "strong", "moderate", "emerging"
    // Scoring and prioritization
    relevance_score: v.number(), // 0-100 how relevant to this user
    timeliness_score: v.optional(v.number()), // 0-100 how timely (temporal context)
    priority: v.number(), // Combined priority for display order
    // Display state
    shown: v.boolean(),
    shown_at: v.optional(v.number()),
    dismissed: v.optional(v.boolean()),
    dismissed_at: v.optional(v.number()),
    // User reaction
    reaction: v.optional(v.string()), // "helpful", "not_helpful", "surprising", "already_knew"
    reaction_at: v.optional(v.number()),
    // Lifecycle
    valid_from: v.number(), // When insight becomes relevant
    valid_until: v.optional(v.number()), // When insight expires
    created_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_shown", ["user_id", "shown"])
    .index("by_user_type", ["user_id", "insight_type"])
    .index("by_priority", ["user_id", "priority"])
    .index("by_valid_from", ["valid_from"]),

  // Intervention effectiveness by cohort
  cohort_intervention_effectiveness: defineTable({
    cohort_hash: v.string(),
    intervention_id: v.string(), // References interventions.intervention_id
    // Effectiveness metrics
    success_rate: v.number(), // 0-100 percentage of users who improved
    improvement_magnitude: v.optional(v.number()), // Average improvement (e.g., ISI point reduction)
    adherence_rate: v.optional(v.number()), // How many stuck with it
    // Time to effect
    avg_days_to_improvement: v.optional(v.number()),
    median_days_to_improvement: v.optional(v.number()),
    // Sample quality
    sample_size: v.number(),
    confidence_interval_low: v.optional(v.number()),
    confidence_interval_high: v.optional(v.number()),
    // Cohort context (denormalized)
    cohort_age_bracket: v.optional(v.string()),
    cohort_gender: v.optional(v.string()),
    cohort_gateway: v.optional(v.string()),
    // Ranking within cohort
    rank_in_cohort: v.optional(v.number()), // 1 = most effective for this cohort
    // Timestamps
    computed_at: v.number(),
    data_start_date: v.optional(v.string()), // Date range of data
    data_end_date: v.optional(v.string()),
  })
    .index("by_cohort", ["cohort_hash"])
    .index("by_intervention", ["intervention_id"])
    .index("by_cohort_intervention", ["cohort_hash", "intervention_id"])
    .index("by_success_rate", ["cohort_hash", "success_rate"]),

  // Anonymous solidarity moments ("You're not alone" real-time)
  solidarity_moments: defineTable({
    moment_type: v.string(), // "awake_now", "streak_milestone", "journey_complete", "improvement"
    // For "awake_now" - cached count
    awake_count: v.optional(v.number()),
    awake_count_updated_at: v.optional(v.number()),
    // For milestones - anonymous success stories
    milestone_type: v.optional(v.string()), // "30_day_streak", "first_improvement", "treatment_success"
    milestone_cohort_description: v.optional(v.string()), // "A 52-year-old father" (anonymized)
    milestone_achievement: v.optional(v.string()), // "hit 30-day streak after 3 years of insomnia"
    // For journey stats
    journeys_completed_this_month: v.optional(v.number()),
    improving_count: v.optional(v.number()),
    // Timing
    valid_for_minutes: v.number(), // How long this moment is valid (e.g., 5 mins for awake_now)
    computed_at: v.number(),
    expires_at: v.number(),
  })
    .index("by_moment_type", ["moment_type"])
    .index("by_expires", ["expires_at"]),

  // ============================================
  // Science-Backed Encouragement Library
  // ============================================

  // Evidence-based encouragement messages
  encouragement_messages: defineTable({
    message_id: v.string(), // Unique identifier
    message_text: v.string(), // The encouragement message
    short_text: v.optional(v.string()), // Shorter version for notifications
    // Targeting
    target_demographics_json: v.optional(v.string()), // JSON: {"gender": "female", "age_min": 45, "age_max": 55}
    target_gateways_json: v.optional(v.string()), // JSON array: ["insomnia", "anxiety"]
    target_scores_json: v.optional(v.string()), // JSON: {"ISI": {"min": 15, "max": 28}}
    target_behaviors_json: v.optional(v.string()), // JSON: {"late_chronotype": true}
    target_triggers_json: v.optional(v.string()), // JSON: {"question_id": "D1", "answer_pattern": "poor"}
    // Evidence
    source_citation: v.string(), // e.g., "Sleep Medicine Reviews, 2021"
    source_url: v.optional(v.string()),
    evidence_level: v.string(), // "strong", "moderate", "emerging"
    // Display
    category: v.string(), // "normalization", "encouragement", "education", "cohort_comparison"
    pillar: v.optional(v.string()), // Related sleep pillar
    display_context: v.string(), // "post_question", "section_complete", "day_complete", "insight"
    priority: v.number(), // Higher = more likely to show
    // Metadata
    is_active: v.boolean(),
    created_at: v.number(),
    updated_at: v.number(),
    reviewed_by: v.optional(v.string()), // Medical reviewer
    reviewed_at: v.optional(v.number()),
  })
    .index("by_message_id", ["message_id"])
    .index("by_category", ["category"])
    .index("by_context", ["display_context"])
    .index("by_pillar", ["pillar"]),

  // Cohort statistics for anonymous comparisons
  cohort_statistics: defineTable({
    stat_id: v.string(), // e.g., "isi_moderate_improvement_rate"
    stat_name: v.string(),
    stat_description: v.string(),
    // Filtering criteria
    cohort_criteria_json: v.string(), // JSON defining the cohort
    // Statistics
    sample_size: v.number(),
    stat_value: v.number(), // e.g., 0.80 for "80% improve"
    stat_type: v.string(), // "percentage", "average", "median"
    confidence_interval_low: v.optional(v.number()),
    confidence_interval_high: v.optional(v.number()),
    // Display
    display_format: v.string(), // e.g., "{{value}}% of users with similar patterns..."
    // Metadata
    computed_at: v.number(),
    data_source: v.string(), // "internal", "published_research"
    is_active: v.boolean(),
  })
    .index("by_stat_id", ["stat_id"]),

  // User encouragement history (what they've seen)
  user_encouragement_history: defineTable({
    user_id: v.id("users"),
    message_id: v.string(),
    shown_at: v.number(),
    context: v.string(), // Where it was shown
    dismissed: v.boolean(),
    reaction: v.optional(v.string()), // "helpful", "not_helpful", null
  })
    .index("by_user", ["user_id"])
    .index("by_user_message", ["user_id", "message_id"])
    .index("by_shown_at", ["shown_at"]),

  // ============================================
  // Patient Journey & Progressive Insights
  // Post-15-Day Treatment Experience
  // ============================================

  // Tracks patient's overall journey phase (intake → analysis → treatment)
  patient_journey_status: defineTable({
    user_id: v.id("users"),
    phase: v.string(), // "intake", "analysis", "treatment_pending", "treatment_active"
    intake_completed_at: v.optional(v.number()),
    // Analysis stage progression (1-4)
    analysis_stage: v.optional(v.number()), // 1=collected, 2=patterns, 3=preparing, 4=ready
    analysis_stage_updated_at: v.optional(v.number()),
    // Treatment activation
    treatment_activated_at: v.optional(v.number()),
    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_phase", ["phase"]),

  // Tracks physician's analysis workflow per patient (findings, notes, prerequisites)
  patient_analysis_workflow: defineTable({
    user_id: v.id("users"),
    physician_id: v.optional(v.string()), // Who is reviewing
    // Stage 2: Patterns Identified - What was found
    patterns_identified_json: v.optional(v.string()), // JSON array of identified patterns
    primary_sleep_issues_json: v.optional(v.string()), // JSON array of main issues
    triggered_gateways_json: v.optional(v.string()), // JSON array of gateways triggered
    risk_factors_json: v.optional(v.string()), // JSON array of risk factors
    // Stage 2 checklist - what physician reviewed
    reviewed_sleep_data: v.optional(v.boolean()),
    reviewed_questionnaire_scores: v.optional(v.boolean()),
    reviewed_gateway_triggers: v.optional(v.boolean()),
    ran_ai_analysis: v.optional(v.boolean()),
    patterns_notes: v.optional(v.string()), // Free-form notes for stage 2
    patterns_completed_at: v.optional(v.number()),
    // Stage 3: Recommendations Preparing
    recommended_interventions_json: v.optional(v.string()), // JSON array of intervention IDs
    treatment_approach: v.optional(v.string()), // e.g., "CBT-I focused", "CPAP + behavioral"
    estimated_duration_weeks: v.optional(v.number()),
    recommendations_notes: v.optional(v.string()), // Free-form notes for stage 3
    recommendations_completed_at: v.optional(v.number()),
    // Stage 4: Treatment Plan Ready
    plan_summary: v.optional(v.string()), // High-level summary for patient
    special_considerations: v.optional(v.string()), // Any special notes
    ready_for_patient: v.optional(v.boolean()),
    final_review_notes: v.optional(v.string()),
    treatment_ready_at: v.optional(v.number()),
    // Timestamps
    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_physician", ["physician_id"]),

  // Progressive insight teaser definitions
  insight_teasers: defineTable({
    teaser_id: v.string(), // e.g., "sleep_efficiency_trend", "wake_pattern"
    unlock_day: v.number(), // Day when insight becomes available
    unlock_data_points: v.optional(v.number()), // Alternative: unlock after N data points
    teaser_type: v.string(), // "countdown" | "discovery"
    title: v.string(), // "Sleep Efficiency Trend"
    locked_description: v.string(), // Shown before unlock: "3 more nights to detect your rhythm"
    unlocked_description: v.optional(v.string()), // Full insight text when unlocked
    // Discovery hints (progressive hints as data builds)
    discovery_hints_json: v.optional(v.string()), // JSON array of hint levels
    // Categorization
    category: v.string(), // "efficiency", "timing", "quality", "pattern"
    icon: v.string(), // SF Symbol name
    color: v.optional(v.string()), // Hex color for UI
    order_index: v.number(),
    is_active: v.boolean(),
    created_at: v.number(),
  })
    .index("by_teaser_id", ["teaser_id"])
    .index("by_unlock_day", ["unlock_day"])
    .index("by_category", ["category"]),

  // User's progress toward unlocking insights
  user_insight_progress: defineTable({
    user_id: v.id("users"),
    teaser_id: v.string(), // References insight_teasers.teaser_id
    unlocked: v.boolean(),
    unlocked_at: v.optional(v.number()),
    data_points_collected: v.number(), // How many data points contributed
    discovery_hint_level: v.number(), // 0-3 for progressive hints
    last_hint_shown_at: v.optional(v.number()),
    // Insight data when unlocked
    insight_value_json: v.optional(v.string()), // JSON with computed insight data
    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_teaser", ["user_id", "teaser_id"])
    .index("by_unlocked", ["unlocked"]),

  // Time window definitions for treatment tasks
  task_time_windows: defineTable({
    window_id: v.string(), // "morning", "afternoon", "evening", "night"
    name: v.string(), // "Morning"
    description: v.optional(v.string()), // "5 AM - 12 PM"
    icon: v.string(), // SF Symbol name
    color: v.string(), // Hex color
    start_hour: v.number(), // 5 for 5 AM
    end_hour: v.number(), // 12 for noon
    order_index: v.number(),
  })
    .index("by_window_id", ["window_id"]),

  // ============================================
  // System Settings
  // Global configuration for AI analysis and other system-wide settings
  // ============================================

  system_settings: defineTable({
    key: v.string(), // Setting key (e.g., "llm_primary_model", "llm_anthropic_key")
    value: v.string(), // Setting value (API keys stored encrypted)
    category: v.string(), // "llm", "notifications", "features"
    description: v.optional(v.string()), // Human-readable description
    is_secret: v.boolean(), // True for API keys and sensitive data
    updated_at: v.number(),
    updated_by: v.optional(v.string()), // User ID or "system"
  })
    .index("by_key", ["key"])
    .index("by_category", ["category"]),
});

