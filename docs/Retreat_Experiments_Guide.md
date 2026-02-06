# Zoe Sleep Retreat: 10 Ad Hoc Experiments
## Half Moon Bay Longevity Retreat | 2-3 Day Protocol

---

## Overview

**Purpose:** Run live, ad hoc experiments with 30 participants during the retreat without requiring pre-existing Zoe journey data. Each experiment uses group-based assignments delivered via the app to test physiological and lifestyle interventions.

**Key Constraints:**
- 2-3 days maximum (not 10 days)
- Minimal pre-retreat data dependency
- Group-based (A/B/C assignments)
- App-delivered protocols
- Immediate measurable outcomes

---

# Experiment 1: The Temperature Sweet Spot

## Concept
Test optimal sleep temperature by assigning participants to different room temperature zones.

## Group Assignment
```
┌─────────────────────────────────────────────────────────┐
│                    30 PARTICIPANTS                       │
└──────────────┬─────────────┬────────────────────────────┘
               │             │
        ┌──────▼──────┐ ┌───▼──────┐ ┌──────────▼────────┐
        │  GROUP A    │ │ GROUP B  │ │    GROUP C        │
        │   (n=10)    │ │  (n=10)  │ │     (n=10)        │
        │   COOL      │ │   WARM   │ │      HOT          │
        │   66°F      │ │   70°F   │ │     74°F          │
        └─────────────┘ └──────────┘ └───────────────────┘
```

## Experimental Flow

```
DAY 1 (Arrival Day)
├─ 3:00 PM → Martin assigns groups via app
├─ 4:00 PM → Participants receive temperature assignment notification
├─ 6:00 PM → Dinner + instruction session
│            "Tonight, set your room to assigned temperature"
├─ 10:00 PM → Evening check-in: Confirm room temp set correctly
└─ NIGHT 1 → Sleep at assigned temperature

DAY 2 (Morning)
├─ 7:00 AM → Wake up
├─ 7:30 AM → Complete sleep log in app:
│            - Sleep quality (1-10)
│            - Minutes to fall asleep
│            - Number of awakenings
│            - Thermal comfort (1-5: too cold → too hot)
└─ 9:00 AM → Breakfast + preliminary results discussion

DAY 2 (Evening Session)
├─ 5:00 PM → Martin presents aggregate findings
│            Show which group had best sleep quality
├─ 6:00 PM → SWITCH: All groups try optimal temperature (66-68°F)
└─ NIGHT 2 → Sleep at optimal temperature

DAY 3 (Morning)
├─ 7:00 AM → Wake up
├─ 7:30 AM → Complete sleep log again
└─ 9:00 AM → Final results: Individual improvement shown
```

## Martin's Preparation

### Pre-Retreat (1 week before)
- [ ] Coordinate with Ritz-Carlton: Ensure all rooms have individual climate control
- [ ] Request room thermometers for each room (or confirm digital thermostat accuracy)
- [ ] Create group assignments in app (randomized, stratified by age/gender)
- [ ] Prepare push notification templates

### Day 1 (Arrival)
- [ ] 3:00 PM: Assign groups via app intervention system
- [ ] 4:00 PM: Send push notification with temperature assignment
- [ ] 6:00 PM: Brief participants during dinner (5-min explanation)
- [ ] 10:00 PM: Monitor check-in completion (ensure 80%+ compliance)

### Day 2 (Morning)
- [ ] 8:00 AM: Pull sleep log data from Convex
- [ ] 8:30 AM: Generate aggregate charts (avg quality by group)
- [ ] 9:00 AM: Present preliminary findings at breakfast

### Day 2 (Evening)
- [ ] 5:00 PM: Present full analysis with visualizations
- [ ] 6:00 PM: Send new assignment (all groups → 66-68°F)

### Day 3 (Morning)
- [ ] 8:00 AM: Pull Night 2 sleep log data
- [ ] 8:30 AM: Generate before/after individual improvement charts
- [ ] 9:00 AM: Share personalized insights with each participant

## Participant's Job

### Day 1 Evening
1. Check app at 4:00 PM for temperature assignment
2. Set room thermostat to assigned temperature by 10:00 PM
3. Complete evening check-in confirming temperature set
4. Sleep through the night (do not adjust temperature)

### Day 2 Morning
1. Complete sleep log immediately upon waking:
   - Rate sleep quality
   - Estimate time to fall asleep
   - Count awakenings
   - Rate thermal comfort

### Day 2 Evening
1. Attend results session (5:00 PM)
2. Receive new assignment (optimal temp)
3. Set room to 66-68°F by 10:00 PM

### Day 3 Morning
1. Complete sleep log again
2. View personal before/after comparison in app

## Data Collection Points

| Time | Data Point | Source | Format |
|------|------------|--------|--------|
| Day 1, 10 PM | Room temperature set | Evening check-in | Manual entry (°F) |
| Day 1, 10 PM | Thermal comfort baseline | Evening check-in | 1-5 scale |
| Day 2, 7:30 AM | Sleep quality | Sleep log | 1-10 scale |
| Day 2, 7:30 AM | Sleep latency | Sleep log | Minutes (numeric) |
| Day 2, 7:30 AM | Awakenings | Sleep log | Count (numeric) |
| Day 2, 7:30 AM | Thermal comfort | Sleep log | 1-5 scale |
| Day 2, 7:30 AM | Sleep efficiency | HealthKit (optional) | Percentage |
| Day 3, 7:30 AM | All above repeated | Sleep log | Same formats |

## Expected Outcomes

### Hypothesis
Participants sleeping at 66-68°F (Group A) will report:
- Higher sleep quality (+1.5 points on 1-10 scale)
- Faster sleep onset (-8 minutes average)
- Fewer awakenings (-1.2 awakenings)
- Better thermal comfort (3/5 "just right")

### Outcome Visualization

```
NIGHT 1 RESULTS (Group Comparison)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sleep Quality (1-10 scale)

Group A (66°F)  ████████████████████ 8.2
Group B (70°F)  ████████████████░░░░ 7.1
Group C (74°F)  ██████████████░░░░░░ 6.4

Sleep Latency (minutes)
Group A (66°F)  ██████████░░░░░░░░░░ 14 min
Group B (70°F)  ████████████░░░░░░░░ 18 min
Group C (74°F)  ███████████████░░░░░ 23 min
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

NIGHT 2 RESULTS (Individual Improvement)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Participants who switched TO optimal (66-68°F):

Group B (70°F → 67°F): +0.8 sleep quality improvement
Group C (74°F → 67°F): +1.6 sleep quality improvement

Group A (stayed at 66°F): +0.1 (control, minimal change)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Key Insights Delivered
1. **Personal optimal:** "You sleep best at 66-68°F"
2. **Quantified impact:** "Switching from 74°F to 67°F improved your sleep quality by 1.6 points"
3. **Actionable takeaway:** "Set your home thermostat to 66-68°F for better sleep"

---

# Experiment 2: Morning Light Exposure Race

## Concept
Test impact of morning light timing on energy and mood by assigning different outdoor exposure windows.

## Group Assignment
```
┌─────────────────────────────────────────────────────────┐
│                    30 PARTICIPANTS                       │
└──────────┬─────────────┬─────────────────────────────────┘
           │             │
    ┌──────▼──────┐ ┌───▼──────┐ ┌──────────▼────────────┐
    │  GROUP A    │ │ GROUP B  │ │    GROUP C            │
    │   (n=10)    │ │  (n=10)  │ │     (n=10)            │
    │ EARLY LIGHT │ │LATE LIGHT│ │ NO INTERVENTION       │
    │ 7:00-7:30AM │ │9:00-9:30AM│ │  (Control)           │
    │ 30min walk  │ │ 30min walk│ │  Indoor morning      │
    └─────────────┘ └──────────┘ └───────────────────────┘
```

## Experimental Flow

```
DAY 1 (Evening)
├─ 6:00 PM → Martin assigns groups via app
├─ 6:30 PM → Participants receive morning walk assignment
└─ 9:00 PM → Reminder notification sent

DAY 2 (Morning - INTERVENTION DAY)
├─ 6:45 AM → Group A wakes up for 7 AM walk
├─ 7:00 AM → Group A: Guided beach walk (30 min)
│            App tracks: Start time, duration, outdoor location (GPS)
├─ 8:45 AM → Group B wakes up for 9 AM walk
├─ 9:00 AM → Group B: Guided beach walk (30 min)
│
├─ 7:30 AM → Group C: Indoor morning (breakfast, reading)
│            No outdoor exposure before 10 AM
│
├─ 10:00 AM → ALL GROUPS: Complete morning check-in
│             - Energy level (1-6)
│             - Mood (1-6)
│             - Focus (1-5)
│             - Minutes of outdoor light exposure (auto-tracked + manual confirm)
└─ 12:00 PM → Midday check-in: Energy, caffeine intake

DAY 2 (Evening)
├─ 6:00 PM → Evening check-in: How did you feel today?
└─ NIGHT 2 → Sleep log next morning

DAY 3 (Morning)
├─ 7:30 AM → Sleep log: Sleep quality, latency
└─ 9:00 AM → Results presentation: Light exposure → next-day energy correlation
```

## Martin's Preparation

### Pre-Retreat
- [ ] Scout optimal beach walk route (30-min loop, accessible, scenic)
- [ ] Create group assignments (randomized, balanced by age)
- [ ] Prepare walk leader guide (or lead yourself)
- [ ] Ensure app tracks outdoor time via HealthKit outdoor workouts

### Day 1 (Evening)
- [ ] 6:00 PM: Assign groups in app
- [ ] 6:30 PM: Send push notifications with walk time assignments
- [ ] Explain circadian science during dinner (5-min talk)

### Day 2 (Morning)
- [ ] 6:45 AM: Meet Group A at lobby for 7 AM walk
- [ ] 7:00-7:30 AM: Lead Group A walk, ensure phones track activity
- [ ] 8:45 AM: Meet Group B at lobby for 9 AM walk
- [ ] 9:00-9:30 AM: Lead Group B walk
- [ ] 10:00 AM: Monitor check-in completion

### Day 2 (Evening)
- [ ] 5:00 PM: Pull check-in data (energy/mood/focus scores)
- [ ] Generate preliminary correlation charts

### Day 3 (Morning)
- [ ] 8:00 AM: Pull sleep log data from Night 2
- [ ] Analyze: Morning light Day 2 → Sleep quality Night 2
- [ ] 9:00 AM: Present findings

## Participant's Job

### Day 1 Evening
1. Check app for morning walk assignment
2. Set alarm according to group (6:45 AM for A, 8:45 AM for B, normal for C)
3. Prepare walking shoes/clothes

### Day 2 Morning (Group A)
1. Wake at 6:45 AM
2. Meet at lobby at 7:00 AM
3. Complete 30-min guided beach walk
4. At 10:00 AM: Complete morning check-in (energy/mood/focus)

### Day 2 Morning (Group B)
1. Wake at 8:45 AM (stay indoors until then)
2. Meet at lobby at 9:00 AM
3. Complete 30-min guided beach walk
4. At 10:00 AM: Complete morning check-in (energy/mood/focus)

### Day 2 Morning (Group C - Control)
1. Wake at normal time
2. Stay indoors until 10:00 AM (breakfast, reading, indoor activities)
3. At 10:00 AM: Complete morning check-in (energy/mood/focus)

### Day 2 (Throughout Day)
1. 12:00 PM: Complete midday check-in
2. 6:00 PM: Complete evening check-in

### Day 3 Morning
1. Complete sleep log
2. View personal results in app

## Data Collection Points

| Time | Data Point | Source | Format |
|------|------------|--------|--------|
| Day 2, 7:00-9:30 AM | Outdoor time (min) | HealthKit + manual | Numeric (minutes) |
| Day 2, 7:00-9:30 AM | Walk completion | App GPS tracking | Boolean (yes/no) |
| Day 2, 10:00 AM | Energy level | Morning check-in | 1-6 scale |
| Day 2, 10:00 AM | Mood | Morning check-in | 1-6 scale |
| Day 2, 10:00 AM | Focus | Morning check-in | 1-5 scale |
| Day 2, 12:00 PM | Midday energy | Midday check-in | 1-4 scale |
| Day 2, 6:00 PM | Evening energy | Evening check-in | 1-5 scale |
| Day 3, 7:30 AM | Sleep quality | Sleep log | 1-10 scale |
| Day 3, 7:30 AM | Sleep latency | Sleep log | Minutes |

## Expected Outcomes

### Hypothesis
Group A (7 AM light) will show:
- Highest 10 AM energy scores (+1.2 points vs control)
- Best mood ratings (+0.9 points vs control)
- Best next-day sleep quality (+0.8 points)

Group B (9 AM light) will show:
- Moderate energy improvement (+0.6 points vs control)
- Moderate mood improvement (+0.5 points vs control)

Group C (no intervention) will show:
- Lower energy/mood scores
- Baseline sleep quality

### Outcome Visualization

```
MORNING ENERGY LEVELS (Day 2, 10:00 AM)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Energy (1-6 scale, measured at 10 AM)

Group A (7AM light)   ████████████████████░ 5.1
Group B (9AM light)   ███████████████░░░░░░ 4.4
Group C (No exposure) ████████████░░░░░░░░░ 3.8

NEXT-DAY SLEEP QUALITY (Night 2)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sleep Quality (1-10 scale)

Group A (7AM light)   ████████████████████░ 8.3
Group B (9AM light)   ██████████████████░░░ 7.7
Group C (No exposure) ████████████████░░░░░ 7.2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

LIGHT EXPOSURE → ENERGY CORRELATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
10 AM Energy Score
    6 │                              ●
      │                          ●
    5 │                      ●
      │                  ●
    4 │              ●
      │          ●
    3 │      ●
      │  ●
    2 └──────────────────────────────
      7AM    8AM    9AM   10AM  11AM
           Light Exposure Time

Correlation: r = 0.76 (strong positive)
Early light → Higher energy
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Key Insights Delivered
1. **Optimal window:** "Getting outdoor light before 8 AM boosted your energy by 35%"
2. **Circadian impact:** "Early light improved your next-night sleep quality by 0.8 points"
3. **Actionable takeaway:** "Aim for 30 minutes of outdoor light within 2 hours of waking"

---

# Experiment 3: Caffeine Cutoff Challenge

## Concept
Test personal caffeine sensitivity by assigning different cutoff times and measuring sleep impact.

## Group Assignment
```
┌─────────────────────────────────────────────────────────┐
│                    30 PARTICIPANTS                       │
└──────────┬─────────────┬─────────────────────────────────┘
           │             │
    ┌──────▼──────┐ ┌───▼──────┐ ┌──────────▼────────────┐
    │  GROUP A    │ │ GROUP B  │ │    GROUP C            │
    │   (n=10)    │ │  (n=10)  │ │     (n=10)            │
    │ STRICT      │ │ MODERATE │ │   CONTROL             │
    │ No caffeine │ │No caffeine│ │ Normal caffeine       │
    │ after 12PM  │ │ after 2PM│ │  intake               │
    └─────────────┘ └──────────┘ └───────────────────────┘
```

## Experimental Flow

```
DAY 1 (Baseline)
├─ 9:00 AM → Breakfast + caffeine consumed (tracked)
├─ 12:00 PM → Midday check-in: Log caffeine intake
├─ 6:00 PM → Evening session: Martin assigns groups
│            "Tomorrow, follow your caffeine cutoff"
└─ NIGHT 1 → Sleep (baseline measurement)

DAY 2 (Intervention Day)
├─ 7:30 AM → Complete sleep log for Night 1 (baseline)
├─ 9:00 AM → Breakfast + caffeine (tracked)
│
├─ 12:00 PM → Group A: STOP caffeine (strict cutoff)
│            Group B/C: Continue as normal
│
├─ 2:00 PM → Group B: STOP caffeine (moderate cutoff)
│           Group C: Continue as normal
│
├─ 6:00 PM → Evening check-in: Log total caffeine consumed + times
│            Question: "How difficult was it to follow your cutoff? (1-5)"
└─ NIGHT 2 → Sleep (intervention measurement)

DAY 3 (Morning)
├─ 7:30 AM → Complete sleep log for Night 2
│            - Sleep latency (primary outcome)
│            - Sleep quality
│            - Awakenings
└─ 9:00 AM → Results: Compare Night 1 vs Night 2 sleep latency
```

## Martin's Preparation

### Pre-Retreat
- [ ] Coordinate with Ritz-Carlton: Label coffee times clearly (breakfast, lunch, afternoon service)
- [ ] Create group assignments (randomized)
- [ ] Prepare caffeine tracking UI enhancement (log each cup with timestamp)

### Day 1
- [ ] Morning: Brief participants on caffeine tracking during breakfast
- [ ] 6:00 PM: Assign groups via app
- [ ] Send detailed instructions for tomorrow's cutoff

### Day 2
- [ ] 9:00 AM: Remind Group A (strict) of 12 PM cutoff
- [ ] 11:30 AM: Send push notification to Group A: "Last chance for caffeine!"
- [ ] 12:00 PM: Group A cutoff begins
- [ ] 1:30 PM: Send push notification to Group B: "Last chance for caffeine!"
- [ ] 2:00 PM: Group B cutoff begins
- [ ] 6:00 PM: Monitor evening check-in completion

### Day 3
- [ ] 8:00 AM: Pull sleep log data
- [ ] Compare Night 1 vs Night 2 sleep latency by group
- [ ] Generate before/after charts
- [ ] 9:00 AM: Present findings

## Participant's Job

### Day 1
1. Track all caffeine intake in app (time + amount)
2. Complete evening check-in
3. Sleep normally

### Day 2 (Group A - Strict)
1. Track morning caffeine (before 12 PM)
2. **12:00 PM: STOP all caffeine**
3. Decline any afternoon coffee/tea
4. Evening check-in: Log total caffeine + difficulty rating
5. Sleep

### Day 2 (Group B - Moderate)
1. Track morning caffeine
2. OK to have caffeine from 12-2 PM
3. **2:00 PM: STOP all caffeine**
4. Evening check-in: Log total caffeine + difficulty rating
5. Sleep

### Day 2 (Group C - Control)
1. Track all caffeine normally
2. No restrictions
3. Evening check-in: Log total caffeine
4. Sleep

### Day 3
1. Complete sleep log
2. View personal before/after comparison

## Data Collection Points

| Time | Data Point | Source | Format |
|------|------------|--------|--------|
| Day 1, Throughout | Caffeine intake | Check-ins | Count (cups) + timestamps |
| Day 2, 7:30 AM | Sleep latency (Night 1) | Sleep log | Minutes |
| Day 2, 7:30 AM | Sleep quality (Night 1) | Sleep log | 1-10 scale |
| Day 2, Throughout | Caffeine intake | Check-ins | Count (cups) + timestamps |
| Day 2, 6:00 PM | Last caffeine time | Evening check-in | Timestamp (HH:MM) |
| Day 2, 6:00 PM | Difficulty rating | Evening check-in | 1-5 scale |
| Day 3, 7:30 AM | Sleep latency (Night 2) | Sleep log | Minutes |
| Day 3, 7:30 AM | Sleep quality (Night 2) | Sleep log | 1-10 scale |

## Expected Outcomes

### Hypothesis
- Group A (12 PM cutoff): -5 to -8 min sleep latency improvement
- Group B (2 PM cutoff): -2 to -4 min sleep latency improvement
- Group C (control): No significant change (±1 min)

### Outcome Visualization

```
SLEEP LATENCY IMPROVEMENT (Night 1 → Night 2)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Minutes to Fall Asleep

             NIGHT 1 (Baseline)  NIGHT 2 (Intervention)
Group A      ████████████ 18min  ███████░ 12min  (-6min) ✓
(12PM cutoff)

Group B      ████████████ 17min  ██████████ 14min (-3min) ✓
(2PM cutoff)

Group C      ████████████ 18min  ████████████ 18min (0min)
(Control)

CAFFEINE HALF-LIFE IMPACT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Caffeine in System at Bedtime (10 PM)

Last caffeine at:
12:00 PM → 10 hours → ~12% remaining (minimal impact)
2:00 PM  → 8 hours  → ~25% remaining (moderate impact)
4:00 PM  → 6 hours  → ~50% remaining (high impact)

Caffeine half-life: ~5 hours (age 50+: 6-7 hours)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Key Insights Delivered
1. **Personal sensitivity:** "Your sleep latency improved by 6 minutes with a 12 PM cutoff"
2. **Half-life calculation:** "At age XX, your caffeine half-life is ~6.5 hours"
3. **Optimal window:** "Stop caffeine by 12 PM for best sleep (target <15% in system at bedtime)"

---

# Experiment 4: Wind-Down Protocol Test

## Concept
Test comprehensive evening routine vs normal routine to quantify sleep quality impact.

## Group Assignment
```
┌─────────────────────────────────────────────────────────┐
│                    30 PARTICIPANTS                       │
└──────────┬─────────────┬─────────────────────────────────┘
           │             │
    ┌──────▼──────┐ ┌───▼──────┐ ┌──────────▼────────────┐
    │  GROUP A    │ │ GROUP B  │ │    GROUP C            │
    │   (n=10)    │ │  (n=10)  │ │     (n=10)            │
    │ FULL        │ │ PARTIAL  │ │   CONTROL             │
    │ PROTOCOL    │ │ PROTOCOL │ │ Normal routine        │
    │ (5 steps)   │ │ (3 steps)│ │                       │
    └─────────────┘ └──────────┘ └───────────────────────┘
```

## Experimental Flow

```
DAY 1 (Baseline)
└─ NIGHT 1 → Normal evening routine, normal sleep (baseline)

DAY 2 (Morning + Evening)
├─ 7:30 AM → Complete sleep log for Night 1 (baseline)
├─ 5:00 PM → Martin assigns groups + delivers protocol instructions
│
├─ 7:00 PM → Group A: Begin FULL protocol (5 steps)
│            Group B: Begin PARTIAL protocol (3 steps)
│            Group C: Normal evening routine
│
├─ 9:30 PM → All groups: Evening check-in
│            - Protocol step completion (checkboxes)
│            - Difficulty rating (1-5)
└─ NIGHT 2 → Sleep (intervention measurement)

DAY 3 (Morning)
├─ 7:30 AM → Complete sleep log for Night 2
└─ 9:00 AM → Results: Compare compliance, sleep quality, difficulty
```

## Protocol Details

### Group A - FULL Protocol (5 Steps)
```
STEP 1: Dim Lights (7:00 PM)
└─ Reduce all indoor lighting to <50 lux
   Set phone to Night Shift mode
   Use warm-toned lamps only

STEP 2: No Screens (8:30 PM - 9:30 PM)
└─ 60-minute screen-free window before bed
   Alternative activities: Reading, conversation, journaling

STEP 3: Room Temperature (9:00 PM)
└─ Set thermostat to 66-68°F
   Confirm temperature by 9:30 PM

STEP 4: Breathing Exercise (9:15 PM)
└─ App-guided 4-7-8 breathing (5 minutes)
   Inhale 4 sec, hold 7 sec, exhale 8 sec × 8 cycles

STEP 5: Consistent Bedtime (10:00 PM ± 15 min)
└─ Lights out between 9:45 PM - 10:15 PM
   No flexibility outside this window
```

### Group B - PARTIAL Protocol (3 Steps)
```
STEP 1: Dim Lights (7:00 PM)
└─ Same as Group A

STEP 3: Room Temperature (9:00 PM)
└─ Same as Group A

STEP 4: Breathing Exercise (9:15 PM)
└─ Same as Group A
```

### Group C - Control
```
Normal evening routine
└─ No protocol requirements
   Act as you normally would
```

## Martin's Preparation

### Pre-Retreat
- [ ] Create app-guided breathing exercise (4-7-8 technique, 5 min)
- [ ] Prepare protocol checklist UI in app (with checkboxes for each step)
- [ ] Create group assignments

### Day 2 (Afternoon)
- [ ] 5:00 PM: Assign groups
- [ ] Send detailed protocol instructions with step-by-step guide
- [ ] Provide lux meter readings for participants to understand <50 lux (or use phone light meter app)

### Day 2 (Evening)
- [ ] 7:00 PM: Send reminder to Group A/B to begin protocol
- [ ] 8:30 PM: Send "no screens" reminder to Group A
- [ ] 9:15 PM: Push notification: "Time for breathing exercise" (Group A/B)
- [ ] 9:30 PM: Monitor evening check-in completion
- [ ] Track: Which steps were completed, which were skipped

### Day 3
- [ ] 8:00 AM: Pull sleep log data
- [ ] Analyze: Protocol adherence → sleep quality correlation
- [ ] Calculate: Average difficulty rating by protocol type
- [ ] 9:00 AM: Present findings

## Participant's Job

### Day 1
1. Sleep normally
2. Complete sleep log in morning (baseline)

### Day 2 (Group A - Full Protocol)
1. 7:00 PM: Dim all lights, set phone to Night Shift
2. 8:30 PM: Put phone away (no screens for 60 min)
3. 9:00 PM: Set room temp to 66-68°F
4. 9:15 PM: Complete app-guided breathing exercise (5 min)
5. 10:00 PM: Lights out (±15 min)
6. 9:30 PM: Check off completed steps in app

### Day 2 (Group B - Partial Protocol)
1. 7:00 PM: Dim all lights
2. 9:00 PM: Set room temp to 66-68°F
3. 9:15 PM: Complete breathing exercise
4. 9:30 PM: Check off completed steps in app
5. Bedtime: Your normal time (no restriction)

### Day 2 (Group C - Control)
1. Normal evening routine
2. 9:30 PM: Confirm in app "followed normal routine"
3. Bedtime: Your normal time

### Day 3
1. Complete sleep log
2. View results

## Data Collection Points

| Time | Data Point | Source | Format |
|------|------------|--------|--------|
| Day 2, 7:30 AM | Sleep quality (Night 1) | Sleep log | 1-10 scale |
| Day 2, 7:30 AM | Sleep latency (Night 1) | Sleep log | Minutes |
| Day 2, 9:30 PM | Step 1 completed? | Evening check-in | Boolean |
| Day 2, 9:30 PM | Step 2 completed? | Evening check-in | Boolean |
| Day 2, 9:30 PM | Step 3 completed? | Evening check-in | Boolean |
| Day 2, 9:30 PM | Step 4 completed? | Evening check-in | Boolean |
| Day 2, 9:30 PM | Step 5 completed? | Evening check-in | Boolean |
| Day 2, 9:30 PM | Difficulty rating | Evening check-in | 1-5 scale |
| Day 3, 7:30 AM | Sleep quality (Night 2) | Sleep log | 1-10 scale |
| Day 3, 7:30 AM | Sleep latency (Night 2) | Sleep log | Minutes |

## Expected Outcomes

### Hypothesis
- Group A (full protocol): +1.8 sleep quality improvement, -7 min latency
- Group B (partial protocol): +1.0 sleep quality improvement, -4 min latency
- Group C (control): No significant change

**Compliance prediction:**
- Group A: 70% complete all 5 steps (harder to follow)
- Group B: 90% complete all 3 steps (easier)

### Outcome Visualization

```
SLEEP QUALITY IMPROVEMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Night 1 (Baseline) → Night 2 (Protocol)

Group A   ██████░ 6.8       ████████████ 8.6  (+1.8) ✓✓
(Full)

Group B   ██████░ 6.9       █████████░ 7.9    (+1.0) ✓
(Partial)

Group C   ██████░ 6.7       ███████░ 7.0      (+0.3)
(Control)

COMPLIANCE vs EFFECTIVENESS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sleep Quality Gain
    2.0 │                  ●
        │
    1.5 │              ●
        │
    1.0 │          ●
        │
    0.5 │      ●
        │  ●
    0.0 └──────────────────
        0   1   2   3   4   5
           Steps Completed

Correlation: r = 0.82
More steps → Better sleep improvement
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DIFFICULTY RATINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Avg Difficulty (1=easy, 5=very hard)

Group A (5 steps)  ████████░ 3.8
Group B (3 steps)  ████░░░░░ 2.1
Group C (control)  █░░░░░░░░ 1.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Key Insights Delivered
1. **Effectiveness:** "Following the full 5-step protocol improved your sleep quality by 1.8 points"
2. **Feasibility:** "Group A found it moderately difficult (3.8/5), but results were worth it"
3. **Critical steps:** "Breathing exercise + consistent bedtime had the biggest impact"
4. **Actionable takeaway:** "Start with 3 steps (lights, temp, breathing), add the others gradually"

---

# Experiment 5: Meal Timing & Sleep

## Concept
Test circadian-aligned eating by assigning early vs late dinner times and measuring digestive impact on sleep.

## Group Assignment
```
┌─────────────────────────────────────────────────────────┐
│                    30 PARTICIPANTS                       │
└──────────┬─────────────┬─────────────────────────────────┘
           │             │
    ┌──────▼──────┐ ┌───▼──────┐ ┌──────────▼────────────┐
    │  GROUP A    │ │ GROUP B  │ │    GROUP C            │
    │   (n=10)    │ │  (n=10)  │ │     (n=10)            │
    │ EARLY       │ │  LATE    │ │   SWITCH              │
    │ Dinner 6PM  │ │Dinner 8PM│ │ Early → Late          │
    │ (3+ hr gap) │ │(1-2hr gap)│ │ (crossover)          │
    └─────────────┘ └──────────┘ └───────────────────────┘
```

## Experimental Flow

```
DAY 1
├─ 5:00 PM → Martin assigns groups + coordinates dinner times with hotel
├─ 6:00 PM → Group A: Early dinner seating
├─ 7:00 PM → Group C: Early dinner seating (crossover night 1)
├─ 8:00 PM → Group B: Late dinner seating
├─ 9:30 PM → Evening check-in:
│            - Last bite time
│            - Fullness level (1-5)
│            - Digestive comfort (1-5)
└─ NIGHT 1 → Sleep

DAY 2
├─ 7:30 AM → Complete sleep log:
│            - Sleep quality
│            - Sleep latency
│            - Awakenings
│            - "Did digestion disrupt your sleep?" (Yes/No + severity)
│
├─ 6:00 PM → Group A: Early dinner (repeat)
├─ 8:00 PM → Group B: Late dinner (repeat)
├─ 8:00 PM → Group C: SWITCH to late dinner (crossover night 2)
│
├─ 9:30 PM → Evening check-in (same questions)
└─ NIGHT 2 → Sleep

DAY 3
├─ 7:30 AM → Complete sleep log (same questions)
└─ 9:00 AM → Results: Early vs Late dinner impact comparison
```

## Martin's Preparation

### Pre-Retreat
- [ ] Coordinate with Ritz-Carlton: Create 2 dinner seatings (6 PM and 8 PM)
- [ ] Ensure identical menus for both seatings (control for food type/quantity)
- [ ] Create group assignments

### Day 1
- [ ] 5:00 PM: Assign groups, notify of dinner seating times
- [ ] Coordinate with hotel: Confirm table assignments by group
- [ ] 9:00 PM: Send reminder for evening check-in

### Day 2
- [ ] 8:00 AM: Pull Night 1 sleep log data
- [ ] Analyze preliminary findings (digestive disruption reports)
- [ ] 5:00 PM: Send dinner time reminders (Group C switches to late!)

### Day 3
- [ ] 8:00 AM: Pull Night 2 sleep log data
- [ ] Analyze:
  - Group A (early both nights) vs Group B (late both nights)
  - Group C crossover: Early night 1 vs Late night 2 (within-person comparison)
- [ ] 9:00 AM: Present findings

## Participant's Job

### Day 1 (Group A - Early)
1. 6:00 PM: Attend early dinner seating
2. Note "last bite" time in app
3. 9:30 PM: Complete evening check-in (fullness, comfort)
4. Sleep

### Day 1 (Group B - Late)
1. 8:00 PM: Attend late dinner seating
2. Note "last bite" time in app
3. 9:30 PM: Complete evening check-in (fullness, comfort)
4. Sleep

### Day 1 (Group C - Early, then switch)
1. 6:00 PM: Attend early dinner seating (like Group A)
2. Same check-in process

### Day 2 (Morning - All Groups)
1. 7:30 AM: Complete sleep log
2. Answer: "Did digestion disrupt your sleep? If yes, how severely? (1-5)"

### Day 2 (Evening - Groups A/B repeat, Group C switches)
1. Groups A/B: Repeat assigned dinner time
2. Group C: SWITCH to 8 PM late dinner
3. All: Complete evening check-in

### Day 3
1. Complete sleep log
2. View results

## Data Collection Points

| Time | Data Point | Source | Format |
|------|------------|--------|--------|
| Day 1, 9:30 PM | Last bite time | Evening check-in | Timestamp (HH:MM) |
| Day 1, 9:30 PM | Fullness level | Evening check-in | 1-5 scale |
| Day 1, 9:30 PM | Digestive comfort | Evening check-in | 1-5 scale |
| Day 2, 7:30 AM | Sleep quality (Night 1) | Sleep log | 1-10 scale |
| Day 2, 7:30 AM | Sleep latency (Night 1) | Sleep log | Minutes |
| Day 2, 7:30 AM | Digestive disruption? | Sleep log | Boolean + severity 1-5 |
| Day 2, 9:30 PM | Last bite time | Evening check-in | Timestamp |
| Day 2, 9:30 PM | Fullness/comfort | Evening check-in | 1-5 scales |
| Day 3, 7:30 AM | Sleep quality (Night 2) | Sleep log | 1-10 scale |
| Day 3, 7:30 AM | Sleep latency (Night 2) | Sleep log | Minutes |
| Day 3, 7:30 AM | Digestive disruption? | Sleep log | Boolean + severity |

## Expected Outcomes

### Hypothesis
- Early dinner (6 PM, 3+ hour gap): Better sleep quality, less digestive disruption
- Late dinner (8 PM, 1-2 hour gap): Lower sleep quality, more disruption
- Group C crossover will show within-person difference (gold standard)

### Outcome Visualization

```
DIGESTIVE DISRUPTION REPORTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"Did digestion disrupt your sleep?"

Group A (Early, 6PM)   ████░░░░░░ 20% reported disruption
Group B (Late, 8PM)    ████████░░ 60% reported disruption

SLEEP QUALITY BY DINNER TIME
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sleep Quality (1-10 scale)

Early Dinner (6PM)  ████████████████████░ 8.1
Late Dinner (8PM)   ███████████████░░░░░░ 6.9

Sleep Latency (minutes)
Early Dinner (6PM)  ███████████░░░░░░░░░░ 16 min
Late Dinner (8PM)   ███████████████░░░░░░ 22 min

GROUP C CROSSOVER (Within-Person)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Individual Sleep Quality Change

Night 1 (Early)  ████████████ 7.8
Night 2 (Late)   ███████░░░░░ 6.5  (-1.3 points) ✓

9 out of 10 participants showed worse sleep
when switching from early to late dinner.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Key Insights Delivered
1. **Optimal window:** "Finish dinner at least 3 hours before bed for best sleep"
2. **Digestive impact:** "Late dinner (8 PM) caused digestive disruption in 60% of participants"
3. **Individual proof:** "Your own data shows: Early dinner → 1.3 point better sleep quality"
4. **Actionable takeaway:** "Target 6-7 PM dinners, or reduce portion size if eating late"

---

# Experiment 6: Nap Mapping Study

## Concept
Test nap duration impact on older adults' nighttime sleep (optimizing vs disrupting).

## Group Assignment
```
┌─────────────────────────────────────────────────────────┐
│                    30 PARTICIPANTS                       │
└──────────┬─────────────┬─────────────────────────────────┘
           │             │
    ┌──────▼──────┐ ┌───▼──────┐ ┌──────────▼────────────┐
    │  GROUP A    │ │ GROUP B  │ │    GROUP C            │
    │   (n=10)    │ │  (n=10)  │ │     (n=10)            │
    │ SHORT NAP   │ │ LONG NAP │ │   NO NAP              │
    │ 20 minutes  │ │45 minutes│ │ (Control)             │
    │ at 2:00 PM  │ │at 2:00 PM│ │                       │
    └─────────────┘ └──────────┘ └───────────────────────┘
```

## Experimental Flow

```
DAY 1 (Baseline)
└─ NIGHT 1 → Normal sleep (no nap intervention)

DAY 2
├─ 7:30 AM → Complete sleep log for Night 1 (baseline)
├─ 12:00 PM → Martin assigns groups + sends nap instructions
│
├─ 2:00 PM → NAP INTERVENTION WINDOW
│            Group A: 20-min nap (2:00-2:20 PM)
│            Group B: 45-min nap (2:00-2:45 PM)
│            Group C: Quiet rest, no sleep (reading, meditation)
│
├─ 3:00 PM → Post-nap check-in:
│            - Did you actually fall asleep? (Yes/No)
│            - Sleep depth (1-5: light doze → deep sleep)
│            - How do you feel now? Energy (1-6)
│
└─ NIGHT 2 → Sleep (measure nap impact)

DAY 3
├─ 7:30 AM → Complete sleep log for Night 2:
│            - Sleep latency
│            - Total sleep time
│            - Sleep quality
│            - "Did your afternoon nap affect nighttime sleep?" (Yes/No + how)
│
└─ 9:00 AM → Results: Nap duration → nighttime sleep impact
```

## Martin's Preparation

### Pre-Retreat
- [ ] Coordinate with Ritz-Carlton: Reserve quiet nap spaces (spa, private lounges)
- [ ] Prepare nap room setup: Eye masks, timers, calm environment
- [ ] Create group assignments

### Day 2 (Morning)
- [ ] 12:00 PM: Assign groups
- [ ] Send detailed nap instructions:
  - Group A: "Set timer for 20 min, wake immediately when it rings"
  - Group B: "Set timer for 45 min, wake when it rings"
  - Group C: "Rest quietly but stay awake (read, meditate)"

### Day 2 (Afternoon)
- [ ] 1:45 PM: Remind participants to head to nap location
- [ ] 2:00 PM: Ensure all participants in position
- [ ] Monitor: Groups A/B actually sleep, Group C stays awake
- [ ] 3:00 PM: Collect post-nap check-ins

### Day 3
- [ ] 8:00 AM: Pull sleep log data
- [ ] Analyze: Nap duration (0/20/45 min) → nighttime sleep latency, total sleep time
- [ ] Identify "good nappers" vs "bad nappers"
- [ ] 9:00 AM: Present findings

## Participant's Job

### Day 1
1. Sleep normally (no nap intervention)

### Day 2 (Morning)
1. 7:30 AM: Complete sleep log (baseline)
2. 12:00 PM: Receive nap assignment

### Day 2 (Afternoon - Group A: 20-min nap)
1. 1:50 PM: Go to designated nap location
2. 2:00 PM: Set timer for 20 minutes
3. Lie down, attempt to sleep
4. 2:20 PM: Wake immediately when timer rings
5. 3:00 PM: Complete post-nap check-in

### Day 2 (Afternoon - Group B: 45-min nap)
1. 1:50 PM: Go to designated nap location
2. 2:00 PM: Set timer for 45 minutes
3. Lie down, sleep
4. 2:45 PM: Wake when timer rings
5. 3:00 PM: Complete post-nap check-in

### Day 2 (Afternoon - Group C: No nap)
1. 2:00 PM: Go to designated rest location
2. Rest quietly (reading, meditation, sitting)
3. Do NOT fall asleep
4. 3:00 PM: Complete post-rest check-in

### Day 3
1. 7:30 AM: Complete sleep log
2. Answer: "Did your afternoon rest/nap affect nighttime sleep?"

## Data Collection Points

| Time | Data Point | Source | Format |
|------|------------|--------|--------|
| Day 2, 7:30 AM | Sleep quality (Night 1) | Sleep log | 1-10 scale |
| Day 2, 7:30 AM | Total sleep (Night 1) | Sleep log | Minutes |
| Day 2, 3:00 PM | Actually fell asleep? | Post-nap check-in | Boolean |
| Day 2, 3:00 PM | Sleep depth | Post-nap check-in | 1-5 scale |
| Day 2, 3:00 PM | Post-nap energy | Post-nap check-in | 1-6 scale |
| Day 3, 7:30 AM | Sleep latency (Night 2) | Sleep log | Minutes |
| Day 3, 7:30 AM | Total sleep (Night 2) | Sleep log | Minutes |
| Day 3, 7:30 AM | Sleep quality (Night 2) | Sleep log | 1-10 scale |
| Day 3, 7:30 AM | Nap affected night? | Sleep log | Boolean + description |

## Expected Outcomes

### Hypothesis
- 20-min nap (Group A): Minimal nighttime disruption, good post-nap energy
- 45-min nap (Group B): Potential nighttime sleep reduction (-30 to -45 min), grogginess (sleep inertia)
- No nap (Group C): No change in nighttime sleep

**Individual variation expected:** Some people are "good nappers" (no night impact), others are "bad nappers" (significant disruption).

### Outcome Visualization

```
NIGHTTIME TOTAL SLEEP (Night 1 vs Night 2)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Minutes of Sleep

             Night 1 (No Nap) → Night 2 (Nap)

Group A      ███████████ 420min → ██████████░ 410min (-10min)
(20min nap)                        Minimal impact ✓

Group B      ███████████ 425min → █████████░░ 385min (-40min)
(45min nap)                        Significant reduction ✗

Group C      ███████████ 418min → ███████████ 420min (+2min)
(No nap)                           No change

POST-NAP ENERGY vs SLEEP INERTIA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Post-Nap Energy (3:00 PM, 1-6 scale)

Group A (20min)  ████████████████░ 4.8  Alert, refreshed
Group B (45min)  ██████████░░░░░░░ 3.2  Groggy, sleep inertia
Group C (No nap) ███████████░░░░░░ 3.5  Baseline

"GOOD NAPPER" vs "BAD NAPPER" PHENOTYPE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Nighttime Sleep Change After 20-min Nap

Good Nappers (n=6): -5 min average (minimal impact)
Bad Nappers (n=4):  -25 min average (significant impact)

"Good nappers" can nap without nighttime penalty.
"Bad nappers" should avoid afternoon naps entirely.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Key Insights Delivered
1. **Optimal nap duration:** "20-minute naps gave energy boost with minimal nighttime impact"
2. **Avoid sleep inertia:** "45-minute naps caused grogginess and reduced nighttime sleep by 40 minutes"
3. **Personal phenotype:** "You are a GOOD napper - 20-min naps don't harm your night sleep"
   OR "You are a BAD napper - skip afternoon naps to protect nighttime sleep"
4. **Actionable takeaway:** "If you must nap, keep it under 20 minutes and before 3 PM"

---

# Experiment 7: Blue Light Blocking

## Concept
Test blue light blockers vs normal evening light exposure on sleep latency and melatonin onset.

## Group Assignment
```
┌─────────────────────────────────────────────────────────┐
│                    30 PARTICIPANTS                       │
└──────────┬─────────────┬─────────────────────────────────┘
           │             │
    ┌──────▼──────┐ ┌───▼──────┐ ┌──────────▼────────────┐
    │  GROUP A    │ │ GROUP B  │ │    GROUP C            │
    │   (n=10)    │ │  (n=10)  │ │     (n=10)            │
    │BLUE BLOCKERS│ │ DIM LIGHT│ │   NORMAL              │
    │ Glasses 7PM │ │Only (no  │ │ Full light            │
    │             │ │ blockers)│ │ (control)             │
    └─────────────┘ └──────────┘ └───────────────────────┘
```

## Experimental Flow

```
DAY 1 (Baseline)
└─ NIGHT 1 → Normal evening light exposure, normal sleep

DAY 2
├─ 7:30 AM → Complete sleep log for Night 1 (baseline)
├─ 5:00 PM → Martin assigns groups + distributes blue light glasses to Group A
│
├─ 7:00 PM → INTERVENTION BEGINS
│            Group A: Put on blue light blocking glasses (wear until bed)
│            Group B: Dim all lights to <50 lux (no blockers)
│            Group C: Normal evening lighting
│
├─ 9:30 PM → Evening check-in:
│            - Compliance: "Did you wear glasses/dim lights?" (Yes/No)
│            - Sleepiness level: "How sleepy do you feel? (1-5)"
│            - Time feeling sleepy started (HH:MM)
│
└─ NIGHT 2 → Sleep (measure intervention impact)

DAY 3
├─ 7:30 AM → Complete sleep log for Night 2:
│            - Sleep latency
│            - Sleep quality
│            - "What time did you first feel sleepy last night?"
│
└─ 9:00 AM → Results: Blue light blocking → melatonin onset timing, sleep latency
```

## Martin's Preparation

### Pre-Retreat
- [ ] Purchase 10 pairs of blue light blocking glasses (amber-tinted, blocks 450-480nm)
- [ ] Test glasses with phone spectrometer app (verify blue light reduction)
- [ ] Create group assignments

### Day 2
- [ ] 5:00 PM: Assign groups
- [ ] Distribute glasses to Group A with instructions:
  - "Wear from 7 PM until you get into bed"
  - "Can wear over prescription glasses if needed"
- [ ] Send instructions to Group B: "Dim all lights to <50 lux (use phone light meter app)"
- [ ] Send reminder to Group C: "Act normally tonight"

### Day 2 (Evening)
- [ ] 7:00 PM: Send reminders to all groups to begin protocol
- [ ] 9:00 PM: Check compliance (are people actually wearing glasses/dimming lights?)

### Day 3
- [ ] 8:00 AM: Pull sleep log data
- [ ] Analyze: Sleepiness onset time, sleep latency by group
- [ ] Calculate melatonin onset proxy: "Time first felt sleepy"
- [ ] 9:00 AM: Present findings

## Participant's Job

### Day 1
1. Sleep normally

### Day 2 (Group A - Blue Blockers)
1. 7:00 PM: Put on blue light blocking glasses
2. Wear until getting into bed (~10:00 PM)
3. Continue normal activities (reading, TV, phone OK while wearing glasses)
4. 9:30 PM: Complete check-in (compliance, sleepiness level, time sleepiness started)

### Day 2 (Group B - Dim Lights)
1. 7:00 PM: Dim all indoor lights to <50 lux
2. Use phone light meter app to verify
3. Keep lights dim until bed
4. 9:30 PM: Complete check-in

### Day 2 (Group C - Control)
1. Normal evening lighting
2. 9:30 PM: Complete check-in

### Day 3
1. 7:30 AM: Complete sleep log
2. Recall: "What time did you first feel sleepy last night?"

## Data Collection Points

| Time | Data Point | Source | Format |
|------|------------|--------|--------|
| Day 2, 7:30 AM | Sleep latency (Night 1) | Sleep log | Minutes |
| Day 2, 7:30 AM | Sleep quality (Night 1) | Sleep log | 1-10 scale |
| Day 2, 9:30 PM | Compliance | Evening check-in | Boolean |
| Day 2, 9:30 PM | Sleepiness level | Evening check-in | 1-5 scale |
| Day 2, 9:30 PM | Time sleepiness started | Evening check-in | Timestamp (HH:MM) |
| Day 3, 7:30 AM | Sleep latency (Night 2) | Sleep log | Minutes |
| Day 3, 7:30 AM | Sleep quality (Night 2) | Sleep log | 1-10 scale |
| Day 3, 7:30 AM | Time first felt sleepy | Sleep log | Timestamp (HH:MM) |

## Expected Outcomes

### Hypothesis
- Group A (blue blockers): Earlier sleepiness onset (-45 to -60 min), faster sleep latency (-5 min)
- Group B (dim lights): Moderate improvement (-30 min onset, -3 min latency)
- Group C (control): No change

### Outcome Visualization

```
MELATONIN ONSET PROXY (Time First Felt Sleepy)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
             Night 1 (Normal) → Night 2 (Intervention)

Group A      10:15 PM         → 9:20 PM  (-55 min) ✓✓
(Blue block)

Group B      10:10 PM         → 9:45 PM  (-25 min) ✓
(Dim lights)

Group C      10:12 PM         → 10:10 PM (-2 min)
(Control)

SLEEP LATENCY IMPROVEMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Minutes to Fall Asleep

             Night 1 → Night 2

Group A      ████████████ 19min → ██████░ 12min (-7min) ✓
(Blue block)

Group B      ████████████ 18min → █████████░ 15min (-3min)
(Dim lights)

Group C      ████████████ 19min → ████████████ 19min (0min)
(Control)

BLUE LIGHT BLOCKING MECHANISM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Evening Light (7-10 PM) → Melatonin Suppression

Normal Light (460nm blue): Delays melatonin by ~90 min
Dim Lights (<50 lux):      Delays melatonin by ~40 min
Blue Blockers (blocks 460): Minimal delay (~15 min)

Earlier melatonin → Earlier sleep drive → Faster sleep
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Key Insights Delivered
1. **Melatonin timing:** "Blue light blockers advanced your sleepiness by 55 minutes"
2. **Sleep latency:** "You fell asleep 7 minutes faster with blue blockers"
3. **Mechanism:** "Evening blue light suppresses melatonin - blocking it restores natural timing"
4. **Actionable takeaway:** "Use blue light blockers after 7 PM, or dim lights + Night Shift mode"

---

# Experiment 8: Gratitude Journaling

## Concept
Test evening gratitude practice impact on rumination, sleep quality, and mood.

## Group Assignment
```
┌─────────────────────────────────────────────────────────┐
│                    30 PARTICIPANTS                       │
└──────────┬─────────────┬─────────────────────────────────┘
           │             │
    ┌──────▼──────┐ ┌───▼──────┐ ┌──────────▼────────────┐
    │  GROUP A    │ │ GROUP B  │ │    GROUP C            │
    │   (n=10)    │ │  (n=10)  │ │     (n=10)            │
    │ GRATITUDE   │ │ NEUTRAL  │ │   CONTROL             │
    │ "3 grateful"│ │"3 events"│ │ No journaling         │
    │ 8:00 PM     │ │ 8:00 PM  │ │                       │
    └─────────────┘ └──────────┘ └───────────────────────┘
```

## Experimental Flow

```
DAY 1 (Baseline)
├─ 9:30 PM → Evening check-in: Rumination baseline
│            "How much did you worry/ruminate before sleep? (1-5)"
└─ NIGHT 1 → Normal sleep

DAY 2
├─ 7:30 AM → Complete sleep log + morning check-in:
│            - Sleep quality (Night 1)
│            - Mood (1-6)
│
├─ 6:00 PM → Martin assigns groups + sends journaling prompt instructions
│
├─ 8:00 PM → JOURNALING INTERVENTION
│            Group A: App prompts "Write 3 things you're grateful for today"
│            Group B: App prompts "Write 3 events that happened today" (neutral)
│            Group C: No prompt
│
├─ 9:30 PM → Evening check-in:
│            - Rumination level (1-5)
│            - Mood (1-6)
│            - "How do you feel after journaling?" (Group A/B only)
│
└─ NIGHT 2 → Sleep

DAY 3
├─ 7:30 AM → Complete sleep log + morning check-in:
│            - Sleep quality (Night 2)
│            - Mood (1-6)
│
└─ 9:00 AM → Results: Gratitude → rumination reduction, sleep quality, mood
```

## Martin's Preparation

### Pre-Retreat
- [ ] Create gratitude prompt UI in app (free-text field, 3 entries)
- [ ] Create neutral prompt UI (3 event descriptions, free-text)
- [ ] Create group assignments

### Day 2
- [ ] 6:00 PM: Assign groups
- [ ] Prepare push notifications:
  - Group A: "It's gratitude time! Write 3 things you're grateful for today."
  - Group B: "Reflection time! Write 3 events that happened today."
  - Group C: No notification
- [ ] 8:00 PM: Send prompts
- [ ] 8:30 PM: Monitor completion (target 80%+ for Groups A/B)

### Day 3
- [ ] 8:00 AM: Pull data
- [ ] Analyze:
  - Rumination: Night 1 vs Night 2 (Group A should show largest reduction)
  - Sleep quality: Night 1 vs Night 2
  - Mood: Day 2 AM vs Day 3 AM (next-day carry-over effect)
- [ ] 9:00 AM: Present findings

## Participant's Job

### Day 1
1. 9:30 PM: Complete evening check-in (rumination baseline)
2. Sleep

### Day 2 (Morning)
1. 7:30 AM: Complete sleep log + morning check-in (mood)

### Day 2 (Evening - Group A: Gratitude)
1. 8:00 PM: Receive app prompt
2. Write 3 things you're grateful for today (free-text, can be simple):
   - Example: "Good conversation with spouse," "Beautiful sunset," "Feeling healthy"
3. 9:30 PM: Complete evening check-in (rumination, mood)

### Day 2 (Evening - Group B: Neutral)
1. 8:00 PM: Receive app prompt
2. Write 3 events that happened today (factual, neutral):
   - Example: "Had breakfast at 8 AM," "Attended talk at 10 AM," "Walked on beach at 2 PM"
3. 9:30 PM: Complete evening check-in (rumination, mood)

### Day 2 (Evening - Group C: Control)
1. No journaling prompt
2. 9:30 PM: Complete evening check-in (rumination, mood)

### Day 3
1. 7:30 AM: Complete sleep log + morning check-in
2. View results

## Data Collection Points

| Time | Data Point | Source | Format |
|------|------------|--------|--------|
| Day 1, 9:30 PM | Rumination (Night 1) | Evening check-in | 1-5 scale |
| Day 2, 7:30 AM | Sleep quality (Night 1) | Sleep log | 1-10 scale |
| Day 2, 7:30 AM | Morning mood | Morning check-in | 1-6 scale |
| Day 2, 8:00 PM | Gratitude entries (text) | App prompt | Free-text (Group A) |
| Day 2, 8:00 PM | Event entries (text) | App prompt | Free-text (Group B) |
| Day 2, 9:30 PM | Rumination (Night 2) | Evening check-in | 1-5 scale |
| Day 2, 9:30 PM | Evening mood | Evening check-in | 1-6 scale |
| Day 3, 7:30 AM | Sleep quality (Night 2) | Sleep log | 1-10 scale |
| Day 3, 7:30 AM | Morning mood | Morning check-in | 1-6 scale |

## Expected Outcomes

### Hypothesis
- Group A (gratitude): -1.5 rumination reduction, +0.8 sleep quality, +1.0 mood
- Group B (neutral): -0.5 rumination (journaling helps, but not as much as gratitude)
- Group C (control): No change

### Outcome Visualization

```
RUMINATION REDUCTION (Night 1 → Night 2)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"How much did you worry before sleep?" (1-5)

             Night 1 → Night 2

Group A      ████░ 3.8 → ██░░░ 2.3  (-1.5) ✓✓
(Gratitude)

Group B      ████░ 3.7 → ███░░ 3.2  (-0.5) ✓
(Neutral)

Group C      ████░ 3.9 → ████░ 3.8  (-0.1)
(Control)

SLEEP QUALITY IMPROVEMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sleep Quality (1-10 scale)

             Night 1 → Night 2

Group A      ██████░ 6.9 → ████████░ 7.7 (+0.8) ✓
(Gratitude)

Group B      ██████░ 7.0 → ███████░░ 7.3 (+0.3)
(Neutral)

Group C      ██████░ 6.8 → ███████░░ 7.0 (+0.2)
(Control)

NEXT-DAY MOOD CARRY-OVER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Morning Mood (1-6 scale)

             Day 2 AM → Day 3 AM

Group A      ████░ 4.2 → █████░ 5.2 (+1.0) ✓
(Gratitude)

Group B      ████░ 4.3 → ████░░ 4.6 (+0.3)
(Neutral)

Group C      ████░ 4.1 → ████░░ 4.2 (+0.1)
(Control)

Gratitude practice → Better sleep → Better next-day mood
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Key Insights Delivered
1. **Rumination reduction:** "Gratitude journaling reduced pre-sleep worry by 40%"
2. **Sleep quality:** "You slept 0.8 points better after gratitude practice"
3. **Mood carry-over:** "Next-day mood improved by 1.0 point - gratitude → sleep → mood cycle"
4. **Actionable takeaway:** "Spend 2 minutes before bed writing 3 things you're grateful for"

---

# Experiment 9: Breathing Exercise Timing

## Concept
Test optimal timing for 4-7-8 breathing: pre-bed vs upon waking vs midday stress relief.

## Group Assignment
```
┌─────────────────────────────────────────────────────────┐
│                    30 PARTICIPANTS                       │
└──────────┬─────────────┬─────────────────────────────────┘
           │             │
    ┌──────▼──────┐ ┌───▼──────┐ ┌──────────▼────────────┐
    │  GROUP A    │ │ GROUP B  │ │    GROUP C            │
    │   (n=10)    │ │  (n=10)  │ │     (n=10)            │
    │ PRE-BED     │ │ MORNING  │ │   CONTROL             │
    │ 9:30 PM     │ │ 7:30 AM  │ │ No breathing          │
    │ (sleep aid) │ │(energize)│ │ exercise              │
    └─────────────┘ └──────────┘ └───────────────────────┘
```

## Experimental Flow

```
DAY 1 (Baseline)
└─ NIGHT 1 → Normal sleep

DAY 2
├─ 7:30 AM → Complete sleep log for Night 1 (baseline)
│            Morning check-in: Energy, mood (baseline)
│
├─ 12:00 PM → Martin assigns groups + sends breathing exercise tutorial
│            App includes guided 4-7-8 breathing (5 min, ~8 cycles)
│
├─ 7:30 AM → Group B: Complete breathing exercise (morning energizing)
│            Post-exercise: "How do you feel? Energy (1-6), Calm (1-5)"
│
├─ 9:30 PM → Group A: Complete breathing exercise (pre-bed relaxation)
│            Post-exercise: "How do you feel? Relaxed (1-5), Sleepy (1-5)"
│
└─ NIGHT 2 → Sleep

DAY 3
├─ 7:30 AM → Complete sleep log for Night 2:
│            - Sleep latency
│            - Sleep quality
│
│            Morning check-in: Energy, mood
│
└─ 9:00 AM → Results: Breathing timing → sleep latency, energy, relaxation
```

## Martin's Preparation

### Pre-Retreat
- [ ] Create app-guided 4-7-8 breathing exercise (audio + visual timer)
  - Inhale 4 seconds
  - Hold 7 seconds
  - Exhale 8 seconds
  - Repeat 8 cycles (~5 minutes total)
- [ ] Create group assignments

### Day 2
- [ ] 12:00 PM: Assign groups
- [ ] Send tutorial video/instructions on 4-7-8 technique
- [ ] 7:15 AM: Send reminder to Group B (morning exercise)
- [ ] 9:15 PM: Send reminder to Group A (pre-bed exercise)
- [ ] Monitor completion rates

### Day 3
- [ ] 8:00 AM: Pull data
- [ ] Analyze:
  - Group A: Pre-bed breathing → sleep latency reduction
  - Group B: Morning breathing → energy/mood improvement
  - Group C: Control (no exercise)
- [ ] 9:00 AM: Present findings

## Participant's Job

### Day 1
1. Sleep normally

### Day 2 (Morning - Group B only)
1. 7:30 AM: Wake up, complete sleep log
2. Immediately after: Complete 4-7-8 breathing exercise (app-guided, 5 min)
3. Post-exercise check-in: Energy and calm ratings

### Day 2 (Evening - Group A only)
1. 9:30 PM: Complete 4-7-8 breathing exercise (app-guided, 5 min)
2. Post-exercise check-in: Relaxation and sleepiness ratings

### Day 2 (Group C - Control)
1. No breathing exercise
2. Normal routine

### Day 3
1. 7:30 AM: Complete sleep log + morning check-in
2. View results

## Data Collection Points

| Time | Data Point | Source | Format |
|------|------------|--------|--------|
| Day 2, 7:30 AM | Sleep latency (Night 1) | Sleep log | Minutes |
| Day 2, 7:30 AM | Energy (baseline) | Morning check-in | 1-6 scale |
| Day 2, 7:30 AM | Mood (baseline) | Morning check-in | 1-6 scale |
| Day 2, 7:30 AM | Post-exercise energy (Group B) | Check-in | 1-6 scale |
| Day 2, 7:30 AM | Post-exercise calm (Group B) | Check-in | 1-5 scale |
| Day 2, 9:30 PM | Post-exercise relaxation (Group A) | Check-in | 1-5 scale |
| Day 2, 9:30 PM | Post-exercise sleepiness (Group A) | Check-in | 1-5 scale |
| Day 3, 7:30 AM | Sleep latency (Night 2) | Sleep log | Minutes |
| Day 3, 7:30 AM | Sleep quality (Night 2) | Sleep log | 1-10 scale |
| Day 3, 7:30 AM | Energy | Morning check-in | 1-6 scale |
| Day 3, 7:30 AM | Mood | Morning check-in | 1-6 scale |

## Expected Outcomes

### Hypothesis
- Group A (pre-bed): -4 min sleep latency, +0.6 sleep quality
- Group B (morning): +1.2 energy, +0.8 mood (but no sleep improvement)
- Group C (control): No change

### Outcome Visualization

```
SLEEP LATENCY IMPROVEMENT (Group A: Pre-Bed Breathing)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Minutes to Fall Asleep

             Night 1 → Night 2

Group A      ████████████ 17min → ████████░ 13min (-4min) ✓
(Pre-bed)

Group B      ████████████ 18min → ████████████ 18min (0min)
(Morning)

Group C      ████████████ 17min → ████████████ 18min (+1min)
(Control)

MORNING ENERGY BOOST (Group B: Morning Breathing)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Morning Energy (1-6 scale)

             Day 2 → Day 3

Group A      ████░ 4.0 → ████░░ 4.1 (+0.1)
(Pre-bed)

Group B      ████░ 3.9 → █████░ 5.1 (+1.2) ✓
(Morning)

Group C      ████░ 4.0 → ████░░ 4.2 (+0.2)
(Control)

IMMEDIATE EFFECTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Post-Exercise Ratings

Group A (Pre-Bed, 9:30 PM):
  Relaxation: ████████░ 4.2/5
  Sleepiness: ████████░ 4.0/5
  "Felt calm and ready for sleep"

Group B (Morning, 7:30 AM):
  Energy:     █████░░░░ 5.0/6
  Calm:       ████████░ 4.5/5
  "Felt alert yet centered"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Key Insights Delivered
1. **Timing matters:** "Pre-bed breathing reduced sleep latency by 4 minutes"
2. **Morning boost:** "Morning breathing increased energy by 1.2 points"
3. **Mechanism:** "4-7-8 breathing activates parasympathetic nervous system (relaxation response)"
4. **Actionable takeaway:** "Use pre-bed breathing for better sleep, morning breathing for calm energy"

---

# Experiment 10: Alcohol & Sleep Architecture

## Concept
Test alcohol consumption impact on sleep stages (deep sleep, REM) and next-day recovery.

## Group Assignment
```
┌─────────────────────────────────────────────────────────┐
│                    30 PARTICIPANTS                       │
└──────────┬─────────────┬─────────────────────────────────┘
           │             │
    ┌──────▼──────┐ ┌───▼──────┐ ┌──────────▼────────────┐
    │  GROUP A    │ │ GROUP B  │ │    GROUP C            │
    │   (n=10)    │ │  (n=10)  │ │     (n=10)            │
    │ NO ALCOHOL  │ │ MODERATE │ │   SWITCH              │
    │ (control)   │ │1-2 drinks│ │ No alcohol → Alcohol  │
    │             │ │with dinner│ │ (crossover)          │
    └─────────────┘ └──────────┘ └───────────────────────┘
```

## Experimental Flow

```
DAY 1
├─ 6:00 PM → Dinner seating
│            Group A: No alcohol
│            Group B: 1-2 drinks with dinner (wine, beer, or cocktail)
│            Group C: No alcohol (crossover night 1)
│
├─ 9:30 PM → Evening check-in:
│            - Alcohol consumed? (Yes/No)
│            - If yes: Type, quantity, last drink time
│
└─ NIGHT 1 → Sleep

DAY 2
├─ 7:30 AM → Complete sleep log:
│            - Sleep quality
│            - Number of awakenings (critical for alcohol disruption)
│            - "Did you wake up feeling refreshed?" (Yes/No)
│
│            Pull wearable data (if available):
│            - Deep sleep %
│            - REM sleep %
│            - Awakenings count
│
├─ 10:00 AM → Morning check-in:
│            - Energy level (1-6)
│            - Mood (1-6)
│            - Focus (1-5)
│
├─ 6:00 PM → Dinner seating (GROUP C SWITCHES)
│            Group A: No alcohol (repeat)
│            Group B: 1-2 drinks (repeat)
│            Group C: 1-2 drinks (SWITCH - crossover night 2)
│
└─ NIGHT 2 → Sleep

DAY 3
├─ 7:30 AM → Complete sleep log (same questions)
│            Pull wearable data
│
├─ 10:00 AM → Morning check-in (energy, mood, focus)
│
└─ 9:00 AM → Results: Alcohol → sleep architecture, awakenings, next-day recovery
```

## Martin's Preparation

### Pre-Retreat
- [ ] Coordinate with Ritz-Carlton: Standardize alcohol servings (1 glass wine = 5oz, 1 beer = 12oz)
- [ ] Create group assignments
- [ ] Ensure participants with wearables have sleep stage tracking enabled

### Day 1
- [ ] 5:00 PM: Assign groups
- [ ] Coordinate with servers: Track who orders alcohol (verify Group A abstains, Group B limited to 1-2)
- [ ] 9:00 PM: Send evening check-in reminder

### Day 2
- [ ] 8:00 AM: Pull sleep log + wearable data
- [ ] Analyze preliminary findings (awakenings, deep sleep %)
- [ ] 5:00 PM: Remind Group C they switch to alcohol tonight

### Day 3
- [ ] 8:00 AM: Pull Night 2 data
- [ ] Analyze:
  - Group A (no alcohol both nights) vs Group B (alcohol both nights)
  - Group C crossover: Night 1 (no alcohol) vs Night 2 (alcohol) - WITHIN-PERSON comparison
- [ ] Focus on: Awakenings, deep sleep %, REM sleep %, next-day energy
- [ ] 9:00 AM: Present findings

## Participant's Job

### Day 1 (Group A - No Alcohol)
1. 6:00 PM: Dinner (no alcohol)
2. 9:30 PM: Confirm in app "no alcohol consumed"
3. Sleep

### Day 1 (Group B - Moderate Alcohol)
1. 6:00 PM: Dinner with 1-2 drinks (wine/beer/cocktail)
2. Note last drink time
3. 9:30 PM: Log alcohol type, quantity, last drink time in app
4. Sleep

### Day 1 (Group C - No Alcohol, then switch)
1. 6:00 PM: Dinner (no alcohol)
2. 9:30 PM: Confirm in app "no alcohol consumed"
3. Sleep

### Day 2 (Morning - All Groups)
1. 7:30 AM: Complete sleep log (quality, awakenings, refreshed?)
2. 10:00 AM: Complete morning check-in (energy, mood, focus)

### Day 2 (Evening - Group C SWITCHES)
1. Group A: No alcohol (repeat)
2. Group B: 1-2 drinks (repeat)
3. Group C: 1-2 drinks (SWITCH)

### Day 3
1. 7:30 AM: Complete sleep log
2. 10:00 AM: Complete morning check-in
3. View results

## Data Collection Points

| Time | Data Point | Source | Format |
|------|------------|--------|--------|
| Day 1, 9:30 PM | Alcohol consumed? | Evening check-in | Boolean |
| Day 1, 9:30 PM | Type, quantity | Evening check-in | Text + numeric |
| Day 1, 9:30 PM | Last drink time | Evening check-in | Timestamp (HH:MM) |
| Day 2, 7:30 AM | Sleep quality (Night 1) | Sleep log | 1-10 scale |
| Day 2, 7:30 AM | Awakenings (Night 1) | Sleep log | Count |
| Day 2, 7:30 AM | Felt refreshed? | Sleep log | Boolean |
| Day 2, 7:30 AM | Deep sleep % (Night 1) | Wearable (optional) | Percentage |
| Day 2, 7:30 AM | REM sleep % (Night 1) | Wearable (optional) | Percentage |
| Day 2, 10:00 AM | Energy | Morning check-in | 1-6 scale |
| Day 2, 10:00 AM | Mood | Morning check-in | 1-6 scale |
| Day 2, 9:30 PM | Alcohol consumed? | Evening check-in | Boolean |
| Day 3, 7:30 AM | Sleep quality (Night 2) | Sleep log | 1-10 scale |
| Day 3, 7:30 AM | Awakenings (Night 2) | Sleep log | Count |
| Day 3, 7:30 AM | Deep sleep % (Night 2) | Wearable (optional) | Percentage |
| Day 3, 7:30 AM | REM sleep % (Night 2) | Wearable (optional) | Percentage |
| Day 3, 10:00 AM | Energy, mood | Morning check-in | 1-6 scales |

## Expected Outcomes

### Hypothesis
- Alcohol suppresses REM sleep (-15 to -20%)
- Alcohol fragments sleep (+2 to +3 awakenings)
- Alcohol reduces deep sleep early in night (but may not show in total %)
- Next-day recovery: Lower energy (-1.0), worse mood (-0.8)

### Outcome Visualization

```
SLEEP ARCHITECTURE IMPACT (Wearable Users Only)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REM Sleep % (Optimal: 20-25%)

No Alcohol   ████████████████████░ 22.3%
Alcohol      ██████████████░░░░░░░ 16.8%  (-25% reduction) ✗

Deep Sleep % (Optimal: 15-25%)
No Alcohol   ███████████████░░░░░░ 18.1%
Alcohol      ████████████████░░░░░ 17.2%  (-5% reduction)

SLEEP FRAGMENTATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Number of Awakenings

No Alcohol   ████░░░░░░ 3.2 awakenings
Alcohol      ████████░░ 5.8 awakenings  (+81% increase) ✗

NEXT-DAY RECOVERY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Morning Energy (1-6 scale)

No Alcohol   ████████████░ 4.8
Alcohol      ███████░░░░░░ 3.7  (-23% lower)

"Felt Refreshed?" (% Yes)
No Alcohol   ████████████████████ 85% Yes
Alcohol      ████████░░░░░░░░░░░░ 35% Yes

GROUP C CROSSOVER (Within-Person)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Individual REM Sleep %

Night 1 (No Alcohol)  ████████████ 21.5%
Night 2 (Alcohol)     ███████░░░░░ 17.2%  (-4.3%) ✗

8 out of 10 participants showed REM reduction
when switching from no alcohol to moderate alcohol.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Key Insights Delivered
1. **REM suppression:** "Alcohol reduced your REM sleep by 25% (critical for memory, mood)"
2. **Sleep fragmentation:** "You woke up 81% more often after alcohol (even if you don't remember)"
3. **Recovery deficit:** "Next-day energy was 23% lower after alcohol, even with same total sleep time"
4. **Actionable takeaway:** "If you drink, finish 3+ hours before bed and limit to 1 drink max for better sleep architecture"

---

# Summary Table: All 10 Experiments

| # | Experiment | Groups | Duration | Primary Outcome | Expected Effect Size | Development Needed |
|---|------------|--------|----------|-----------------|---------------------|-------------------|
| 1 | Temperature | Cool/Warm/Hot | 2 nights | Sleep quality | +1.5 points (cool) | Add temp field to sleep log |
| 2 | Morning Light | 7AM/9AM/No light | 1 day + night | Energy, sleep quality | +1.2 energy, +0.8 quality (7AM) | Add light exposure field |
| 3 | Caffeine Cutoff | 12PM/2PM/Normal | 2 days | Sleep latency | -6 min (12PM cutoff) | Enhanced caffeine tracking |
| 4 | Wind-Down Protocol | Full/Partial/Control | 1 night | Sleep quality | +1.8 quality (full protocol) | Protocol checklist UI |
| 5 | Meal Timing | Early/Late/Switch | 2 nights | Digestive disruption, quality | 60% disruption (late) | Add meal time field |
| 6 | Nap Study | 20min/45min/No nap | 1 day + night | Nighttime sleep reduction | -40 min (45min nap) | Nap impact calculator |
| 7 | Blue Light Blocking | Blockers/Dim/Normal | 1 night | Sleepiness onset, latency | -55 min onset (blockers) | Minimal (just check-in fields) |
| 8 | Gratitude Journal | Gratitude/Neutral/Control | 1 night | Rumination, mood | -1.5 rumination, +1.0 mood | Journaling prompt UI |
| 9 | Breathing Exercise | Pre-bed/Morning/Control | 1 night | Sleep latency (pre-bed), energy (AM) | -4 min latency, +1.2 energy | Guided breathing exercise |
| 10 | Alcohol & Sleep | No alcohol/Moderate/Switch | 2 nights | REM sleep, awakenings | -25% REM, +81% awakenings | Minimal (just check-in fields) |

---

# Development Priority

## High Priority (Minimal Development, Maximum Impact)
1. **Experiment 1 (Temperature)** - Add 1 field to sleep log
2. **Experiment 3 (Caffeine)** - Enhance existing caffeine tracking
3. **Experiment 7 (Blue Light)** - Just check-in fields + glasses purchase
4. **Experiment 10 (Alcohol)** - Just check-in fields

## Medium Priority (Moderate Development)
5. **Experiment 2 (Morning Light)** - Add light exposure field
6. **Experiment 5 (Meal Timing)** - Add meal time field
7. **Experiment 8 (Gratitude)** - Create journaling prompt UI

## Lower Priority (More Development Time)
8. **Experiment 4 (Wind-Down)** - Protocol checklist UI
9. **Experiment 6 (Nap Study)** - Nap impact calculator
10. **Experiment 9 (Breathing)** - Guided breathing exercise (audio/visual)

---

# Next Steps

1. **Confirm experiment selection:** Martin reviews and selects 5-7 experiments to run
2. **Finalize development priorities:** Lock in features needed for selected experiments
3. **Coordinate logistics:** Ritz-Carlton coordination (meals, rooms, nap spaces)
4. **Prepare materials:** Blue light glasses, light meters, etc.
5. **Create participant communication:** Pre-retreat email explaining Zoe setup and retreat experiments

---

*This guide provides complete experimental protocols, group assignments, data collection plans, and expected outcomes for all 10 ad hoc retreat experiments. Each can be run during the 2-3 day retreat with minimal pre-existing data dependency.*
