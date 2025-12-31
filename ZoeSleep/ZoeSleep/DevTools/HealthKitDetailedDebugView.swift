//
//  HealthKitDetailedDebugView.swift
//  ZoeSleep
//
//  Comprehensive debug view for HealthKit data verification
//  Shows sleep, HR, HRV, activity, temperature, and light exposure
//  with trend charts and date filtering
//

import SwiftUI
import Charts
import HealthKit

// MARK: - Data Models

struct HealthMetricEntry: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String
}

struct SleepStageEntry: Identifiable {
    let id = UUID()
    let date: Date
    let deep: Double
    let light: Double
    let rem: Double
    let awake: Double
}

struct DailySleepSummary: Identifiable {
    let id = UUID()
    let date: Date
    let dateString: String
    let totalSleepMins: Int
    let deepMins: Int
    let lightMins: Int
    let remMins: Int
    let awakeMins: Int
    let efficiency: Double
    let latencyMins: Int
    let awakenings: Int
    let inBedTime: String?
    let wakeTime: String?
    let source: String
}

struct HeartRateSummary: Identifiable {
    let id = UUID()
    let date: Date
    let dateString: String
    let restingHR: Double?
    let avgHR: Double?
    let minHR: Double?
    let maxHR: Double?
}

struct HRVSummary: Identifiable {
    let id = UUID()
    let date: Date
    let dateString: String
    let avgHRV: Double
    let minHRV: Double?
    let maxHRV: Double?
}

struct ActivitySummary: Identifiable {
    let id = UUID()
    let date: Date
    let dateString: String
    let steps: Int
    let activeCalories: Double
    let exerciseMinutes: Int
    let standHours: Int
}

struct TemperatureSummary: Identifiable {
    let id = UUID()
    let date: Date
    let dateString: String
    let wristTemp: Double?
    let tempDeviation: Double?
}

struct LightExposureSummary: Identifiable {
    let id = UUID()
    let date: Date
    let dateString: String
    let totalMinutes: Int
}

// MARK: - Main View

struct HealthKitDetailedDebugView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = HealthKitDebugViewModel()

    @State private var selectedTab = 0
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var showDatePicker = false

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: 0) {
            // Date Range Picker
            dateRangeHeader

            // Tab Selection
            tabPicker

            // Content based on selected tab
            TabView(selection: $selectedTab) {
                sleepTab.tag(0)
                heartRateTab.tag(1)
                hrvTab.tag(2)
                activityTab.tag(3)
                temperatureTab.tag(4)
                lightExposureTab.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("HealthKit Debug")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.syncToConvex() }
                } label: {
                    if viewModel.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath.circle")
                    }
                }
                .disabled(viewModel.isSyncing)
            }
        }
        .task {
            await viewModel.fetchAllData(from: startDate, to: endDate)
        }
        .onChange(of: startDate) { _, _ in
            Task { await viewModel.fetchAllData(from: startDate, to: endDate) }
        }
        .onChange(of: endDate) { _, _ in
            Task { await viewModel.fetchAllData(from: startDate, to: endDate) }
        }
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
    }

    // MARK: - Date Range Header

    private var dateRangeHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    showDatePicker = true
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                        Text("\(formatDate(startDate)) - \(formatDate(endDate))")
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()

                // PROMINENT Mock Data Button
                Button {
                    print("[HealthKitDebug] Loading mock data...")
                    viewModel.loadMockData(from: startDate, to: endDate)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ladybug.fill")
                        Text("MOCK")
                            .fontWeight(.bold)
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }

                // Quick presets
                Menu {
                    Button("Last 7 Days") { setDateRange(days: 7) }
                    Button("Last 30 Days") { setDateRange(days: 30) }
                    Button("Last 90 Days") { setDateRange(days: 90) }
                    Button("Last 6 Months") { setDateRange(days: 180) }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)

            // Status bar
            HStack {
                Circle()
                    .fill(viewModel.isMockData ? Color.orange : (viewModel.isAuthorized ? Color.green : Color.red))
                    .frame(width: 8, height: 8)
                Text(viewModel.isMockData ? "MOCK DATA MODE" : (viewModel.isAuthorized ? "HealthKit Authorized" : "Not Authorized"))
                    .font(.caption)
                    .fontWeight(viewModel.isMockData ? .bold : .regular)
                    .foregroundColor(viewModel.isMockData ? .orange : .secondary)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            // Sync/Status message
            if let msg = viewModel.syncMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                    .padding(.horizontal)
            }

            // No data warning
            if !viewModel.isLoading && viewModel.sleepData.isEmpty && viewModel.heartRateData.isEmpty && !viewModel.isMockData {
                Text("No HealthKit data found. Tap MOCK to load test data for simulator testing.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                tabButton(title: "Sleep", icon: "moon.zzz.fill", index: 0, color: .purple)
                tabButton(title: "HR", icon: "heart.fill", index: 1, color: .red)
                tabButton(title: "HRV", icon: "waveform.path.ecg", index: 2, color: .orange)
                tabButton(title: "Activity", icon: "figure.walk", index: 3, color: .green)
                tabButton(title: "Temp", icon: "thermometer.medium", index: 4, color: .cyan)
                tabButton(title: "Light", icon: "sun.max.fill", index: 5, color: .yellow)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func tabButton(title: String, icon: String, index: Int, color: Color) -> some View {
        Button {
            withAnimation { selectedTab = index }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedTab == index ? color.opacity(0.2) : Color.clear)
            .foregroundColor(selectedTab == index ? color : .secondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedTab == index ? color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sleep Tab

    private var sleepTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Sleep Duration Chart
                chartCard(title: "Sleep Duration", icon: "moon.zzz.fill", color: .purple) {
                    if viewModel.sleepData.isEmpty {
                        emptyDataView(message: "No sleep data available")
                    } else {
                        Chart(viewModel.sleepData) { entry in
                            BarMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("Hours", Double(entry.totalSleepMins) / 60.0)
                            )
                            .foregroundStyle(Color.purple.gradient)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let hours = value.as(Double.self) {
                                        Text("\(Int(hours))h")
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: max(1, viewModel.sleepData.count / 7))) { value in
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .frame(height: 180)
                    }
                }

                // Sleep Stages Chart
                chartCard(title: "Sleep Stages", icon: "chart.bar.fill", color: .indigo) {
                    if viewModel.sleepData.isEmpty {
                        emptyDataView(message: "No sleep stage data")
                    } else {
                        Chart(viewModel.sleepData) { entry in
                            BarMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("Deep", Double(entry.deepMins) / 60.0)
                            )
                            .foregroundStyle(by: .value("Stage", "Deep"))

                            BarMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("REM", Double(entry.remMins) / 60.0)
                            )
                            .foregroundStyle(by: .value("Stage", "REM"))

                            BarMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("Light", Double(entry.lightMins) / 60.0)
                            )
                            .foregroundStyle(by: .value("Stage", "Light"))
                        }
                        .chartForegroundStyleScale([
                            "Deep": Color.indigo,
                            "REM": Color.cyan,
                            "Light": Color.purple.opacity(0.5)
                        ])
                        .frame(height: 180)
                    }
                }

                // Sleep Efficiency Chart
                chartCard(title: "Sleep Efficiency", icon: "percent", color: .green) {
                    if viewModel.sleepData.isEmpty {
                        emptyDataView(message: "No efficiency data")
                    } else {
                        Chart(viewModel.sleepData) { entry in
                            LineMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("Efficiency", entry.efficiency)
                            )
                            .foregroundStyle(Color.green)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("Efficiency", entry.efficiency)
                            )
                            .foregroundStyle(Color.green.opacity(0.2))
                            .interpolationMethod(.catmullRom)

                            // 85% threshold line
                            RuleMark(y: .value("Target", 85))
                                .foregroundStyle(Color.orange.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        }
                        .chartYScale(domain: 50...100)
                        .frame(height: 150)
                    }
                }

                // Sleep Data List
                dataListCard(title: "Daily Sleep Details", icon: "list.bullet") {
                    ForEach(viewModel.sleepData.prefix(14)) { entry in
                        sleepDetailRow(entry)
                        if entry.id != viewModel.sleepData.prefix(14).last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func sleepDetailRow(_ entry: DailySleepSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.dateString)
                    .font(.headline)
                Spacer()
                Text(formatDuration(entry.totalSleepMins))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            }

            HStack(spacing: 16) {
                miniStat(label: "Deep", value: formatDuration(entry.deepMins), color: .indigo)
                miniStat(label: "REM", value: formatDuration(entry.remMins), color: .cyan)
                miniStat(label: "Light", value: formatDuration(entry.lightMins), color: .purple.opacity(0.6))
                miniStat(label: "Awake", value: formatDuration(entry.awakeMins), color: .orange)
            }

            HStack(spacing: 16) {
                Label("\(Int(entry.efficiency))%", systemImage: "percent")
                    .font(.caption)
                    .foregroundColor(entry.efficiency >= 85 ? .green : .orange)

                if entry.latencyMins > 0 {
                    Label("\(entry.latencyMins)m onset", systemImage: "hourglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if entry.awakenings > 0 {
                    Label("\(entry.awakenings) wakeups", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(entry.source)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Heart Rate Tab

    private var heartRateTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Resting HR Chart
                chartCard(title: "Resting Heart Rate", icon: "heart.fill", color: .red) {
                    if viewModel.heartRateData.isEmpty {
                        emptyDataView(message: "No heart rate data available")
                    } else {
                        Chart(viewModel.heartRateData.filter { $0.restingHR != nil }) { entry in
                            LineMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("BPM", entry.restingHR ?? 0)
                            )
                            .foregroundStyle(Color.red)
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("BPM", entry.restingHR ?? 0)
                            )
                            .foregroundStyle(Color.red)
                        }
                        .frame(height: 180)
                    }
                }

                // HR Range Chart
                chartCard(title: "Heart Rate Range", icon: "arrow.up.arrow.down", color: .pink) {
                    if viewModel.heartRateData.isEmpty {
                        emptyDataView(message: "No heart rate range data")
                    } else {
                        Chart(viewModel.heartRateData.filter { $0.minHR != nil && $0.maxHR != nil }) { entry in
                            RectangleMark(
                                x: .value("Date", entry.date, unit: .day),
                                yStart: .value("Min", entry.minHR ?? 0),
                                yEnd: .value("Max", entry.maxHR ?? 0)
                            )
                            .foregroundStyle(Color.pink.opacity(0.3))

                            if let avg = entry.avgHR {
                                PointMark(
                                    x: .value("Date", entry.date, unit: .day),
                                    y: .value("Avg", avg)
                                )
                                .foregroundStyle(Color.pink)
                            }
                        }
                        .frame(height: 180)
                    }
                }

                // HR Data List
                dataListCard(title: "Daily Heart Rate", icon: "list.bullet") {
                    ForEach(viewModel.heartRateData.prefix(14)) { entry in
                        HStack {
                            Text(entry.dateString)
                                .font(.subheadline)
                            Spacer()
                            if let resting = entry.restingHR {
                                VStack(alignment: .trailing) {
                                    Text("\(Int(resting)) bpm")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    Text("Resting")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            if let min = entry.minHR, let max = entry.maxHR {
                                VStack(alignment: .trailing) {
                                    Text("\(Int(min))-\(Int(max))")
                                        .font(.subheadline)
                                    Text("Range")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 12)
                            }
                        }
                        .padding(.vertical, 4)
                        if entry.id != viewModel.heartRateData.prefix(14).last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - HRV Tab

    private var hrvTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // HRV Trend Chart
                chartCard(title: "Heart Rate Variability (SDNN)", icon: "waveform.path.ecg", color: .orange) {
                    if viewModel.hrvData.isEmpty {
                        emptyDataView(message: "No HRV data available")
                    } else {
                        Chart(viewModel.hrvData) { entry in
                            LineMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("HRV", entry.avgHRV)
                            )
                            .foregroundStyle(Color.orange)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("HRV", entry.avgHRV)
                            )
                            .foregroundStyle(Color.orange.opacity(0.2))
                            .interpolationMethod(.catmullRom)
                        }
                        .frame(height: 180)
                    }
                }

                // HRV Stats
                if !viewModel.hrvData.isEmpty {
                    statsCard(title: "HRV Statistics", stats: [
                        ("Average", String(format: "%.0f ms", viewModel.hrvData.map { $0.avgHRV }.reduce(0, +) / Double(viewModel.hrvData.count))),
                        ("Min", String(format: "%.0f ms", viewModel.hrvData.map { $0.avgHRV }.min() ?? 0)),
                        ("Max", String(format: "%.0f ms", viewModel.hrvData.map { $0.avgHRV }.max() ?? 0)),
                        ("Days", "\(viewModel.hrvData.count)")
                    ])
                }

                // HRV Data List
                dataListCard(title: "Daily HRV", icon: "list.bullet") {
                    ForEach(viewModel.hrvData.prefix(14)) { entry in
                        HStack {
                            Text(entry.dateString)
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(entry.avgHRV)) ms")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                        if entry.id != viewModel.hrvData.prefix(14).last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Activity Tab

    private var activityTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Steps Chart
                chartCard(title: "Daily Steps", icon: "figure.walk", color: .green) {
                    if viewModel.activityData.isEmpty {
                        emptyDataView(message: "No activity data available")
                    } else {
                        Chart(viewModel.activityData) { entry in
                            BarMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("Steps", entry.steps)
                            )
                            .foregroundStyle(Color.green.gradient)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let steps = value.as(Int.self) {
                                        Text("\(steps / 1000)k")
                                    }
                                }
                            }
                        }
                        .frame(height: 180)
                    }
                }

                // Exercise Minutes Chart
                chartCard(title: "Exercise Minutes", icon: "flame.fill", color: .orange) {
                    if viewModel.activityData.isEmpty {
                        emptyDataView(message: "No exercise data")
                    } else {
                        Chart(viewModel.activityData) { entry in
                            BarMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("Minutes", entry.exerciseMinutes)
                            )
                            .foregroundStyle(Color.orange.gradient)

                            // 30 min goal line
                            RuleMark(y: .value("Goal", 30))
                                .foregroundStyle(Color.green.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        }
                        .frame(height: 150)
                    }
                }

                // Activity Stats
                if !viewModel.activityData.isEmpty {
                    let avgSteps = viewModel.activityData.map { $0.steps }.reduce(0, +) / max(1, viewModel.activityData.count)
                    let totalCals = viewModel.activityData.map { $0.activeCalories }.reduce(0, +)
                    let avgExercise = viewModel.activityData.map { $0.exerciseMinutes }.reduce(0, +) / max(1, viewModel.activityData.count)

                    statsCard(title: "Activity Summary", stats: [
                        ("Avg Steps", "\(avgSteps.formatted())"),
                        ("Total Calories", "\(Int(totalCals))"),
                        ("Avg Exercise", "\(avgExercise) min"),
                        ("Days", "\(viewModel.activityData.count)")
                    ])
                }

                // Activity Data List
                dataListCard(title: "Daily Activity", icon: "list.bullet") {
                    ForEach(viewModel.activityData.prefix(14)) { entry in
                        HStack {
                            Text(entry.dateString)
                                .font(.subheadline)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(entry.steps.formatted()) steps")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                HStack(spacing: 8) {
                                    Text("\(entry.exerciseMinutes)m exercise")
                                    Text("\(Int(entry.activeCalories)) cal")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        if entry.id != viewModel.activityData.prefix(14).last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Temperature Tab

    private var temperatureTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Temperature Deviation Chart
                chartCard(title: "Wrist Temperature Deviation", icon: "thermometer.medium", color: .cyan) {
                    if viewModel.temperatureData.isEmpty {
                        emptyDataView(message: "No temperature data available\n(Requires Apple Watch Series 8+)")
                    } else {
                        Chart(viewModel.temperatureData.filter { $0.tempDeviation != nil }) { entry in
                            BarMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("Deviation", entry.tempDeviation ?? 0)
                            )
                            .foregroundStyle(
                                (entry.tempDeviation ?? 0) >= 0 ? Color.red.gradient : Color.blue.gradient
                            )
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let temp = value.as(Double.self) {
                                        Text(String(format: "%+.1f°", temp))
                                    }
                                }
                            }
                        }
                        .frame(height: 180)
                    }
                }

                // Temperature Data List
                dataListCard(title: "Temperature Readings", icon: "list.bullet") {
                    if viewModel.temperatureData.isEmpty {
                        Text("No temperature data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(viewModel.temperatureData.prefix(14)) { entry in
                            HStack {
                                Text(entry.dateString)
                                    .font(.subheadline)
                                Spacer()
                                if let deviation = entry.tempDeviation {
                                    Text(String(format: "%+.2f°C", deviation))
                                        .font(.headline)
                                        .foregroundColor(deviation >= 0 ? .red : .blue)
                                }
                            }
                            .padding(.vertical, 4)
                            if entry.id != viewModel.temperatureData.prefix(14).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Light Exposure Tab

    private var lightExposureTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Light Exposure Chart
                chartCard(title: "Time in Daylight", icon: "sun.max.fill", color: .yellow) {
                    if viewModel.lightExposureData.isEmpty {
                        emptyDataView(message: "No light exposure data available\n(Requires iOS 17+ and Apple Watch)")
                    } else {
                        Chart(viewModel.lightExposureData) { entry in
                            BarMark(
                                x: .value("Date", entry.date, unit: .day),
                                y: .value("Minutes", entry.totalMinutes)
                            )
                            .foregroundStyle(Color.yellow.gradient)

                            // 30 min recommended line
                            RuleMark(y: .value("Recommended", 30))
                                .foregroundStyle(Color.green.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        }
                        .frame(height: 180)
                    }
                }

                // Light Stats
                if !viewModel.lightExposureData.isEmpty {
                    let avgLight = viewModel.lightExposureData.map { $0.totalMinutes }.reduce(0, +) / max(1, viewModel.lightExposureData.count)
                    let totalLight = viewModel.lightExposureData.map { $0.totalMinutes }.reduce(0, +)

                    statsCard(title: "Light Exposure Summary", stats: [
                        ("Avg Daily", "\(avgLight) min"),
                        ("Total", "\(totalLight / 60) hrs"),
                        ("Max", "\(viewModel.lightExposureData.map { $0.totalMinutes }.max() ?? 0) min"),
                        ("Days", "\(viewModel.lightExposureData.count)")
                    ])
                }

                // Light Data List
                dataListCard(title: "Daily Light Exposure", icon: "list.bullet") {
                    if viewModel.lightExposureData.isEmpty {
                        Text("No light exposure data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(viewModel.lightExposureData.prefix(14)) { entry in
                            HStack {
                                Text(entry.dateString)
                                    .font(.subheadline)
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: lightIcon(for: entry.totalMinutes))
                                        .foregroundColor(lightColor(for: entry.totalMinutes))
                                    Text("\(entry.totalMinutes) min")
                                        .font(.headline)
                                        .foregroundColor(lightColor(for: entry.totalMinutes))
                                }
                            }
                            .padding(.vertical, 4)
                            if entry.id != viewModel.lightExposureData.prefix(14).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Helper Views

    private func chartCard<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }

            content()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func dataListCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.headline)
                Spacer()
            }

            content()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func statsCard(title: String, stats: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            HStack {
                ForEach(stats, id: \.0) { stat in
                    VStack {
                        Text(stat.1)
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(stat.0)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func emptyDataView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title)
                .foregroundColor(.secondary)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
    }

    private func miniStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var datePickerSheet: some View {
        NavigationView {
            Form {
                DatePicker("Start Date", selection: $startDate, in: ...endDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
            .navigationTitle("Select Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDatePicker = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func setDateRange(days: Int) {
        endDate = Date()
        startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
    }

    private func formatDuration(_ mins: Int) -> String {
        let hours = mins / 60
        let minutes = mins % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func lightIcon(for minutes: Int) -> String {
        switch minutes {
        case 0..<15: return "sun.min"
        case 15..<30: return "sun.max"
        default: return "sun.max.fill"
        }
    }

    private func lightColor(for minutes: Int) -> Color {
        switch minutes {
        case 0..<15: return .orange
        case 15..<30: return .yellow
        default: return .green
        }
    }
}

// MARK: - ViewModel

@MainActor
class HealthKitDebugViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isAuthorized = false
    @Published var isSyncing = false
    @Published var syncMessage: String?
    @Published var isMockData = false

    @Published var sleepData: [DailySleepSummary] = []
    @Published var heartRateData: [HeartRateSummary] = []
    @Published var hrvData: [HRVSummary] = []
    @Published var activityData: [ActivitySummary] = []
    @Published var temperatureData: [TemperatureSummary] = []
    @Published var lightExposureData: [LightExposureSummary] = []

    private let healthStore = HKHealthStore()
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    // MARK: - Mock Data Generation (for Simulator testing)

    func loadMockData(from startDate: Date, to endDate: Date) {
        isLoading = true
        isMockData = true
        isAuthorized = true

        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 30

        // Generate mock data for each type
        sleepData = generateMockSleepData(days: days, endDate: endDate)
        heartRateData = generateMockHeartRateData(days: days, endDate: endDate)
        hrvData = generateMockHRVData(days: days, endDate: endDate)
        activityData = generateMockActivityData(days: days, endDate: endDate)
        temperatureData = generateMockTemperatureData(days: days, endDate: endDate)
        lightExposureData = generateMockLightData(days: days, endDate: endDate)

        isLoading = false
        syncMessage = "Loaded \(days) days of mock data"
    }

    private func generateMockSleepData(days: Int, endDate: Date) -> [DailySleepSummary] {
        let calendar = Calendar.current
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else { return nil }

            let totalSleep = Int.random(in: 320...480)
            let deepPct = Double.random(in: 0.15...0.25)
            let remPct = Double.random(in: 0.18...0.25)
            let awakePct = Double.random(in: 0.03...0.10)

            let deepMins = Int(Double(totalSleep) * deepPct)
            let remMins = Int(Double(totalSleep) * remPct)
            let awakeMins = Int(Double(totalSleep) * awakePct)
            let lightMins = totalSleep - deepMins - remMins - awakeMins

            // Generate bed/wake times
            var bedComponents = calendar.dateComponents([.year, .month, .day], from: date)
            bedComponents.hour = Int.random(in: 21...23)
            bedComponents.minute = Int.random(in: 0...59)
            let bedDate = calendar.date(from: bedComponents) ?? date

            let latency = Int.random(in: 5...25)
            let wakeDate = calendar.date(byAdding: .minute, value: totalSleep + latency, to: bedDate) ?? date

            let actualSleep = totalSleep - awakeMins
            let efficiency = Double(actualSleep) / Double(totalSleep + latency) * 100

            return DailySleepSummary(
                date: date,
                dateString: dateFormatter.string(from: date),
                totalSleepMins: actualSleep,
                deepMins: deepMins,
                lightMins: lightMins,
                remMins: remMins,
                awakeMins: awakeMins,
                efficiency: min(98, efficiency),
                latencyMins: latency,
                awakenings: Int.random(in: 0...4),
                inBedTime: timeFmt.string(from: bedDate),
                wakeTime: timeFmt.string(from: wakeDate),
                source: "Mock Data"
            )
        }
    }

    private func generateMockHeartRateData(days: Int, endDate: Date) -> [HeartRateSummary] {
        let calendar = Calendar.current
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else { return nil }
            let resting = Double.random(in: 55...75)
            return HeartRateSummary(
                date: date,
                dateString: dateFormatter.string(from: date),
                restingHR: resting,
                avgHR: resting + Double.random(in: 10...25),
                minHR: resting - Double.random(in: 5...15),
                maxHR: resting + Double.random(in: 60...100)
            )
        }
    }

    private func generateMockHRVData(days: Int, endDate: Date) -> [HRVSummary] {
        let calendar = Calendar.current
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else { return nil }
            return HRVSummary(
                date: date,
                dateString: dateFormatter.string(from: date),
                avgHRV: Double.random(in: 25...65),
                minHRV: nil,
                maxHRV: nil
            )
        }
    }

    private func generateMockActivityData(days: Int, endDate: Date) -> [ActivitySummary] {
        let calendar = Calendar.current
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else { return nil }
            return ActivitySummary(
                date: date,
                dateString: dateFormatter.string(from: date),
                steps: Int.random(in: 3000...15000),
                activeCalories: Double.random(in: 200...600),
                exerciseMinutes: Int.random(in: 10...90),
                standHours: Int.random(in: 6...14)
            )
        }
    }

    private func generateMockTemperatureData(days: Int, endDate: Date) -> [TemperatureSummary] {
        let calendar = Calendar.current
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else { return nil }
            return TemperatureSummary(
                date: date,
                dateString: dateFormatter.string(from: date),
                wristTemp: nil,
                tempDeviation: Double.random(in: -0.5...0.5)
            )
        }
    }

    private func generateMockLightData(days: Int, endDate: Date) -> [LightExposureSummary] {
        let calendar = Calendar.current
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else { return nil }
            return LightExposureSummary(
                date: date,
                dateString: dateFormatter.string(from: date),
                totalMinutes: Int.random(in: 5...90)
            )
        }
    }

    func fetchAllData(from startDate: Date, to endDate: Date) async {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }

        isLoading = true

        // Request authorization for all types
        let typesToRead: Set<HKObjectType> = [
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKQuantityType.quantityType(forIdentifier: .appleStandTime)!,
        ]

        // Add temperature if available (iOS 16+)
        if let tempType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
            var mutableTypes = typesToRead
            mutableTypes.insert(tempType)
        }

        // Add light exposure if available (iOS 17+)
        if let lightType = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) {
            var mutableTypes = typesToRead
            mutableTypes.insert(lightType)
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            isAuthorized = true
        } catch {
            print("[HealthKitDebug] Auth error: \(error)")
            isAuthorized = false
            isLoading = false
            return
        }

        // Fetch all data types in parallel
        async let sleepTask = fetchSleepData(from: startDate, to: endDate)
        async let hrTask = fetchHeartRateData(from: startDate, to: endDate)
        async let hrvTask = fetchHRVData(from: startDate, to: endDate)
        async let activityTask = fetchActivityData(from: startDate, to: endDate)
        async let tempTask = fetchTemperatureData(from: startDate, to: endDate)
        async let lightTask = fetchLightExposureData(from: startDate, to: endDate)

        let (sleep, hr, hrv, activity, temp, light) = await (sleepTask, hrTask, hrvTask, activityTask, tempTask, lightTask)

        sleepData = sleep
        heartRateData = hr
        hrvData = hrv
        activityData = activity
        temperatureData = temp
        lightExposureData = light

        isLoading = false
    }

    // MARK: - Sleep Data

    private func fetchSleepData(from startDate: Date, to endDate: Date) async -> [DailySleepSummary] {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { [weak self] _, samples, error in
                guard let self = self, let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let result = self.processSleepSamples(samples)
                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }

    private func processSleepSamples(_ samples: [HKCategorySample]) -> [DailySleepSummary] {
        let calendar = Calendar.current
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"

        // Step 1: Deduplicate overlapping samples from multiple sources
        // Priority: Apple Watch > iPhone native > Third-party
        let deduplicatedSamples = deduplicateOverlappingSamples(samples)

        // Step 2: Group by sleep session (night) - use the END date to group overnight sleep correctly
        // A sleep session starting at 11pm Dec 30 and ending 7am Dec 31 should be attributed to Dec 31
        var dateGroups: [String: [HKCategorySample]] = [:]
        for sample in deduplicatedSamples {
            // Use the date when sleep ended (wake date) as the session date
            // This ensures overnight sleep is counted on the day you wake up
            let dateKey = dateFmt.string(from: sample.endDate)
            dateGroups[dateKey, default: []].append(sample)
        }

        var summaries: [DailySleepSummary] = []

        for (dateStr, daySamples) in dateGroups.sorted(by: { $0.key > $1.key }) {
            guard let date = dateFmt.date(from: dateStr) else { continue }

            var deepMins = 0, lightMins = 0, remMins = 0, awakeMins = 0, awakenings = 0
            var inBedStart: Date?, asleepStart: Date?, wakeTime: Date?
            var sources: Set<String> = []

            for sample in daySamples {
                let duration = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
                sources.insert(sample.sourceRevision.source.name)

                switch sample.value {
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    if inBedStart == nil || sample.startDate < inBedStart! { inBedStart = sample.startDate }
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    lightMins += duration
                    if asleepStart == nil || sample.startDate < asleepStart! { asleepStart = sample.startDate }
                    if wakeTime == nil || sample.endDate > wakeTime! { wakeTime = sample.endDate }
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deepMins += duration
                    if asleepStart == nil || sample.startDate < asleepStart! { asleepStart = sample.startDate }
                    if wakeTime == nil || sample.endDate > wakeTime! { wakeTime = sample.endDate }
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    remMins += duration
                    if asleepStart == nil || sample.startDate < asleepStart! { asleepStart = sample.startDate }
                    if wakeTime == nil || sample.endDate > wakeTime! { wakeTime = sample.endDate }
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    awakeMins += duration
                    awakenings += 1
                default: break
                }
            }

            let totalSleep = deepMins + lightMins + remMins
            guard totalSleep > 0 else { continue }

            let latency = (inBedStart != nil && asleepStart != nil) ? Int(asleepStart!.timeIntervalSince(inBedStart!) / 60) : 0
            let totalTime = totalSleep + awakeMins
            let efficiency = totalTime > 0 ? (Double(totalSleep) / Double(totalTime)) * 100 : 0

            summaries.append(DailySleepSummary(
                date: date,
                dateString: dateFormatter.string(from: date),
                totalSleepMins: totalSleep,
                deepMins: deepMins,
                lightMins: lightMins,
                remMins: remMins,
                awakeMins: awakeMins,
                efficiency: min(100, efficiency),
                latencyMins: max(0, latency),
                awakenings: awakenings,
                inBedTime: inBedStart.map { timeFmt.string(from: $0) },
                wakeTime: wakeTime.map { timeFmt.string(from: $0) },
                source: sources.joined(separator: ", ")
            ))
        }

        return summaries
    }

    /// Deduplicates overlapping sleep samples from multiple sources
    /// Prioritizes: Apple Watch > iPhone native > Third-party apps
    private func deduplicateOverlappingSamples(_ samples: [HKCategorySample]) -> [HKCategorySample] {
        // Skip "inBed" samples for sleep calculations - only count actual sleep stages
        let sleepSamples = samples.filter { sample in
            let value = sample.value
            return value != HKCategoryValueSleepAnalysis.inBed.rawValue
        }

        // Sort by start time
        let sorted = sleepSamples.sorted { $0.startDate < $1.startDate }

        // Get source priority (lower = better)
        func sourcePriority(_ sample: HKCategorySample) -> Int {
            let name = sample.sourceRevision.source.name.lowercased()
            let bundleId = sample.sourceRevision.source.bundleIdentifier

            if name.contains("watch") || name.contains("apple watch") {
                return 1 // Apple Watch = highest priority
            } else if bundleId.hasPrefix("com.apple") {
                return 2 // iPhone native apps
            } else {
                return 3 // Third-party (Oura, Fitbit, WHOOP, etc.)
            }
        }

        var result: [HKCategorySample] = []

        for sample in sorted {
            // Check if this sample overlaps with any already-kept sample
            var hasOverlap = false
            var overlapIndex: Int? = nil

            for (index, existing) in result.enumerated() {
                // Check for time overlap
                let overlaps = sample.startDate < existing.endDate && sample.endDate > existing.startDate

                if overlaps {
                    hasOverlap = true
                    // Keep the one with higher priority (lower number)
                    if sourcePriority(sample) < sourcePriority(existing) {
                        overlapIndex = index
                    }
                    break
                }
            }

            if let replaceIndex = overlapIndex {
                // Replace with higher priority sample
                result.remove(at: replaceIndex)
                result.append(sample)
            } else if !hasOverlap {
                // No overlap, add the sample
                result.append(sample)
            }
            // If hasOverlap but no replaceIndex, the existing sample has higher priority - skip this one
        }

        return result
    }

    // MARK: - Heart Rate Data

    private func fetchHeartRateData(from startDate: Date, to endDate: Date) async -> [HeartRateSummary] {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!

        // Fetch resting HR
        let restingHR = await fetchDailyStatistics(type: restingHRType, from: startDate, to: endDate, options: .discreteAverage)

        // Fetch HR min/max/avg
        let hrStats = await fetchDailyHRStats(from: startDate, to: endDate)

        // Merge data
        var summaries: [HeartRateSummary] = []
        let calendar = Calendar.current

        var date = startDate
        while date <= endDate {
            let dateStr = dateFormatter.string(from: date)
            let resting = restingHR[dateStr]
            let stats = hrStats[dateStr]

            if resting != nil || stats != nil {
                summaries.append(HeartRateSummary(
                    date: date,
                    dateString: dateStr,
                    restingHR: resting,
                    avgHR: stats?.avg,
                    minHR: stats?.min,
                    maxHR: stats?.max
                ))
            }

            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        return summaries.sorted { $0.date > $1.date }
    }

    private func fetchDailyHRStats(from startDate: Date, to endDate: Date) async -> [String: (min: Double, max: Double, avg: Double)] {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: hrType,
                quantitySamplePredicate: predicate,
                options: [.discreteMin, .discreteMax, .discreteAverage],
                anchorDate: startDate,
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { [weak self] _, results, error in
                guard let self = self, let results = results else {
                    continuation.resume(returning: [:])
                    return
                }

                var stats: [String: (min: Double, max: Double, avg: Double)] = [:]
                results.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                    let dateStr = self.dateFormatter.string(from: stat.startDate)
                    let unit = HKUnit.count().unitDivided(by: .minute())

                    if let min = stat.minimumQuantity()?.doubleValue(for: unit),
                       let max = stat.maximumQuantity()?.doubleValue(for: unit),
                       let avg = stat.averageQuantity()?.doubleValue(for: unit) {
                        stats[dateStr] = (min: min, max: max, avg: avg)
                    }
                }

                continuation.resume(returning: stats)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - HRV Data

    private func fetchHRVData(from startDate: Date, to endDate: Date) async -> [HRVSummary] {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let values = await fetchDailyStatistics(type: hrvType, from: startDate, to: endDate, options: .discreteAverage, unit: .secondUnit(with: .milli))

        return values.map { dateStr, value in
            HRVSummary(
                date: dateFormatter.date(from: dateStr) ?? Date(),
                dateString: dateStr,
                avgHRV: value,
                minHRV: nil,
                maxHRV: nil
            )
        }.sorted { $0.date > $1.date }
    }

    // MARK: - Activity Data

    private func fetchActivityData(from startDate: Date, to endDate: Date) async -> [ActivitySummary] {
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!

        async let stepsTask = fetchDailyStatistics(type: stepsType, from: startDate, to: endDate, options: .cumulativeSum, unit: .count())
        async let caloriesTask = fetchDailyStatistics(type: caloriesType, from: startDate, to: endDate, options: .cumulativeSum, unit: .kilocalorie())
        async let exerciseTask = fetchDailyStatistics(type: exerciseType, from: startDate, to: endDate, options: .cumulativeSum, unit: .minute())

        let (steps, calories, exercise) = await (stepsTask, caloriesTask, exerciseTask)

        var summaries: [ActivitySummary] = []
        let allDates = Set(steps.keys).union(calories.keys).union(exercise.keys)

        for dateStr in allDates {
            guard let date = dateFormatter.date(from: dateStr) else { continue }
            summaries.append(ActivitySummary(
                date: date,
                dateString: dateStr,
                steps: Int(steps[dateStr] ?? 0),
                activeCalories: calories[dateStr] ?? 0,
                exerciseMinutes: Int(exercise[dateStr] ?? 0),
                standHours: 0
            ))
        }

        return summaries.sorted { $0.date > $1.date }
    }

    // MARK: - Temperature Data

    private func fetchTemperatureData(from startDate: Date, to endDate: Date) async -> [TemperatureSummary] {
        guard let tempType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else {
            return []
        }

        let values = await fetchDailyStatistics(type: tempType, from: startDate, to: endDate, options: .discreteAverage, unit: .degreeCelsius())

        return values.map { dateStr, value in
            TemperatureSummary(
                date: dateFormatter.date(from: dateStr) ?? Date(),
                dateString: dateStr,
                wristTemp: nil,
                tempDeviation: value
            )
        }.sorted { $0.date > $1.date }
    }

    // MARK: - Light Exposure Data

    private func fetchLightExposureData(from startDate: Date, to endDate: Date) async -> [LightExposureSummary] {
        guard let lightType = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) else {
            return []
        }

        let values = await fetchDailyStatistics(type: lightType, from: startDate, to: endDate, options: .cumulativeSum, unit: .minute())

        return values.map { dateStr, value in
            LightExposureSummary(
                date: dateFormatter.date(from: dateStr) ?? Date(),
                dateString: dateStr,
                totalMinutes: Int(value)
            )
        }.sorted { $0.date > $1.date }
    }

    // MARK: - Generic Statistics Fetcher

    private func fetchDailyStatistics(
        type: HKQuantityType,
        from startDate: Date,
        to endDate: Date,
        options: HKStatisticsOptions,
        unit: HKUnit? = nil
    ) async -> [String: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: startDate,
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { [weak self] _, results, error in
                guard let self = self, let results = results else {
                    continuation.resume(returning: [:])
                    return
                }

                var values: [String: Double] = [:]
                results.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                    let dateStr = self.dateFormatter.string(from: stat.startDate)

                    let quantity: HKQuantity?
                    if options.contains(.cumulativeSum) {
                        quantity = stat.sumQuantity()
                    } else {
                        quantity = stat.averageQuantity()
                    }

                    if let quantity = quantity {
                        let actualUnit = unit ?? self.defaultUnit(for: type)
                        values[dateStr] = quantity.doubleValue(for: actualUnit)
                    }
                }

                continuation.resume(returning: values)
            }

            healthStore.execute(query)
        }
    }

    private func defaultUnit(for type: HKQuantityType) -> HKUnit {
        switch type.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue,
             HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())
        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
            return .secondUnit(with: .milli)
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return .count()
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            return .kilocalorie()
        case HKQuantityTypeIdentifier.appleExerciseTime.rawValue:
            return .minute()
        default:
            return .count()
        }
    }

    // MARK: - Sync to Convex

    func syncToConvex() async {
        isSyncing = true
        syncMessage = nil

        let healthKitManager = HealthKitManager()
        healthKitManager.syncAllHealthData { [weak self] result in
            DispatchQueue.main.async {
                self?.isSyncing = false
                switch result {
                case .success(let response):
                    let total = response["totalRecordsSynced"] as? Int ?? 0
                    self?.syncMessage = "Synced \(total) records"
                case .failure(let error):
                    self?.syncMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct HealthKitDetailedDebugView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HealthKitDetailedDebugView()
                .environmentObject(ThemeManager.shared)
        }
    }
}
#endif
