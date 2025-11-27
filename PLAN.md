# Zoe Sleep for Longevity System - Implementation Plan

## Overview

This plan addresses 7 major areas:
1. Rebranding to "Zoe Sleep for Longevity System" with elegant circadian-themed design
2. **Watch-First Design** - Easy morning answers on Apple Watch, synced across all platforms
3. iOS Settings screen with theme customization, accessibility, and debug mode
4. Physician/Admin dashboard with patient review, question management, and prescription workflow
5. Clear separation of Stanford Sleep Log vs. assessment questionnaires
6. Smart time picker defaults for sleep-related questions
7. Manual "Advance to Next Day" button (in Settings > Debug Mode)

---

## 1. Rebranding: Zoe Sleep for Longevity System

### New Branding
- **Name:** Zoe Sleep for Longevity System
- **Tagline:** "The best sleep of your life and maximum daily energy while protecting your health"

### Design Direction: Elegant Circadian Themes
**NO moon/stars clichés. Focus on:**
- **Circadian wave patterns** - Sinusoidal curves representing the 24-hour rhythm
- **Gradient flows** - Smooth transitions from warm (day/energy) to cool (night/rest)
- **Abstract waveforms** - Clean, modern representation of sleep cycles
- **Color palette:**
  - Dawn/Energy: Warm coral (#FF6B6B) → Soft gold (#FFD93D)
  - Day/Vitality: Bright teal (#4ECDC4) → Sky blue (#45B7D1)
  - Dusk/Transition: Purple (#9B59B6) → Deep violet (#6C5CE7)
  - Night/Rest: Deep indigo (#2C3E50) → Soft navy (#34495E)

### App Icon Redesign
- **Concept:** Abstract circadian wave flowing through a stylized "Z"
- **Style:** Gradient wave pattern, no literal moon/stars
- **Files to update:**
  - `/Sleep360/Sleep360/Assets.xcassets/AppIcon.appiconset/` - New iOS icons
  - `/Sleep360/Sleep360 Watch App/Assets.xcassets/AppIcon.appiconset/` - New watchOS icons
  - `/scripts/generate_app_icons.py` - Update generator for new design

### Files to Update for Branding Text

| File | Current | New |
|------|---------|-----|
| `/client/src/app/page.tsx:48-53` | "Sleep 360°" | "Zoe Sleep for Longevity System" |
| `/client/src/app/layout.tsx` | Page title | "Zoe Sleep for Longevity System" |
| `/Sleep360/Sleep360/Views/ContentView.swift` | "Sleep 360" | "Zoe Sleep" |
| `/Sleep360/Sleep360 Watch App/*.swift` | Watch branding | "Zoe Sleep" |

---

## 2. Watch-First Design Philosophy

### Core Principle: "Answer in Seconds on Your Wrist"

The Stanford Sleep Log (5 questions) should be completable in **under 60 seconds** on Apple Watch right after waking up. Design everything for the smallest screen first, then scale up.

### Platform Sync Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                    PATIENT PLATFORMS                         │
│                                                              │
│   ⌚ Apple Watch    📱 iPhone App    💻 Web App              │
│   (Primary AM)      (Full Features)  (Desktop/Tablet)       │
│        │                  │                │                 │
│        └──────────┬───────┴────────────────┘                │
│                   │                                          │
│              ┌────▼────┐                                    │
│              │  Convex │  Real-time sync                    │
│              │ Backend │  Progress saved instantly          │
│              └─────────┘                                    │
│                                                              │
│   Start on Watch → Continue on iPhone → Finish on Web       │
│   (or any combination - progress syncs immediately)         │
└─────────────────────────────────────────────────────────────┘
```

### Supported Apple Watch Models

**Full support for ALL Apple Watch sizes:**

| Model | Case Size | Screen Width | Screen Height | Min Tap Target |
|-------|-----------|--------------|---------------|----------------|
| Series 7/8/9 | 41mm | 352px | 430px | 44pt |
| Series 7/8/9 | 45mm | 396px | 484px | 44pt |
| SE (2nd gen) | 40mm | 324px | 394px | 44pt |
| SE (2nd gen) | 44mm | 368px | 448px | 44pt |
| **Ultra/Ultra 2** | **49mm** | **410px** | **502px** | **44pt** |

### Adaptive Layout System

The UI automatically adapts to each watch size using SwiftUI's environment:

```swift
struct AdaptiveWatchLayout {
    @Environment(\.watchSize) var watchSize

    var buttonHeight: CGFloat {
        switch watchSize {
        case .ultra49mm: return 60    // Ultra has more space
        case .large45mm, .large44mm: return 54
        case .medium41mm, .medium40mm: return 48
        default: return 44
        }
    }

    var fontSize: CGFloat {
        switch watchSize {
        case .ultra49mm: return 18
        case .large45mm, .large44mm: return 16
        default: return 15
        }
    }

    var gridColumns: Int {
        switch watchSize {
        case .ultra49mm: return 5      // Can fit 5 columns
        case .large45mm, .large44mm: return 4
        default: return 4
        }
    }
}
```

### Watch-Optimized Question UI

**Design Principles:**
1. **Large touch targets** - Minimum 44pt tap areas (Apple HIG), 60pt on Ultra
2. **Single-hand operation** - Digital Crown for scrolling/selection
3. **Glanceable answers** - See question + respond in one screen
4. **Haptic feedback** - Confirmation taps for selections
5. **Adaptive layouts** - Automatically adjust to watch size

### Watch Question Types (All Sizes)

#### 1. Time Picker (Bedtime/Wake Time)

**41mm/40mm (Compact):**
```
┌─────────────────────┐
│   ⌚ 41mm Watch     │
├─────────────────────┤
│  What time did you  │
│  go to bed?         │
│                     │
│   ┌─────────────┐   │
│   │   9:30 PM   │   │
│   └─────────────┘   │
│        ▲            │
│   [ ✓ Confirm ]     │
└─────────────────────┘
```

**45mm/44mm (Standard):**
```
┌───────────────────────────┐
│   ⌚ 45mm Watch           │
├───────────────────────────┤
│                           │
│  What time did you        │
│  go to bed last night?    │
│                           │
│     ┌───────────────┐     │
│     │    9:30 PM    │     │
│     └───────────────┘     │
│          ▲                │
│   Use Crown to adjust     │
│                           │
│   [    ✓ Confirm    ]     │
│                           │
└───────────────────────────┘
```

**49mm Ultra (Spacious):**
```
┌─────────────────────────────────┐
│   ⌚ 49mm Apple Watch Ultra     │
├─────────────────────────────────┤
│                                 │
│   What time did you go to       │
│   bed last night?               │
│                                 │
│       ┌─────────────────┐       │
│       │                 │       │
│       │     9:30 PM     │       │
│       │                 │       │
│       └─────────────────┘       │
│            ▲                    │
│   Rotate Crown to adjust time   │
│                                 │
│   [      ✓ Confirm      ]       │
│                                 │
└─────────────────────────────────┘
```

**Implementation:**
- Default to smart time (9 PM for bed, 7 AM for wake)
- 15-minute increments for faster scrolling
- Crown rotation = time change with haptic clicks
- Single tap to confirm
- Larger time display on Ultra (24pt vs 20pt font)

#### 2. Number Picker (Awakenings)

**41mm/40mm (2x4 Grid):**
```
┌─────────────────────┐
│   ⌚ 41mm Watch     │
├─────────────────────┤
│  How many times     │
│  did you wake up?   │
│                     │
│  ┌───┬───┬───┬───┐  │
│  │ 0 │ 1 │ 2 │ 3 │  │
│  └───┴───┴───┴───┘  │
│  ┌───┬───┬───┬───┐  │
│  │ 4 │ 5 │ 6 │ 7+│  │
│  └───┴───┴───┴───┘  │
└─────────────────────┘
```

**49mm Ultra (2x5 Grid - More Space):**
```
┌─────────────────────────────────┐
│   ⌚ 49mm Apple Watch Ultra     │
├─────────────────────────────────┤
│                                 │
│   How many times did you        │
│   wake up last night?           │
│                                 │
│   ┌─────┬─────┬─────┬─────┬─────┐
│   │  0  │  1  │  2  │  3  │  4  │
│   └─────┴─────┴─────┴─────┴─────┘
│   ┌─────┬─────┬─────┬─────┬─────┐
│   │  5  │  6  │  7  │  8  │ 9+  │
│   └─────┴─────┴─────┴─────┴─────┘
│                                 │
└─────────────────────────────────┘
```

**Implementation:**
- Grid adapts: 4 columns (small), 5 columns (Ultra)
- Button size scales with watch size
- Single tap selects AND advances
- Most common values (0, 1, 2) always visible without scrolling

#### 3. Scale (Sleep Quality 1-10)

**All Sizes (Crown-based):**
```
┌─────────────────────────────────┐
│   ⌚ 49mm Apple Watch Ultra     │
├─────────────────────────────────┤
│                                 │
│   Rate your sleep quality       │
│                                 │
│   😴 Poor              Great 😊 │
│                                 │
│   ┌───────────────────────────┐ │
│   │ ██████████████░░░░░░░░░░░ │ │
│   │            7              │ │
│   └───────────────────────────┘ │
│                                 │
│   [      ✓ Confirm      ]       │
│                                 │
└─────────────────────────────────┘
```

**Implementation:**
- Visual slider bar width adapts to screen
- Digital Crown for precise adjustment
- Haptic tick every number change
- Large current value display (28pt on Ultra, 22pt on smaller)
- Emoji anchors always visible

#### 4. Yes/No Questions

**All Sizes (Full-width buttons):**
```
┌─────────────────────────────────┐
│   ⌚ 49mm Apple Watch Ultra     │
├─────────────────────────────────┤
│                                 │
│   Did you take any sleep        │
│   medication last night?        │
│                                 │
│   ┌───────────────────────────┐ │
│   │           YES             │ │
│   │         (teal)            │ │
│   └───────────────────────────┘ │
│   ┌───────────────────────────┐ │
│   │           NO              │ │
│   │         (gray)            │ │
│   └───────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

**Implementation:**
- Full-width buttons on ALL watch sizes
- Button height: 44pt (small), 54pt (large), 60pt (Ultra)
- Tap instantly selects AND advances
- Color coding with accent color (teal for yes, gray for no)

#### 5. Single Select (Multiple Choice)

**49mm Ultra (More visible options):**
```
┌─────────────────────────────────┐
│   ⌚ 49mm Apple Watch Ultra     │
├─────────────────────────────────┤
│                                 │
│   How do you feel this morning? │
│                                 │
│   ┌───────────────────────────┐ │
│   │  😫  Exhausted            │ │
│   └───────────────────────────┘ │
│   ┌───────────────────────────┐ │
│   │  😐  Okay                 │ │
│   └───────────────────────────┘ │
│   ┌───────────────────────────┐ │
│   │  😊  Refreshed            │ │
│   └───────────────────────────┘ │
│   ┌───────────────────────────┐ │
│   │  🤩  Amazing!             │ │
│   └───────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

**Implementation:**
- Vertical list, Crown-scrollable
- Row height adapts: 44pt (small), 50pt (large), 56pt (Ultra)
- Ultra can show 4 options without scroll, smaller shows 3
- Tap to select and advance
- Emoji icons for quick recognition

### Stanford Sleep Log - Watch Flow (60 seconds total)

**Adaptive notification based on watch size:**

```
Morning Wake-Up Flow:

[Notification: "Good morning! Quick sleep check?"]
        │
        ▼
┌───────────────────────────────────┐
│ Q1: Bedtime?                      │  ~10 sec
│ [Crown → 10:30 PM]                │
│ [✓ Tap]                           │
│                                   │
│ Ultra: Shows hint text            │
│ Smaller: Compact layout           │
└───────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────┐
│ Q2: Fell asleep?                  │  ~10 sec
│ [Crown → 11:00 PM]                │
│ [✓ Tap]                           │
└───────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────┐
│ Q3: Awakenings?                   │  ~5 sec
│ [Tap grid: 2]                     │
│                                   │
│ Ultra: 5-column grid              │
│ Smaller: 4-column grid            │
└───────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────┐
│ Q4: Wake time?                    │  ~10 sec
│ [Crown → 6:45 AM]                 │
│ [✓ Tap]                           │
└───────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────┐
│ Q5: Quality?                      │  ~10 sec
│ [Crown → 7/10]                    │
│ [✓ Tap]                           │
└───────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────┐
│ ✅ Sleep Log Complete!            │
│                                   │
│ "Great start to your day!"        │
│                                   │
│ Ultra: Shows sleep summary        │
│ [Continue on 📱?] [Done for now]  │
└───────────────────────────────────┘
```

### Watch Size Detection (SwiftUI)

```swift
enum WatchSize {
    case small40mm    // SE 40mm
    case medium41mm   // Series 7/8/9 41mm
    case large44mm    // SE 44mm
    case large45mm    // Series 7/8/9 45mm
    case ultra49mm    // Ultra/Ultra 2 49mm

    static var current: WatchSize {
        let screenWidth = WKInterfaceDevice.current().screenBounds.width
        switch screenWidth {
        case 162: return .small40mm
        case 176: return .medium41mm
        case 184: return .large44mm
        case 198: return .large45mm
        case 205: return .ultra49mm
        default: return .medium41mm
        }
    }

    var isUltra: Bool { self == .ultra49mm }
    var isLarge: Bool { self == .large44mm || self == .large45mm || self == .ultra49mm }
}
```

### Cross-Platform Consistency

**Shared Design Language:**

| Element | Watch | iPhone | Web |
|---------|-------|--------|-----|
| Time Picker | Crown scroll | Wheel picker | Click/scroll wheel |
| Scale 1-10 | Crown + bar | Slider | Slider |
| Yes/No | 2 large buttons | 2 large buttons | 2 large buttons |
| Number (0-10) | Grid buttons | Grid buttons | Grid buttons |
| Multi-select | Checkmark list | Checkmark chips | Checkmark chips |

**Visual Consistency:**
- Same color palette across platforms
- Same question wording
- Same progress indicators (dots/bars)
- Same completion celebrations

### iPhone App - Watch-Influenced Design

Even on iPhone, use watch-inspired simplicity:

```
┌─────────────────────────────────────┐
│  DAILY SLEEP LOG        1 of 5  ●○○○○│
├─────────────────────────────────────┤
│                                      │
│   What time did you go to bed        │
│   last night?                        │
│                                      │
│          ┌─────────────────┐         │
│          │                 │         │
│          │    9:30 PM      │         │  Large, centered
│          │                 │         │  time display
│          └─────────────────┘         │
│               ▲     ▼                │
│                                      │
│   Swipe or tap arrows to adjust      │
│                                      │
│                                      │
│  ┌─────────────────────────────────┐ │
│  │          NEXT →                 │ │  Full-width button
│  └─────────────────────────────────┘ │
│                                      │
└─────────────────────────────────────┘
```

### Web App - Touch-Friendly Design

Responsive design that works on tablets and desktops:

```
┌────────────────────────────────────────────────────────────┐
│  Zoe Sleep                                    Day 3 of 15  │
├────────────────────────────────────────────────────────────┤
│                                                            │
│           DAILY SLEEP LOG                                  │
│           Stanford Sleep Diary                             │
│           ━━━━━━━━━━━━━━━━━━━━━━━━━━                       │
│                                                            │
│           What time did you go to bed last night?          │
│                                                            │
│                    ┌──────────────┐                        │
│                    │              │                        │
│                    │   9:30 PM    │                        │
│                    │              │                        │
│                    └──────────────┘                        │
│                      ◄    ▲▼    ►                          │
│                                                            │
│           ○ ○ ○ ○ ○  Question 1 of 5                       │
│                                                            │
│           ┌──────────────────────────────────┐             │
│           │           NEXT →                 │             │
│           └──────────────────────────────────┘             │
│                                                            │
│           ← Back                                           │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 3. iOS Settings Screen (with Accessibility)

### Settings View Structure

```
┌─────────────────────────────────────┐
│  ⚙️ Settings                        │
├─────────────────────────────────────┤
│  APPEARANCE                         │
│  ├─ Color Theme                     │
│  │   ○ System Default               │
│  │   ○ Light                        │
│  │   ○ Dark                         │
│  │   ○ Circadian (auto by time)     │
│  ├─ Accent Color                    │
│  │   [Teal] [Coral] [Violet] [Gold] │
│  │                                  │
├─────────────────────────────────────┤
│  ACCESSIBILITY                      │
│  ├─ Large Icons Mode  [Toggle]      │
│  │   Makes buttons & text 30% larger│
│  ├─ High Contrast     [Toggle]      │
│  │   Bolder colors, clearer borders │
│  ├─ Reduce Motion     [Toggle]      │
│  │   Minimizes animations           │
│  └─ Text Size                       │
│      [A]───────●───────[A]          │
│       ↑                 ↑           │
│     Small             Large         │
├─────────────────────────────────────┤
│  DEVELOPER                          │
│  ├─ Debug Mode  [Toggle]            │
│  │   (When ON, shows debug options) │
│  └─ IF DEBUG MODE ON:               │
│      ├─ ⏭️ Advance to Next Day      │
│      ├─ 🔄 Reset Journey Progress   │
│      └─ 📊 View Raw Data            │
├─────────────────────────────────────┤
│  ACCOUNT                            │
│  ├─ Profile                         │
│  ├─ Notifications                   │
│  └─ Sign Out                        │
└─────────────────────────────────────┘
```

### Accessibility: Large Icons Mode

**Normal Mode:**
```
┌─────────────────────────────────────┐
│  How many times did you wake up?    │
│                                     │
│  ┌───┬───┬───┬───┬───┐             │
│  │ 0 │ 1 │ 2 │ 3 │ 4 │             │
│  └───┴───┴───┴───┴───┘             │
│  ┌───┬───┬───┬───┬───┐             │
│  │ 5 │ 6 │ 7 │ 8 │ 9+│             │
│  └───┴───┴───┴───┴───┘             │
└─────────────────────────────────────┘
```

**Large Icons Mode (30% bigger):**
```
┌─────────────────────────────────────┐
│  How many times did you             │
│  wake up?                           │
│                                     │
│  ┌─────┬─────┬─────┐               │
│  │     │     │     │               │
│  │  0  │  1  │  2  │               │
│  │     │     │     │               │
│  └─────┴─────┴─────┘               │
│  ┌─────┬─────┬─────┐               │
│  │     │     │     │               │
│  │  3  │  4  │  5+ │               │
│  │     │     │     │               │
│  └─────┴─────┴─────┘               │
│                                     │
│  ┌─────────────────────────────────┐│
│  │         NEXT →                  ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

### Implementation

**ThemeManager with Accessibility:**

```swift
class ThemeManager: ObservableObject {
    enum ColorTheme: String, CaseIterable {
        case system, light, dark, circadian
    }

    enum AccentColor: String, CaseIterable {
        case teal, coral, violet, gold

        var color: Color {
            switch self {
            case .teal: return Color(hex: "#4ECDC4")
            case .coral: return Color(hex: "#FF6B6B")
            case .violet: return Color(hex: "#6C5CE7")
            case .gold: return Color(hex: "#FFD93D")
            }
        }
    }

    // Appearance
    @AppStorage("colorTheme") var colorTheme: ColorTheme = .system
    @AppStorage("accentColor") var accentColor: AccentColor = .teal

    // Accessibility
    @AppStorage("largeIconsMode") var largeIconsMode: Bool = false
    @AppStorage("highContrast") var highContrast: Bool = false
    @AppStorage("reduceMotion") var reduceMotion: Bool = false
    @AppStorage("textSizeMultiplier") var textSizeMultiplier: Double = 1.0  // 0.8 to 1.4

    // Debug
    @AppStorage("debugMode") var debugMode: Bool = false

    // Computed properties
    var buttonScale: CGFloat {
        largeIconsMode ? 1.3 : 1.0
    }

    var minimumTapTarget: CGFloat {
        largeIconsMode ? 58 : 44  // Apple HIG minimum is 44pt
    }

    var currentColorScheme: ColorScheme? {
        switch colorTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        case .circadian: return circadianScheme()
        }
    }

    private func circadianScheme() -> ColorScheme {
        let hour = Calendar.current.component(.hour, from: Date())
        return (hour >= 7 && hour < 19) ? .light : .dark
    }
}
```

### Watch Settings (Simplified)

On Apple Watch, settings are streamlined:

```
┌─────────────────────┐
│  ⚙️ Settings        │
├─────────────────────┤
│                     │
│  Large Text    [ON] │
│                     │
│  High Contrast [OFF]│
│                     │
│  ─────────────────  │
│                     │
│  Debug Mode   [OFF] │
│                     │
│  Sign Out           │
│                     │
└─────────────────────┘
```

---

## 4. Physician/Admin Dashboard (Comprehensive)

### 4.1 Dashboard Structure

```
/client/src/app/physician/
├── page.tsx                      # Patient list overview
├── layout.tsx                    # Sidebar navigation
├── patient/[id]/
│   ├── page.tsx                 # Patient summary + scores
│   ├── responses/page.tsx       # Day-by-day response viewer
│   ├── scores/page.tsx          # Questionnaire score summary
│   └── prescription/page.tsx    # Create treatment plan
└── questions/
    ├── page.tsx                 # Question manager
    └── new/page.tsx             # Add new question form
```

### 4.2 Patient List Dashboard (`/physician`)

**Features:**
- Table with columns: Name, Current Day, Progress %, Review Status, Gateway Triggers, Actions
- Filter by: Status, Day range, Triggered gateways
- Search by name/email
- Bulk actions: Export data, Mark reviewed

### 4.3 Patient Detail View (`/physician/patient/[id]`)

**Summary Tab:**
```
┌─────────────────────────────────────────────────────────┐
│  John Smith                                    Day 12/15 │
│  Progress: ████████████░░░ 80%                          │
├─────────────────────────────────────────────────────────┤
│  TRIGGERED ASSESSMENTS                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                │
│  │ Insomnia │ │ Anxiety  │ │ OSA Risk │                │
│  │   ISI    │ │  GAD-7   │ │STOP-BANG │                │
│  └──────────┘ └──────────┘ └──────────┘                │
├─────────────────────────────────────────────────────────┤
│  QUESTIONNAIRE SCORES                                    │
│                                                          │
│  ISI (Insomnia Severity Index)                          │
│  Score: 18/28  │  Category: Moderate Clinical Insomnia  │
│  ████████████████████░░░░░░░░                           │
│                                                          │
│  GAD-7 (Generalized Anxiety)                            │
│  Score: 12/21  │  Category: Moderate Anxiety            │
│  ████████████████░░░░░░░░░░░                            │
│                                                          │
│  ESS (Epworth Sleepiness Scale)                         │
│  Score: 14/24  │  Category: Excessive Daytime Sleepiness│
│  ████████████████████░░░░░░░░                           │
│                                                          │
│  PHQ-9 (Depression)                                      │
│  Score: 8/27   │  Category: Mild Depression             │
│  ██████████░░░░░░░░░░░░░░░░░░                           │
│                                                          │
│  [View All Responses]  [Create Prescription →]          │
└─────────────────────────────────────────────────────────┘
```

### 4.4 Day-by-Day Responses (`/physician/patient/[id]/responses`)

**Accordion View:**
```
▼ Day 1: Demographics & Sleep Quality Core
  ┌─────────────────────────────────────────────┐
  │ Q: What is your full name?                  │
  │ A: John Smith                               │
  ├─────────────────────────────────────────────┤
  │ Q: Overall sleep quality (1-10)?            │
  │ A: 4 ⚠️ (Triggered: Poor Sleep Quality)     │
  ├─────────────────────────────────────────────┤
  │ Q: Minutes to fall asleep?                  │
  │ A: 45 min ⚠️ (Triggered: Insomnia)          │
  └─────────────────────────────────────────────┘

▶ Day 2: PSQI & Sleep Patterns
▶ Day 3: Sleep Timing & Mental Health
... (Days 4-15 collapsed)
```

### 4.5 Questionnaire Score Summary (`/physician/patient/[id]/scores`)

**All Completed Questionnaires with Clinical Interpretation:**

| Questionnaire | Score | Max | Category | Clinical Notes |
|---------------|-------|-----|----------|----------------|
| ISI | 18 | 28 | Moderate Clinical Insomnia | Consider CBT-I |
| PSQI | 12 | 21 | Poor Sleep Quality | Multiple domains affected |
| GAD-7 | 12 | 21 | Moderate Anxiety | May benefit from relaxation |
| PHQ-9 | 8 | 27 | Mild Depression | Monitor, supportive care |
| ESS | 14 | 24 | Excessive Sleepiness | Rule out OSA |
| STOP-BANG | 5 | 8 | High OSA Risk | Recommend sleep study |

### 4.6 Prescription Page (`/physician/patient/[id]/prescription`)

**Create Treatment Plan:**
```
┌─────────────────────────────────────────────────────────┐
│  CREATE PRESCRIPTION FOR: John Smith                     │
├─────────────────────────────────────────────────────────┤
│  BASED ON ASSESSMENT FINDINGS:                           │
│  • Moderate insomnia (ISI: 18)                          │
│  • High OSA risk (STOP-BANG: 5)                         │
│  • Moderate anxiety (GAD-7: 12)                         │
├─────────────────────────────────────────────────────────┤
│  RECOMMENDED INTERVENTIONS                               │
│                                                          │
│  ☑ Sleep Hygiene Education                              │
│    └─ Duration: 2 weeks                                 │
│    └─ Tasks: [Configure tasks...]                       │
│                                                          │
│  ☑ Sleep Restriction Therapy                            │
│    └─ Initial sleep window: 11pm - 5:30am (6.5 hrs)    │
│    └─ Weekly adjustment protocol                        │
│                                                          │
│  ☑ Relaxation Training                                  │
│    └─ Progressive muscle relaxation                     │
│    └─ Daily practice: 15 min before bed                │
│                                                          │
│  ☑ Refer for Sleep Study                                │
│    └─ Priority: High (OSA risk)                         │
│    └─ Add referral letter to patient portal            │
│                                                          │
│  ☐ Cognitive Behavioral Therapy for Insomnia (CBT-I)   │
│  ☐ Light Therapy Protocol                               │
│  ☐ Medication Review                                    │
├─────────────────────────────────────────────────────────┤
│  CUSTOM TASKS FOR PATIENT APP                            │
│                                                          │
│  + Add Task                                              │
│  ┌─────────────────────────────────────────────────────┐│
│  │ Task: "Practice 4-7-8 breathing before bed"         ││
│  │ Frequency: Daily                                     ││
│  │ Duration: 2 weeks                                    ││
│  │ Reminder: 9:30 PM                                    ││
│  └─────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────┐│
│  │ Task: "No screens 1 hour before bed"                ││
│  │ Frequency: Daily                                     ││
│  │ Duration: Ongoing                                    ││
│  │ Reminder: 9:00 PM                                    ││
│  └─────────────────────────────────────────────────────┘│
│                                                          │
│  [Save Draft]  [Preview in App]  [Send to Patient →]    │
└─────────────────────────────────────────────────────────┘
```

### 4.7 Question Manager (`/physician/questions`)

**Features:**
- Day selector (1-15)
- Drag-and-drop question list
- Question type icons for visual identification
- "Add New Question" button

### 4.8 Add New Question Form (`/physician/questions/new`)

```
┌─────────────────────────────────────────────────────────┐
│  ADD NEW QUESTION                                        │
├─────────────────────────────────────────────────────────┤
│  Question Text:                                          │
│  ┌─────────────────────────────────────────────────────┐│
│  │ How many hours do you typically work per week?      ││
│  └─────────────────────────────────────────────────────┘│
│                                                          │
│  Answer Type:                                            │
│  ○ Slider (1-10 scale)                                  │
│  ○ Number Input                                         │
│  ○ Time Picker (point in time)                          │
│  ○ Duration (minutes)                                   │
│  ○ Yes/No                                               │
│  ○ Yes/No/Don't Know                                    │
│  ● Single Select (choose one)                           │
│  ○ Multi Select (choose many)                           │
│  ○ Free Text                                            │
│                                                          │
│  IF SINGLE/MULTI SELECT:                                │
│  Options:                                                │
│  [Less than 20 hours        ] [×]                       │
│  [20-40 hours               ] [×]                       │
│  [40-50 hours               ] [×]                       │
│  [More than 50 hours        ] [×]                       │
│  [+ Add Option]                                          │
│                                                          │
│  Assign to Day: [Dropdown: Day 1-15]                    │
│                                                          │
│  Pillar/Category: [Dropdown: Social, Sleep Quality...]  │
│                                                          │
│  Is Gateway Question? [Toggle]                           │
│  IF YES: Gateway Type: [Dropdown]                        │
│          Trigger Threshold: [Input]                      │
│                                                          │
│  Required? [Toggle: Yes]                                 │
│                                                          │
│  [Cancel]  [Save Question]                               │
└─────────────────────────────────────────────────────────┘
```

### 4.9 Patient App: Post-Intake Actions View

After 15-day intake completes, the app transitions to **"Treatment Mode"**:

```
┌─────────────────────────────────────────────────────────┐
│  Zoe Sleep                              ⚙️              │
│  Good morning, John!                                     │
├─────────────────────────────────────────────────────────┤
│  YOUR TREATMENT PLAN                                     │
│  Prepared by Dr. Smith on Nov 26, 2025                  │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐│
│  │  📋 TODAY'S TASKS                           3 of 5  ││
│  │                                                      ││
│  │  ☑ Morning: Record wake time                        ││
│  │  ☑ Evening: Practice 4-7-8 breathing (15 min)      ││
│  │  ☐ Evening: No screens after 9pm                    ││
│  │  ☐ Night: Go to bed at 11:00 PM (sleep window)     ││
│  │  ☐ Log: Complete daily sleep diary                  ││
│  │                                                      ││
│  │  [View All Tasks →]                                 ││
│  └─────────────────────────────────────────────────────┘│
│                                                          │
│  ┌─────────────────────────────────────────────────────┐│
│  │  📊 THIS WEEK'S PROGRESS                            ││
│  │                                                      ││
│  │  Sleep Window Adherence: 85%                        ││
│  │  ████████████████░░░░                               ││
│  │                                                      ││
│  │  Task Completion: 78%                               ││
│  │  ███████████████░░░░░                               ││
│  │                                                      ││
│  │  [View Detailed Progress →]                         ││
│  └─────────────────────────────────────────────────────┘│
│                                                          │
│  ┌─────────────────────────────────────────────────────┐│
│  │  💬 MESSAGE FROM DR. SMITH                          ││
│  │  "Great progress this week! Your sleep efficiency   ││
│  │   improved from 72% to 81%. Let's extend your       ││
│  │   sleep window by 15 minutes next week."            ││
│  │  [Reply] [View Full Notes]                          ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

### 4.10 Apple Watch Treatment Tasks (Post-Intake)

After the 15-day intake, the Apple Watch app switches to **Treatment Mode**, showing daily tasks from the physician's prescription:

**Watch Home Screen (Treatment Mode):**
```
┌─────────────────────────────────┐
│   ⌚ 49mm Apple Watch Ultra     │
├─────────────────────────────────┤
│                                 │
│   🌅 Good Morning, John         │
│                                 │
│   TODAY'S TASKS                 │
│   ───────────────               │
│                                 │
│   ┌─────────────────────────────┐
│   │ ☑ Record wake time          │
│   │   Completed 7:15 AM         │
│   └─────────────────────────────┘
│   ┌─────────────────────────────┐
│   │ ☐ 4-7-8 Breathing           │
│   │   Tonight at 9:30 PM        │
│   └─────────────────────────────┘
│   ┌─────────────────────────────┐
│   │ ☐ No screens after 9pm      │
│   │   Reminder at 9:00 PM       │
│   └─────────────────────────────┘
│   ┌─────────────────────────────┐
│   │ ☐ Sleep Diary               │
│   │   Before bed                │
│   └─────────────────────────────┘
│                                 │
│   Progress: 1/4 tasks           │
│   ██░░░░░░░░░░░░░░              │
│                                 │
└─────────────────────────────────┘
```

**Task Detail View:**
```
┌─────────────────────────────────┐
│   ⌚ Apple Watch                │
├─────────────────────────────────┤
│                                 │
│   🌬️ 4-7-8 Breathing           │
│                                 │
│   Practice relaxation breathing │
│   for 15 minutes before bed.    │
│                                 │
│   From: Dr. Smith               │
│   Duration: 2 weeks             │
│                                 │
│   ┌───────────────────────────┐ │
│   │    ✅ Mark Complete       │ │
│   └───────────────────────────┘ │
│   ┌───────────────────────────┐ │
│   │    ⏭️ Skip Today          │ │
│   └───────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

**Physician Message Notification:**
```
┌─────────────────────────────────┐
│   ⌚ Apple Watch                │
├─────────────────────────────────┤
│                                 │
│   💬 NEW MESSAGE                │
│   From: Dr. Smith               │
│                                 │
│   "Great progress this week!    │
│    Your sleep efficiency        │
│    improved to 81%."            │
│                                 │
│   ┌───────────────────────────┐ │
│   │    View Full Message      │ │
│   └───────────────────────────┘ │
│   ┌───────────────────────────┐ │
│   │    Dismiss                │ │
│   └───────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

**Implementation Files:**
- `/Sleep360/Sleep360 Watch App/TreatmentView.swift` - Main treatment task list
- `/Sleep360/Sleep360 Watch App/TaskDetailView.swift` - Individual task detail
- `/Sleep360/Sleep360 Watch App/MessageView.swift` - Physician messages
- `/convex/watch.ts` - Add treatment task queries for watch

**Cross-Platform Sync:**
- Task completions sync instantly to Convex
- Physician sees completions in real-time on dashboard
- Web/iOS/Watch all show same task status
- Notifications pushed to all connected devices

### 4.11 Wearable Data Integration (HealthKit → Physician View)

The physician dashboard shows Apple Watch/HealthKit data alongside questionnaire responses:

**Patient Detail - Wearable Data Tab:**
```
┌─────────────────────────────────────────────────────────┐
│  WEARABLE DATA - Last 7 Days                            │
├─────────────────────────────────────────────────────────┤
│  SLEEP METRICS (from Apple Watch)                       │
│                                                          │
│  Average Sleep Duration: 6h 23m                         │
│  ████████████████░░░░░░░░  (Target: 7-8h)              │
│                                                          │
│  Sleep Efficiency: 78%                                  │
│  ███████████████░░░░░░░░░  (Target: 85%+)              │
│                                                          │
│  Time in Bed vs Asleep:                                 │
│  ┌──────────────────────────────────────────────┐      │
│  │ In Bed:  11pm ░░░░░░░░░░░░░░░░░░░░░░ 7am    │      │
│  │ Asleep:  12am ████████████████████░░ 6:30am │      │
│  └──────────────────────────────────────────────┘      │
│                                                          │
│  HEART RATE (Resting)                                   │
│  Average: 62 bpm   Min: 54 bpm   Max: 78 bpm           │
│                                                          │
│  HRV (Heart Rate Variability)                           │
│  Average: 42ms  (trending ↑ from 38ms last week)       │
│                                                          │
│  ACTIVITY                                               │
│  Steps: 6,234/day avg   Active Minutes: 28/day avg     │
├─────────────────────────────────────────────────────────┤
│  COMPARE: Self-Report vs Wearable                       │
│                                                          │
│  Patient reports "fell asleep at 11pm"                  │
│  Watch shows first sleep stage at 11:52pm              │
│  → Discrepancy: 52 minutes (sleep onset misperception) │
│                                                          │
│  Patient reports "woke up 2 times"                      │
│  Watch detected 4 awakenings >5min                      │
│  → Patient may underestimate awakenings                 │
│                                                          │
│  [Download Full Report PDF]                             │
└─────────────────────────────────────────────────────────┘
```

**This data helps physicians:**
1. Validate patient-reported sleep times
2. Identify sleep onset latency issues
3. Track treatment progress objectively
4. Detect patterns patient may not notice
5. Adjust treatment plans based on objective data

### 4.12 New Database Schema

```typescript
// Add to /convex/schema.ts

// Treatment plans created by physicians
treatment_plans: defineTable({
    patient_id: v.id("users"),
    physician_id: v.string(),
    created_at: v.number(),
    updated_at: v.number(),
    status: v.string(), // "draft", "active", "completed", "archived"
    summary: v.string(),
    findings_json: v.string(), // JSON of assessment findings
    interventions_json: v.string(), // JSON of selected interventions
})

// Individual tasks within a treatment plan
treatment_tasks: defineTable({
    plan_id: v.id("treatment_plans"),
    patient_id: v.id("users"),
    title: v.string(),
    description: v.optional(v.string()),
    frequency: v.string(), // "daily", "weekly", "once"
    time_of_day: v.optional(v.string()), // "morning", "evening", "night"
    reminder_time: v.optional(v.string()), // "21:30"
    duration_weeks: v.optional(v.number()),
    start_date: v.number(),
    end_date: v.optional(v.number()),
    status: v.string(), // "active", "completed", "skipped"
    order: v.number(),
})

// Daily task completions
task_completions: defineTable({
    task_id: v.id("treatment_tasks"),
    patient_id: v.id("users"),
    date: v.string(), // "2025-11-26"
    completed: v.boolean(),
    completed_at: v.optional(v.number()),
    notes: v.optional(v.string()),
})

// Physician messages to patients
physician_messages: defineTable({
    patient_id: v.id("users"),
    physician_id: v.string(),
    message: v.string(),
    created_at: v.number(),
    read_at: v.optional(v.number()),
})

// Custom questions added by physicians
custom_questions: defineTable({
    text: v.string(),
    question_type: v.string(),
    pillar: v.string(),
    day_number: v.number(),
    options_json: v.optional(v.string()),
    scale_min: v.optional(v.number()),
    scale_max: v.optional(v.number()),
    min_value: v.optional(v.number()),
    max_value: v.optional(v.number()),
    unit: v.optional(v.string()),
    is_gateway: v.boolean(),
    gateway_type: v.optional(v.string()),
    gateway_threshold: v.optional(v.number()),
    required: v.boolean(),
    order: v.number(),
    created_by: v.string(),
    created_at: v.number(),
})
```

---

## 5. Stanford Sleep Log - Clear Separation

### Start with Sleep Log First

When user opens app for daily tasks:

```
┌─────────────────────────────────────────────────────────┐
│  DAILY SLEEP LOG                                         │
│  Stanford Sleep Diary                                    │
│  About last night's sleep...                            │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1/5  What time did you go to bed last night?           │
│                                                          │
│       ┌─────────────────────────────────────┐           │
│       │     🌙 BEDTIME                      │           │
│       │                                      │           │
│       │        ┌──────────────┐             │           │
│       │        │   9:30 PM    │  ← Default  │           │
│       │        └──────────────┘             │           │
│       │         ▲            ▼              │           │
│       └─────────────────────────────────────┘           │
│                                                          │
│  [Previous]                           [Next →]           │
└─────────────────────────────────────────────────────────┘
```

### Visual Distinction

**Sleep Log Questions:**
- Header: "DAILY SLEEP LOG - Stanford Sleep Diary"
- Subheader: "About last night's sleep..."
- Background: Soft blue tint (#E3F2FD)
- Icon: 🌙 moon for nighttime questions

**Assessment Questions:**
- Header: "DAY 3 ASSESSMENT - Sleep Timing & Mental Health"
- Subheader: "About your typical patterns..."
- Background: Soft purple tint (#F3E5F5)
- Icon: 📋 clipboard for assessment

### Completion Flow

1. **Sleep Log First** (5 questions) → Completion checkmark
2. **Brief Transition Screen:** "Great! Now let's continue your Day 3 assessment..."
3. **Day Assessment** (varies by day) → Day completion

---

## 6. Smart Time Picker Defaults

### Pre-selected Default Times

| Question | Context | Default Value |
|----------|---------|---------------|
| SL_BEDTIME | "What time did you go to bed?" | **9:00 PM** |
| SL_ASLEEP_TIME | "What time did you fall asleep?" | **9:30 PM** |
| SL_WAKE_TIME | "What time did you wake up?" | **7:00 AM** |
| PSQI_1 | "Usual bedtime in past month" | **10:00 PM** |
| PSQI_3 | "Usual wake time in past month" | **6:30 AM** |

### Implementation

**iOS & Watch (QuestionComponents.swift):**

```swift
struct TimeInput: View {
    let question: Question
    @Binding var value: String
    @EnvironmentObject var themeManager: ThemeManager

    var defaultTime: Date {
        let calendar = Calendar.current
        var components = DateComponents()

        switch question.id {
        case "SL_BEDTIME":
            components.hour = 21  // 9 PM
            components.minute = 0
        case "SL_ASLEEP_TIME":
            components.hour = 21
            components.minute = 30
        case "SL_WAKE_TIME", "PSQI_3":
            components.hour = 7   // 7 AM
            components.minute = 0
        case "PSQI_1":
            components.hour = 22  // 10 PM
            components.minute = 0
        default:
            // Evening default for sleep-related, morning for wake-related
            if question.text.lowercased().contains("wake") ||
               question.text.lowercased().contains("morning") {
                components.hour = 7
            } else {
                components.hour = 21
            }
            components.minute = 0
        }

        return calendar.date(from: components) ?? Date()
    }

    var body: some View {
        DatePicker(
            "",
            selection: Binding(
                get: { parseTime(value) ?? defaultTime },
                set: { value = formatTime($0) }
            ),
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.wheel)
        .scaleEffect(themeManager.largeIconsMode ? 1.2 : 1.0)
        .onAppear {
            if value.isEmpty {
                value = formatTime(defaultTime)
            }
        }
    }
}
```

---

## 7. Implementation Phases

### Phase 1: Foundation & Testing (Start Here)
1. **iOS Settings Screen** - Gear icon, theme options, accessibility, debug mode
2. **Advance Day Button** - Under Settings > Debug Mode
3. **Smart Time Defaults** - Pre-select reasonable times
4. **Large Icons Mode** - Accessibility for poor eyesight

### Phase 2: Watch-First Optimization
5. **Watch Sleep Log UI** - Optimized 60-second completion flow
6. **Watch Question Components** - Crown-friendly, large tap targets
7. **Cross-Platform Sync** - Real-time progress sync via Convex
8. **Watch Settings** - Simplified accessibility options

### Phase 3: Consumer App Clarity
9. **Sleep Log Separation** - Distinct UI, always first
10. **Visual Differentiation** - Blue for log, purple for assessment
11. **Completion Flow** - Clear transition between sections
12. **Consistent Design Language** - Same patterns across all platforms

### Phase 4: Rebranding
13. **Text Updates** - All "Sleep 360" → "Zoe Sleep"
14. **Icon Redesign** - Circadian wave theme (elegant, no moon/stars)
15. **Color Scheme** - Update accent colors app-wide

### Phase 5: Physician Dashboard
16. **Patient List** - Overview with progress
17. **Patient Detail** - Day-by-day responses + scores
18. **Score Summary** - All questionnaire results with interpretation
19. **Prescription Page** - Create treatment plans
20. **Question Manager** - Add/edit/reorder questions

### Phase 6: Treatment Mode (Post-Intake)
21. **iOS Treatment View** - Post-intake daily task list from physician prescription
22. **Web Treatment View** - Same tasks accessible via browser
23. **Watch Treatment View** - Daily tasks on Apple Watch with completion tracking
24. **Task Completion Tracking** - Sync completions across all platforms
25. **Physician Messaging** - Two-way communication (messages appear on Watch too)
26. **Progress Dashboard** - Show task adherence, sleep metrics improvement
27. **Wearable Data Insights** - Compare self-report vs Apple Watch data for physician

---

## Files Summary

### New Files to Create

**iOS:**
- `/Sleep360/Sleep360/Views/SettingsView.swift`
- `/Sleep360/Sleep360/Managers/ThemeManager.swift`
- `/Sleep360/Sleep360/Views/TreatmentView.swift` (Phase 6)
- `/Sleep360/Sleep360/Views/TaskListView.swift` (Phase 6)

**watchOS:**
- `/Sleep360/Sleep360 Watch App/SettingsView.swift`
- `/Sleep360/Sleep360 Watch App/SleepLogView.swift` (optimized)
- `/Sleep360/Sleep360 Watch App/WatchQuestionComponents.swift`
- `/Sleep360/Sleep360 Watch App/TreatmentView.swift` (Phase 6 - post-intake tasks)
- `/Sleep360/Sleep360 Watch App/TaskDetailView.swift` (Phase 6 - task detail)
- `/Sleep360/Sleep360 Watch App/MessageView.swift` (Phase 6 - physician messages)

**Web (Physician Dashboard):**
- `/client/src/app/physician/page.tsx`
- `/client/src/app/physician/layout.tsx`
- `/client/src/app/physician/patient/[id]/page.tsx`
- `/client/src/app/physician/patient/[id]/responses/page.tsx`
- `/client/src/app/physician/patient/[id]/scores/page.tsx`
- `/client/src/app/physician/patient/[id]/prescription/page.tsx`
- `/client/src/app/physician/questions/page.tsx`
- `/client/src/app/physician/questions/new/page.tsx`
- `/client/src/app/physician/components/PatientTable.tsx`
- `/client/src/app/physician/components/ScoreCard.tsx`
- `/client/src/app/physician/components/QuestionEditor.tsx`
- `/client/src/app/physician/components/DragDropList.tsx`
- `/client/src/app/physician/components/PrescriptionBuilder.tsx`

**Convex:**
- Updates to `/convex/schema.ts` (new tables)
- Updates to `/convex/physician.ts` (new functions)
- New `/convex/treatment.ts` (treatment plan functions)

### Files to Modify

- `/Sleep360/Sleep360/Views/ContentView.swift` - Settings icon, sleep log separation
- `/Sleep360/Sleep360/Views/QuestionnaireView.swift` - Sleep log first flow
- `/Sleep360/Sleep360/Views/QuestionComponents.swift` - Smart time defaults, accessibility
- `/Sleep360/Sleep360/Managers/QuestionnaireManager.swift` - Separation logic
- `/Sleep360/Sleep360 Watch App/QuestionnaireView.swift` - Watch-optimized UI
- `/client/src/app/page.tsx` - Rebranding
- `/client/src/app/layout.tsx` - Rebranding
- `/client/src/app/journey/page.tsx` - Watch-consistent design
- `/client/src/middleware.ts` - Physician route protection

---

## Design Principles Summary

### 1. Watch-First, Scale Up
Design for 41mm Apple Watch first, then adapt for larger screens.

### 2. 60-Second Sleep Log
Stanford Sleep Log completable in under 1 minute on any device.

### 3. Single-Action Responses
One tap or one crown rotation = answer submitted.

### 4. Accessibility by Default
- Large tap targets (minimum 44pt, 58pt in large mode)
- High contrast option
- Scalable text
- Reduce motion option

### 5. Beautiful & Functional
- Elegant circadian gradients
- Smooth animations (unless reduced)
- Consistent visual language across platforms

---

## Ready for Your Review

**Recommended Starting Point:** Phase 1 (Settings + Debug Mode + Accessibility + Smart Times)

This gives you:
- Immediate testing capability (advance day)
- Accessibility features for poor eyesight
- Smart defaults for faster input

Shall I begin implementation with Phase 1?
