//
//  NotificationsSettingsView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Notification preferences settings
//

import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {
    @State private var notificationsEnabled = false
    @State private var morningReminder = true
    @State private var eveningReminder = true
    @State private var morningTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var eveningTime = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
    @State private var showingPermissionAlert = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Notifications")
                            .font(.headline)
                        Text("Get reminders to complete your sleep log")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        requestNotificationPermission()
                    }
                }
            } header: {
                Text("Notifications")
            }

            if notificationsEnabled {
                Section {
                    Toggle(isOn: $morningReminder) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Morning Sleep Log")
                                .font(.headline)
                            Text("Reminder to log last night's sleep")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if morningReminder {
                        DatePicker("Time", selection: $morningTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Morning Reminder")
                }

                Section {
                    Toggle(isOn: $eveningReminder) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Evening Check-in")
                                .font(.headline)
                            Text("Reminder to complete daily assessment")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if eveningReminder {
                        DatePicker("Time", selection: $eveningTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Evening Reminder")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkNotificationStatus()
        }
        .alert("Notifications Disabled", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                notificationsEnabled = false
            }
        } message: {
            Text("Please enable notifications in Settings to receive reminders.")
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if !granted {
                    showingPermissionAlert = true
                }
                notificationsEnabled = granted
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
}
