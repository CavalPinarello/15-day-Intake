# Sleep-Optimized Circadian Color System

**Date:** 2025-12-02

## Critical Design Principle
**NO BLUE LIGHT AFTER DUSK** - As a sleep app, Zoe Sleep must avoid the blue light spectrum (blue, teal, cyan, purple, green) in evening/night mode. Only warm colors (amber, orange, brown, red) are used after sunset.

## Features Implemented

### 1. iOS ColorTheme Sleep-Optimization (`QuestionModels.swift`)
Complete rewrite of the `ColorTheme` struct to use sleep-safe colors:

| Color Property | Day (Morning/Afternoon) | Evening/Night |
|----------------|------------------------|---------------|
| `primary` | Sky blue `#0EA5E9` / Amber `#F59E0B` | Warm amber `#F28C40` |
| `secondary` | Light blue `#38BDF8` / Golden `#FBBF24` | Deep amber `#D97706` |
| `tertiary` | Cyan `#06B6D4` / Deep amber | Burnt orange `#B45309` |
| `backgroundTint` | Blue/amber tint | Warm amber tint |
| `cardBackground` | Light blue `#F0F9FF` / Cream | Deep warm brown `#2D1A14` |
| `textPrimary` | System default | Warm white `rgb(1.0, 0.92, 0.85)` |
| `textSecondary` | System default | Warm tan `rgb(0.85, 0.70, 0.55)` |
| `insights` | Emerald green | Amber `#F59E0B` |
| `sleepDiary` | Purple | Deep amber `#D97706` |

### 2. iOS Wave Background (`CircadianWaveBackground.swift`)
- `DashboardWaveBackground`: Animated flowing waves with circadian-aware colors
- `QuestionnaireWaveBackground`: Subtle animated waves for questionnaire screens
- `CircadianPalette`: Centralized palette with seasonal sunrise/sunset calculation
- `GlassyCardBackground`: Translucent cards with warm brown tones at night

### 3. Apple Watch Circadian System
- Added `WatchCircadianPalette` struct matching iOS implementation
- Updated all Watch UI components to use circadian colors
- Warm amber ribbons at night
- All UI elements are circadian-aware

### 4. Web Client Circadian Theme
Created complete circadian theme system for the web client:
- `/client/src/lib/circadianTheme.ts` - Color palette and utilities
- `/client/src/hooks/useCircadianTheme.ts` - React hook for components
- Updated all question components with circadian support

### 5. Text Color Contrast Fix
Fixed critical visibility issue where text was invisible on warm brown backgrounds:
- Synchronized `TimePeriod.current` with `CircadianPalette.current`
- Brighter text colors for dark backgrounds:
  - Primary text: Bright cream (`#FEF3C7`)
  - Secondary text: Golden yellow (`#FCD34D`)
  - Muted text: Amber (`#F59E0B`)

## Time-Based Color Logic
Uses seasonal sunrise/sunset calculation:
```swift
let seasonalOffset = sin(Double(dayOfYear - 80) / 365.0 * .pi * 2)
let sunriseHour = 6.5 - seasonalOffset * 1.0  // 5:30 to 7:30 AM
let sunsetHour = 18.5 + seasonalOffset * 2.0   // 4:30 to 8:30 PM
```

## Key Files Modified
- `/ZoeSleep/ZoeSleep/Models/QuestionModels.swift` - Complete ColorTheme rewrite
- `/ZoeSleep/ZoeSleep/Views/CircadianWaveBackground.swift` - Wave animations + CircadianPalette
- `/ZoeSleep/ZoeSleep/ContentView.swift` - Use theme.textPrimary/textSecondary throughout
- `/ZoeSleep/ZoeSleep/Services/ConvexService.swift` - JSON crash fix
- `/ZoeSleep/ZoeSleep Watch App/WatchThemeManager.swift` - WatchCircadianPalette
- `/ZoeSleep/ZoeSleep Watch App/WatchHomeView.swift` - All UI using circadian colors
- `/client/src/lib/circadianTheme.ts` - NEW: Web circadian color system
- `/client/src/hooks/useCircadianTheme.ts` - NEW: React hook for circadian theme