# Navigation Overhaul Plan

## Overview

This plan addresses three interconnected issues with the Zoe Sleep iOS app navigation and data display:

1. **Progress Dots Navigation** - Make dots clickable to view completed day summaries
2. **Today's Focus Card Redesign** - Clean up the awkward vertical text layout
3. **Sleep Diary History Data** - Fix data not displaying for previous days

---

## Issue 1: Progress Dots Navigation

### Current Behavior
- 15 progress dots on home screen show completion status
- Dots are purely visual indicators (not interactive)
- Users must navigate to Sleep Diary History separately to view past days

### Desired Behavior
- Tapping any completed day dot navigates to a day summary view
- Summary shows: Sleep Log status, Assessment status, Expansion Packs completed
- Incomplete days remain non-interactive

### Implementation

#### Option A: Navigate to Sleep Diary History with Pre-selected Day (Recommended)
**Location:** `ContentView.swift` → `journeyProgressCard` (lines 321-359)

1. Wrap `ProgressDots` in a custom interactive version
2. Replace static `ProgressDots` with `InteractiveProgressDots`
3. On tap, navigate to `SleepDiaryHistoryView` with `selectedDay` pre-set

```swift
// New component: InteractiveProgressDots
struct InteractiveProgressDots: View {
    let current: Int
    let total: Int
    let completedDays: [Int]
    let onDayTapped: (Int) -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<total, id: \.self) { index in
                let day = index + 1
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: day == current ? 10 : 8, height: day == current ? 10 : 8)
                    .onTapGesture {
                        if completedDays.contains(day) {
                            onDayTapped(day)
                        }
                    }
            }
        }
    }
}
```

#### Option B: Create New Day Summary Sheet
- Show a modal sheet with day accomplishments
- More complex but provides focused summary

### Files to Modify
- `ContentView.swift`: Add `InteractiveProgressDots`, navigation state
- `ThemeManager.swift`: Keep existing `ProgressDots` (used elsewhere) or merge

---

## Issue 2: Today's Focus Card Redesign

### Current Design Problems
- "Your sleep last night" text wrapped vertically in cramped layout
- "Quick check-..." truncated with ellipsis
- `~3 min` and chevron feel disconnected
- Icon + multi-line text + duration don't flow well

### Current `CalmTaskCard` Structure (lines 941-991)
```
┌─────────────────────────────────────────┐
│  ┌────┐   Your         ~3 min          │
│  │icon│   sleep          >             │
│  └────┘   last                         │
│           night                        │
│           Quick check-...              │
└─────────────────────────────────────────┘
```

### Proposed New Design
Clean horizontal layout with clear task list format:

```
┌─────────────────────────────────────────┐
│  Today's focus                          │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │ 🌙  Sleep Log                 ~3min ││
│  │     Quick check-in about last night ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │ 📋  Assessment              ~10min  ││
│  │     Today's questions               ││
│  └─────────────────────────────────────┘│
│                                         │
│  (Optional: Expansion Pack if triggered)│
└─────────────────────────────────────────┘
```

### Design Principles
1. **Show all tasks upfront** - User sees complete picture of what's due
2. **Horizontal text flow** - No awkward vertical wrapping
3. **Clear visual hierarchy** - Icon | Title + subtitle | Duration
4. **Completion states** - Strikethrough or checkmark for completed items
5. **Progress indicator** - "1 of 2 complete" or similar

### New Component: `TaskListCard`

```swift
struct TaskListCard: View {
    struct TaskItem {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        let duration: String
        let isCompleted: Bool
        let destination: AnyView?
    }

    let tasks: [TaskItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header with completion count
            HStack {
                Text("Today's focus")
                    .font(.headline)
                Spacer()
                Text("\(completedCount)/\(tasks.count)")
                    .font(.caption)
                    .foregroundColor(theme.textOnCardMuted)
            }

            // Task rows
            ForEach(tasks) { task in
                TaskRow(task: task)
            }
        }
    }
}

struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            Image(systemName: task.icon)
                .frame(width: 24)
                .foregroundColor(task.isCompleted ? theme.success : theme.primary)

            // Title + Subtitle (horizontal flow)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.isCompleted)

                    if task.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.success)
                    }
                }

                Text(task.subtitle)
                    .font(.caption)
                    .foregroundColor(theme.textOnCardSecondary)
            }

            Spacer()

            // Duration + chevron
            if !task.isCompleted {
                HStack(spacing: 4) {
                    Text(task.duration)
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(theme.textOnCardMuted)
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}
```

### Files to Modify
- `ContentView.swift`: Replace `todaysTasksCard` implementation (lines 414-540)
- Consider keeping `CalmTaskCard` for backward compatibility or remove if unused

---

## Issue 3: Sleep Diary History Data Not Loading

### Current Bug
- Day selector shows completed days with checkmarks
- Selecting Day 3 or Day 5 shows empty Sleep Timing, Sleep Metrics cards
- Data exists in Convex but not displaying

### Root Cause Analysis

The `loadDayEntry` function (lines 1549-1576) has several potential issues:

#### Problem 1: ISO8601 Date Parsing
```swift
// Current code (line 1559)
if let date = ISO8601DateFormatter().date(from: stringValue) {
    responses[questionId] = date
}
```
- Default `ISO8601DateFormatter` may not match the format Convex sends
- Time values might be stored as epoch timestamps, not ISO8601 strings

#### Problem 2: Question ID Mismatch
The Sleep Log uses different question IDs than what `SleepDiaryEntry` expects:

| Sleep Log (Saved) | Diary Entry (Expected) | Status |
|-------------------|------------------------|--------|
| `SL_BEDTIME` | `CSD_INTO_BED` fallback | ✅ |
| `SL_ASLEEP_TIME` | `CSD_TRY_SLEEP` fallback | ✅ |
| `SL_WAKE_TIME` | `CSD_FINAL_WAKE` fallback | ✅ |
| `SL_QUALITY` | `CSD_QUALITY` fallback | ⚠️ |
| `SL_AWAKENINGS` | `CSD_AWAKENINGS` fallback | ✅ |

The fallbacks exist but may not be working due to type mismatches.

#### Problem 3: Type Casting Issues
```swift
// Current (line 1564-1565)
} else if let numberValue = responseValue.numberValue {
    responses[questionId] = Int(numberValue)
}
```
- All numbers converted to `Int`, but some fields expect `Double`
- Quality ratings stored as `Double` might be truncated

#### Problem 4: Date Storage Format
Looking at how dates are saved vs. parsed:
- Dates might be stored as timestamps (epoch milliseconds)
- Current parsing only handles ISO8601 strings
- Need to handle multiple formats

### Fix Implementation

#### Step 1: Enhanced Date Parsing in `loadDayEntry`
```swift
private func loadDayEntry(day: Int) async -> SleepDiaryEntry? {
    do {
        let savedResponses = try await ConvexService.shared.getSavedResponses(dayNumber: day)

        var responses: [String: Any] = [:]
        for (questionId, responseValue) in savedResponses {
            // Handle string values
            if let stringValue = responseValue.stringValue {
                // Try multiple date formats
                if let date = parseFlexibleDate(stringValue) {
                    responses[questionId] = date
                } else {
                    responses[questionId] = stringValue
                }
            } else if let numberValue = responseValue.numberValue {
                // Check if this could be a timestamp (epoch milliseconds)
                if questionId.contains("TIME") || questionId.contains("BED") || questionId.contains("WAKE") {
                    // Timestamps are typically > 1600000000000 (year 2020+)
                    if numberValue > 1_000_000_000_000 {
                        let date = Date(timeIntervalSince1970: numberValue / 1000)
                        responses[questionId] = date
                    }
                }
                // Keep number for non-time fields
                responses[questionId] = numberValue  // Keep as Double
            } else if let arrayValue = responseValue.arrayValue {
                responses[questionId] = arrayValue
            }
        }

        return SleepDiaryEntry(from: responses, day: day)
    } catch {
        print("[SleepDiaryHistory] Failed to load day \(day): \(error)")
        return nil
    }
}

private func parseFlexibleDate(_ string: String) -> Date? {
    // Try ISO8601 with fractional seconds
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = isoFormatter.date(from: string) {
        return date
    }

    // Try ISO8601 without fractional seconds
    isoFormatter.formatOptions = [.withInternetDateTime]
    if let date = isoFormatter.date(from: string) {
        return date
    }

    // Try epoch timestamp as string
    if let timestamp = Double(string), timestamp > 1_000_000_000 {
        return Date(timeIntervalSince1970: timestamp > 1_000_000_000_000 ? timestamp / 1000 : timestamp)
    }

    return nil
}
```

#### Step 2: Fix `SleepDiaryEntry` Type Handling
```swift
init(from responses: [String: Any], day: Int) {
    // ... existing code ...

    // Fix: Handle Double values for metrics
    self.sleepLatency = (responses["CSD_LATENCY"] as? Int) ?? Int(responses["CSD_LATENCY"] as? Double ?? 0)
    self.awakenings = (responses["CSD_AWAKENINGS"] as? Int) ?? (responses["SL_AWAKENINGS"] as? Int) ??
                      Int(responses["CSD_AWAKENINGS"] as? Double ?? responses["SL_AWAKENINGS"] as? Double ?? 0)

    // Fix: Better quality parsing
    if let quality = responses["CSD_QUALITY"] as? Int {
        self.sleepQuality = quality
    } else if let quality = responses["CSD_QUALITY"] as? Double {
        self.sleepQuality = Int(quality)
    } else if let quality = responses["SL_QUALITY"] as? Int {
        self.sleepQuality = quality <= 5 ? quality : Int(Double(quality) / 2.0)
    } else if let quality = responses["SL_QUALITY"] as? Double {
        self.sleepQuality = Int(quality) <= 5 ? Int(quality) : Int(quality / 2.0)
    } else {
        self.sleepQuality = nil
    }
}
```

#### Step 3: Add Debug Logging
```swift
private func loadDayEntry(day: Int) async -> SleepDiaryEntry? {
    do {
        let savedResponses = try await ConvexService.shared.getSavedResponses(dayNumber: day)

        #if DEBUG
        print("[SleepDiaryHistory] Day \(day) raw responses:")
        for (key, value) in savedResponses {
            print("  \(key): string=\(value.stringValue ?? "nil"), number=\(value.numberValue ?? 0), array=\(value.arrayValue ?? [])")
        }
        #endif

        // ... rest of parsing
    }
}
```

### Files to Modify
- `ContentView.swift`:
  - `loadDayEntry` function (lines 1549-1576)
  - `SleepDiaryEntry.init` (lines 1673-1722)

---

## Implementation Order

### Phase 1: Fix Data Loading (Issue 3) - HIGHEST PRIORITY
1. Add debug logging to see actual data format
2. Fix date parsing to handle timestamps
3. Fix type casting for numeric values
4. Test with existing completed days

### Phase 2: Redesign Today's Focus Card (Issue 2)
1. Create new `TaskListCard` component
2. Migrate `todaysTasksCard` to new design
3. Handle completion states and expansion packs
4. Remove or deprecate `CalmTaskCard`

### Phase 3: Add Interactive Progress Dots (Issue 1)
1. Create `InteractiveProgressDots` component
2. Add navigation state to `MainDashboardView`
3. Wire up tap handlers to navigate to Sleep Diary History
4. Test navigation flow

---

## Testing Checklist

### Issue 3 Tests
- [ ] Day 1 shows Sleep Timing data
- [ ] Day 3 shows Sleep Metrics data
- [ ] Day 5 shows all data categories
- [ ] Sleep Quality Trend chart populates
- [ ] Dates display correctly (not as raw timestamps)

### Issue 2 Tests
- [ ] All tasks visible at once
- [ ] Completed tasks show checkmark
- [ ] Tapping incomplete task navigates correctly
- [ ] Expansion pack appears when triggered
- [ ] Circadian colors applied correctly

### Issue 1 Tests
- [ ] Completed day dots are tappable
- [ ] Incomplete day dots are not interactive
- [ ] Tapping navigates to Sleep Diary History
- [ ] Correct day is pre-selected
- [ ] Animation feels smooth

---

## Additional Considerations

### HealthKit Integration
- Sleep Quality Trend should eventually show:
  - Subjective quality (from Sleep Log)
  - Objective quality (from HealthKit sleep data)
- This is a future enhancement, not part of this overhaul

### Performance
- Sleep history loads all completed days on appear
- For 15 days, this is acceptable
- Consider pagination if expanding to longer periods

### Accessibility
- Ensure progress dots have accessible labels
- Task rows need proper VoiceOver descriptions
- Maintain circadian theming compliance
