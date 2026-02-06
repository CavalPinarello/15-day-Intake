//
//  NotificationTimelineView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Visual timeline preview of all scheduled notifications
//  Sorted chronologically with icons, colors, and time display
//

import SwiftUI

struct NotificationTimelineView: View {
    let sleepLogEnabled: Bool
    let sleepLogTime: Date
    let assessmentEnabled: Bool
    let assessmentTime: Date
    let overdueEnabled: Bool
    let overdueTime: Date
    let morningCheckInEnabled: Bool
    let morningCheckInTime: Date
    let middayCheckInEnabled: Bool
    let middayCheckInTime: Date
    let eveningCheckInEnabled: Bool
    let eveningCheckInTime: Date
    let hasWatch: Bool

    private struct ScheduledNotification: Identifiable {
        let id = UUID()
        let time: Date
        let title: String
        let icon: String
        let color: Color
        let isConditional: Bool
    }

    private var scheduledNotifications: [ScheduledNotification] {
        var notifications: [ScheduledNotification] = []

        if sleepLogEnabled {
            notifications.append(ScheduledNotification(
                time: sleepLogTime,
                title: "Sleep Log",
                icon: "moon.zzz.fill",
                color: .blue,
                isConditional: false
            ))
        }

        if assessmentEnabled {
            notifications.append(ScheduledNotification(
                time: assessmentTime,
                title: "Assessment",
                icon: "checklist",
                color: .green,
                isConditional: false
            ))
        }

        if overdueEnabled {
            notifications.append(ScheduledNotification(
                time: overdueTime,
                title: "Catch-Up (if needed)",
                icon: "clock.badge.exclamationmark",
                color: .orange,
                isConditional: true
            ))
        }

        if morningCheckInEnabled {
            notifications.append(ScheduledNotification(
                time: morningCheckInTime,
                title: "Morning Check-In",
                icon: "sun.max.fill",
                color: .yellow,
                isConditional: false
            ))
        }

        if middayCheckInEnabled {
            notifications.append(ScheduledNotification(
                time: middayCheckInTime,
                title: hasWatch ? "Midday Check-In (Watch)" : "Midday Check-In",
                icon: hasWatch ? "applewatch" : "sun.and.horizon.fill",
                color: .orange,
                isConditional: false
            ))
        }

        if eveningCheckInEnabled {
            notifications.append(ScheduledNotification(
                time: eveningCheckInTime,
                title: hasWatch ? "Evening Check-In (Watch)" : "Evening Check-In",
                icon: hasWatch ? "applewatch" : "moon.fill",
                color: .indigo,
                isConditional: false
            ))
        }

        return notifications.sorted { $0.time < $1.time }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if scheduledNotifications.isEmpty {
                HStack {
                    Image(systemName: "bell.slash.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No notifications scheduled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(scheduledNotifications) { notification in
                    HStack(spacing: 12) {
                        Image(systemName: notification.icon)
                            .font(.title3)
                            .foregroundColor(notification.color)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(notification.title)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            if notification.isConditional {
                                Text("Only sent if tasks incomplete")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Text(formatTime(notification.time))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    let previewTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()

    List {
        Section {
            NotificationTimelineView(
                sleepLogEnabled: true,
                sleepLogTime: previewTime,
                assessmentEnabled: true,
                assessmentTime: previewTime,
                overdueEnabled: true,
                overdueTime: Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date(),
                morningCheckInEnabled: true,
                morningCheckInTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date(),
                middayCheckInEnabled: true,
                middayCheckInTime: Calendar.current.date(from: DateComponents(hour: 13, minute: 0)) ?? Date(),
                eveningCheckInEnabled: true,
                eveningCheckInTime: Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date(),
                hasWatch: true
            )
        } header: {
            Text("Today's Schedule")
        }
    }
}
