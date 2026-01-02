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
    @State private var morningReminderEnabled = true
    @State private var morningTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var eveningReminderEnabled = true
    @State private var eveningTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    @State private var showingPermissionAlert = false
    @ObservedObject private var timeFormatManager = TimeFormatManager.shared

    // Force DatePicker to use 12-hour or 24-hour format based on user preference
    private var pickerLocale: Locale {
        switch timeFormatManager.preference {
        case .system:
            return Locale.current
        case .hour12:
            return Locale(identifier: "en_US")
        case .hour24:
            return Locale(identifier: "en_GB")
        }
    }

    var body: some View {
        List {
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Notifications")
                            .font(.headline)
                        Text("Get reminders to complete your daily tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        requestNotificationPermission()
                    } else {
                        // Cancel all reminders when disabled
                        NotificationManager.shared.cancelDailyTaskReminder()
                    }
                }
            } header: {
                Text("Notifications")
            }

            if notificationsEnabled {
                Section {
                    Toggle(isOn: $morningReminderEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Morning Reminder")
                                .font(.headline)
                            Text("Reminder to log your sleep")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: morningReminderEnabled) { _, _ in
                        saveAndScheduleMorningReminder()
                    }

                    if morningReminderEnabled {
                        DatePicker("Time", selection: $morningTime, displayedComponents: .hourAndMinute)
                            .environment(\.locale, pickerLocale)
                            .onChange(of: morningTime) { _, _ in
                                saveAndScheduleMorningReminder()
                            }
                    }
                } header: {
                    Text("Morning Reminder")
                } footer: {
                    Text("Reminds you to complete your sleep log after waking up.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Toggle(isOn: $eveningReminderEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Evening Reminder")
                                .font(.headline)
                            Text("Follow-up if tasks are still incomplete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: eveningReminderEnabled) { _, _ in
                        saveAndScheduleEveningReminder()
                    }

                    if eveningReminderEnabled {
                        DatePicker("Time", selection: $eveningTime, displayedComponents: .hourAndMinute)
                            .environment(\.locale, pickerLocale)
                            .onChange(of: eveningTime) { _, _ in
                                saveAndScheduleEveningReminder()
                            }
                    }
                } header: {
                    Text("Evening Reminder")
                } footer: {
                    Text("A gentle follow-up if you haven't completed your tasks yet. Won't notify if everything is done.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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

        // Load morning reminder settings (default 9:00 AM)
        morningReminderEnabled = defaults.object(forKey: NotificationManager.dailyReminderEnabledKey) as? Bool ?? true
        let morningHour = defaults.object(forKey: NotificationManager.dailyReminderHourKey) as? Int ?? 9
        let morningMinute = defaults.object(forKey: NotificationManager.dailyReminderMinuteKey) as? Int ?? 0
        morningTime = Calendar.current.date(from: DateComponents(hour: morningHour, minute: morningMinute)) ?? Date()

        // Load evening reminder settings (default 8:00 PM)
        eveningReminderEnabled = defaults.object(forKey: NotificationManager.eveningReminderEnabledKey) as? Bool ?? true
        let eveningHour = defaults.object(forKey: NotificationManager.eveningReminderHourKey) as? Int ?? 20
        let eveningMinute = defaults.object(forKey: NotificationManager.eveningReminderMinuteKey) as? Int ?? 0
        eveningTime = Calendar.current.date(from: DateComponents(hour: eveningHour, minute: eveningMinute)) ?? Date()

        print("[Notifications] Loaded settings - Morning: \(morningHour):\(String(format: "%02d", morningMinute)), Evening: \(eveningHour):\(String(format: "%02d", eveningMinute))")
    }

    private func saveAndScheduleMorningReminder() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: morningTime)
        let hour = components.hour ?? 9
        let minute = components.minute ?? 0

        print("[Notifications] Saving morning reminder - enabled: \(morningReminderEnabled), time: \(hour):\(String(format: "%02d", minute))")

        Task {
            await NotificationManager.shared.scheduleDailyTaskReminder(
                enabled: morningReminderEnabled,
                hour: hour,
                minute: minute
            )
        }
    }

    private func saveAndScheduleEveningReminder() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: eveningTime)
        let hour = components.hour ?? 20
        let minute = components.minute ?? 0

        print("[Notifications] Saving evening reminder - enabled: \(eveningReminderEnabled), time: \(hour):\(String(format: "%02d", minute))")

        Task {
            await NotificationManager.shared.scheduleEveningReminder(
                enabled: eveningReminderEnabled,
                hour: hour,
                minute: minute
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
                    // Schedule both reminders with current settings after permission granted
                    saveAndScheduleMorningReminder()
                    saveAndScheduleEveningReminder()
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
