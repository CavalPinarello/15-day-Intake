//
//  NotificationsSettingsView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Comprehensive notification management panel
//  - Sleep log & assessment reminders
//  - Overdue catch-up notifications
//  - Energy check-ins (iPhone + Watch coordination)
//  - Visual timeline preview
//

import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {
    @State private var notificationsEnabled = false
    @State private var showingPermissionAlert = false

    // Sleep Log & Assessment
    @State private var sleepLogEnabled = true
    @State private var sleepLogTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var assessmentEnabled = true
    @State private var assessmentSameAsSleepLog = true
    @State private var assessmentTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()

    // Overdue Catch-Up
    @State private var overdueEnabled = true
    @State private var overdueReminderTime = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
    @State private var overdueCheckTime = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()

    // Check-Ins
    @State private var morningCheckInEnabled = true
    @State private var morningCheckInTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @State private var middayCheckInEnabled = true
    @State private var middayCheckInTime = Calendar.current.date(from: DateComponents(hour: 13, minute: 0)) ?? Date()
    @State private var eveningCheckInEnabled = true
    @State private var eveningCheckInTime = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()

    // Watch Coordination
    @State private var autoSkipIfWatch = true

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

    private var activeNotificationCountText: String {
        var count = 0
        if sleepLogEnabled { count += 1 }
        if assessmentEnabled { count += 1 }
        if overdueEnabled { count += 1 }
        if morningCheckInEnabled { count += 1 }
        if middayCheckInEnabled && (!autoSkipIfWatch || !watchConnectivity.isWatchAppInstalled) { count += 1 }
        if eveningCheckInEnabled && (!autoSkipIfWatch || !watchConnectivity.isWatchAppInstalled) { count += 1 }

        if watchConnectivity.isWatchAppInstalled && autoSkipIfWatch {
            return "\(count) iPhone + 2 Watch reminders active"
        } else {
            return "\(count) reminders active"
        }
    }

    private var footerText: Text {
        if watchConnectivity.isWatchAppInstalled {
            return Text("Manage your notification preferences. Your Apple Watch will handle energy check-ins during the day.")
        } else {
            return Text("Manage your daily notification preferences. Get reminders to complete tasks and check-ins.")
        }
    }

    var body: some View {
        List {
            // SECTION 1: Master Toggle
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Notifications")
                            .font(.headline)
                        Text(activeNotificationCountText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        requestNotificationPermission()
                    } else {
                        // Cancel all reminders when disabled
                        NotificationManager.shared.cancelAllNotifications()
                    }
                }
            } header: {
                Text("Notifications")
            } footer: {
                footerText
            }

            if notificationsEnabled {
                // SECTION 2: Daily Tasks (iPhone)
                Section {
                    // Sleep Log Reminder
                    Toggle(isOn: $sleepLogEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sleep Log Reminder")
                                .font(.headline)
                            Text("Log how you slept last night")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: sleepLogEnabled) { _, _ in
                        saveAndSchedule()
                    }

                    if sleepLogEnabled {
                        DatePicker("Time", selection: $sleepLogTime, displayedComponents: .hourAndMinute)
                            .environment(\.locale, pickerLocale)
                            .onChange(of: sleepLogTime) { _, _ in
                                saveAndSchedule()
                            }
                    }

                    // Assessment Reminder
                    Toggle(isOn: $assessmentEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Assessment Reminder")
                                .font(.headline)
                            Text("Daily health questions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: assessmentEnabled) { _, _ in
                        saveAndSchedule()
                    }

                    if assessmentEnabled {
                        Toggle("Same time as Sleep Log", isOn: $assessmentSameAsSleepLog)
                            .font(.subheadline)
                            .onChange(of: assessmentSameAsSleepLog) { _, _ in
                                saveAndSchedule()
                            }

                        if !assessmentSameAsSleepLog {
                            DatePicker("Time", selection: $assessmentTime, displayedComponents: .hourAndMinute)
                                .environment(\.locale, pickerLocale)
                                .onChange(of: assessmentTime) { _, _ in
                                    saveAndSchedule()
                                }
                        }
                    }
                } header: {
                    Text("Daily Tasks (iPhone)")
                } footer: {
                    Text("Reminders to complete your sleep log and daily assessment questions.")
                }

                // SECTION 3: Overdue Catch-Up
                Section {
                    Toggle(isOn: $overdueEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Catch-Up Reminder")
                                .font(.headline)
                            Text("Reminds you if tasks incomplete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: overdueEnabled) { _, _ in
                        saveAndSchedule()
                    }

                    if overdueEnabled {
                        DatePicker("Check if incomplete by", selection: $overdueCheckTime, displayedComponents: .hourAndMinute)
                            .environment(\.locale, pickerLocale)
                            .onChange(of: overdueCheckTime) { _, _ in
                                saveAndSchedule()
                            }

                        DatePicker("Send reminder at", selection: $overdueReminderTime, displayedComponents: .hourAndMinute)
                            .environment(\.locale, pickerLocale)
                            .onChange(of: overdueReminderTime) { _, _ in
                                saveAndSchedule()
                            }
                    }
                } header: {
                    Text("Catch-Up Reminder (iPhone)")
                } footer: {
                    Text("If sleep log or assessment is still incomplete by the check time, you'll receive a catch-up reminder.")
                }

                // SECTION 4: Energy Check-Ins
                Section {
                    // Morning Check-In
                    Toggle(isOn: $morningCheckInEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Morning Check-In")
                                .font(.headline)
                            Text("Energy · Mood · Focus")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: morningCheckInEnabled) { _, _ in
                        saveAndSchedule()
                    }

                    if morningCheckInEnabled {
                        DatePicker("Time", selection: $morningCheckInTime, displayedComponents: .hourAndMinute)
                            .environment(\.locale, pickerLocale)
                            .onChange(of: morningCheckInTime) { _, _ in
                                saveAndSchedule()
                            }
                    }

                    // Midday Check-In
                    if watchConnectivity.isWatchAppInstalled {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Midday Check-In")
                                    .font(.headline)
                                HStack(spacing: 4) {
                                    Image(systemName: "applewatch")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    Text("Managed by Apple Watch")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(formatTime(middayCheckInTime))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Toggle(isOn: $middayCheckInEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Midday Check-In")
                                    .font(.headline)
                                Text("Energy · Mood · Focus")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: middayCheckInEnabled) { _, _ in
                            saveAndSchedule()
                        }

                        if middayCheckInEnabled {
                            DatePicker("Time", selection: $middayCheckInTime, displayedComponents: .hourAndMinute)
                                .environment(\.locale, pickerLocale)
                                .onChange(of: middayCheckInTime) { _, _ in
                                    saveAndSchedule()
                                }
                        }
                    }

                    // Evening Check-In
                    if watchConnectivity.isWatchAppInstalled {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Evening Check-In")
                                    .font(.headline)
                                HStack(spacing: 4) {
                                    Image(systemName: "applewatch")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    Text("Managed by Apple Watch")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(formatTime(eveningCheckInTime))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Toggle(isOn: $eveningCheckInEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Evening Check-In")
                                    .font(.headline)
                                Text("Energy · Mood · Focus")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: eveningCheckInEnabled) { _, _ in
                            saveAndSchedule()
                        }

                        if eveningCheckInEnabled {
                            DatePicker("Time", selection: $eveningCheckInTime, displayedComponents: .hourAndMinute)
                                .environment(\.locale, pickerLocale)
                                .onChange(of: eveningCheckInTime) { _, _ in
                                    saveAndSchedule()
                                }
                        }
                    }
                } header: {
                    Text("Energy Check-Ins")
                } footer: {
                    if watchConnectivity.isWatchAppInstalled {
                        Text("Your Apple Watch handles midday and evening check-ins. The times shown are suggestions synced from your iPhone settings.")
                    } else {
                        Text("Quick daily check-ins to rate your energy, mood, and focus levels.")
                    }
                }

                // SECTION 5: Notification Timeline Preview
                // Note: NotificationTimelineView.swift exists but needs to be added to Xcode project target
                // To enable, add ZoeSleep/Views/NotificationTimelineView.swift to the ZoeSleep target in Xcode
                /*
                Section {
                    NotificationTimelineView(
                        sleepLogEnabled: sleepLogEnabled,
                        sleepLogTime: sleepLogTime,
                        assessmentEnabled: assessmentEnabled,
                        assessmentTime: assessmentSameAsSleepLog ? sleepLogTime : assessmentTime,
                        overdueEnabled: overdueEnabled,
                        overdueTime: overdueReminderTime,
                        morningCheckInEnabled: morningCheckInEnabled,
                        morningCheckInTime: morningCheckInTime,
                        middayCheckInEnabled: middayCheckInEnabled,
                        middayCheckInTime: middayCheckInTime,
                        eveningCheckInEnabled: eveningCheckInEnabled,
                        eveningCheckInTime: eveningCheckInTime,
                        hasWatch: watchConnectivity.isWatchAppInstalled
                    )
                } header: {
                    Text("Today's Schedule")
                }
                */

                // SECTION 6: Smart Features
                if watchConnectivity.isWatchAppInstalled {
                    Section {
                        Toggle(isOn: $autoSkipIfWatch) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto-skip iPhone reminders")
                                    .font(.headline)
                                Text("Skip iPhone check-in reminders when Watch handles them")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: autoSkipIfWatch) { _, _ in
                            saveAndSchedule()
                        }
                    } header: {
                        Text("Smart Features")
                    }
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

    // MARK: - Helper Functions

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Load/Save Settings

    private func loadSavedSettings() {
        let defaults = UserDefaults.standard

        // Sleep Log
        sleepLogEnabled = defaults.object(forKey: NotificationManager.sleepLogReminderEnabledKey) as? Bool ?? true
        let sleepLogHour = defaults.object(forKey: NotificationManager.sleepLogReminderHourKey) as? Int ?? 8
        let sleepLogMinute = defaults.object(forKey: NotificationManager.sleepLogReminderMinuteKey) as? Int ?? 0
        sleepLogTime = Calendar.current.date(from: DateComponents(hour: sleepLogHour, minute: sleepLogMinute)) ?? Date()

        // Assessment
        assessmentEnabled = defaults.object(forKey: NotificationManager.assessmentReminderEnabledKey) as? Bool ?? true
        assessmentSameAsSleepLog = defaults.object(forKey: NotificationManager.assessmentSameAsSleepLogKey) as? Bool ?? true
        let assessmentHour = defaults.object(forKey: NotificationManager.assessmentReminderHourKey) as? Int ?? 9
        let assessmentMinute = defaults.object(forKey: NotificationManager.assessmentReminderMinuteKey) as? Int ?? 0
        assessmentTime = Calendar.current.date(from: DateComponents(hour: assessmentHour, minute: assessmentMinute)) ?? Date()

        // Overdue
        overdueEnabled = defaults.object(forKey: NotificationManager.overdueReminderEnabledKey) as? Bool ?? true
        let overdueHour = defaults.object(forKey: NotificationManager.overdueReminderHourKey) as? Int ?? 18
        let overdueMinute = defaults.object(forKey: NotificationManager.overdueReminderMinuteKey) as? Int ?? 0
        overdueReminderTime = Calendar.current.date(from: DateComponents(hour: overdueHour, minute: overdueMinute)) ?? Date()
        let overdueCheckHour = defaults.object(forKey: NotificationManager.overdueCheckTimeHourKey) as? Int ?? 17
        let overdueCheckMinute = defaults.object(forKey: NotificationManager.overdueCheckTimeMinuteKey) as? Int ?? 0
        overdueCheckTime = Calendar.current.date(from: DateComponents(hour: overdueCheckHour, minute: overdueCheckMinute)) ?? Date()

        // Check-Ins
        morningCheckInEnabled = defaults.object(forKey: NotificationManager.morningCheckInReminderEnabledKey) as? Bool ?? true
        let morningCheckInHour = defaults.object(forKey: NotificationManager.morningCheckInReminderHourKey) as? Int ?? 7
        let morningCheckInMinute = defaults.object(forKey: NotificationManager.morningCheckInReminderMinuteKey) as? Int ?? 0
        morningCheckInTime = Calendar.current.date(from: DateComponents(hour: morningCheckInHour, minute: morningCheckInMinute)) ?? Date()

        middayCheckInEnabled = defaults.object(forKey: NotificationManager.middayCheckInReminderEnabledKey) as? Bool ?? true
        let middayCheckInHour = defaults.object(forKey: NotificationManager.middayCheckInReminderHourKey) as? Int ?? 13
        let middayCheckInMinute = defaults.object(forKey: NotificationManager.middayCheckInReminderMinuteKey) as? Int ?? 0
        middayCheckInTime = Calendar.current.date(from: DateComponents(hour: middayCheckInHour, minute: middayCheckInMinute)) ?? Date()

        eveningCheckInEnabled = defaults.object(forKey: NotificationManager.eveningCheckInReminderEnabledKey) as? Bool ?? true
        let eveningCheckInHour = defaults.object(forKey: NotificationManager.eveningCheckInReminderHourKey) as? Int ?? 18
        let eveningCheckInMinute = defaults.object(forKey: NotificationManager.eveningCheckInReminderMinuteKey) as? Int ?? 0
        eveningCheckInTime = Calendar.current.date(from: DateComponents(hour: eveningCheckInHour, minute: eveningCheckInMinute)) ?? Date()

        // Watch Coordination
        autoSkipIfWatch = defaults.object(forKey: NotificationManager.autoSkipIPhoneIfWatchEnabledKey) as? Bool ?? true

        print("[Notifications] Loaded settings - Sleep Log: \(sleepLogHour):\(String(format: "%02d", sleepLogMinute)), Assessment: \(assessmentSameAsSleepLog ? "Same as Sleep Log" : "\(assessmentHour):\(String(format: "%02d", assessmentMinute))")")
    }

    private func saveAndSchedule() {
        let defaults = UserDefaults.standard

        // Sleep Log
        defaults.set(sleepLogEnabled, forKey: NotificationManager.sleepLogReminderEnabledKey)
        let sleepLogComponents = Calendar.current.dateComponents([.hour, .minute], from: sleepLogTime)
        defaults.set(sleepLogComponents.hour ?? 8, forKey: NotificationManager.sleepLogReminderHourKey)
        defaults.set(sleepLogComponents.minute ?? 0, forKey: NotificationManager.sleepLogReminderMinuteKey)

        // Assessment
        defaults.set(assessmentEnabled, forKey: NotificationManager.assessmentReminderEnabledKey)
        defaults.set(assessmentSameAsSleepLog, forKey: NotificationManager.assessmentSameAsSleepLogKey)
        let assessmentComponents = Calendar.current.dateComponents([.hour, .minute], from: assessmentTime)
        defaults.set(assessmentComponents.hour ?? 9, forKey: NotificationManager.assessmentReminderHourKey)
        defaults.set(assessmentComponents.minute ?? 0, forKey: NotificationManager.assessmentReminderMinuteKey)

        // Overdue
        defaults.set(overdueEnabled, forKey: NotificationManager.overdueReminderEnabledKey)
        let overdueComponents = Calendar.current.dateComponents([.hour, .minute], from: overdueReminderTime)
        defaults.set(overdueComponents.hour ?? 18, forKey: NotificationManager.overdueReminderHourKey)
        defaults.set(overdueComponents.minute ?? 0, forKey: NotificationManager.overdueReminderMinuteKey)
        let overdueCheckComponents = Calendar.current.dateComponents([.hour, .minute], from: overdueCheckTime)
        defaults.set(overdueCheckComponents.hour ?? 17, forKey: NotificationManager.overdueCheckTimeHourKey)
        defaults.set(overdueCheckComponents.minute ?? 0, forKey: NotificationManager.overdueCheckTimeMinuteKey)

        // Check-Ins
        defaults.set(morningCheckInEnabled, forKey: NotificationManager.morningCheckInReminderEnabledKey)
        let morningComponents = Calendar.current.dateComponents([.hour, .minute], from: morningCheckInTime)
        defaults.set(morningComponents.hour ?? 7, forKey: NotificationManager.morningCheckInReminderHourKey)
        defaults.set(morningComponents.minute ?? 0, forKey: NotificationManager.morningCheckInReminderMinuteKey)

        defaults.set(middayCheckInEnabled, forKey: NotificationManager.middayCheckInReminderEnabledKey)
        let middayComponents = Calendar.current.dateComponents([.hour, .minute], from: middayCheckInTime)
        defaults.set(middayComponents.hour ?? 13, forKey: NotificationManager.middayCheckInReminderHourKey)
        defaults.set(middayComponents.minute ?? 0, forKey: NotificationManager.middayCheckInReminderMinuteKey)

        defaults.set(eveningCheckInEnabled, forKey: NotificationManager.eveningCheckInReminderEnabledKey)
        let eveningComponents = Calendar.current.dateComponents([.hour, .minute], from: eveningCheckInTime)
        defaults.set(eveningComponents.hour ?? 18, forKey: NotificationManager.eveningCheckInReminderHourKey)
        defaults.set(eveningComponents.minute ?? 0, forKey: NotificationManager.eveningCheckInReminderMinuteKey)

        // Watch Coordination
        defaults.set(autoSkipIfWatch, forKey: NotificationManager.autoSkipIPhoneIfWatchEnabledKey)

        print("[Notifications] Saved settings - scheduling all notifications")

        // Schedule all notifications
        Task {
            await NotificationManager.shared.scheduleAllNotificationsFromSettings()

            // Sync times to Watch (if installed)
            if watchConnectivity.isWatchAppInstalled {
                iOSWatchConnectivityManager.shared.syncNotificationTimesToWatch()
            }
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
                    // Schedule notifications after permission granted
                    saveAndSchedule()
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
