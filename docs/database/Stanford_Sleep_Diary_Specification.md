# Stanford Sleep Health and Insomnia Program: Two Week Sleep Diary

**Source**: Adapted from the American Academy of Sleep Medicine

---

## Overview

This is a 2-week sleep diary that captures detailed sleep patterns using a visual timeline format. The diary tracks sleep/wake times, medication use, and sleep periods across 24-hour periods for 14 consecutive days.

---

## Instructions for Users

1. **Date Information**: Write the date, day of the week, and type of day (Work, School, Day Off, or Vacation)
2. **Medication Tracking**: Put the letter "M" in the box when you take any relevant medication
3. **Bed Times**: Put a line (|) to show when you got into bed and a line when you got out of bed in the morning
4. **Sleep Intention**: Put a down arrow (↓) when you start intending to sleep and an up arrow (↑) when you got up (woke up and no longer intended to sleep)
5. **Sleep Periods**: Shade in the box that shows when you think you fell asleep and shade in all the boxes that show when you are asleep
6. **Wake Periods**: Leave boxes unshaded to show when you wake up at night & when you are awake during the day. If you were asleep for a portion of an hour, you can shade a portion of a box

---

## Diary Structure

### Time Grid Layout

The diary uses a 24-hour grid format with the following columns:

**Column Headers** (repeated for each day):
- Today's Date
- Day of the week (Mon, Tue, Wed, Thu, Fri, Sat, Sun)
- Type of Day (Work, School, Day Off, Vacation)
- Noon
- 1PM
- 2
- 3
- 4
- 5
- 6PM
- 7
- 8
- 9
- 10
- 11PM
- Midnight
- 1AM
- 2
- 3
- 4
- 5
- 6AM
- 7
- 8
- 9
- 10
- 11AM

### Format
- **Week 1**: 7 rows (one per day)
- **Week 2**: 7 rows (one per day)
- Each row represents a full 24-hour period from noon to noon

---

## Data Points to Extract for Digital Implementation

### Daily Metadata
```json
{
  "date": "YYYY-MM-DD",
  "day_of_week": "Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday",
  "day_type": "Work|School|Day Off|Vacation"
}
```

### Sleep/Wake Events
```json
{
  "got_into_bed_time": "HH:MM",
  "lights_out_time": "HH:MM",
  "sleep_onset_time": "HH:MM",
  "final_wake_time": "HH:MM",
  "out_of_bed_time": "HH:MM"
}
```

### Medication Tracking
```json
{
  "medication_taken": true|false,
  "medication_time": "HH:MM"
}
```

### Sleep Periods
```json
{
  "sleep_periods": [
    {
      "start_time": "HH:MM",
      "end_time": "HH:MM",
      "type": "main_sleep|nap"
    }
  ],
  "wake_periods": [
    {
      "start_time": "HH:MM",
      "end_time": "HH:MM",
      "duration_minutes": number
    }
  ]
}
```

---

## Digital Questions to Replace Visual Diary

### Daily Morning Questions (completed upon waking)

**Q1. Date and Day Information**
- What is today's date?
  - *Type*: Date picker
  - *Field*: `date`

- What day of the week is it?
  - *Type*: Auto-calculated from date
  - *Field*: `day_of_week`

- What type of day is today?
  - *Type*: Multiple choice
  - *Options*: Work, School, Day Off, Vacation
  - *Field*: `day_type`

**Q2. Medication Tracking**
- Did you take any sleep-related medication yesterday or last night?
  - *Type*: Yes/No
  - *Field*: `medication_taken`

- If yes, what time did you take it?
  - *Type*: Time picker
  - *Field*: `medication_time`
  - *Conditional*: Only if medication_taken = Yes

**Q3. Bedtime Routine**
- What time did you get into bed last night?
  - *Type*: Time picker
  - *Field*: `got_into_bed_time`
  - *Helper text*: "When you physically got into bed, not necessarily trying to sleep"

- What time did you turn off the lights and try to sleep?
  - *Type*: Time picker
  - *Field*: `lights_out_time`
  - *Helper text*: "When you started trying to fall asleep"

**Q4. Sleep Onset**
- What time do you think you fell asleep?
  - *Type*: Time picker
  - *Field*: `sleep_onset_time`
  - *Helper text*: "Your best estimate of when you actually fell asleep"

- How long did it take you to fall asleep? (minutes)
  - *Type*: Number input
  - *Field*: `sleep_latency_minutes`
  - *Auto-calculated*: lights_out_time - sleep_onset_time
  - *Allow manual override*: Yes

**Q5. Night Awakenings**
- How many times did you wake up during the night?
  - *Type*: Number input (0-20)
  - *Field*: `number_of_awakenings`

- If you woke up, approximately how much total time were you awake during the night? (minutes)
  - *Type*: Number input
  - *Field*: `total_wake_time_minutes`
  - *Conditional*: Only if number_of_awakenings > 0

**Q6. Morning Wake Time**
- What time did you wake up for the final time this morning?
  - *Type*: Time picker
  - *Field*: `final_wake_time`
  - *Helper text*: "The last time you woke up and decided to get up for the day"

- What time did you get out of bed this morning?
  - *Type*: Time picker
  - *Field*: `out_of_bed_time`
  - *Helper text*: "When you physically got out of bed"

**Q7. Sleep Quality**
- How would you rate the quality of your sleep last night?
  - *Type*: Scale (1-5)
  - *Options*: 1=Very Poor, 2=Poor, 3=Fair, 4=Good, 5=Very Good
  - *Field*: `sleep_quality_rating`

**Q8. Naps (Optional)**
- Did you take any naps yesterday?
  - *Type*: Yes/No
  - *Field*: `naps_taken`

- If yes, how many naps?
  - *Type*: Number input (1-5)
  - *Field*: `number_of_naps`
  - *Conditional*: Only if naps_taken = Yes

- For each nap, what time did it start and how long was it?
  - *Type*: Repeating time picker + duration
  - *Fields*: `nap_start_time[]`, `nap_duration_minutes[]`
  - *Conditional*: Only if naps_taken = Yes

---

## Calculated Metrics (Derived from Questions)

These metrics should be automatically calculated by the system:

```javascript
{
  // Total Time in Bed (TIB)
  "time_in_bed_minutes": out_of_bed_time - got_into_bed_time,
  
  // Total Sleep Time (TST)
  "total_sleep_time_minutes": time_in_bed_minutes - sleep_latency_minutes - total_wake_time_minutes,
  
  // Sleep Efficiency (SE)
  "sleep_efficiency_percent": (total_sleep_time_minutes / time_in_bed_minutes) * 100,
  
  // Wake After Sleep Onset (WASO)
  "waso_minutes": total_wake_time_minutes,
  
  // Sleep Onset Latency (SOL)
  "sleep_onset_latency_minutes": sleep_latency_minutes,
  
  // Time in bed before sleep
  "time_in_bed_before_sleep_minutes": got_into_bed_time - lights_out_time,
  
  // Time in bed after wake
  "time_in_bed_after_wake_minutes": out_of_bed_time - final_wake_time
}
```

---

## Data Validation Rules

1. **Time Logic**:
   - `got_into_bed_time` ≤ `lights_out_time` ≤ `sleep_onset_time` < `final_wake_time` ≤ `out_of_bed_time`
   - If times cross midnight, handle 24-hour wraparound

2. **Duration Constraints**:
   - `sleep_latency_minutes`: 0-240 minutes (warn if >60 minutes)
   - `total_sleep_time_minutes`: 60-960 minutes (1-16 hours)
   - `total_wake_time_minutes`: 0-480 minutes
   - `time_in_bed_minutes`: 120-960 minutes (2-16 hours)

3. **Quality Checks**:
   - Sleep efficiency should be 0-100%
   - If sleep efficiency < 50%, flag for review
   - If sleep latency > 60 minutes, flag for insomnia screening

---

## Alternative: Evening Questions (Optional Pre-Sleep Assessment)

Some implementations split the diary into evening and morning questions:

### Evening Questions (before bed)

**E1. Today's Activity**
- What type of day was today?
  - Work, School, Day Off, Vacation

**E2. Daytime Naps**
- Did you nap today?
  - If yes: Start time(s) and duration(s)

**E3. Evening Medication**
- Did you take any sleep medication tonight?
  - If yes: What time?

**E4. Caffeine/Alcohol**
- Did you consume caffeine after 2pm?
  - If yes: What time and how much?
- Did you consume alcohol this evening?
  - If yes: Number of drinks and time of last drink

### Morning Questions
(Same as listed above in main section)

---

## Mobile App Implementation Considerations

### User Experience
1. **Push Notification Timing**:
   - Morning reminder: 30 minutes after typical wake time
   - Evening reminder (if using split format): 30 minutes before typical bedtime

2. **Smart Defaults**:
   - Pre-fill times based on previous entries
   - Suggest typical values for that day of week

3. **Quick Entry Mode**:
   - Allow simple "Same as yesterday" option for routine nights
   - Still require confirmation of key metrics

4. **Visual Feedback**:
   - Show calculated sleep efficiency immediately
   - Display trend graphs for past week
   - Highlight concerning patterns (low efficiency, long latency)

### Data Storage Schema

```sql
CREATE TABLE sleep_diary_entries (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    date DATE NOT NULL,
    day_of_week VARCHAR(10),
    day_type VARCHAR(20),
    
    -- Medication
    medication_taken BOOLEAN,
    medication_time TIME,
    
    -- Bedtime
    got_into_bed_time TIME,
    lights_out_time TIME,
    sleep_onset_time TIME,
    sleep_latency_minutes INTEGER,
    
    -- Night awakenings
    number_of_awakenings INTEGER,
    total_wake_time_minutes INTEGER,
    
    -- Morning
    final_wake_time TIME,
    out_of_bed_time TIME,
    sleep_quality_rating INTEGER,
    
    -- Naps
    naps_taken BOOLEAN,
    number_of_naps INTEGER,
    nap_details JSONB,
    
    -- Calculated metrics
    time_in_bed_minutes INTEGER,
    total_sleep_time_minutes INTEGER,
    sleep_efficiency_percent DECIMAL(5,2),
    waso_minutes INTEGER,
    
    -- Metadata
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    
    UNIQUE(user_id, date)
);
```

---

## Integration with Sleep 360° Framework

### Mapping to Sleep 360° Pillars

This sleep diary data maps to the following Sleep 360° pillars:

1. **Sleep Quantity** (Pillar 2)
   - Total sleep time
   - Time in bed
   - Nap duration

2. **Sleep Quality** (Pillar 1)
   - Sleep efficiency
   - Number of awakenings
   - WASO
   - Sleep quality rating

3. **Sleep Regularity** (Pillar 3)
   - Consistency of bedtime across days
   - Consistency of wake time across days
   - Weekday vs weekend patterns

4. **Sleep Timing** (Pillar 4)
   - Bedtime
   - Wake time
   - Midpoint of sleep
   - Social jetlag (weekday vs weekend difference)

5. **Nutritional** (Pillar 9)
   - Caffeine timing (if tracked)
   - Alcohol consumption (if tracked)

### Derived Sleep Regularity Metrics (from 2-week diary)

```javascript
// Calculate from all 14 days of data
{
  "bedtime_variability_minutes": standardDeviation(lights_out_time_array),
  "wake_time_variability_minutes": standardDeviation(final_wake_time_array),
  "sleep_duration_variability_minutes": standardDeviation(total_sleep_time_array),
  
  "weekday_avg_bedtime": average(weekday_lights_out_times),
  "weekend_avg_bedtime": average(weekend_lights_out_times),
  "social_jetlag_minutes": abs(weekday_sleep_midpoint - weekend_sleep_midpoint),
  
  "average_sleep_efficiency": average(sleep_efficiency_array),
  "average_sleep_latency": average(sleep_latency_array),
  "average_waso": average(waso_array)
}
```

---

## Example JSON Output (Single Day Entry)

```json
{
  "sleep_diary_entry": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "date": "2025-01-15",
    "day_of_week": "Wednesday",
    "day_type": "Work",
    
    "medication": {
      "taken": true,
      "time": "22:30"
    },
    
    "bedtime": {
      "got_into_bed": "22:45",
      "lights_out": "23:00",
      "fell_asleep": "23:25",
      "sleep_latency_minutes": 25
    },
    
    "night_awakenings": {
      "count": 2,
      "total_wake_time_minutes": 15
    },
    
    "morning": {
      "final_wake": "06:30",
      "out_of_bed": "06:45",
      "sleep_quality_rating": 3
    },
    
    "naps": {
      "taken": false,
      "count": 0,
      "details": []
    },
    
    "calculated_metrics": {
      "time_in_bed_minutes": 480,
      "total_sleep_time_minutes": 440,
      "sleep_efficiency_percent": 91.67,
      "waso_minutes": 15,
      "sleep_onset_latency_minutes": 25
    },
    
    "metadata": {
      "created_at": "2025-01-16T06:50:00Z",
      "updated_at": "2025-01-16T06:50:00Z",
      "completion_time_seconds": 142,
      "entry_method": "mobile_app"
    }
  }
}
```

---

## Implementation Checklist for Coding Agent

- [ ] Create database schema for sleep diary entries
- [ ] Build morning questionnaire flow with 8 core questions
- [ ] Implement time validation logic (handle midnight crossover)
- [ ] Calculate derived metrics automatically (TST, SE, WASO, SOL)
- [ ] Add data quality checks and warnings
- [ ] Create 14-day view/summary dashboard
- [ ] Implement CSV/PDF export for clinical use
- [ ] Build visualization: sleep timeline graph (similar to original visual diary)
- [ ] Add comparison to Sleep 360° CORE questions (detect discrepancies)
- [ ] Set up push notifications for daily completion reminders
- [ ] Implement "smart defaults" based on user patterns
- [ ] Create weekly summary report with trends
- [ ] Build integration with Sleep 360° pillar metrics
- [ ] Add social jetlag calculation (weekday vs weekend)
- [ ] Implement sleep regularity index calculation

---

*This specification converts the Stanford 2-week visual sleep diary into a structured digital format compatible with the Sleep 360° framework and suitable for automated coding implementation.*
