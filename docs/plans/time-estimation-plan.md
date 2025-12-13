# Time Estimation Rethink Plan

## Current Problem

1. **Inaccurate estimates**: Day 15 shows "~29 min" even when only 1-2 gateways are triggered
2. **No module breakdown**: User doesn't know what they're spending time on
3. **Mismatch with physician dashboard**: iOS estimates don't align with `assessment_modules.json`

## Goal

Show accurate, module-specific time estimates like:
- Core days: "Sleep quality assessment (~10 min)"
- Expansion days: "Deep dive: Pain (~8 min) + Nutrition (~7 min)"

## Data Sources

### Physician Dashboard (Source of Truth)
From `/data/assessment_modules.json`:

| Module | Questions | Time |
|--------|-----------|------|
| `core_social` | 15 | 8.5 min |
| `core_metabolic` | 17 | 13.5 min |
| `core_sleep_quality_1` | 12 | 10 min |
| `core_sleep_quality_2` | 11 | 9.5 min |
| `core_sleep_quantity` | 3 | 1.5 min |
| `core_sleep_regularity` | 4 | 2 min |
| `core_sleep_timing` | 8 | 5.5 min |
| `core_physical` | 11 | 5.5 min |
| `core_nutritional` | 11 | 5.5 min |

**Expansion Modules:**
| Module | Questions | Time |
|--------|-----------|------|
| `expansion_sleep_quality_1` | 17 | 8.5 min |
| `expansion_sleep_quality_2` | 17 | 8.5 min |
| `expansion_mental_health_1` | 16 | 8 min |
| `expansion_mental_health_2` | 16 | 8 min |
| `expansion_mental_health_3` | 16 | 8 min |
| `expansion_cognitive_1` | 17 | 8.5 min |
| `expansion_cognitive_2` | 16 | 8 min |
| `expansion_physical_1` | 16 | 8 min |
| `expansion_physical_2` | 15 | 7.5 min |
| `expansion_sleep_timing` | 19 | 9.5 min |
| `expansion_nutritional` | 14 | 7 min |

### Gateway to Expansion Mapping
```swift
.insomnia, .poorSleepQuality → expansion_sleep_quality (~17 min total)
.depression, .anxiety → expansion_mental_health (~24 min total)
.excessiveSleepiness, .cognitive → expansion_cognitive (~16.5 min total)
.osa, .pain → expansion_physical (~15.5 min total)
.sleepTiming → expansion_sleep_timing (~9.5 min)
.dietImpact → expansion_nutritional (~7 min)
```

## Implementation Plan

### Step 1: Add Gateway Time Estimates to GatewayType

Add a computed property to `GatewayType` for estimated minutes:

```swift
var estimatedMinutes: Double {
    switch self {
    case .insomnia, .poorSleepQuality: return 8.5  // Per day (spread across days)
    case .depression, .anxiety: return 8.0
    case .excessiveSleepiness: return 7.0
    case .cognitive: return 8.0
    case .osa: return 8.0
    case .pain: return 8.0
    case .sleepTiming: return 9.5
    case .dietImpact: return 7.0
    }
}
```

### Step 2: Update Core Day Estimates

For Days 1-5, use accurate totals based on actual modules:

| Day | Modules | Total Time |
|-----|---------|------------|
| 1 | social + sleep_quality_1 | ~12 min |
| 2 | sleep_quality_2 + quantity + regularity | ~13 min |
| 3 | sleep_timing | ~6 min |
| 4 | physical + metabolic | ~9 min |
| 5 | nutritional | ~6 min |

### Step 3: Update Expansion Day Display

For Days 6-15:
1. Get triggered gateways for the user
2. Get which gateways are scheduled for TODAY
3. Show individual times: "Pain (~8 min) + Nutrition (~7 min)"

### Step 4: Update ContentView Helper Methods

```swift
// New struct to hold module info for display
struct TodayModuleInfo {
    let name: String
    let estimatedMinutes: Int
}

// Get modules scheduled for today with their times
private func getTodayModules() -> [TodayModuleInfo] {
    // For core days, return core module info
    // For expansion days, return triggered gateway modules
}

// Format display string
private func getAssessmentSubtitle() -> String {
    let modules = getTodayModules()
    if modules.isEmpty {
        return "No assessment today"
    }
    return modules.map { "\($0.name) (~\($0.estimatedMinutes) min)" }.joined(separator: " + ")
}

// Total time
private func getAssessmentMinutes() -> Int {
    return getTodayModules().reduce(0) { $0 + $1.estimatedMinutes }
}
```

### Step 5: Update UI Display

**Sleep Log Card:**
```
Sleep Log
Quick check-in about last night    ~3 min >
```

**Core Assessment Card (Days 1-5):**
```
Assessment
Sleep quality & patterns           ~12 min >
```

**Expansion Assessment Card (Days 6-15):**
```
Deep Dive
Pain (~8 min) + Nutrition (~7 min)  ~15 min >
```

Or if only one gateway:
```
Deep Dive: Pain
Detailed pain assessment            ~8 min >
```

## Files to Modify

1. **`QuestionModels.swift`**: Add `estimatedMinutes` to `GatewayType`
2. **`ContentView.swift`**: Update `getAssessmentMinutes()` and `getDayDescription()`
3. **`QuestionnaireManager.swift`**: Add helper to get today's module info

## Validation

After implementation:
1. Compare iOS estimates with physician dashboard for same day/user
2. Verify expansion days show correct triggered modules
3. Ensure totals match when multiple modules are scheduled

## Notes

- Sleep Log is always 5 questions (~3 min) - this stays constant
- Core assessment varies by day (6-13 min)
- Expansion assessment depends entirely on triggered gateways
- If no gateways triggered for an expansion day, show "No additional assessment needed"
