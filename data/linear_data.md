# Linear Data Export

**Project:** ZOE scope
**Fetched:** 2025-11-09 19:13
**Total Issues:** 100
**Main Components:** 5

---

## Main Components

### SLE-130: Component 1: 14-Day Onboarding Journey

- **State:** Backlog
- **Priority:** 1
- **Tasks:** 15

#### Tasks

- **SLE-131** - Backend schema (84 questions + answers)
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Database schema for 84 questions across 14 themed groups  **Requirements:**  * 14 question groups (1 per day) * Question types: Multiple choice, sliders (4-12 hour ranges), yes/no, freque...

- **SLE-132** - Daily unlock mechanism (time-gated)
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Time-based unlock system for daily question groups  **Requirements:**  * User sets preferred unlock time (e.g., 8:00 AM) * Groups unlock sequentially (cannot skip ahead) * Day 1 available...

- **SLE-133** - Question UI components (9 input types)
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Reusable question input components  **Input Types:**  1. **Slider (numeric range):** 4-12 hours, with labels at endpoints 2. **Multiple choice (single select):** Radio buttons with visual...

- **SLE-134** - 14 group screens with themed backgrounds
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Visually themed screens for each question group  **Design System:**  * Unique gradient backgrounds per theme (see spec for color schemes) * Ambient animated backgrounds (subtle particles,...

- **SLE-135** - Insight generation logic (42 insights)
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Conditional logic engine for personalized insights (3 per group = 42 total)  **CRITICAL COMPONENT - High complexity**  **Structure per Group:**  * 💡 Personalized Insight: 4-6 variants bas...

- **SLE-136** - Conditional logic engine
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Core decision engine for insight variant selection  **Algorithm:**  1. Parse user's answers for the group 2. Identify most critical issue (priority ranking) 3. Select highest-priority ins...

- **SLE-137** - Progress tracking UI
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Visual progress indicators throughout onboarding  **Components:**  * Main progress bar: "Day 4/14" with filled circles * Within-group progress: "Question 3 of 6" * Completion celebrations...

- **SLE-138** - Swipeable card interface
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Instagram/TikTok-style vertical swipe navigation  **User Flow:**  1. User completes last question in group 2. Swipes up → Celebration screen 3. Swipes up → Insight Card 1 (💡 Personalized)...

- **SLE-139** - Celebration animations
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Positive reinforcement after completing each group  **Animations:**  * Confetti burst on group completion * Check mark animation with sound * Progress circle fill animation * Subtle parti...

- **SLE-140** - Notification scheduling (daily unlock)
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Push notifications for daily group unlocks  **Notification Types:**  1. **Daily unlock:** "Day 4 is ready! 🌙" (at user's chosen time) 2. **Reminder:** "Don't forget Day 3" (if skipped for...

- **SLE-141** - Testing & refinement
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Comprehensive testing of 14-day onboarding flow  **Test Cases:**  * All 84 questions render correctly * All input types work on iOS/Android * Unlock mechanism triggers at correct times * ...

- **SLE-142** - Content: Write 42 insight variants
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Write all insight card content with conditional variants  **Structure:**  * 14 groups × 3 cards = 42 insight cards * Each card has 3-6 conditional variants * Total: \~200-250 unique text ...

- **SLE-143** - Content: Map conditional logic
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Map which insight variants show for which answer patterns  **Deliverables:**  * Decision trees for all 42 insights * Priority rankings for overlapping conditions * Edge case handling (e.g...

- **SLE-144** - Content: Medical/scientific review
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Ensure all content is medically accurate and evidence-based  **Requirements:**  * Review all 200+ text snippets for accuracy * Cite research for key claims * Ensure disclaimers where appr...

- **SLE-145** - Content: User testing & iteration
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-130
  - Description: **Purpose:** Test content clarity and effectiveness with real users  **Testing Protocol:**  1. Recruit 10 diverse test users 2. Have them complete onboarding 3. Interview about insight clarity 4. Meas...


---

### SLE-146: Component 2: Daily App Use

- **State:** Backlog
- **Priority:** 1
- **Tasks:** 28

#### Tasks

- **SLE-147** - Morning: Metric card UI components
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Display cards for 6 key sleep metrics with % change vs 30-day average  **Metrics:**  1. Total Sleep Time: 7h 32m (↑ 8.2%) 2. Bedtime Regularity: Variance 28 min (↑ 12.5%) 3. Sleep Latency...

- **SLE-148** - Morning: 30-day baseline calculation logic
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Calculate rolling 30-day averages for all metrics  **Algorithm:**  * Rolling window: Past 30 days of data * Handle missing days gracefully * Minimum 7 days of data before showing comparis...

- **SLE-149** - Morning: % change calculation engine
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Calculate percentage change vs baseline with proper formatting  **Logic:**  * % change = ((current - baseline) / baseline) \* 100 * Direction indicators: ↑ ↓ → (using thresholds) * Thresh...

- **SLE-150** - Morning: Sleep architecture visualization
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Visual breakdown of sleep stages with expanded detail view  **Main View:**  * Horizontal bar showing proportions: \[Deep\]\[Light\]\[REM\]\[Awake\] * Percentages: 18% / 52% / 22% / 8% * C...

- **SLE-151** - Morning: Charge (HRV) calculation
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** HRV-based recovery score (similar to Whoop/Oura)  **Algorithm:**  * Compare today's morning HRV to yesterday's * Also show % vs 30-day average * Status: "Ready for activity" or "Prioritiz...

- **SLE-152** - Morning: Trend indicators & colors
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Visual indicators for metric improvements/declines  **Icons:**  * ↑ Green: Improvement * ↓ Red: Decline (or green if lower is better, e.g., RHR) * → Yellow: No significant change * ⚠️ Ora...

- **SLE-153** - Morning: Mini trend chart widgets
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** 7-day sparkline charts for quick visual trends  **Implementation:**  * Small line charts (100px × 30px) * Show past 7 days * No axes labels (just visual pattern) * Color gradient based on...

- **SLE-154** - Morning: Ambient content integration
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Morning-themed audio and visual ambiance  **Audio:**  * Forest Dawn (birds chirping, gentle morning sounds) * Ocean Sunrise (waves, seagulls) * User selectable, or random daily * Auto-pla...

- **SLE-155** - Morning: Apple Health data fetching
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Fetch sleep and health data from Apple HealthKit  **Data Points:**  * Sleep analysis: asleep time, in-bed time, sleep stages * HRV: morning reading (within 1 hour of wake) * Resting heart...

- **SLE-156** - Morning: Data aggregation & processing
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Transform raw HealthKit data into usable metrics  **Processing Steps:**  1. Fetch raw sleep samples from HealthKit 2. Aggregate into sleep duration, stages 3. Calculate derived metrics (e...

- **SLE-157** - Morning: Animation and transitions
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Smooth, delightful animations for morning check-in  **Animations:**  * Metric cards: Slide in from bottom with stagger * % change numbers: Count-up animation * Trend arrows: Bounce in * S...

- **SLE-158** - Morning: Testing
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Test all morning check-in functionality  **Test Cases:**  * All metrics display correctly * % changes calculate accurately * Colors match metric direction * Trend charts render * Apple He...

- **SLE-159** - Evening: Activity metric cards
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Display today's activity stats with % change vs 30-day average  **Metrics:**  1. Total Active Time: 2h 18m (↑ 15.3%) 2. Steps: 9,234 steps (↑ 8.7%) 3. Exercise Minutes: 45 min (↑ 22.5%) 4...

- **SLE-160** - Evening: Workout list UI with details
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Show today's workouts with heart rate zones  **Display:**  ``` 🏃 Morning Run 7:15 AM • 35 min 4.2 miles • 142 avg HR Zone 2-3 • 420 calories [Tap for HR zones]  🏋️ Strength Training 6:30 ...

- **SLE-161** - Evening: Cardiovascular load calculation
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Calculate daily cardiovascular stress/load  **Algorithm:**  * Duration × Intensity × HR zones * Categories: Low / Medium / High / Very High * Compare to 30-day average * Predict recovery ...

- **SLE-162** - Evening: Load visualization
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Visual representation of cardiovascular load  **Design:**  * Progress bar with zones: Low━━●━━━━━━━High * Current position marked * Color gradient from green → yellow → orange → red * Lab...

- **SLE-163** - Evening: Intervention checkbox list
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Track completion of assigned interventions  **Display:**  ``` □ Magnesium Glycinate   400mg • 30min before bed   Schedule: Daily   [Tap to mark complete]   [Add note (optional)]  ☑ 10-min...

- **SLE-164** - Evening: Note input per intervention
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Allow users to add notes about interventions  **UI:**  * Quick notes: "Felt great" / "No effect" / "Side effects" * Custom text input (optional) * Character limit: 200 * Timestamps automa...

- **SLE-165** - Evening: Weekly compliance tracking
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Calculate and display intervention adherence  **Calculation:**  * Completed / Total scheduled × 100 * Per intervention and overall * Weekly rolling window  **Display:**  * Progress ring: ...

- **SLE-166** - Evening: Ambient content integration
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Evening-themed calming ambiance  **Audio:**  * Rain on Window * Night Forest (crickets, distant owl) * Ocean at Night * Auto-plays at 30% volume  **Visuals:**  * Sunset/moonlight gradient...

- **SLE-167** - Evening: Testing
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Test evening check-in functionality  **Test Cases:**  * Activity metrics accurate * Workout details display * Cardiovascular load calculates correctly * Intervention checkboxes work * Not...

- **SLE-168** - My Interventions: Current list UI
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** List view of all active interventions  **Display:**  ``` Magnesium Glycinate Supplement • Week 2 of 4 Daily • 400mg before bed This week: ●●●●●○○ (71%) [View details]  No Screens 1hr Befo...

- **SLE-169** - My Interventions: Detail view
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Full details for a single intervention  **Sections:**  1. **Schedule:** Frequency, time, amount, form 2. **Progress:** Overall compliance, week-by-week 3. **What to Expect:** Benefits by ...

- **SLE-170** - My Interventions: Weekly calendar widget
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Visual 7-day compliance calendar  **Display:**  * 7 circles for days of week * Filled (●): Completed * Empty (○): Missed/not due yet * Gray: Scheduled rest day  **Animation:**  * Fill ani...

- **SLE-171** - My Interventions: Compliance calculation
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Calculate adherence percentages  **Logic:**  * Completed / Scheduled × 100 * Exclude future days * Handle rest days appropriately * Rolling 7-day window for "this week" * All-time complia...

- **SLE-172** - My Interventions: Notes system (CRUD)
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Full CRUD for user notes on interventions  **Operations:**  * Create: Add note with timestamp * Read: Display chronologically * Update: Edit existing note (within 24 hours) * Delete: Remo...

- **SLE-173** - My Interventions: Past archive
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** View completed interventions  **Display:**  ``` L-Theanine Supplement Sept 15 - Oct 12 (4 weeks) Compliance: 24/28 (86%) Status: ✓ Completed [View details] ```  **Features:**  * Chronolog...

- **SLE-174** - My Interventions: Testing
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-146
  - Description: **Purpose:** Test interventions tab  **Test Cases:**  * List displays all active interventions * Detail view shows accurate data * Calendar widget updates in real-time * Compliance calculates correctl...


---

### SLE-175: Component 3: Full Sleep Report

- **State:** Backlog
- **Priority:** 1
- **Tasks:** 21

#### Tasks

- **SLE-176** - Report: Backend schema (sections + roadmap)
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Database schema for sleep report structure  **Tables:**  * sleep_reports (id, user_id, generated_at, overall_score, archetype) * report_sections (id, report_id, section_num, name, score, ...

- **SLE-177** - Report: Executive summary generation
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Generate overall sleep health summary  **Algorithm:**  1. Calculate overall score (0-100) from 8 section scores 2. Determine sleep archetype based on pattern analysis 3. Identify top 3 qu...

- **SLE-178** - Report: Sleep archetype algorithm
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Classify user's sleep pattern into archetype  **Decision Tree:**  ``` IF quality >= 8 AND duration >= 7.5h:     → "The Optimizer" ELSE IF bedtime_variance > 90min:     → "The Irregular" E...

- **SLE-179** - Report: Section template UI (reusable)
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Reusable component for all 8 sections  **Template Structure:**  * Section header with score * Key findings (3-5 bullets) * Top 3 Strengths (collapsible) * Top 3 Areas to Improve (priority...

- **SLE-180** - Report: 8 section-specific logic engines
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Generate analysis for each of 8 sections  **THIS IS A MAJOR FEATURE - 80-120 hours**  **Sections:**  1. Sleep Quantity 2. Sleep Quality 3. Sleep Regularity & Timing 4. Environment 5. Acti...

- **SLE-181** - Report: Strength identification algorithm
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Find 3 positive aspects per section  **Logic:**  * Compare user's metrics to population norms * Identify metrics in "good" or "excellent" range * Rank by impact on sleep quality * Select ...

- **SLE-182** - Report: Issue prioritization algorithm
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Rank sleep issues by priority  **Scoring Matrix:**  * P0: Safety concerns (sleep apnea symptoms) * P1: Major issues (chronic short sleep) * P2: Moderate issues (irregular schedule) * P3: ...

- **SLE-183** - Report: Effort/impact scoring system
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Rate interventions by effort and impact  **Effort Score (1-5):**  * 1: <1 week, minimal change * 2: 1-2 weeks, small lifestyle adjustment * 3: 2-4 weeks, moderate change * 4: 4-8 weeks, s...

- **SLE-184** - Report: 1-year roadmap generator
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Create personalized 12-24 month improvement plan  **Algorithm:**  1. Collect all issues from 8 sections 2. Sort by priority (P0, P1, P2, P3) 3. Schedule max 2 tasks per month 4. Front-loa...

- **SLE-185** - Report: Quarterly milestone logic
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Define goals for each quarter  **Q1 Example:**  ``` Primary Focus: Quick Wins & Basics Target: +8-12 points overall score Key Interventions: - Sleep schedule consistency - Bedroom optimiz...

- **SLE-186** - Report: Monthly task builder
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Generate 1-2 specific tasks per month  **Task Structure:**  ``` Month 1, Task 1: Consistent Wake Time - Priority: P1 - Effort: ●●○○○ (2/5) - Impact: ●●●●● (10/10) - Duration: 4 weeks  Wha...

- **SLE-187** - Report: Coach presentation mode
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Progressive unveiling for coach-led session  **Flow:**  1. Coach logs in to presentation mode 2. Sections locked initially 3. Coach clicks "Unlock Section 1" 4. Section animates in 5. Dis...

- **SLE-188** - Report: Progressive unveiling system
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Animated reveal of sections  **Animation:**  * Fade in with slide up * Stagger subsections (100ms delay) * Smooth transitions * Sound effects (optional)  **State Management:**  * Track wh...

- **SLE-189** - Report: PDF export functionality
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Export report as PDF  **Library:** React-PDF or Puppeteer  **PDF Structure:**  * Cover page with score and archetype * Table of contents * All 8 sections with charts * 1-year roadmap * Ap...

- **SLE-190** - Report: Data visualization (charts)
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Visual representations of sleep data  **Charts Needed:**  1. **Overall Score Radial**    * 8 sections around circle    * Filled based on score    * Color-coded 2. **Sleep Architecture Bre...

- **SLE-191** - Report: Testing & refinement
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Test sleep report generation  **Test Cases:**  * Generate report for various archetypes * Verify all sections score correctly * Check roadmap task ordering * PDF export quality * Coach pr...

- **SLE-192** - Report Content: Section templates
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Write content templates for 8 sections  **Per Section:**  * Intro paragraph explaining section * Strength templates (10+ variants) * Issue templates (20+ variants) * Conditional logic for...

- **SLE-193** - Report Content: Strength/issue descriptions
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Write all strength and issue text variants  **Structure:**  * 8 sections × 10 strength variants = 80 texts * 8 sections × 20 issue variants = 160 texts * Total: 240 text snippets  **Tone:...

- **SLE-194** - Report Content: Task library (200+ tasks)
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Create library of intervention tasks for roadmap  **Categories:**  * Sleep schedule (20 tasks) * Environment optimization (30 tasks) * Lifestyle modifications (40 tasks) * Supplements (30...

- **SLE-195** - Report Content: Medical/scientific review
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Medical accuracy review of all report content  **Review Areas:**  * All strength/issue descriptions * Task library recommendations * Medical disclaimers * Liability concerns * Evidence ba...

- **SLE-196** - Report Content: User testing & iteration
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-175
  - Description: **Purpose:** Test report clarity with real users  **Protocol:**  * 10 beta users get full reports * Conduct interviews * Survey comprehension * Measure action item completion * Collect feedback  **Met...


---

### SLE-197: Component 4: Coach Dashboard

- **State:** Backlog
- **Priority:** 1
- **Tasks:** 27

#### Tasks

- **SLE-198** - Coach: Next.js project setup
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Initialize Next.js web application for coach dashboard  **Tech Stack:**  * Next.js 14+ (App Router) * TypeScript * Tailwind CSS * shadcn/ui components * React Query for data fetching * Zu...

- **SLE-199** - Coach: Authentication system
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Secure authentication for sleep coaches  **Requirements:**  * Login with email/password * JWT token management * Role-based access control (coach, senior coach, admin) * Session persisten...

- **SLE-200** - Coach: Customer list view
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Main dashboard showing all assigned customers  **Features:**  * Searchable customer list * Filter by status (Active, Inactive, Onboarding) * Sort by name, last active, compliance * Pagina...

- **SLE-201** - Coach: Customer profile pages
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Detailed customer view with all data  **Tabs:**  1. Overview: Quick stats, recent activity, alerts 2. Onboarding: All 84 questions and responses 3. Stats: Apple Health metrics and trends ...

- **SLE-202** - Coach: Onboarding data display
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** View all 84 onboarding questions and user responses  **Structure:**  * 14 groups expandable/collapsible * Show completion date per group * Display all Q&A pairs * Show generated insights ...

- **SLE-203** - Coach: Apple Health stats integration
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Display customer's Apple Health data with trends  **Metrics Displayed:**  * Sleep: Duration, stages, efficiency, latency * Activity: Steps, active time, workouts * Recovery: HRV, resting ...

- **SLE-204** - Coach: Trend charts & visualizations
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Visual analytics for customer health data  **Chart Types:**  1. **Sleep Duration Trend** (Line chart)    * 30-day rolling average    * Min/max range bands    * Target zone highlighting 2....

- **SLE-205** - Coach: Intervention library UI
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Browse and manage intervention library  **Views:**  1. **List View:**    * Grid of intervention cards    * Search and filter    * Sort by evidence score, popularity 2. **Card Display:**  ...

- **SLE-206** - Coach: Intervention detail views
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Full intervention information for coach reference  **Sections:**  1. **Overview:**    * Name, type, evidence score    * Primary benefit    * Typical duration    * Success rate from past u...

- **SLE-207** - Coach: Intervention CRUD operations
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Create, Read, Update, Delete interventions in library  **THIS IS A MAJOR FEATURE - 264-352 hours estimated**  **Create Intervention (5-step wizard):**  **Step 1: Basic Info**  * Name (tex...

- **SLE-208** - Coach: Create intervention wizard (5 steps)
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Guided flow for creating new interventions  **Step Navigation:**  * Progress indicator (Step X of 5) * Back/Next buttons * Save as draft at any step * Validation per step  **Form Componen...

- **SLE-209** - Coach: Edit intervention interface
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Modify existing interventions  **Features:**  * Load existing intervention data * Tab-based editing (Basic, Implementation, Outcomes, Safety) * Real-time validation * Unsaved changes warn...

- **SLE-210** - Coach: Archive/restore functionality
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Archive interventions without deleting  **Archive Flow:**  1. Click Archive button 2. Show impact: "Currently assigned to X customers" 3. Select reason (dropdown):    * Replaced by better...

- **SLE-211** - Coach: Delete with safety checks
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Permanently delete interventions (rarely used)  **Safety Checks:**  1. Prevent if ever assigned to customers 2. Warning dialog with impact 3. Require typing intervention name to confirm 4...

- **SLE-212** - Coach: Assignment flow (3-step wizard)
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Assign intervention to customer with schedule  **Step 1: Select Intervention**  * Search/browse intervention library * Preview intervention details * Evidence score and success rate visib...

- **SLE-213** - Coach: Frequency selector
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** UI component for intervention frequency selection  **Options:**  * Daily (7 days) * 6 days/week (with rest day picker) * 5 days/week (weekdays M-F) * 3 days/week (custom picker) * As need...

- **SLE-214** - Coach: Duration slider & presets
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Select intervention duration  **Interface:**  * Slider (1-12 weeks) * Quick preset buttons: \[1w\] \[2w\] \[3w\] \[4w\] \[6w\] \[8w\] \[12w\] \[Custom\] * Show recommended duration highli...

- **SLE-215** - Coach: Schedule configuration
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Comprehensive scheduling interface  **Components:**  * Frequency selector * Duration slider * Date pickers (start/end) * Implementation details form * Preview calendar  **Calendar Preview...

- **SLE-216** - Coach: Active interventions management
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** View and manage customer's current interventions  **Display:**  ``` Current Interventions for [Customer Name]  ┌─ Magnesium Glycinate ────────────────┐ │ Supplement • Week 2 of 4         ...

- **SLE-217** - Coach: Edit intervention functionality
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Modify active intervention assignment  **Editable:**  * Duration (extend or shorten) * Frequency (change days/week) * Implementation details (dosage, timing) * Instructions to user * End ...

- **SLE-218** - Coach: End intervention early flow
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Stop intervention before scheduled end  **Reasons:**  * Achieved goals * Side effects * Not effective * Customer request * Medical advice * Other (specify)  **Flow:**  1. Click "End Early...

- **SLE-219** - Coach: Coach notes system
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Internal notes about customer (not visible to user)  **Features:**  * Add note with timestamp * Tag notes (General, Concern, Success, Follow-up) * Search notes * Filter by tag and date * ...

- **SLE-220** - Coach: Alert/notification system
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Flag important events and concerns  **Alert Types:**  1. **Low Compliance**    * <50% for 2+ weeks    * Action: "Check in with customer" 2. **Unusual Metrics**    * HRV drop >20% for 3+ d...

- **SLE-221** - Coach: Analytics dashboard
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Coach performance and customer success metrics  **Coach Metrics:**  * Number of active customers * Average customer compliance * Successful intervention completion rate * Response time to...

- **SLE-222** - Coach: Search & filter functionality
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Find customers and interventions quickly  **Customer Search:**  * By name (fuzzy match) * By email * By ID  **Customer Filters:**  * Status (Active, Inactive, Onboarding) * Compliance ran...

- **SLE-223** - Coach: Responsive design
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Ensure dashboard works on all screen sizes  **Breakpoints:**  * Desktop: 1280px+ (optimal) * Laptop: 1024-1279px * Tablet: 768-1023px * Mobile: <768px (view-only, limited editing)  **Resp...

- **SLE-224** - Coach: Testing
  - State: Backlog (backlog)
  - Priority: 2
  - Parent: SLE-197
  - Description: **Purpose:** Comprehensive testing of coach dashboard  **Test Areas:**  1. **Authentication:**    * Login/logout    * Session persistence    * Role-based access    * Password reset 2. **Customer Manag...


---

### SLE-225: Component 5: Supporting Systems

- **State:** Backlog
- **Priority:** 1
- **Tasks:** 4

#### Tasks

- **SLE-226** - Support: Apple Health integration
  - State: Backlog (backlog)
  - Priority: 2
  - Assignee: Martin Caval
  - Parent: SLE-225
  - Description: **Purpose:** Comprehensive Apple Health data synchronization  **Data Types to Fetch:**  1. **Sleep Analysis:**    * HKCategoryTypeIdentifierSleepAnalysis    * In bed time, asleep time    * Sleep stage...

- **SLE-227** - Support: Backend infrastructure
  - State: Backlog (backlog)
  - Priority: 2
  - Assignee: Martin Caval
  - Parent: SLE-225
  - Description: **Purpose:** Robust backend supporting all system components  **CRITICAL: ELABORATE BACKEND ARCHITECTURE**  **Tech Stack:**  * Node.js + Express (or Python + FastAPI) * PostgreSQL for relational data ...

- **SLE-228** - Support: Authentication & security
  - State: Backlog (backlog)
  - Priority: 2
  - Assignee: Martin Caval
  - Parent: SLE-225
  - Description: **Purpose:** Secure authentication for users and coaches  **User Authentication:**  * Email/password signup * Email verification * OAuth (Apple Sign-In) * JWT tokens * Refresh token rotation  **Coach ...

- **SLE-229** - Support: Notification system
  - State: Backlog (backlog)
  - Priority: 2
  - Assignee: Martin Caval
  - Parent: SLE-225
  - Description: **Purpose:** Push notifications and emails  **Notification Types:**  **Push Notifications (iOS):**  1. Daily unlock reminder (8 AM) 2. Intervention due soon (30 min before) 3. Streak at risk (if misse...


---

