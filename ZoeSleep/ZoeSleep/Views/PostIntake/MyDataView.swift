//
//  MyDataView.swift
//  Zoe Sleep for Longevity System
//
//  Shows user's completed journey data while awaiting physician analysis
//  Reuses existing Sleep Diary and Insights views
//

import SwiftUI

struct MyDataView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            TabView {
                // Sleep Diary Tab
                SleepDiaryHistoryView()
                    .environmentObject(themeManager)
                    .tabItem {
                        Label("Sleep Diary", systemImage: "moon.zzz.fill")
                    }

                // Insights Tab
                SleepInsightsDashboardView()
                    .environmentObject(themeManager)
                    .tabItem {
                        Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                    }
            }
            .tint(theme.accent)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.accent)
                }
            }
        }
    }
}

#Preview {
    MyDataView()
        .environmentObject(ThemeManager.shared)
}
