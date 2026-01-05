//
//  WatchConnectivityDebugView.swift
//  ZoeSleep
//
//  Debug view for Apple Watch connectivity events
//  Shows real-time log of all WatchConnectivity messages and state changes
//

import SwiftUI
import WatchConnectivity

struct WatchConnectivityDebugView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var watchConnectivity = iOSWatchConnectivityManager.shared

    var body: some View {
        List {
            // Status Section
            Section {
                statusRow("Session Active", value: WCSession.default.activationState == .activated, required: true)
                statusRow("Watch Paired", value: WCSession.default.isPaired, required: true)
                statusRow("Watch App Installed", value: watchConnectivity.isWatchAppInstalled, required: true)
                // Real-time link is optional - sync works via queue even when standby
                statusRow("Real-time Link", value: watchConnectivity.isWatchConnected, required: false)
            } header: {
                Text("Connection Status")
            } footer: {
                Text("Real-time link is only active when both apps are in foreground. Sync works via queue when standby.")
                    .font(.caption2)
            }

            // Actions Section
            Section {
                Button {
                    watchConnectivity.log("Manual session activate requested")
                    WCSession.default.activate()
                } label: {
                    Label("Activate Session", systemImage: "bolt.fill")
                }

                Button {
                    if let userId = ConvexService.shared.userId,
                       let username = KeychainHelper.load(forKey: "convex_username") {
                        watchConnectivity.syncCredentialsToWatch(userId: userId, username: username)
                    } else {
                        watchConnectivity.log("Cannot sync - no credentials available", level: .error)
                    }
                } label: {
                    Label("Sync Credentials", systemImage: "person.badge.key.fill")
                }

                Button {
                    watchConnectivity.sendUserDataToWatch()
                } label: {
                    Label("Send User Data", systemImage: "arrow.up.doc.fill")
                }

                Button {
                    watchConnectivity.notifyWatchLogout()
                } label: {
                    Label("Send Logout Signal", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                }
            } header: {
                Text("Test Actions")
            }

            // Log Section
            Section {
                if watchConnectivity.connectivityLog.isEmpty {
                    Text("No log entries yet")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(watchConnectivity.connectivityLog) { entry in
                        logEntryRow(entry)
                    }
                }
            } header: {
                HStack {
                    Text("Event Log (\(watchConnectivity.connectivityLog.count))")
                    Spacer()
                    Button("Clear") {
                        watchConnectivity.clearLog()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Watch Connectivity")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            // Refresh status
            watchConnectivity.log("Manual refresh triggered")
        }
    }

    private func statusRow(_ label: String, value: Bool, required: Bool = true) -> some View {
        HStack {
            Text(label)
            Spacer()
            if value {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Yes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if required {
                // Required but missing - show as error
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("No")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Optional and off - show as neutral (standby)
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.secondary)
                Text("Standby")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func logEntryRow(_ entry: iOSConnectivityLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.level.emoji)
                Text(entry.formattedTime)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                Spacer()
                Text(entry.level.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(levelColor(entry.level).opacity(0.2))
                    .foregroundColor(levelColor(entry.level))
                    .cornerRadius(4)
            }
            Text(entry.message)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }

    private func levelColor(_ level: iOSConnectivityLogEntry.Level) -> Color {
        switch level {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

#Preview {
    NavigationStack {
        WatchConnectivityDebugView()
            .environmentObject(ThemeManager.shared)
    }
}
