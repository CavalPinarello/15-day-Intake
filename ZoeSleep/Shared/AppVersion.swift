//
//  AppVersion.swift
//  Zoe Sleep for Longevity System
//
//  Single source of truth for app versioning.
//  Update this file when releasing new builds.
//

import Foundation

/// App versioning - single source of truth
/// Version format: MAJOR.MINOR.BUILD
/// - MAJOR: Breaking changes or major feature releases
/// - MINOR: New features, backwards compatible
/// - BUILD: Incremental builds, bug fixes, improvements
struct AppVersion {
    // MARK: - Current Version

    /// Marketing version (shown to users)
    static let version = "1.0.12"

    /// Build number (incremental)
    static let build = 12

    /// Build date
    static let buildDate = "2026-01-02"

    // MARK: - Computed Properties

    /// Full version string (e.g., "1.0.12 (12)")
    static var fullVersion: String {
        "\(version) (\(build))"
    }

    /// Short version for display
    static var displayVersion: String {
        version
    }

    /// Build string for display
    static var displayBuild: String {
        String(build)
    }

    // MARK: - Build History
    // Update this when creating new builds for tracking purposes

    /// Build history for reference (most recent first)
    /// Format: (build number, date, summary)
    static let buildHistory: [(build: Int, date: String, notes: String)] = [
        (12, "2026-01-02", "Versioning system overhaul, single source of truth"),
        (11, "2026-01-02", "Unit-aware help text, Time Travel testing mode"),
        (10, "2026-01-02", "Glassy card UI, frosted glass effect"),
        (9, "2026-01-02", "Empty assessment handling fix"),
        (8, "2026-01-01", "Unified 1-10 scale for sliders, haptic feedback"),
        (7, "2025-12-31", "Profile settings cleanup, experimental features"),
        (6, "2025-12-30", "Expansion pack scheduling fix, 20+ new questions"),
        (5, "2025-12-29", "Debug reset fix, dashboard pillar completion"),
        (4, "2025-12-28", "Expansion pack slider UX, journey intro flow"),
        (3, "2025-12-27", "Day type analysis, nap/medication tracking"),
        (2, "2025-12-22", "8-phase circadian system, unified debug panel"),
        (1, "2025-12-15", "Initial release"),
    ]
}
