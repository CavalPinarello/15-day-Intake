# 🍷 The Sleep Sacrifice Challenge - Complete Implementation Guide

## Core Concept

**The Challenge:** Give up ONE sleep disruptor for one night. Can you do it? Does it help?

**Why It Works:**
- ✅ Works with ANY level of app engagement (1 day to 10 days)
- ✅ No wearables needed (100% subjective)
- ✅ Fun, social, competitive
- ✅ Creates accountability & confessions
- ✅ Delivers personalized insights based on available data
- ✅ Easy to build (just logging + smart assignment)

---

## Implementation Strategy: 3 Tiers Based on Data Availability

### TIER 1: Minimal Data (Day 1-2 users)
**Who:** Just started using Zoe, minimal history

**Strategy:** Simple before/after comparison
- Night 1: Do your normal routine (establish baseline)
- Night 2: Sacrifice assigned item
- Compare the two nights

**Assignment Method:** User chooses their suspected worst habit
- App presents 6 options, they pick what they think hurts their sleep most

---

### TIER 2: Some Data (Day 3-7 users)
**Who:** Has logged a few nights, some patterns emerging

**Strategy:** Pattern-based smart assignment
- Analyze their logged data for red flags
- Assign sacrifice based on detected patterns
- Compare Night 2 vs their personal average (past 3-7 nights)

**Assignment Method:** Algorithm suggests, but user can override

---

### TIER 3: Rich Data (Day 8-10 users)
**Who:** Completed most/all of Zoe journey

**Strategy:** Personalized impact prediction
- Use full journey data + gateway analysis
- Show correlation: "Your sleep is 1.8 points lower on nights with late caffeine"
- Assign sacrifice with BIGGEST predicted impact
- Compare against full historical baseline

**Assignment Method:** Highly personalized recommendation with proof

---

## The 6 Sacrifice Options

| Sacrifice | Detection Logic | Data Required | Tier |
|-----------|----------------|---------------|------|
| **No alcohol after 6 PM** | Has logged alcohol in past 3+ days | Alcohol tracking | 2-3 |
| **No caffeine after 12 PM** | Has logged caffeine after 12 PM in past 3+ days | Caffeine tracking | 2-3 |
| **No phone after 9 PM** | Self-reported or common habit | None (everyone has phones) | 1-3 |
| **No late-night snack after 8 PM** | Has logged late meals | Meal timing (optional) | 2-3 |
| **Consistent bedtime (10 PM ±15 min)** | Bedtime variance > 1 hour in past week | Sleep log bedtime | 2-3 |
| **No screens in bed** | Self-reported or common habit | None (universal) | 1-3 |

---

## Smart Assignment Algorithm

### Step 1: Check Available Data
```
IF user has < 3 days of data:
  → TIER 1: User chooses from all 6 options

ELSE IF user has 3-7 days of data:
  → TIER 2: Analyze patterns, suggest top 2-3 options

ELSE IF user has 8+ days of data:
  → TIER 3: Calculate correlations, recommend #1 option with proof
```

### Step 2: Pattern Detection (Tier 2-3)

**Alcohol Detection:**
```
Query: user_sleep_data + daily_checkins for past 7 days
IF alcohol logged on 3+ nights:
  Calculate: Avg sleep quality (alcohol nights) vs (no-alcohol nights)
  IF alcohol nights have -0.5+ lower quality:
    → Flag: "Alcohol may be disrupting your sleep"
    → Suggest: "No alcohol after 6 PM"
```

**Caffeine Detection:**
```
Query: midday/evening check-ins for caffeine timing
IF caffeine logged after 12 PM on 3+ days:
  Calculate: Avg sleep latency (late caffeine) vs (no late caffeine)
  IF late caffeine nights have +5min latency:
    → Flag: "Late caffeine linked to longer sleep onset"
    → Suggest: "No caffeine after 12 PM"
```

**Bedtime Consistency:**
```
Query: sleep_log bedtime for past 7 days
Calculate: Standard deviation of bedtimes
IF stddev > 60 minutes:
  → Flag: "Irregular bedtime may be affecting sleep quality"
  → Suggest: "Consistent bedtime (10 PM ±15 min)"
```

**Screen Time (Default):**
```
IF no other patterns detected:
  → Default suggest: "No phone after 9 PM" (universal issue)
```

### Step 3: Personalized Messaging

**Tier 1 (Choose Your Own):**
```
"Pick Your Sleep Sacrifice"

You're joining the Sleep Sacrifice Challenge! Choose ONE habit
to give up tomorrow night. Which do you think hurts your sleep most?

☐ No alcohol after 6 PM
☐ No caffeine after 12 PM
☐ No phone after 9 PM
☐ No late-night snack after 8 PM
☐ Consistent bedtime (10 PM ±15 min)
☐ No screens in bed

[CHOOSE]
```

**Tier 2 (Smart Suggestion):**
```
"Your Sleep Sacrifice Assignment"

Based on your past week, we noticed:
🔴 You've had caffeine after 2 PM on 5 out of 6 days
📊 Those nights, your sleep latency averaged 22 minutes
📊 Nights without late caffeine: 14 minutes

YOUR CHALLENGE: No caffeine after 12 PM tomorrow

Think you can do it?
[ACCEPT CHALLENGE] [PICK DIFFERENT]
```

**Tier 3 (Data-Driven Prediction):**
```
"Your Personalized Sleep Sacrifice"

Martin, we analyzed your 10-day journey data:

📊 Nights WITH alcohol (4 nights):
   Sleep quality: 6.2/10
   Awakenings: 4.5x per night

📊 Nights WITHOUT alcohol (6 nights):
   Sleep quality: 7.8/10
   Awakenings: 2.1x per night

📈 PREDICTED IMPACT: +1.6 sleep quality improvement

YOUR CHALLENGE: No alcohol after 6 PM tomorrow

Ready to test it?
[I'M IN] [SHOW OTHER OPTIONS]
```

---

## Retreat Implementation: 2-Night Protocol

### DAY 1 (Arrival Day - Evening)

**5:00 PM: Assignment Time**
- Martin triggers "Sleep Sacrifice Challenge" in admin panel
- Algorithm assigns each participant based on their tier
- Push notification sent

**6:00 PM: Dinner + Announcement**
- Martin explains challenge at dinner (5 min talk)
- "Tonight is your NORMAL night - do everything you usually do"
- "We need a baseline to compare against tomorrow"

**9:30 PM: Baseline Check-In**
- App prompts: "Let's establish your baseline"

```
BASELINE LOGGING (Night 1)

How did you spend your evening?

Alcohol:
☐ None
☐ 1 drink
☐ 2 drinks
☐ 3+ drinks
Last drink time: [____]

Caffeine today:
☐ None after noon
☐ Had caffeine after 12 PM
☐ Had caffeine after 2 PM
☐ Had caffeine after 4 PM
Last caffeine: [____]

Phone/Screens:
What time did you last look at your phone? [____]
Did you watch TV in bed? ☐ Yes ☐ No

Food:
What time did you finish dinner? [____]
Late-night snack? ☐ Yes ☐ No

Bedtime:
What time are you going to bed? [____]

How do you feel right now?
Energy: [1-6 slider]
Stress: [1-5 slider]
```

**NIGHT 1: Sleep normally**

---

### DAY 2 (Morning)

**7:30 AM: Morning Check-In**
```
MORNING LOG (Night 1 - Baseline)

How did you sleep last night?
Sleep quality: [1-10 slider] ⭐⭐⭐⭐⭐⭐⭐☆☆☆

How long did it take you to fall asleep?
☐ < 10 minutes
☐ 10-20 minutes
☐ 20-30 minutes
☐ 30+ minutes

How many times did you wake up? [____]

How do you feel this morning?
Energy: [1-6 slider]
Mood: [1-6 slider]
Refreshed? ☐ Yes ☐ Somewhat ☐ No

[SUBMIT]
```

**9:00 AM: Breakfast Reveal**
- Martin shows aggregate baseline data on screen:
  - "15 people had alcohol last night"
  - "22 people had caffeine after 12 PM"
  - "28 people looked at their phone after 9 PM"
  - Average sleep quality: 6.8/10

---

### DAY 2 (Evening - SACRIFICE NIGHT)

**12:00 PM: Reminder Notification**
```
🚨 REMINDER: Tonight is SACRIFICE NIGHT! 🚨

Your challenge: [No caffeine after 12 PM]

This is your last chance for caffeine!
(You accepted this challenge - can you do it?)

Tips:
• Switch to decaf after noon
• Try herbal tea instead
• Remember: it's just one night!

Good luck! 💪
```

**3:00 PM: Accountability Check-In (Optional Mid-Day)**
```
QUICK CHECK: How's it going?

Have you successfully avoided [caffeine after 12 PM] so far?
☐ Yes! Still going strong 💪
☐ I slipped up... (confess below)
☐ Tempted but resisting

[Optional: Share your struggle]
_______________________________
```

**6:00 PM: Evening Motivation**
```
🌙 SACRIFICE NIGHT UPDATE

Great job so far! You're in the home stretch.

20 out of 28 people are successfully holding strong!

Remember your challenge:
🚫 [No caffeine after 12 PM]

Just a few more hours until bed. You got this!
```

**9:30 PM: Final Compliance Check**
```
🏁 SACRIFICE NIGHT: Final Check-In

Did you SUCCESSFULLY complete your sacrifice?

Your challenge: [No caffeine after 12 PM]

☐ YES! I did it! 💪 (No caffeine after 12 PM all day)
☐ I tried but failed (confession time)

[IF FAILED]
What time did you break? [____]
Why did you break? (No judgment!)
☐ Forgot about it
☐ Too tempting
☐ Felt tired, needed energy
☐ Social situation (hard to say no)
☐ Other: _______

How hard was this challenge?
Difficulty: [1-10 slider]
1 = Easy, didn't miss it
10 = Extremely difficult

Same baseline questions as Night 1:
[Alcohol, food timing, phone time, bedtime, energy, stress]

[SUBMIT]
```

**NIGHT 2: Sleep with sacrifice in place**

---

### DAY 3 (Morning - RESULTS)

**7:30 AM: Morning Results Log**
```
🌅 SACRIFICE NIGHT RESULTS

How did you sleep after your sacrifice?

Sleep quality: [1-10 slider] ⭐⭐⭐⭐⭐⭐⭐⭐☆☆

How long did it take you to fall asleep?
☐ < 10 minutes
☐ 10-20 minutes
☐ 20-30 minutes
☐ 30+ minutes

How many times did you wake up? [____]

How do you feel this morning?
Energy: [1-6 slider]
Mood: [1-6 slider]
Refreshed? ☐ Yes ☐ Somewhat ☐ No

Do you think the sacrifice helped?
☐ Definitely helped!
☐ Maybe helped
☐ No difference
☐ Actually made it worse

Would you do this sacrifice again at home?
☐ Yes, I'm converted!
☐ Maybe occasionally
☐ No way

[SUBMIT]
```

**9:00 AM: Breakfast Results Presentation**

Martin shows aggregate results on big screen:

```
🎉 SLEEP SACRIFICE RESULTS 🎉

SUCCESS RATE:
✅ 23 out of 28 completed their sacrifice (82%)
❌ 5 people confessed to breaking

CONFESSIONS (Anonymous):
• "I made it to 8 PM then caved and had espresso. Worth it? No."
• "Forgot about the challenge and drank wine at dinner. Oops!"
• "Phone was charging in bathroom. Went to 'check the time' at 11 PM... ended up scrolling for 30 min"

───────────────────────────────────────

RESULTS BY SACRIFICE TYPE:

🚫 NO CAFFEINE AFTER 12 PM (n=8)
   Baseline (Night 1): 6.5/10 sleep quality
   Sacrifice (Night 2): 7.8/10 sleep quality
   📈 Improvement: +1.3 points (20% better!)
   💤 Sleep latency: -6 minutes average

🚫 NO ALCOHOL AFTER 6 PM (n=6)
   Baseline: 6.2/10
   Sacrifice: 7.6/10
   📈 Improvement: +1.4 points
   🌙 Awakenings: -2.1 per night

📱 NO PHONE AFTER 9 PM (n=7)
   Baseline: 6.9/10
   Sacrifice: 7.4/10
   📈 Improvement: +0.5 points
   💤 Sleep latency: -4 minutes

🛏️ CONSISTENT BEDTIME (n=4)
   Baseline: 6.4/10
   Sacrifice: 7.9/10
   📈 Improvement: +1.5 points (best result!)

🍕 NO LATE-NIGHT SNACK (n=2)
   Baseline: 7.0/10
   Sacrifice: 7.2/10
   📈 Improvement: +0.2 points (minimal)

📺 NO SCREENS IN BED (n=3)
   Baseline: 6.7/10
   Sacrifice: 7.5/10
   📈 Improvement: +0.8 points

───────────────────────────────────────

🏆 BIGGEST WINNERS:

Individual Improvements:
1. Sarah: +2.5 points (consistent bedtime)
2. Mike: +2.1 points (no alcohol)
3. Jessica: +1.9 points (no caffeine)

───────────────────────────────────────

💡 KEY INSIGHT:

People who successfully completed their sacrifice
improved sleep quality by +1.2 points average.

People who broke their sacrifice:
improved by only +0.3 points.

Compliance matters!
```

---

## Data Schema & Implementation

### New Convex Tables

#### `sleep_sacrifice_challenges`
```typescript
{
  _id: Id<"sleep_sacrifice_challenges">,
  user_id: Id<"users">,
  retreat_id: string, // "half-moon-bay-jan-2026"

  // Assignment
  assigned_sacrifice: "no_alcohol" | "no_caffeine" | "no_phone" | "no_snack" | "consistent_bedtime" | "no_screens",
  assignment_tier: 1 | 2 | 3, // Data availability tier
  assignment_reason: string, // Why this sacrifice was chosen
  assigned_at: number, // Unix timestamp

  // User acceptance
  accepted: boolean,
  accepted_at?: number,
  custom_sacrifice?: string, // If they picked different

  // Baseline Night (Night 1)
  baseline_logged: boolean,
  baseline_alcohol: "none" | "1_drink" | "2_drinks" | "3_plus",
  baseline_alcohol_last_time?: string, // "8:30 PM"
  baseline_caffeine_after_noon: boolean,
  baseline_caffeine_last_time?: string,
  baseline_phone_last_time?: string,
  baseline_snack: boolean,
  baseline_bedtime?: string,
  baseline_energy: number, // 1-6
  baseline_stress: number, // 1-5

  baseline_sleep_quality?: number, // 1-10
  baseline_sleep_latency?: string, // "10-20 minutes"
  baseline_awakenings?: number,
  baseline_morning_energy?: number, // 1-6
  baseline_morning_mood?: number, // 1-6
  baseline_refreshed?: boolean,

  // Sacrifice Night (Night 2)
  sacrifice_logged: boolean,
  sacrifice_successful: boolean, // Did they actually do it?
  sacrifice_break_time?: string, // When they broke (if failed)
  sacrifice_break_reason?: string,
  sacrifice_difficulty: number, // 1-10

  sacrifice_alcohol?: string,
  sacrifice_caffeine_after_noon?: boolean,
  sacrifice_phone_last_time?: string,
  sacrifice_snack?: boolean,
  sacrifice_bedtime?: string,
  sacrifice_energy?: number,
  sacrifice_stress?: number,

  sacrifice_sleep_quality?: number,
  sacrifice_sleep_latency?: string,
  sacrifice_awakenings?: number,
  sacrifice_morning_energy?: number,
  sacrifice_morning_mood?: number,
  sacrifice_refreshed?: boolean,

  // Results
  improvement_calculated: boolean,
  sleep_quality_delta?: number, // Night 2 - Night 1
  perceived_help: "definitely" | "maybe" | "no_difference" | "worse",
  would_do_again: "yes" | "maybe" | "no",

  created_at: number,
  updated_at: number,
}
```

### Key Convex Mutations

#### `assignSleepSacrifice`
```typescript
// Admin-triggered: Assign sacrifice to all retreat participants

export const assignSleepSacrifice = mutation({
  args: { retreat_id: v.string() },
  handler: async (ctx, { retreat_id }) => {
    // Get all retreat participants
    const participants = await ctx.db
      .query("retreat_participants")
      .withIndex("by_retreat", q => q.eq("retreat_id", retreat_id))
      .collect();

    for (const participant of participants) {
      // Determine tier based on user data
      const tier = await determineUserTier(ctx, participant.user_id);

      // Get smart sacrifice assignment
      const assignment = await getSmartSacrifice(ctx, participant.user_id, tier);

      // Create challenge record
      await ctx.db.insert("sleep_sacrifice_challenges", {
        user_id: participant.user_id,
        retreat_id,
        assigned_sacrifice: assignment.sacrifice,
        assignment_tier: tier,
        assignment_reason: assignment.reason,
        assigned_at: Date.now(),
        accepted: false,
        baseline_logged: false,
        sacrifice_logged: false,
        sacrifice_successful: false,
        improvement_calculated: false,
        created_at: Date.now(),
        updated_at: Date.now(),
      });

      // Send push notification with assignment
      await sendSacrificeAssignment(participant.user_id, assignment);
    }

    return { success: true, assigned: participants.length };
  },
});
```

#### `determineUserTier`
```typescript
async function determineUserTier(ctx, user_id: Id<"users">): Promise<1 | 2 | 3> {
  // Count how many days of sleep log data
  const sleepLogs = await ctx.db
    .query("user_sleep_data")
    .withIndex("by_user", q => q.eq("user_id", user_id))
    .collect();

  const daysLogged = sleepLogs.length;

  if (daysLogged < 3) return 1; // Tier 1: Minimal data
  if (daysLogged < 8) return 2; // Tier 2: Some data
  return 3; // Tier 3: Rich data
}
```

#### `getSmartSacrifice`
```typescript
async function getSmartSacrifice(
  ctx,
  user_id: Id<"users">,
  tier: 1 | 2 | 3
): Promise<{ sacrifice: string; reason: string }> {

  if (tier === 1) {
    // Tier 1: Default to universal issue (phone)
    return {
      sacrifice: "no_phone",
      reason: "Most people benefit from reducing evening screen time",
    };
  }

  // Tier 2-3: Analyze patterns

  // Check alcohol pattern
  const alcoholNights = await getRecentCheckIns(ctx, user_id, 7);
  const alcoholCount = alcoholNights.filter(n => n.alcohol_consumed).length;

  if (alcoholCount >= 3) {
    const alcoholQuality = avgQuality(alcoholNights.filter(n => n.alcohol_consumed));
    const noAlcoholQuality = avgQuality(alcoholNights.filter(n => !n.alcohol_consumed));

    if (noAlcoholQuality - alcoholQuality > 0.5) {
      return {
        sacrifice: "no_alcohol",
        reason: `Your sleep is ${(noAlcoholQuality - alcoholQuality).toFixed(1)} points better on nights without alcohol`,
      };
    }
  }

  // Check caffeine pattern
  const caffeineData = await getRecentCaffeineData(ctx, user_id, 7);
  const lateCaffeineNights = caffeineData.filter(n => n.caffeine_after_12pm).length;

  if (lateCaffeineNights >= 3) {
    const lateCaffeineLatency = avgLatency(caffeineData.filter(n => n.caffeine_after_12pm));
    const noCaffeineLatency = avgLatency(caffeineData.filter(n => !n.caffeine_after_12pm));

    if (lateCaffeineLatency - noCaffeineLatency > 5) {
      return {
        sacrifice: "no_caffeine",
        reason: `Late caffeine adds ${(lateCaffeineLatency - noCaffeineLatency).toFixed(0)} minutes to your sleep latency`,
      };
    }
  }

  // Check bedtime consistency
  const sleepLogs = await getRecentSleepLogs(ctx, user_id, 7);
  const bedtimes = sleepLogs.map(log => log.bedtime_timestamp);
  const bedtimeStdDev = calculateStdDev(bedtimes);

  if (bedtimeStdDev > 3600000) { // > 1 hour variance
    return {
      sacrifice: "consistent_bedtime",
      reason: `Your bedtime varies by ${(bedtimeStdDev / 3600000).toFixed(1)} hours - consistency could help`,
    };
  }

  // Default fallback
  return {
    sacrifice: "no_phone",
    reason: "Reducing evening screen time is a great starting point",
  };
}
```

#### `logBaselineNight`
```typescript
export const logBaselineNight = mutation({
  args: {
    challenge_id: v.id("sleep_sacrifice_challenges"),
    alcohol: v.string(),
    alcohol_last_time: v.optional(v.string()),
    caffeine_after_noon: v.boolean(),
    caffeine_last_time: v.optional(v.string()),
    phone_last_time: v.string(),
    snack: v.boolean(),
    bedtime: v.string(),
    energy: v.number(),
    stress: v.number(),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.challenge_id, {
      baseline_logged: true,
      baseline_alcohol: args.alcohol,
      baseline_alcohol_last_time: args.alcohol_last_time,
      baseline_caffeine_after_noon: args.caffeine_after_noon,
      baseline_caffeine_last_time: args.caffeine_last_time,
      baseline_phone_last_time: args.phone_last_time,
      baseline_snack: args.snack,
      baseline_bedtime: args.bedtime,
      baseline_energy: args.energy,
      baseline_stress: args.stress,
      updated_at: Date.now(),
    });

    return { success: true };
  },
});
```

#### `logBaselineMorning`
```typescript
export const logBaselineMorning = mutation({
  args: {
    challenge_id: v.id("sleep_sacrifice_challenges"),
    sleep_quality: v.number(),
    sleep_latency: v.string(),
    awakenings: v.number(),
    morning_energy: v.number(),
    morning_mood: v.number(),
    refreshed: v.boolean(),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.challenge_id, {
      baseline_sleep_quality: args.sleep_quality,
      baseline_sleep_latency: args.sleep_latency,
      baseline_awakenings: args.awakenings,
      baseline_morning_energy: args.morning_energy,
      baseline_morning_mood: args.morning_mood,
      baseline_refreshed: args.refreshed,
      updated_at: Date.now(),
    });

    return { success: true };
  },
});
```

#### `logSacrificeCompliance`
```typescript
export const logSacrificeCompliance = mutation({
  args: {
    challenge_id: v.id("sleep_sacrifice_challenges"),
    successful: v.boolean(),
    break_time: v.optional(v.string()),
    break_reason: v.optional(v.string()),
    difficulty: v.number(),
    // ... same fields as baseline
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.challenge_id, {
      sacrifice_logged: true,
      sacrifice_successful: args.successful,
      sacrifice_break_time: args.break_time,
      sacrifice_break_reason: args.break_reason,
      sacrifice_difficulty: args.difficulty,
      // ... update other fields
      updated_at: Date.now(),
    });

    return { success: true };
  },
});
```

#### `calculateSacrificeResults`
```typescript
export const calculateSacrificeResults = mutation({
  args: { retreat_id: v.string() },
  handler: async (ctx, { retreat_id }) => {
    // Get all challenges for this retreat
    const challenges = await ctx.db
      .query("sleep_sacrifice_challenges")
      .withIndex("by_retreat", q => q.eq("retreat_id", retreat_id))
      .filter(q => q.eq(q.field("baseline_logged"), true))
      .filter(q => q.eq(q.field("sacrifice_logged"), true))
      .collect();

    // Calculate improvements for each
    for (const challenge of challenges) {
      const delta = challenge.sacrifice_sleep_quality - challenge.baseline_sleep_quality;

      await ctx.db.patch(challenge._id, {
        improvement_calculated: true,
        sleep_quality_delta: delta,
        updated_at: Date.now(),
      });
    }

    // Generate aggregate stats
    const stats = {
      total_participants: challenges.length,
      successful_count: challenges.filter(c => c.sacrifice_successful).length,
      avg_improvement_success: avgDelta(challenges.filter(c => c.sacrifice_successful)),
      avg_improvement_failed: avgDelta(challenges.filter(c => !c.sacrifice_successful)),

      by_sacrifice_type: {
        no_caffeine: calculateByType(challenges, "no_caffeine"),
        no_alcohol: calculateByType(challenges, "no_alcohol"),
        no_phone: calculateByType(challenges, "no_phone"),
        consistent_bedtime: calculateByType(challenges, "consistent_bedtime"),
        no_snack: calculateByType(challenges, "no_snack"),
        no_screens: calculateByType(challenges, "no_screens"),
      },

      top_performers: challenges
        .sort((a, b) => b.sleep_quality_delta - a.sleep_quality_delta)
        .slice(0, 3),
    };

    return stats;
  },
});
```

---

## UI Components (iOS, Web)

### iOS: Assignment Screen
```swift
struct SacrificeChallengeAssignmentView: View {
    let assignment: SacrificeAssignment
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("🍷 Sleep Sacrifice Challenge")
                .font(.system(size: 32, weight: .bold))

            Text("Give up ONE habit for better sleep")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Tier-specific messaging
            if assignment.tier == 3 {
                // Data-driven recommendation
                VStack(alignment: .leading, spacing: 15) {
                    Text("We analyzed your 10-day journey:")
                        .font(.headline)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("With \(assignment.trigger)")
                            Text("Sleep Quality: \(assignment.baseline_avg, specifier: "%.1f")/10")
                                .font(.caption)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Without \(assignment.trigger)")
                            Text("Sleep Quality: \(assignment.improved_avg, specifier: "%.1f")/10")
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                    Text("Predicted Impact: +\(assignment.predicted_improvement, specifier: "%.1f") points")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            } else if assignment.tier == 2 {
                // Pattern-based suggestion
                Text(assignment.reason)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                // Tier 1: Let them choose
                Text("Pick the habit you think hurts your sleep most:")
                    .multilineTextAlignment(.center)
            }

            // The sacrifice
            VStack(spacing: 10) {
                Text("YOUR CHALLENGE:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(sacrificeTitle(assignment.sacrifice))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(theme.accent)
            }
            .padding()
            .background(theme.cardBackground)
            .cornerRadius(15)

            // CTA buttons
            HStack(spacing: 15) {
                Button("I'M IN! 💪") {
                    acceptChallenge()
                }
                .buttonStyle(PrimaryButtonStyle())

                if assignment.tier > 1 {
                    Button("Pick Different") {
                        showDetails = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .padding()
        .sheet(isPresented: $showDetails) {
            AllSacrificeOptionsView()
        }
    }
}
```

### iOS: Baseline Check-In
```swift
struct BaselineCheckInView: View {
    @State private var alcoholAmount = "none"
    @State private var alcoholLastTime = Date()
    @State private var hadCaffeineAfterNoon = false
    @State private var caffeineLastTime = Date()
    @State private var phoneLastTime = Date()
    @State private var hadSnack = false
    @State private var bedtime = Date()
    @State private var energy: Double = 3
    @State private var stress: Double = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("Baseline Night")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Tonight, do everything NORMALLY. We need a baseline to compare against tomorrow.")
                    .foregroundColor(.secondary)

                Divider()

                // Alcohol
                SectionHeader(title: "Alcohol", icon: "🍷")
                Picker("Amount", selection: $alcoholAmount) {
                    Text("None").tag("none")
                    Text("1 drink").tag("1_drink")
                    Text("2 drinks").tag("2_drinks")
                    Text("3+ drinks").tag("3_plus")
                }
                .pickerStyle(.segmented)

                if alcoholAmount != "none" {
                    TimePicker(
                        title: "Last drink time",
                        time: $alcoholLastTime
                    )
                }

                // Caffeine
                SectionHeader(title: "Caffeine", icon: "☕")
                Toggle("Had caffeine after noon?", isOn: $hadCaffeineAfterNoon)

                if hadCaffeineAfterNoon {
                    TimePicker(
                        title: "Last caffeine",
                        time: $caffeineLastTime
                    )
                }

                // Phone
                SectionHeader(title: "Screens", icon: "📱")
                TimePicker(
                    title: "Last looked at phone",
                    time: $phoneLastTime
                )

                // Snack
                SectionHeader(title: "Food", icon: "🍕")
                Toggle("Late-night snack?", isOn: $hadSnack)

                // Bedtime
                SectionHeader(title: "Bedtime", icon: "🛏️")
                TimePicker(
                    title: "Going to bed at",
                    time: $bedtime
                )

                // Energy & Stress
                SectionHeader(title: "How do you feel?", icon: "💭")

                SliderWithLabel(
                    title: "Energy",
                    value: $energy,
                    range: 1...6,
                    labels: ["Exhausted", "Energized"]
                )

                SliderWithLabel(
                    title: "Stress",
                    value: $stress,
                    range: 1...5,
                    labels: ["Calm", "Very Stressed"]
                )

                Button("Submit Baseline") {
                    submitBaseline()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top)
            }
            .padding()
        }
    }
}
```

### Web Dashboard: Admin Results View
```typescript
function SacrificeChallengeResults({ retreatId }: { retreatId: string }) {
  const results = useQuery(api.sleepSacrifice.getResults, { retreat_id: retreatId });

  if (!results) return <Spinner />;

  return (
    <div className="sacrifice-results">
      <h1>🍷 Sleep Sacrifice Challenge Results</h1>

      {/* Success Rate */}
      <div className="stats-card">
        <h2>Success Rate</h2>
        <div className="stat-large">
          {results.successful_count} / {results.total_participants}
          <span className="percentage">
            ({Math.round((results.successful_count / results.total_participants) * 100)}%)
          </span>
        </div>
        <p>Successfully completed their sacrifice</p>
      </div>

      {/* Confessions */}
      {results.confessions.length > 0 && (
        <div className="confessions-card">
          <h2>Anonymous Confessions</h2>
          {results.confessions.map((confession, i) => (
            <div key={i} className="confession">
              <p>"{confession.text}"</p>
              <span className="time">Broke at {confession.time}</span>
            </div>
          ))}
        </div>
      )}

      {/* Results by Type */}
      <div className="results-grid">
        {Object.entries(results.by_sacrifice_type).map(([type, data]) => (
          <SacrificeTypeCard key={type} type={type} data={data} />
        ))}
      </div>

      {/* Top Performers */}
      <div className="leaderboard">
        <h2>🏆 Biggest Winners</h2>
        {results.top_performers.map((performer, i) => (
          <div key={i} className="performer">
            <span className="rank">{i + 1}</span>
            <span className="name">{performer.name}</span>
            <span className="improvement">
              +{performer.sleep_quality_delta.toFixed(1)} points
            </span>
            <span className="sacrifice">{performer.sacrifice}</span>
          </div>
        ))}
      </div>

      {/* Export Button */}
      <button onClick={() => exportToPDF(results)}>
        Export Results to PDF
      </button>
    </div>
  );
}
```

---

## Timeline Summary

**Pre-Retreat (1 week before):**
- Build schema, mutations, UI components
- Test with sample data
- Prepare Martin's admin dashboard

**Day 1 (Arrival, 5:00 PM):**
- Martin clicks "Assign Sleep Sacrifice Challenge"
- Algorithm runs, assigns everyone based on their tier
- Push notifications sent

**Day 1 (6:00 PM):**
- Martin explains challenge at dinner
- "Tonight = normal, tomorrow = sacrifice"

**Day 1 (9:30 PM):**
- Baseline check-in (alcohol, caffeine, phone, etc.)

**Day 2 (7:30 AM):**
- Baseline morning log (sleep quality, latency, etc.)

**Day 2 (9:00 AM):**
- Martin shows aggregate baseline stats at breakfast

**Day 2 (Throughout day):**
- Reminders sent (12 PM, 6 PM)
- Optional mid-day check-in

**Day 2 (9:30 PM):**
- Sacrifice compliance check (did you do it?)

**Day 3 (7:30 AM):**
- Sacrifice morning log (results)

**Day 3 (9:00 AM):**
- RESULTS PRESENTATION at breakfast
- Individual + aggregate insights
- Confessions shared (anonymous)
- Winners celebrated

---

## Why This Works

✅ **Adaptive:** Works with 1 day or 10 days of data
✅ **Personalized:** Algorithm suggests best sacrifice per person
✅ **Social:** Confessions, leaderboard, group bonding
✅ **Actionable:** Clear takeaway ("cut caffeine by noon!")
✅ **Measurable:** Before/after comparison, clear results
✅ **Fun:** Competitive, confessional, lighthearted
✅ **Memorable:** Stories to tell friends back home
✅ **Investor-worthy:** Shows Zoe's smart personalization

This is the perfect retreat experiment!
