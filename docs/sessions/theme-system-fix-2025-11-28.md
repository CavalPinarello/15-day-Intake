# Theme System Fix Session - 2025-11-28

## Session Goal
Fix critical issues with the iOS theme system where theme and accent color changes weren't propagating globally throughout the app and to the Apple Watch.

## Problem Description
Users reported that when changing themes or accent colors in the iOS Settings view:
- Theme selections (System, Light, Dark, Circadian) only affected the Settings page
- Accent color changes (Teal, Coral, Violet, Gold) weren't applying app-wide
- Theme changes weren't syncing to the Apple Watch

## Root Cause Analysis

### 1. `@AppStorage` in `ObservableObject` Limitation
The original `ThemeManager.swift` used `@AppStorage` properties:
```swift
@AppStorage("colorTheme") var appearanceMode: AppearanceMode = .system
```

**Issue:** `@AppStorage` properties inside an `ObservableObject` class do NOT automatically trigger `objectWillChange`. This is a known SwiftUI limitation - the property wrapper updates UserDefaults but doesn't notify SwiftUI views that depend on the observable object.

### 2. Missing Xcode Project References
- `WatchConnectivityManager.swift` existed in `/Sleep360/Sleep360/Managers/` but wasn't added to the Xcode project's iOS target
- `WatchThemeManager.swift` was created for the Watch app but wasn't in the build phase

### 3. Improper Root-Level Theme Application
The app wasn't applying `.preferredColorScheme()` and `.tint()` modifiers at the root view level with proper observation.

## Technical Solution

### 1. ThemeManager.swift Rewrite
Changed from `@AppStorage` to `@Published` properties with manual UserDefaults sync:

```swift
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var appearanceMode: AppearanceMode = .system {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "colorTheme")
        }
    }

    @Published var accentColorOption: AccentColorOption = .teal {
        didSet {
            UserDefaults.standard.set(accentColorOption.rawValue, forKey: "accentColor")
        }
    }

    // ... other @Published properties with didSet

    private init() {
        loadFromUserDefaults()
    }

    private func loadFromUserDefaults() {
        if let modeString = UserDefaults.standard.string(forKey: "colorTheme"),
           let mode = AppearanceMode(rawValue: modeString) {
            self.appearanceMode = mode
        }
        // ... load other values
    }
}
```

### 2. Sleep360App.swift - ThemedRootView Wrapper
Added a wrapper view that observes theme changes and applies them at the root level:

```swift
struct ThemedRootView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ContentView()
            .preferredColorScheme(themeManager.currentColorScheme)
            .tint(themeManager.accentColor)
            .onChange(of: themeManager.appearanceMode) { _, _ in
                // Force UI update
            }
            .onChange(of: themeManager.accentColorOption) { _, _ in
                iOSWatchConnectivityManager.shared.sendThemeSettingsToWatch()
            }
    }
}
```

### 3. SettingsView.swift - Standard Picker Controls
Replaced custom button implementations with standard SwiftUI Picker controls:

```swift
Picker(selection: $themeManager.appearanceMode) {
    ForEach(ThemeManager.AppearanceMode.allCases) { mode in
        HStack {
            Image(systemName: mode.icon)
            Text(mode.rawValue)
        }
        .tag(mode)
    }
} label: {
    Label("Color Theme", systemImage: "paintbrush.fill")
}
```

### 4. Xcode Project.pbxproj Updates
Added missing file references:
- `4A5E3BE22C8E123456789D03` - WatchConnectivityManager.swift build file (iOS)
- `4A5E3BE32C8E123456789D04` - WatchConnectivityManager.swift file reference (iOS)
- `4A5E3BE02C8E123456789D01` - WatchThemeManager.swift build file (Watch)
- `4A5E3BE12C8E123456789D02` - WatchThemeManager.swift file reference (Watch)

## Files Modified

### iOS Application
| File | Change Type | Description |
|------|-------------|-------------|
| `ThemeManager.swift` | Major Rewrite | Changed from @AppStorage to @Published with UserDefaults |
| `Sleep360App.swift` | Modified | Added ThemedRootView wrapper |
| `SettingsView.swift` | Modified | Changed to standard Picker controls |
| `WatchConnectivityManager.swift` | Added to Project | Was missing from Xcode build |
| `QuestionModels.swift` | Modified | ColorTheme supports accent colors |
| `ContentView.swift` | Minor | Theme integration updates |

### watchOS Application
| File | Change Type | Description |
|------|-------------|-------------|
| `WatchThemeManager.swift` | New + Added | Complete theme manager for Watch |
| `SettingsView.swift` | Modified | Theme display updates |
| `WatchConnectivityManager.swift` | Modified | Theme sync handling |
| `TreatmentTasksView.swift` | Modified | Theme integration |
| `QuestionnaireView.swift` | Modified | Theme colors |
| `WatchQuestionComponents.swift` | Modified | Theme support |

### Project Files
| File | Change Type | Description |
|------|-------------|-------------|
| `project.pbxproj` | Modified | Added missing file references |

## Build Verification
- iOS app builds successfully on iPhone 17 simulator
- watchOS app builds successfully on Apple Watch Series 11 (46mm) simulator

## Key Technical Learnings

1. **@AppStorage + ObservableObject = No UI Updates**: Never use `@AppStorage` inside `ObservableObject` if you expect SwiftUI views to update. Use `@Published` with manual UserDefaults sync instead.

2. **Root-Level Theme Application**: Theme modifiers like `.preferredColorScheme()` must be applied at the app's root view level to affect all child views.

3. **SwiftUI Picker vs Custom Buttons**: Standard `Picker` controls with bindings work more reliably than custom button implementations for settings.

4. **File References Matter**: Files can exist on disk but not be included in Xcode builds - always verify project.pbxproj includes new files.

## Testing Checklist
- [ ] Change accent color (Teal → Coral → Violet → Gold) - verify app-wide color change
- [ ] Change appearance mode (System → Light → Dark → Circadian) - verify color scheme change
- [ ] Open multiple views after theme change - verify consistency
- [ ] Pair with Apple Watch - verify theme sync
- [ ] Kill and relaunch app - verify theme persistence

## Commit Information
- **Commit Message:** "Fix theme system: global propagation and Watch sync"
- **Files Changed:** 17 files, ~1100 insertions, ~480 deletions
