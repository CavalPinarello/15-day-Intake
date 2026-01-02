# Version History - Zoe Sleep

> **Current Version:** 1.0.12 (Build 12)
> **Last Updated:** 2026-01-02

## Versioning System

The app uses semantic versioning: `MAJOR.MINOR.BUILD`

- **MAJOR**: Breaking changes or major feature releases
- **MINOR**: New features, backwards compatible
- **BUILD**: Incremental builds, bug fixes, improvements

### Single Source of Truth

All version information comes from `ZoeSleep/Shared/AppVersion.swift`. Update this file when creating new builds:

```swift
struct AppVersion {
    static let version = "1.0.12"
    static let build = 12
    static let buildDate = "2026-01-02"
}
```

## Build History

| Build | Version | Date | Summary |
|-------|---------|------|---------|
| 12 | 1.0.12 | 2026-01-02 | Versioning system overhaul, single source of truth |
| 11 | 1.0.11 | 2026-01-02 | Unit-aware help text, Time Travel testing mode |
| 10 | 1.0.10 | 2026-01-02 | Glassy card UI, frosted glass effect |
| 9 | 1.0.9 | 2026-01-02 | Empty assessment handling fix |
| 8 | 1.0.8 | 2026-01-01 | Unified 1-10 scale for sliders, haptic feedback |
| 7 | 1.0.7 | 2025-12-31 | Profile settings cleanup, experimental features |
| 6 | 1.0.6 | 2025-12-30 | Expansion pack scheduling fix, 20+ new questions |
| 5 | 1.0.5 | 2025-12-29 | Debug reset fix, dashboard pillar completion |
| 4 | 1.0.4 | 2025-12-28 | Expansion pack slider UX, journey intro flow |
| 3 | 1.0.3 | 2025-12-27 | Day type analysis, nap/medication tracking |
| 2 | 1.0.2 | 2025-12-22 | 8-phase circadian system, unified debug panel |
| 1 | 1.0.1 | 2025-12-15 | Initial release |

## How to Release a New Build

1. **Update `AppVersion.swift`**:
   ```swift
   static let version = "1.0.13"  // Increment version
   static let build = 13          // Increment build number
   static let buildDate = "YYYY-MM-DD"  // Today's date
   ```

2. **Add to build history** in `AppVersion.swift`:
   ```swift
   (13, "YYYY-MM-DD", "Brief description of changes"),
   ```

3. **Update this document** with the new build entry

4. **Update `CLAUDE.md`** with release notes if significant changes

5. **Commit** with message: `Release v1.0.13 (Build 13) - Brief description`

## Files That Reference Version

- `ZoeSleep/Shared/AppVersion.swift` - **PRIMARY SOURCE**
- `ZoeSleep/ZoeSleep/Config.swift` - References `AppVersion.version`
- `ZoeSleep/ZoeSleep/Views/ProfileSettingsView.swift` - Displays in Settings
- `ZoeSleep/ZoeSleep Watch App/SettingsView.swift` - Displays in Watch Settings

## Notes

- Build numbers are sequential (never decrease)
- Version numbers follow semantic versioning
- Keep build history updated for tracking purposes
- The Xcode project's `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` can be kept in sync manually or via build scripts
