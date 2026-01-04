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
                statusRow("Session Active", value: WCSession.default.activationState == .activated)
                statusRow("Watch Paired", value: WCSession.default.isPaired)
                statusRow("Watch App Installed", value: watchConnectivity.isWatchAppInstalled)
                statusRow("Watch Reachable", value: watchConnectivity.isWatchConnected)
            } header: {
                Text("Connection Status")
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

    private func statusRow(_ label: String, value: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(value ? .green : .red)
            Text(value ? "Yes" : "No")
                .font(.caption)
                .foregroundColor(.secondary)
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
