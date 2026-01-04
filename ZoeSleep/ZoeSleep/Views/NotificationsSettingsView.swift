//
//  NotificationsSettingsView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Notification preferences settings
//  Simplified to 3 daily reminders: Morning (9 AM), Afternoon (1 PM), Evening (8 PM)
//

import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {
    @State private var notificationsEnabled = false
    @State private var morningReminderEnabled = true
    @State private var morningTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var afternoonReminderEnabled = true
    @State private var afternoonTime = Calendar.current.date(from: DateComponents(hour: 13, minute: 0)) ?? Date()
    @State private var eveningReminderEnabled = true
    @State private var eveningTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    @State private var showingPermissionAlert = false
    @ObservedObject private var timeFormatManager = TimeFormatManager.shared
    @ObservedObject private var watchConnectivity = iOSWatchConnectivityManager.shared

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
                        NotificationManager.shared.cancelAllCheckInNudges()
                    }
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("You'll receive up to 3 reminders per day: morning, afternoon, and evening.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if notificationsEnabled {
                // MARK: - Morning Reminder
                Section {
                    Toggle(isOn: $morningReminderEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Morning Reminder")
                                .font(.headline)
                            Text("Sleep log, assessment & energy check-in")
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
                    Text("Morning")
                } footer: {
                    Text("Reminds you to complete your sleep log, daily assessment, and morning energy check-in.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - Afternoon Reminder
                Section {
                    Toggle(isOn: $afternoonReminderEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Afternoon Reminder")
                                .font(.headline)
                            HStack(spacing: 4) {
                                Text("Midday energy check-in")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if watchConnectivity.isWatchAppInstalled {
                                    Text("(Watch handles this)")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .onChange(of: afternoonReminderEnabled) { _, _ in
                        saveAndScheduleAfternoonReminder()
                    }

                    if afternoonReminderEnabled && !watchConnectivity.isWatchAppInstalled {
                        DatePicker("Time", selection: $afternoonTime, displayedComponents: .hourAndMinute)
                            .environment(\.locale, pickerLocale)
                            .onChange(of: afternoonTime) { _, _ in
                                saveAndScheduleAfternoonReminder()
                            }
                    }
                } header: {
                    Text("Afternoon")
                } footer: {
                    if watchConnectivity.isWatchAppInstalled {
                        Text("Your Apple Watch will handle midday check-in reminders.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Reminds you to complete your midday energy, mood, and focus check-in.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - Evening Reminder
                Section {
                    Toggle(isOn: $eveningReminderEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Evening Reminder")
                                .font(.headline)
                            Text("Energy check-in & incomplete tasks")
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
                    Text("Evening")
                } footer: {
                    Text("Reminds you to complete your evening energy check-in and any remaining tasks from the day.")
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

        // Load afternoon reminder settings (default 1:00 PM)
        afternoonReminderEnabled = defaults.object(forKey: NotificationManager.afternoonReminderEnabledKey) as? Bool ?? true
        let afternoonHour = defaults.object(forKey: NotificationManager.afternoonReminderHourKey) as? Int ?? 13
        let afternoonMinute = defaults.object(forKey: NotificationManager.afternoonReminderMinuteKey) as? Int ?? 0
        afternoonTime = Calendar.current.date(from: DateComponents(hour: afternoonHour, minute: afternoonMinute)) ?? Date()

        // Load evening reminder settings (default 8:00 PM)
        eveningReminderEnabled = defaults.object(forKey: NotificationManager.eveningReminderEnabledKey) as? Bool ?? true
        let eveningHour = defaults.object(forKey: NotificationManager.eveningReminderHourKey) as? Int ?? 20
        let eveningMinute = defaults.object(forKey: NotificationManager.eveningReminderMinuteKey) as? Int ?? 0
        eveningTime = Calendar.current.date(from: DateComponents(hour: eveningHour, minute: eveningMinute)) ?? Date()

        print("[Notifications] Loaded settings - Morning: \(morningHour):\(String(format: "%02d", morningMinute)), Afternoon: \(afternoonHour):\(String(format: "%02d", afternoonMinute)), Evening: \(eveningHour):\(String(format: "%02d", eveningMinute))")
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

    private func saveAndScheduleAfternoonReminder() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: afternoonTime)
        let hour = components.hour ?? 13
        let minute = components.minute ?? 0

        print("[Notifications] Saving afternoon reminder - enabled: \(afternoonReminderEnabled), time: \(hour):\(String(format: "%02d", minute))")

        Task {
            await NotificationManager.shared.scheduleAfternoonReminder(
                enabled: afternoonReminderEnabled,
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
                    // Schedule all reminders with current settings after permission granted
                    saveAndScheduleMorningReminder()
                    saveAndScheduleAfternoonReminder()
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
