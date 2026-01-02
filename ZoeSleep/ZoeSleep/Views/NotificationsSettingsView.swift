//
//  NotificationsSettingsView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Notification preferences settings
//

import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {
    // MARK: - UserDefaults Keys
    private static let morningReminderEnabledKey = "morningReminderEnabled"
    private static let eveningReminderEnabledKey = "eveningReminderEnabled"
    private static let morningReminderHourKey = "morningReminderHour"
    private static let morningReminderMinuteKey = "morningReminderMinute"
    private static let eveningReminderHourKey = "eveningReminderHour"
    private static let eveningReminderMinuteKey = "eveningReminderMinute"

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
                    } else {
                        // Cancel all reminders when disabled
                        NotificationManager.shared.cancelSleepReminders()
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
                    .onChange(of: morningReminder) { _, enabled in
                        saveMorningReminder(enabled: enabled)
                        scheduleReminders()
                    }

                    if morningReminder {
                        DatePicker("Time", selection: $morningTime, displayedComponents: .hourAndMinute)
                            .onChange(of: morningTime) { _, newTime in
                                saveMorningTime(newTime)
                                scheduleReminders()
                            }
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
                    .onChange(of: eveningReminder) { _, enabled in
                        saveEveningReminder(enabled: enabled)
                        scheduleReminders()
                    }

                    if eveningReminder {
                        DatePicker("Time", selection: $eveningTime, displayedComponents: .hourAndMinute)
                            .onChange(of: eveningTime) { _, newTime in
                                saveEveningTime(newTime)
                                scheduleReminders()
                            }
                    }
                } header: {
                    Text("Evening Reminder")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSavedSettings()
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

    // MARK: - Load/Save Settings

    private func loadSavedSettings() {
        let defaults = UserDefaults.standard

        // Load reminder toggles (default to true)
        morningReminder = defaults.object(forKey: Self.morningReminderEnabledKey) as? Bool ?? true
        eveningReminder = defaults.object(forKey: Self.eveningReminderEnabledKey) as? Bool ?? true

        // Load morning time (default 8:00 AM)
        let morningHour = defaults.object(forKey: Self.morningReminderHourKey) as? Int ?? 8
        let morningMinute = defaults.object(forKey: Self.morningReminderMinuteKey) as? Int ?? 0
        morningTime = Calendar.current.date(from: DateComponents(hour: morningHour, minute: morningMinute)) ?? Date()

        // Load evening time (default 9:00 PM)
        let eveningHour = defaults.object(forKey: Self.eveningReminderHourKey) as? Int ?? 21
        let eveningMinute = defaults.object(forKey: Self.eveningReminderMinuteKey) as? Int ?? 0
        eveningTime = Calendar.current.date(from: DateComponents(hour: eveningHour, minute: eveningMinute)) ?? Date()

        print("[Notifications] Loaded settings - Morning: \(morningHour):\(morningMinute), Evening: \(eveningHour):\(eveningMinute)")
    }

    private func saveMorningReminder(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.morningReminderEnabledKey)
    }

    private func saveEveningReminder(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.eveningReminderEnabledKey)
    }

    private func saveMorningTime(_ time: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        UserDefaults.standard.set(components.hour, forKey: Self.morningReminderHourKey)
        UserDefaults.standard.set(components.minute, forKey: Self.morningReminderMinuteKey)
        print("[Notifications] Saved morning time: \(components.hour ?? 8):\(components.minute ?? 0)")
    }

    private func saveEveningTime(_ time: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        UserDefaults.standard.set(components.hour, forKey: Self.eveningReminderHourKey)
        UserDefaults.standard.set(components.minute, forKey: Self.eveningReminderMinuteKey)
        print("[Notifications] Saved evening time: \(components.hour ?? 21):\(components.minute ?? 0)")
    }

    // MARK: - Notification Scheduling

    private func scheduleReminders() {
        Task {
            let morningComponents = Calendar.current.dateComponents([.hour, .minute], from: morningTime)
            let eveningComponents = Calendar.current.dateComponents([.hour, .minute], from: eveningTime)

            await NotificationManager.shared.scheduleSleepReminders(
                morningEnabled: morningReminder,
                morningHour: morningComponents.hour ?? 8,
                morningMinute: morningComponents.minute ?? 0,
                eveningEnabled: eveningReminder,
                eveningHour: eveningComponents.hour ?? 21,
                eveningMinute: eveningComponents.minute ?? 0
            )
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
                if granted {
                    // Schedule reminders with current settings after permission granted
                    scheduleReminders()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
}
