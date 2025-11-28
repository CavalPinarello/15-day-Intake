//
//  SettingsView.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Simplified settings for Apple Watch (all sizes including Ultra)
//

import SwiftUI
import WatchKit

struct WatchSettingsView: View {
    @EnvironmentObject var themeManager: WatchThemeManager
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @AppStorage("debugMode") private var debugMode: Bool = false
    @AppStorage("watchCurrentDay") private var currentDay: Int = 1
    @AppStorage("watchCompletedDays") private var completedDaysData: Data = Data()

    @State private var showingAdvanceConfirmation = false
    @State private var showingResetConfirmation = false
    @State private var isResetting = false

    private let watchSize = WatchSizeDetector.current

    var body: some View {
        List {
            // MARK: - Appearance
            Section("Appearance") {
                // Accent Color (synced from iPhone)
                HStack {
                    Label("Accent", systemImage: "paintpalette.fill")
                    Spacer()
                    Circle()
                        .fill(themeManager.accentColor)
                        .frame(width: 20, height: 20)
                    Text(themeManager.accentColorOption.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Theme Mode (synced from iPhone)
                HStack {
                    Label("Theme", systemImage: "circle.lefthalf.filled")
                    Spacer()
                    Text(themeManager.appearanceMode.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Change theme on iPhone")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // MARK: - Accessibility
            Section("Display") {
                Toggle(isOn: $themeManager.largeIconsMode) {
                    Label("Large Text", systemImage: "textformat.size.larger")
                }
                .tint(themeManager.accentColor)

                Toggle(isOn: $themeManager.highContrast) {
                    Label("High Contrast", systemImage: "circle.lefthalf.filled")
                }
                .tint(themeManager.accentColor)
            }

            // MARK: - Developer
            Section("Developer") {
                Toggle(isOn: $debugMode) {
                    Label("Debug Mode", systemImage: "hammer.fill")
                }
                .tint(.orange)

                if debugMode {
                    Button {
                        showingAdvanceConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "forward.fill")
                                .foregroundColor(.orange)
                            Text("Next Day")
                                .foregroundColor(.orange)
                            Spacer()
                            Text("Day \(currentDay)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(currentDay >= 15)

                    Button {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.red)
                            if isResetting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Reset Progress")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .disabled(isResetting)
                }
            }

            // MARK: - About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Watch")
                    Spacer()
                    Text(watchSize.displayName)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Advance Day?", isPresented: $showingAdvanceConfirmation) {
            Button("Go to Day \(currentDay + 1)") {
                advanceDay()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Reset Progress?", isPresented: $showingResetConfirmation) {
            Button("Reset to Day 1", role: .destructive) {
                resetProgress()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func advanceDay() {
        if currentDay < 15 {
            currentDay += 1
            WKInterfaceDevice.current().play(.success)
        }
    }

    private func resetProgress() {
        // Reset local storage
        currentDay = 1
        completedDaysData = Data() // Clear completed days

        WKInterfaceDevice.current().play(.success)

        // Also try to sync with iPhone if connected
        watchConnectivity.resetJourneyProgress { _, _ in }
    }
}

// MARK: - Watch Size Detection

enum WatchSizeDetector {
    case small40mm    // SE 40mm
    case medium41mm   // Series 7/8/9/10 41mm
    case large44mm    // SE 44mm
    case large45mm    // Series 7/8/9/10 45mm
    case ultra49mm    // Ultra/Ultra 2 49mm

    static var current: WatchSizeDetector {
        let screenWidth = WKInterfaceDevice.current().screenBounds.width

        switch screenWidth {
        case 0..<165:
            return .small40mm
        case 165..<180:
            return .medium41mm
        case 180..<190:
            return .large44mm
        case 190..<205:
            return .large45mm
        default:
            return .ultra49mm
        }
    }

    var isUltra: Bool {
        self == .ultra49mm
    }

    var isLarge: Bool {
        switch self {
        case .large44mm, .large45mm, .ultra49mm:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .small40mm: return "40mm"
        case .medium41mm: return "41mm"
        case .large44mm: return "44mm"
        case .large45mm: return "45mm"
        case .ultra49mm: return "49mm Ultra"
        }
    }

    // MARK: - Adaptive Sizing

    var buttonHeight: CGFloat {
        switch self {
        case .ultra49mm: return 60
        case .large45mm, .large44mm: return 54
        case .medium41mm: return 48
        case .small40mm: return 44
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .ultra49mm: return 18
        case .large45mm, .large44mm: return 16
        default: return 15
        }
    }

    var titleFontSize: CGFloat {
        switch self {
        case .ultra49mm: return 22
        case .large45mm, .large44mm: return 20
        default: return 18
        }
    }

    var gridColumns: Int {
        switch self {
        case .ultra49mm: return 5
        default: return 4
        }
    }

    var maxVisibleOptions: Int {
        switch self {
        case .ultra49mm: return 4
        case .large45mm, .large44mm: return 3
        default: return 3
        }
    }

    var rowHeight: CGFloat {
        switch self {
        case .ultra49mm: return 56
        case .large45mm, .large44mm: return 50
        default: return 44
        }
    }

    var timeDisplayFontSize: CGFloat {
        switch self {
        case .ultra49mm: return 28
        case .large45mm, .large44mm: return 24
        default: return 20
        }
    }

    var scaleValueFontSize: CGFloat {
        switch self {
        case .ultra49mm: return 32
        case .large45mm, .large44mm: return 28
        default: return 24
        }
    }
}

// MARK: - Preview

#Preview {
    WatchSettingsView()
        .environmentObject(WatchThemeManager.shared)
        .environmentObject(WatchConnectivityManager())
}
