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
    oauth_provider: v.optional(v.union(v.literal("google"), v.literal("apple"))),
    oauth_id: v.optional(v.string()), // External OAuth user ID
    profile_picture: v.optional(v.string()),
  })
    .index("by_username", ["username"])
    .index("by_email", ["email"])
    .index("by_role", ["role"])
    .index("by_onboarding", ["onboarding_completed", "current_day"])
    .index("by_oauth", ["oauth_provider", "oauth_id"])
    .index("by_verification_token", ["email_verification_token"])
    .index("by_reset_token", ["password_reset_token"]),

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
    checkin_type: v.union(v.literal("morning"), v.literal("evening")),
    completed: v.boolean(),
    completed_at: v.optional(v.number()),
    data_json: v.optional(v.string()), // JSON string
    created_at: v.number(),
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
    created_at: v.number(),
    updated_at: v.number(),
  })
    .index("by_user", ["user_id"])
    .index("by_user_question", ["user_id", "question_id"])
    .index("by_user_day", ["user_id", "day_number"])
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
});

