//
//  UnifiedDebugPanel.swift
//  ZoeSleep
//
//  Single, unified debug panel consolidating all developer tools
//  Replaces: DevPanelView, MockPlaybackView, ExpansionSchedulerTestView
//
//  Architecture:
//  - Section 1: Status Overview (current state)
//  - Section 2: Data Generation (all mock data options)
//  - Section 3: Schedule Preview (gateway-based)
//  - Section 4: Journey Controls (advance, reset)
//  - Section 5: Repair Tools (fix data issues)
//
//  NOTE: Available in all builds (including TestFlight) when Debug Mode is enabled
//

import SwiftUI

// MARK: - Expansion Module (for schedule preview)

struct ExpansionModule: Identifiable {
    let id: String
    let name: String
    let instrument: String
    let questionCount: Int
    let estimatedMinutes: Int
    let priority: Int
    let requiredGateway: GatewayType

    static let allModules: [ExpansionModule] = [
        ExpansionModule(id: "expansion_isi", name: "Insomnia Severity", instrument: "ISI", questionCount: 7, estimatedMinutes: 3, priority: 1, requiredGateway: .insomnia),
        ExpansionModule(id: "expansion_phq9", name: "Depression Screen", instrument: "PHQ-9", questionCount: 9, estimatedMinutes: 4, priority: 1, requiredGateway: .depression),
        ExpansionModule(id: "expansion_gad7", name: "Anxiety Screen", instrument: "GAD-7", questionCount: 7, estimatedMinutes: 3, priority: 1, requiredGateway: .anxiety),
        ExpansionModule(id: "expansion_stop_bang", name: "OSA Screen", instrument: "STOP-BANG", questionCount: 8, estimatedMinutes: 3, priority: 1, requiredGateway: .osa),
        ExpansionModule(id: "expansion_ess", name: "Sleepiness Scale", instrument: "ESS", questionCount: 8, estimatedMinutes: 3, priority: 2, requiredGateway: .excessiveSleepiness),
        ExpansionModule(id: "expansion_berlin", name: "Berlin OSA", instrument: "Berlin", questionCount: 10, estimatedMinutes: 4, priority: 2, requiredGateway: .osa),
        ExpansionModule(id: "expansion_dbas", name: "Sleep Beliefs", instrument: "DBAS-16", questionCount: 16, estimatedMinutes: 6, priority: 3, requiredGateway: .insomnia),
        ExpansionModule(id: "expansion_sleep_hygiene", name: "Sleep Hygiene", instrument: "SHI", questionCount: 10, estimatedMinutes: 4, priority: 3, requiredGateway: .insomnia),
        ExpansionModule(id: "expansion_psas", name: "Pre-Sleep Arousal", instrument: "PSAS", questionCount: 16, estimatedMinutes: 6, priority: 3, requiredGateway: .insomnia),
        ExpansionModule(id: "expansion_fss", name: "Fatigue Scale", instrument: "FSS", questionCount: 9, estimatedMinutes: 4, priority: 3, requiredGateway: .excessiveSleepiness),
        ExpansionModule(id: "expansion_fosq", name: "Functional Outcomes", instrument: "FOSQ-10", questionCount: 10, estimatedMinutes: 4, priority: 3, requiredGateway: .excessiveSleepiness),
        ExpansionModule(id: "expansion_dass21", name: "DASS-21", instrument: "DASS-21", questionCount: 21, estimatedMinutes: 8, priority: 4, requiredGateway: .anxiety),
        ExpansionModule(id: "expansion_promis_cognitive", name: "Cognitive Function", instrument: "PROMIS-Cog", questionCount: 6, estimatedMinutes: 2, priority: 4, requiredGateway: .cognitive),
        ExpansionModule(id: "expansion_bpi", name: "Pain Inventory", instrument: "BPI", questionCount: 11, estimatedMinutes: 4, priority: 4, requiredGateway: .pain),
        ExpansionModule(id: "expansion_medas", name: "Diet Assessment", instrument: "MEDAS", questionCount: 14, estimatedMinutes: 5, priority: 5, requiredGateway: .dietImpact),
        ExpansionModule(id: "expansion_meq", name: "Chronotype", instrument: "MEQ", questionCount: 19, estimatedMinutes: 7, priority: 5, requiredGateway: .sleepTiming),
    ]
}

// MARK: - Schedule Preview Model

struct SchedulePreview {
    let totalQuestions: Int
    let totalDays: Int
    let totalMinutes: Int
    let days: [DayPreview]

    struct DayPreview {
        let dayNumber: Int
        let modules: [String]
        let questionCount: Int
        let estimatedMinutes: Int
    }
}

// MARK: - Generation Mode

enum DataGenerationMode: String, CaseIterable, Identifiable {
    case fullRandom = "Full Journey (Random)"
    case maxLoad = "Max Load (All Gateways)"
    case selective = "Selective (Choose Gateways)"
    case quickTest = "Quick Test (Days 1-5)"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .fullRandom: return "10 days with ~40% gateway triggers"
        case .maxLoad: return "10 days with ALL 10 gateways triggered"
        case .selective: return "Choose which gateways to trigger"
        case .quickTest: return "Days 1-5 only, ~30 seconds"
        }
    }

    var icon: String {
        switch self {
        case .fullRandom: return "dice"
        case .maxLoad: return "flame"
        case .selective: return "checklist"
        case .quickTest: return "hare"
        }
    }

    var estimatedTime: String {
        switch self {
        case .fullRandom: return "~2 min"
        case .maxLoad: return "~3 min"
        case .selective: return "~2-3 min"
        case .quickTest: return "~30 sec"
        }
    }

    var days: ClosedRange<Int> {
        switch self {
        case .quickTest: return 1...5
        default: return 1...10
        }
    }
}

// MARK: - Unified Debug Panel

struct UnifiedDebugPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var questionnaireManager: QuestionnaireManager
    @Environment(\.dismiss) var dismiss

    // Time Travel Manager
    @StateObject private var timeTravelManager = TimeTravelManager.shared

    // Day Advancement Logger
    @ObservedObject private var advancementLogger = DayAdvancementLogger.shared

    // State
    @State private var selectedMode: DataGenerationMode = .fullRandom
    @State private var selectedGateways: Set<GatewayType> = []
    @State private var isGenerating = false
    @State private var showConfirmation = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    // Generation progress - created dynamically with the right config
    @State private var generator: MockPlaybackController?

    // Progress tracking (updated via timer since @State doesn't observe ObservableObject)
    @State private var progressCurrentDay: Int = 1
    @State private var progressTotalDays: Int = 10
    @State private var progressSection: String = "Sleep Log"
    @State private var progressQuestionIndex: Int = 0
    @State private var progressTotalQuestions: Int = 0
    @State private var progressAnswered: Int = 0
    @State private var progressElapsed: TimeInterval = 0
    @State private var progressDayProgress: Double = 0

    // Schedule preview
    @State private var schedulePreview: SchedulePreview?
    @State private var isLoadingPreview = false

    // Journey controls
    @State private var isAdvancingDay = false
    @State private var isResetting = false
    @State private var isRepairing = false

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        NavigationView {
            List {
                // MARK: - Section 1: Status Overview
                statusSection

                // MARK: - Section 2: Data Generation
                dataGenerationSection

                // MARK: - Section 3: Gateway Selection (if selective mode)
                if selectedMode == .selective {
                    gatewaySelectionSection
                }

                // MARK: - Section 4: Schedule Preview
                if selectedMode == .selective || selectedMode == .maxLoad {
                    schedulePreviewSection
                }

                // MARK: - Section 5: Generation Progress (if running)
                if isGenerating {
                    generationProgressSection
                }

                // MARK: - Section 6: Time Travel Mode
                timeTravelModeSection

                // MARK: - Section 7: Journey Controls
                journeyControlsSection

                // MARK: - Section 7.5: Day Advancement Log
                dayAdvancementLogSection

                // MARK: - Section 8: Experimental Features
                experimentalFeaturesSection

                // MARK: - Section 9: Watch Connectivity
                watchConnectivitySection

                // MARK: - Section 10: Repair Tools
                repairToolsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Debug Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Generate Mock Data?", isPresented: $showConfirmation) {
                Button("Generate \(selectedMode.days.count) Days", role: .destructive) {
                    startGeneration()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset your journey progress and generate mock data. All existing responses will be cleared.")
            }
            .task {
                await refreshPreview()
                await timeTravelManager.syncWithServer()
            }
            .onChange(of: selectedMode) { _, _ in
                Task { await refreshPreview() }
            }
            .onChange(of: selectedGateways) { _, _ in
                Task { await refreshPreview() }
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            // Current Day
            HStack {
                Label("Current Day", systemImage: "calendar")
                Spacer()
                Text("Day \(questionnaireManager.currentDay)")
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }

            // Section Status
            HStack {
                Label("Sleep Log", systemImage: "moon.zzz")
                Spacer()
                StatusBadge(
                    isComplete: questionnaireManager.journeyProgress?.sleepLogCompleted == true,
                    completeText: "Done",
                    pendingText: "Pending"
                )
            }

            HStack {
                Label("Assessment", systemImage: "clipboard")
                Spacer()
                let currentDay = questionnaireManager.currentDay
                let triggeredCount = questionnaireManager.gatewayStates.filter { $0.triggered }.count
                let isExpansionDay = currentDay > 5
                let hasNoAssessment = isExpansionDay && triggeredCount == 0

                StatusBadge(
                    isComplete: questionnaireManager.journeyProgress?.assessmentCompleted == true,
                    completeText: "Done",
                    pendingText: "Pending",
                    isNotApplicable: hasNoAssessment,
                    notApplicableText: "None (0 gateways)"
                )
            }

            // Completed Days
            HStack {
                Label("Completed Days", systemImage: "checkmark.circle")
                Spacer()
                Text("\(questionnaireManager.journeyProgress?.completedDays.count ?? 0) of 10")
                    .foregroundColor(.secondary)
            }

            // Triggered Gateways with questionnaire mapping
            let triggeredGateways = questionnaireManager.gatewayStates.filter { $0.triggered }
            let triggeredCount = triggeredGateways.count
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Gateways Triggered", systemImage: "exclamationmark.triangle")
                    Spacer()
                    Text("\(triggeredCount) of 10")
                        .foregroundColor(triggeredCount > 0 ? .orange : .secondary)
                }

                // Show triggered gateways with their questionnaires
                if triggeredCount > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(triggeredGateways, id: \.gatewayType) { gateway in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: gateway.gatewayType.icon)
                                        .font(.caption)
                                        .foregroundColor(gateway.gatewayType.color)
                                    Text(gateway.gatewayType.shortName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                Text("→ \(gateway.gatewayType.questionnaireAbbreviations)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        } header: {
            Label("Current Status", systemImage: "info.circle")
        }
    }

    // MARK: - Data Generation Section

    private var dataGenerationSection: some View {
        Section {
            // Mode Picker
            ForEach(DataGenerationMode.allCases) { mode in
                HStack {
                    Image(systemName: mode.icon)
                        .foregroundColor(mode == selectedMode ? .white : .purple)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(mode.description)
                            .font(.caption2)
                            .foregroundColor(mode == selectedMode ? .white.opacity(0.8) : .secondary)
                    }

                    Spacer()

                    Text(mode.estimatedTime)
                        .font(.caption)
                        .foregroundColor(mode == selectedMode ? .white.opacity(0.8) : .secondary)

                    if mode == selectedMode {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                .foregroundColor(mode == selectedMode ? .white : .primary)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedMode = mode
                }
                .listRowBackground(
                    mode == selectedMode ?
                    Color.purple.opacity(0.9) :
                    Color(UIColor.secondarySystemGroupedBackground)
                )
            }

            // Generate Button - using onTapGesture for reliable touch handling
            HStack {
                Spacer()
                HStack {
                    Image(systemName: "play.fill")
                    Text("Generate Mock Data")
                        .fontWeight(.semibold)
                }
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isGenerating {
                    showConfirmation = true
                }
            }
            .listRowBackground(isGenerating ? Color.gray : Color.green)
            .listRowInsets(EdgeInsets())

        } header: {
            Label("Data Generation", systemImage: "wand.and.stars")
        } footer: {
            Text("Select a mode and tap Generate. \(selectedMode.rawValue) will create \(selectedMode.days.count) days of questionnaire responses.")
        }
    }

    // MARK: - Gateway Selection Section

    private var gatewaySelectionSection: some View {
        Section {
            // Quick actions
            HStack {
                Button("Select All") {
                    selectedGateways = Set(GatewayType.allCases)
                }
                .buttonStyle(.bordered)
                .tint(.purple)

                Button("Clear All") {
                    selectedGateways = []
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Spacer()

                Text("\(selectedGateways.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Gateway toggles
            ForEach(GatewayType.allCases, id: \.self) { gateway in
                Toggle(isOn: Binding(
                    get: { selectedGateways.contains(gateway) },
                    set: { isSelected in
                        if isSelected {
                            selectedGateways.insert(gateway)
                        } else {
                            selectedGateways.remove(gateway)
                        }
                    }
                )) {
                    HStack {
                        Image(systemName: gateway.icon)
                            .foregroundColor(gateway.color)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(gateway.displayName)
                                .font(.subheadline)
                            Text(gateway.triggerDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(gateway.color)
            }
        } header: {
            Label("Select Gateways to Trigger", systemImage: "checklist")
        }
    }

    // MARK: - Schedule Preview Section

    private var schedulePreviewSection: some View {
        Section {
            if isLoadingPreview {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Computing schedule...")
                        .foregroundColor(.secondary)
                }
            } else if let preview = schedulePreview {
                // Summary stats
                HStack {
                    VStack {
                        Text("\(preview.totalQuestions)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Questions")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("\(preview.totalDays)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Days")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("~\(preview.totalMinutes)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Minutes")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)

                Divider()

                // Day breakdown
                ForEach(preview.days, id: \.dayNumber) { day in
                    HStack {
                        Text("Day \(day.dayNumber)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(width: 50, alignment: .leading)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(day.modules, id: \.self) { moduleId in
                                    Text(moduleId.replacingOccurrences(of: "expansion_", with: ""))
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }

                        Spacer()

                        Text("\(day.questionCount)Q")
                            .font(.caption)
                            .foregroundColor(day.questionCount > 18 ? .red : .secondary)
                    }
                }
            } else {
                Text("Select gateways to preview expansion schedule")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Label("Expansion Schedule (Days 6-10)", systemImage: "calendar.badge.clock")
        }
    }

    // MARK: - Generation Progress Section

    private var generationProgressSection: some View {
        Section {
            // Day progress
            HStack {
                Text("Day \(progressCurrentDay)")
                    .font(.headline)
                Spacer()
                Text("\(progressCurrentDay) of \(progressTotalDays)")
                    .foregroundColor(.secondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: geometry.size.width * progressDayProgress, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.3), value: progressDayProgress)
                }
            }
            .frame(height: 8)

            // Current section
            HStack {
                Image(systemName: progressSection == "Sleep Log" ? "moon.zzz.fill" : "clipboard.fill")
                    .foregroundColor(.purple)
                Text(progressSection)
                Spacer()
                Text("Q\(progressQuestionIndex)/\(progressTotalQuestions)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Stats
            HStack {
                Label("\(progressAnswered)", systemImage: "checkmark.circle")
                    .font(.caption)
                Spacer()
                Label(formatTime(progressElapsed), systemImage: "clock")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            // Cancel button
            Button {
                generator?.cancel()
                isGenerating = false
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Cancel")
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
            }
        } header: {
            Label("Generation Progress", systemImage: "arrow.triangle.2.circlepath")
        }
    }

    // MARK: - Time Travel Mode Section

    @State private var timeTravelSelectedDate: Date = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()

    private var timeTravelModeSection: some View {
        Section {
            // === INACTIVE STATE: Calendar Picker ===
            if !timeTravelManager.isTimeTravelActive {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select a past date to simulate as \"today\"")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Graphical calendar picker
                    DatePicker("Simulated Date",
                               selection: $timeTravelSelectedDate,
                               in: timeTravelManager.minSelectableDate...timeTravelManager.maxSelectableDate,
                               displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(.cyan)

                    // Show how many days ago
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.cyan)
                        Text("\(daysAgoForSelectedDate) days ago")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.cyan)
                        Spacer()
                    }
                }
                .padding(.vertical, 4)

                // Start Time Travel Button
                Button {
                    Task {
                        do {
                            try await timeTravelManager.setup(simulatedDate: timeTravelSelectedDate)
                            statusMessage = "Time Travel started - simulating \(timeTravelManager.formattedSimulatedDate)"
                            statusIsError = false
                            await questionnaireManager.loadJourneyProgress()
                        } catch {
                            statusMessage = "Error: \(error.localizedDescription)"
                            statusIsError = true
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.2.circlepath")
                        Text("Start Time Travel")
                            .fontWeight(.semibold)
                        Spacer()
                        if timeTravelManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .foregroundColor(.white)
                }
                .listRowBackground(Color.cyan)
                .disabled(timeTravelManager.isLoading)
            }

            // === ACTIVE STATE: Status & Controls ===
            if timeTravelManager.isTimeTravelActive {
                // Status Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ZStack {
                            Image(systemName: "clock.arrow.2.circlepath")
                                .font(.title2)
                                .foregroundColor(.cyan)
                            Circle()
                                .fill(.cyan)
                                .frame(width: 8, height: 8)
                                .offset(x: 12, y: -10)
                        }

                        Text("Time Travel Active")
                            .font(.headline)
                            .foregroundColor(.cyan)

                        Spacer()

                        Text("Day \(timeTravelManager.currentDay)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                    }

                    // Prominent simulated date display
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Simulating:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(timeTravelManager.formattedSimulatedDate)
                                .font(.headline)
                        }
                        Spacer()
                        Text("\(timeTravelManager.daysAgo) days ago")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }

                    // Day completion status
                    HStack {
                        Image(systemName: timeTravelManager.dayCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(timeTravelManager.dayCompleted ? .green : .secondary)
                        Text(timeTravelManager.dayCompleted ? "Day \(timeTravelManager.currentDay) Completed" : "Day \(timeTravelManager.currentDay) In Progress")
                            .font(.caption)
                            .foregroundColor(timeTravelManager.dayCompleted ? .green : .secondary)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.cyan.opacity(0.1))

                // === ADVANCE BUTTON (Always Visible) ===
                Button {
                    Task {
                        do {
                            try await timeTravelManager.advanceToNextDay()
                            questionnaireManager.currentDay = timeTravelManager.currentDay
                            statusMessage = "Advanced to Day \(timeTravelManager.currentDay) - \(timeTravelManager.formattedSimulatedDate)"
                            statusIsError = false
                            await questionnaireManager.loadJourneyProgress()
                        } catch {
                            statusMessage = "Error: \(error.localizedDescription)"
                            statusIsError = true
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(timeTravelManager.canAdvanceToNextDay ? .orange : .secondary)
                        Text("Advance to Next Day")
                            .foregroundColor(timeTravelManager.canAdvanceToNextDay ? .primary : .secondary)
                        Spacer()
                        if let reason = timeTravelManager.advanceDisabledReason {
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if timeTravelManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(!timeTravelManager.canAdvanceToNextDay || timeTravelManager.isLoading)
                .listRowBackground(timeTravelManager.canAdvanceToNextDay ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.05))

                // === FILL WITH MOCK DATA (Optional Helper) ===
                Button {
                    Task {
                        do {
                            try await timeTravelManager.completeDay()
                            statusMessage = "Day \(timeTravelManager.currentDay) filled with mock data"
                            statusIsError = false
                            await questionnaireManager.loadJourneyProgress()
                        } catch {
                            statusMessage = "Error: \(error.localizedDescription)"
                            statusIsError = true
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(timeTravelManager.dayCompleted ? .secondary : .purple)
                        Text("Fill Day with Mock Data")
                            .foregroundColor(timeTravelManager.dayCompleted ? .secondary : .primary)
                        Spacer()
                        if timeTravelManager.dayCompleted {
                            Text("Already completed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if timeTravelManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(timeTravelManager.dayCompleted || timeTravelManager.isLoading)

                // === RESET BUTTON ===
                Button(role: .destructive) {
                    Task {
                        do {
                            try await timeTravelManager.resetJourney()
                            questionnaireManager.currentDay = 1
                            clearSplashScreenTracking()
                            JourneyPhaseManager.shared.currentPhase = .intake
                            statusMessage = "Time Travel reset - all data cleared"
                            statusIsError = false
                            await questionnaireManager.loadJourneyProgress()
                        } catch {
                            statusMessage = "Error: \(error.localizedDescription)"
                            statusIsError = true
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Time Travel")
                        Spacer()
                        if timeTravelManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Clear all data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(timeTravelManager.isLoading)
            }

            // Test Data Indicator
            if timeTravelManager.isTestData {
                HStack {
                    Image(systemName: "testtube.2")
                        .foregroundColor(.orange)
                    Text("Account marked as test data")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button("Clear Flag") {
                        Task {
                            do {
                                try await timeTravelManager.clearTestDataFlag()
                                statusMessage = "Test data flag cleared"
                                statusIsError = false
                            } catch {
                                statusMessage = "Error: \(error.localizedDescription)"
                                statusIsError = true
                            }
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
        } header: {
            HStack {
                Label("Time Travel Mode", systemImage: "clock.arrow.2.circlepath")
                if timeTravelManager.isTimeTravelActive {
                    Spacer()
                    Text("ACTIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.cyan))
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if timeTravelManager.isTimeTravelActive {
                    Text("Advance moves the simulated date forward by 1 day. All responses are timestamped with the simulated date.")
                } else {
                    Text("Pick a past date as your simulated \"today\". Complete the journey day by day, advancing through time.")
                }
            }
        }
    }

    /// Helper to calculate days ago for the selected date
    private var daysAgoForSelectedDate: Int {
        let components = Calendar.current.dateComponents([.day], from: timeTravelSelectedDate, to: Date())
        return max(0, components.day ?? 0)
    }

    // NOTE: Test Day Unlock Section removed - 4 AM unlock logic no longer used
    // Day advancement is now completion-gated only (no time restrictions)

    // MARK: - Journey Controls Section

    private var journeyControlsSection: some View {
        Section {
            // Time bypass toggle removed - calendar-gated system replaces time-based unlock
            // Users can catch up on missed days but cannot complete future days

            // Reset Progress
            Button {
                resetProgress()
            } label: {
                HStack {
                    Label("Reset to Day 1", systemImage: "arrow.counterclockwise")
                        .foregroundColor(.red)
                    Spacer()
                    if isResetting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isResetting)

            // Refresh from Server
            Button {
                refreshFromServer()
            } label: {
                Label("Refresh from Server", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
            }
        } header: {
            Label("Journey Controls", systemImage: "slider.horizontal.3")
        } footer: {
            Text("Day advancement is now completion-gated only. Complete Sleep Log + Assessment to advance.")
        }
    }

    // MARK: - Day Advancement Log Section

    private var dayAdvancementLogSection: some View {
        Section {
            // Statistics summary
            HStack(spacing: 16) {
                StatBox(
                    title: "Total",
                    value: "\(advancementLogger.totalAttempts)",
                    color: .blue
                )
                StatBox(
                    title: "Success",
                    value: "\(advancementLogger.successfulAdvances)",
                    color: .green
                )
                StatBox(
                    title: "Failed",
                    value: "\(advancementLogger.failedAdvances)",
                    color: .red
                )
                StatBox(
                    title: "Retries",
                    value: "\(advancementLogger.retryAttempts)",
                    color: .orange
                )
            }
            .padding(.vertical, 4)

            // Success rate
            if advancementLogger.totalAttempts > 0 {
                HStack {
                    Text("Success Rate")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f%%", advancementLogger.successRate))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(advancementLogger.successRate > 80 ? .green : advancementLogger.successRate > 50 ? .orange : .red)
                }
            }

            // Last error (if recent)
            if advancementLogger.hasRecentError, let error = advancementLogger.lastError {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Error")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            // Recent events
            if !advancementLogger.events.isEmpty {
                DisclosureGroup("Recent Events (\(advancementLogger.events.count))") {
                    ForEach(advancementLogger.events.prefix(10)) { event in
                        DayAdvancementEventRow(event: event)
                    }
                }
            }

            // Clear log button
            Button(role: .destructive) {
                advancementLogger.clearEvents()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear Log")
                }
                .foregroundColor(.red)
            }
            .disabled(advancementLogger.events.isEmpty)
        } header: {
            Label("Day Advancement Log", systemImage: "list.bullet.clipboard")
        } footer: {
            Text("Tracks all day advancement attempts to help debug issues. Events are persisted across app launches.")
        }
    }

    // MARK: - Experimental Features Section

    private var experimentalFeaturesSection: some View {
        Section {
            Toggle(isOn: $themeManager.showSleepDiaryHistory) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Sleep Diary History")
                            .font(.subheadline)
                        Text("View past sleep log entries")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.green)

            Toggle(isOn: $themeManager.showSleepInsights) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Sleep Insights")
                            .font(.subheadline)
                        Text("Patterns and recommendations")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.blue)

            Toggle(isOn: $themeManager.gamificationEnabled) {
                HStack {
                    Image(systemName: "star.circle")
                        .foregroundColor(.yellow)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("XP & Gamification")
                            .font(.subheadline)
                        Text("Levels, badges, XP tracking (parked)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.yellow)

            Toggle(isOn: $themeManager.showWatchStyleCheckIns) {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Watch-Style Check-Ins")
                            .font(.subheadline)
                        Text("Energy, Mood, Focus tracking")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.orange)

            Toggle(isOn: $themeManager.sleepProfileEnabled) {
                HStack {
                    Image(systemName: "moon.zzz")
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text("Sleep Profile")
                                .font(.subheadline)
                            Text("BETA")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple.opacity(0.8))
                                .cornerRadius(4)
                        }
                        Text("Chronotype & sleep times in Profile")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.purple)

            // Reset chronotype analysis button (only show when Sleep Profile is enabled)
            if themeManager.sleepProfileEnabled {
                Button {
                    ChronotypeManager.shared.clearSavedResult()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Reset Chronotype Analysis")
                                .font(.subheadline)
                            Text("Clear cached result to re-analyze")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }

                // Travel History debug view
                NavigationLink {
                    TravelHistoryDebugView()
                        .environmentObject(themeManager)
                } label: {
                    HStack {
                        Image(systemName: "airplane")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text("Travel History")
                                    .font(.subheadline)
                                Text("BETA")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.8))
                                    .cornerRadius(4)
                            }
                            Text("Detect timezone shifts from sleep data")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Voice API Test Section
            voiceTestSection
        } header: {
            Label("Experimental Features", systemImage: "flask")
        } footer: {
            Text("These features are still in development. Enable to test them on the main dashboard.")
        }
    }

    // MARK: - Voice Test Section

    @State private var voiceTestStatus: String = "Not tested"
    @State private var voiceTestInProgress: Bool = false
    @State private var ttsTestResult: String = ""
    @State private var sttTestResult: String = ""

    @ViewBuilder
    private var voiceTestSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Divider()
                .padding(.vertical, Spacing.xs)

            Text("🎤 Voice API Tests")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.purple)

            // TTS Test
            Button {
                testTTS()
            } label: {
                HStack {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Test ElevenLabs TTS")
                            .font(.subheadline)
                        Text("Speak: \"Hello, this is a test\"")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if voiceTestInProgress {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(voiceTestInProgress)

            if !ttsTestResult.isEmpty {
                Text(ttsTestResult)
                    .font(.caption)
                    .foregroundColor(ttsTestResult.contains("✅") ? .green : .red)
                    .padding(.leading, 28)
            }

            // STT Test
            Button {
                testSTT()
            } label: {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Test Whisper STT")
                            .font(.subheadline)
                        Text("Record 3 seconds and transcribe")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .disabled(voiceTestInProgress)

            if !sttTestResult.isEmpty {
                Text(sttTestResult)
                    .font(.caption)
                    .foregroundColor(sttTestResult.contains("✅") ? .green : .red)
                    .padding(.leading, 28)
            }
        }
    }

    private func testTTS() {
        voiceTestInProgress = true
        ttsTestResult = "Testing..."

        Task {
            do {
                let audioData = try await ConvexService.shared.callVoiceSynthesize(
                    text: "Hello, this is a test of the voice synthesis system.",
                    voiceId: "rachel",
                    speed: 1.0
                )

                print("TTS Test: Got \(audioData.count) bytes of audio")

                // Play the audio
                try await AudioSessionManager.shared.playAudio(data: audioData)

                await MainActor.run {
                    ttsTestResult = "✅ Success! \(audioData.count) bytes"
                    voiceTestInProgress = false
                }
            } catch {
                print("TTS Test Error: \(error)")
                await MainActor.run {
                    ttsTestResult = "❌ Error: \(error.localizedDescription)"
                    voiceTestInProgress = false
                }
            }
        }
    }

    private func testSTT() {
        voiceTestInProgress = true
        sttTestResult = "Recording for 3 seconds..."

        Task {
            do {
                // Request mic permission if needed
                let audioManager = AudioSessionManager.shared
                if audioManager.hasMicrophonePermission != true {
                    let granted = await audioManager.requestMicrophonePermission()
                    if !granted {
                        await MainActor.run {
                            sttTestResult = "❌ Mic permission denied"
                            voiceTestInProgress = false
                        }
                        return
                    }
                }

                // Start recording
                try await audioManager.startRecording()

                // Wait 3 seconds
                try await Task.sleep(nanoseconds: 3_000_000_000)

                // Stop and get audio
                guard let audioData = audioManager.stopRecording() else {
                    await MainActor.run {
                        sttTestResult = "❌ No audio recorded"
                        voiceTestInProgress = false
                    }
                    return
                }

                await MainActor.run {
                    sttTestResult = "Transcribing \(audioData.count) bytes..."
                }

                // Transcribe
                let base64Audio = audioData.base64EncodedString()
                let transcript = try await ConvexService.shared.callVoiceTranscribe(audioBase64: base64Audio)

                await MainActor.run {
                    sttTestResult = "✅ Heard: \"\(transcript)\""
                    voiceTestInProgress = false
                }
            } catch {
                print("STT Test Error: \(error)")
                await MainActor.run {
                    sttTestResult = "❌ Error: \(error.localizedDescription)"
                    voiceTestInProgress = false
                }
            }
        }
    }

    // MARK: - Watch Connectivity Section

    @ObservedObject private var watchManager = iOSWatchConnectivityManager.shared

    private var watchConnectivitySection: some View {
        Section {
            // App Installed Status (most important - shows if sync will work)
            HStack {
                Image(systemName: "applewatch")
                    .foregroundColor(watchManager.isWatchAppInstalled ? .blue : .gray)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Watch App")
                        .font(.subheadline)
                    Text(watchManager.isWatchAppInstalled ? "Installed" : "Not Installed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if watchManager.isWatchAppInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            // Real-time Connection Status (only matters for immediate delivery)
            HStack {
                Image(systemName: watchManager.isWatchConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(watchManager.isWatchConnected ? .green : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Real-time Link")
                        .font(.subheadline)
                    // Friendlier status - not reachable is normal, not an error
                    Text(watchManager.isWatchConnected ? "Active (both apps open)" : "Standby")
                        .font(.caption2)
                        .foregroundColor(watchManager.isWatchConnected ? .green : .secondary)
                }
                Spacer()
                Circle()
                    .fill(watchManager.isWatchConnected ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 10, height: 10)
            }

            // Sync Actions
            Button {
                watchManager.sendUserDataToWatch()
                watchManager.log("Manual user data sync triggered")
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Sync User Data")
                        .font(.subheadline)
                }
            }

            // View Log NavigationLink
            NavigationLink {
                WatchConnectivityLogView()
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Connectivity Log")
                            .font(.subheadline)
                        Text("\(watchManager.connectivityLog.count) entries")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Clear Log
            Button {
                watchManager.clearLog()
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("Clear Log")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
        } header: {
            Label("Watch Connectivity", systemImage: "applewatch")
        } footer: {
            Text("Monitor and debug Apple Watch communication. The log shows all connectivity events.")
        }
    }

    // MARK: - Repair Tools Section

    @State private var isVerifyingHealthKit = false
    @State private var healthKitVerificationResult: String?

    private var repairToolsSection: some View {
        Section {
            // Detailed HealthKit Data View (NEW)
            NavigationLink {
                HealthKitDetailedDebugView()
                    .environmentObject(themeManager)
            } label: {
                Label("HealthKit Data (6 Months)", systemImage: "waveform.path.ecg.rectangle")
                    .foregroundColor(.cyan)
            }

            // Verify HealthKit Data
            Button {
                verifyHealthKitData()
            } label: {
                HStack {
                    Label("Verify HealthKit Data", systemImage: "heart.text.square")
                        .foregroundColor(.pink)
                    Spacer()
                    if isVerifyingHealthKit {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isVerifyingHealthKit)

            // Show HealthKit verification result
            if let result = healthKitVerificationResult {
                Text(result)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Repair Sleep Insights
            Button {
                repairSleepInsights()
            } label: {
                HStack {
                    Label("Repair Sleep Insights", systemImage: "wrench.and.screwdriver.fill")
                        .foregroundColor(.blue)
                    Spacer()
                    if isRepairing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isRepairing)

            // Calculate Scores
            Button {
                calculateScores()
            } label: {
                Label("Recalculate All Scores", systemImage: "function")
                    .foregroundColor(.indigo)
            }

            // Reset Journey Intro
            Button {
                resetJourneyIntro()
            } label: {
                Label("Reset Journey Intro", systemImage: "arrow.counterclockwise.circle")
                    .foregroundColor(.purple)
            }

            // Reset Feature Guides
            Button {
                resetFeatureGuides()
            } label: {
                Label("Reset Feature Guides", systemImage: "book.circle")
                    .foregroundColor(.teal)
            }

            // Status message
            if let message = statusMessage {
                HStack {
                    Image(systemName: statusIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(statusIsError ? .red : .green)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(statusIsError ? .red : .green)
                }
            }
        } header: {
            Label("Repair & Diagnostics", systemImage: "wrench.adjustable")
        } footer: {
            Text("Verify HealthKit to check wearable data connectivity. Reset Journey Intro to test the intro screens again (restart app after).")
        }
    }

    private func verifyHealthKitData() {
        isVerifyingHealthKit = true
        healthKitVerificationResult = nil

        Task {
            let healthKitManager = HealthKitManager()
            let result = await healthKitManager.verifyHealthKitData()
            await MainActor.run {
                healthKitVerificationResult = result.summary
                isVerifyingHealthKit = false
            }
        }
    }

    // MARK: - Actions

    private func startGeneration() {
        isGenerating = true
        statusMessage = nil

        // Reset progress tracking
        progressCurrentDay = 1
        progressTotalDays = selectedMode.days.count
        progressSection = "Preparing..."
        progressQuestionIndex = 0
        progressTotalQuestions = 0
        progressAnswered = 0
        progressElapsed = 0
        progressDayProgress = 0

        // Configure based on mode
        var config = MockGeneratorConfig()
        config.dayRange = selectedMode.days
        config.questionDelay = 0.05 // Balanced speed

        switch selectedMode {
        case .fullRandom:
            config.gatewayTriggerProbability = 0.4
        case .maxLoad:
            config.gatewayTriggerProbability = 1.0
        case .selective:
            config.gatewayTriggerProbability = 1.0
            // TODO: Pass specific gateways to generator
        case .quickTest:
            config.gatewayTriggerProbability = 0.4
        }

        // Create generator with the configured settings
        let newGenerator = MockPlaybackController(config: config)
        generator = newGenerator

        // Start generation
        newGenerator.startGeneration()

        // Monitor progress and completion
        Task {
            while newGenerator.state.isActive {
                // Update progress state from generator
                await MainActor.run {
                    progressCurrentDay = newGenerator.progress.currentDay
                    progressTotalDays = newGenerator.progress.totalDays
                    progressSection = newGenerator.progress.currentSection
                    progressQuestionIndex = newGenerator.progress.currentQuestionIndex
                    progressTotalQuestions = newGenerator.progress.totalQuestionsForSection
                    progressAnswered = newGenerator.progress.totalQuestionsAnswered
                    progressElapsed = newGenerator.progress.elapsedTime
                    progressDayProgress = newGenerator.progress.dayProgress
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }

            await MainActor.run {
                isGenerating = false

                switch newGenerator.state {
                case .completed:
                    statusMessage = "Generated \(newGenerator.progress.totalQuestionsAnswered) responses"
                    statusIsError = false
                case .failed(let error):
                    statusMessage = "Failed: \(error)"
                    statusIsError = true
                case .cancelled:
                    statusMessage = "Cancelled"
                    statusIsError = false
                default:
                    break
                }

                // Refresh status
                Task {
                    await questionnaireManager.loadJourneyProgress()
                    await questionnaireManager.loadGatewayStatesFromServer()
                }
            }
        }
    }

    private func advanceDay() {
        isAdvancingDay = true
        statusMessage = nil

        Task {
            do {
                // Calendar-gated: no time bypass needed, backend validates completion + calendar date
                let response = try await ConvexService.shared.advanceToNextDay()
                await MainActor.run {
                    if response.success {
                        questionnaireManager.currentDay = response.newDay ?? questionnaireManager.currentDay
                        statusMessage = "Advanced to Day \(response.newDay ?? 0)"
                        statusIsError = false
                    } else {
                        statusMessage = response.error ?? "Failed"
                        statusIsError = true
                    }
                    isAdvancingDay = false
                }
                await questionnaireManager.loadJourneyProgress()
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                    statusIsError = true
                    isAdvancingDay = false
                }
            }
        }
    }

    private func resetProgress() {
        isResetting = true
        statusMessage = nil

        Task {
            do {
                _ = try await ConvexService.shared.resetJourneyProgress()

                // Clear UserDefaults splash screen tracking so they show again
                await MainActor.run {
                    clearSplashScreenTracking()
                    // Reset journey phase back to intake
                    JourneyPhaseManager.shared.currentPhase = .intake
                }

                await questionnaireManager.loadJourneyProgress()
                await MainActor.run {
                    questionnaireManager.currentDay = 1
                    statusMessage = "Reset to Day 1"
                    statusIsError = false
                    isResetting = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                    statusIsError = true
                    isResetting = false
                }
            }
        }
    }

    /// Clear UserDefaults keys that track if day splash screens have been shown
    /// NOTE: Does NOT clear journey intro - that's a one-time app intro, not per-journey
    private func clearSplashScreenTracking() {
        // Clear day splash keys (daySplashShown_day1_assessment through day10)
        for day in 1...10 {
            UserDefaults.standard.removeObject(forKey: "daySplashShown_day\(day)_assessment")
            UserDefaults.standard.removeObject(forKey: "expansionSplashShown_day\(day)")
        }
        // NOTE: Do NOT clear hasSeenJourneyIntro - that's a one-time app introduction
        // The journey intro explains the app once per device, not once per journey
        print("[Debug] Cleared day splash screen tracking UserDefaults")
    }

    /// Reset just the journey intro flag so it shows again on next app launch
    private func resetJourneyIntro() {
        OnboardingManager.shared.resetJourneyIntro()
        statusMessage = "Journey intro reset - restart app to see it"
        statusIsError = false
        print("[Debug] Journey intro reset - will show on next app launch")
    }

    /// Reset all first-time feature guides so they show again
    private func resetFeatureGuides() {
        FirstTimeGuideManager.shared.resetAllGuides()
        FirstTimeGuideManager.shared.resetAllCoachMarks()
        statusMessage = "All guides & coach marks reset"
        statusIsError = false
        print("[Debug] All first-time feature guides and coach marks reset")
    }

    private func refreshFromServer() {
        Task {
            await questionnaireManager.loadJourneyProgress()
            await questionnaireManager.loadGatewayStatesFromServer()
            await MainActor.run {
                statusMessage = "Refreshed from server"
                statusIsError = false
            }
        }
    }

    private func repairSleepInsights() {
        isRepairing = true
        statusMessage = nil

        Task {
            do {
                let daysProcessed = try await ConvexService.shared.computeAllSleepMetricsFromResponses()
                await MainActor.run {
                    statusMessage = "Repaired \(daysProcessed) days of sleep data"
                    statusIsError = false
                    isRepairing = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                    statusIsError = true
                    isRepairing = false
                }
            }
        }
    }

    private func calculateScores() {
        Task {
            do {
                _ = try await ConvexService.shared.persistCalculatedScores()
                await MainActor.run {
                    statusMessage = "Scores recalculated"
                    statusIsError = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = error.localizedDescription
                    statusIsError = true
                }
            }
        }
    }

    private func refreshPreview() async {
        guard selectedMode == .selective || selectedMode == .maxLoad else {
            schedulePreview = nil
            return
        }

        isLoadingPreview = true

        let gateways: Set<GatewayType>
        if selectedMode == .maxLoad {
            gateways = Set(GatewayType.allCases)
        } else {
            gateways = selectedGateways
        }

        let gatewayIds = gateways.map { $0.rawValue }
        let schedule = computeLocalSchedule(triggeredGateways: gatewayIds)

        await MainActor.run {
            schedulePreview = SchedulePreview(
                totalQuestions: schedule.reduce(0) { $0 + $1.questionCount },
                totalDays: schedule.count,
                totalMinutes: schedule.reduce(0) { $0 + $1.estimatedMinutes },
                days: schedule.map { day in
                    SchedulePreview.DayPreview(
                        dayNumber: day.dayNumber,
                        modules: day.modules,
                        questionCount: day.questionCount,
                        estimatedMinutes: day.estimatedMinutes
                    )
                }
            )
            isLoadingPreview = false
        }
    }

    // MARK: - Schedule Computation (mirrors Convex algorithm)

    private func computeLocalSchedule(triggeredGateways: [String]) -> [(dayNumber: Int, modules: [String], questionCount: Int, estimatedMinutes: Int)] {
        let maxQuestionsPerDay = 18
        let expansionStartDay = 6
        let expansionEndDay = 10

        var eligibleModules = ExpansionModule.allModules.filter { module in
            triggeredGateways.contains(module.requiredGateway.rawValue)
        }
        eligibleModules.sort { $0.priority < $1.priority }

        var dayAssignments: [(dayNumber: Int, modules: [String], questionCount: Int, estimatedMinutes: Int)] = []
        var currentDay = expansionStartDay
        var currentDayModules: [String] = []
        var currentDayQuestions = 0
        var currentDayMinutes = 0

        for module in eligibleModules {
            if currentDayQuestions + module.questionCount <= maxQuestionsPerDay {
                currentDayModules.append(module.id)
                currentDayQuestions += module.questionCount
                currentDayMinutes += module.estimatedMinutes
            } else {
                if !currentDayModules.isEmpty {
                    dayAssignments.append((currentDay, currentDayModules, currentDayQuestions, currentDayMinutes))
                }
                currentDay += 1
                if currentDay > expansionEndDay { break }
                currentDayModules = [module.id]
                currentDayQuestions = module.questionCount
                currentDayMinutes = module.estimatedMinutes
            }

            if currentDayQuestions >= 14 && currentDay < expansionEndDay {
                dayAssignments.append((currentDay, currentDayModules, currentDayQuestions, currentDayMinutes))
                currentDay += 1
                currentDayModules = []
                currentDayQuestions = 0
                currentDayMinutes = 0
            }
        }

        if !currentDayModules.isEmpty && currentDay <= expansionEndDay {
            dayAssignments.append((currentDay, currentDayModules, currentDayQuestions, currentDayMinutes))
        }

        return dayAssignments
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Supporting Views

struct StatusBadge: View {
    let isComplete: Bool
    let completeText: String
    let pendingText: String
    var isNotApplicable: Bool = false
    var notApplicableText: String = "None"

    var body: some View {
        Group {
            if isNotApplicable {
                Text(notApplicableText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
            } else {
                Text(isComplete ? completeText : pendingText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isComplete ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background((isComplete ? Color.green : Color.orange).opacity(0.15))
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Watch Connectivity Log View

struct WatchConnectivityLogView: View {
    @ObservedObject private var watchManager = iOSWatchConnectivityManager.shared
    @State private var filterLevel: iOSConnectivityLogEntry.Level? = nil

    var filteredLog: [iOSConnectivityLogEntry] {
        if let level = filterLevel {
            return watchManager.connectivityLog.filter { $0.level == level }
        }
        return watchManager.connectivityLog
    }

    var body: some View {
        List {
            // Status Summary
            Section {
                HStack {
                    Image(systemName: "app.badge")
                    Text("App Installed")
                    Spacer()
                    Text(watchManager.isWatchAppInstalled ? "Yes" : "No")
                        .foregroundColor(watchManager.isWatchAppInstalled ? .green : .orange)
                }
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Real-time Link")
                    Spacer()
                    Text(watchManager.isWatchConnected ? "Active" : "Standby")
                        .foregroundColor(watchManager.isWatchConnected ? .green : .secondary)
                }
            } header: {
                Text("Status")
            }

            // Filter
            Section {
                Picker("Filter", selection: $filterLevel) {
                    Text("All (\(watchManager.connectivityLog.count))").tag(nil as iOSConnectivityLogEntry.Level?)
                    Text("Info").tag(iOSConnectivityLogEntry.Level.info as iOSConnectivityLogEntry.Level?)
                    Text("Success").tag(iOSConnectivityLogEntry.Level.success as iOSConnectivityLogEntry.Level?)
                    Text("Warning").tag(iOSConnectivityLogEntry.Level.warning as iOSConnectivityLogEntry.Level?)
                    Text("Error").tag(iOSConnectivityLogEntry.Level.error as iOSConnectivityLogEntry.Level?)
                }
                .pickerStyle(.segmented)
            }

            // Log Entries
            Section {
                if filteredLog.isEmpty {
                    Text("No log entries")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(filteredLog) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.level.emoji)
                                Text(entry.formattedTime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                                Spacer()
                                Text(entry.level.rawValue)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(colorForLevel(entry.level))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(colorForLevel(entry.level).opacity(0.15))
                                    .cornerRadius(4)
                            }
                            Text(entry.message)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                HStack {
                    Text("Log Entries")
                    Spacer()
                    Text("\(filteredLog.count) entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Connectivity Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    watchManager.clearLog()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    private func colorForLevel(_ level: iOSConnectivityLogEntry.Level) -> Color {
        switch level {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Travel History Debug View

struct TravelHistoryDebugView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var chronotypeManager = ChronotypeManager.shared
    @ObservedObject var healthKitManager = HealthKitManager(authManager: nil)

    @State private var isLoading = false
    @State private var sleepData: [[String: Any]] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            // Status Section
            Section {
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Fetching 1 year of sleep data...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(sleepData.count) nights loaded")
                            .font(.subheadline)
                    }
                }

                Button {
                    fetchAndAnalyze()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(sleepData.isEmpty ? "Analyze Travel History" : "Re-analyze")
                    }
                }
                .disabled(isLoading)
            } header: {
                Text("Data Source")
            } footer: {
                Text("Fetches up to 1 year of sleep data from Apple Health and detects timezone shifts.")
            }

            // Summary Section
            if !chronotypeManager.detectedEpochs.isEmpty {
                Section {
                    let stableNights = chronotypeManager.detectedEpochs.filter { !$0.isJetLagged }.reduce(0) { $0 + $1.nightCount }
                    let jetLagNights = chronotypeManager.detectedEpochs.filter { $0.isJetLagged }.reduce(0) { $0 + $1.nightCount }
                    let uniqueLocations = Set(chronotypeManager.detectedEpochs.map { $0.inferredTimezone }).count

                    HStack {
                        Label("Location Changes", systemImage: "airplane")
                        Spacer()
                        Text("\(chronotypeManager.detectedEpochs.count - 1)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Unique Timezones", systemImage: "globe")
                        Spacer()
                        Text("\(uniqueLocations)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Stable Nights", systemImage: "moon.zzz.fill")
                        Spacer()
                        Text("\(stableNights)")
                            .foregroundColor(.green)
                    }

                    HStack {
                        Label("Jet Lag Nights", systemImage: "clock.badge.exclamationmark")
                        Spacer()
                        Text("\(jetLagNights)")
                            .foregroundColor(.orange)
                    }
                } header: {
                    Text("Summary")
                }
            }

            // Epochs Section
            if !chronotypeManager.detectedEpochs.isEmpty {
                Section {
                    ForEach(chronotypeManager.detectedEpochs) { epoch in
                        HStack {
                            // Icon
                            Image(systemName: epoch.isJetLagged ? "airplane" : "mappin.circle.fill")
                                .foregroundColor(epoch.isJetLagged ? .orange : .blue)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(epoch.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    if epoch.isJetLagged {
                                        Text("Jet Lag")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.orange)
                                            .cornerRadius(4)
                                    }
                                }

                                Text(epoch.dateRange)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(epoch.nightCount) nights")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("UTC bed: \(String(format: "%.1f", epoch.avgUtcBedtimeHour))h")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Detected Location Epochs")
                } footer: {
                    Text("Timezone shifts >4 hours between consecutive nights indicate travel. First 3 nights after travel are marked as jet lag.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Travel History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if sleepData.isEmpty {
                fetchAndAnalyze()
            }
        }
    }

    private func fetchAndAnalyze() {
        isLoading = true
        errorMessage = nil

        // Fetch 365 days of sleep data
        healthKitManager.fetchSleepData(daysBack: 365) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let data):
                    sleepData = data
                    if data.isEmpty {
                        errorMessage = "No sleep data found in Apple Health"
                    } else {
                        // Run travel analysis
                        chronotypeManager.analyzeTravel(from: data)
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Day Advancement Log Helper Views

/// Small stat box for the log section
private struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Row for displaying a day advancement event
private struct DayAdvancementEventRow: View {
    let event: DayAdvancementEvent

    private var eventColor: Color {
        switch event.eventColor {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        default: return .blue
        }
    }

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(event.timestamp)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Event icon
            Image(systemName: event.eventIcon)
                .foregroundColor(eventColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                // Event type and day
                HStack {
                    Text(event.eventType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .fontWeight(.medium)

                    if let toDay = event.toDay {
                        Text("Day \(event.fromDay) → \(toDay)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Day \(event.fromDay)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Error message if failed
                if let error = event.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }

                // Status flags
                HStack(spacing: 4) {
                    if let sleepLog = event.sleepLogCompleted {
                        AdvancementStatusBadge(label: "SL", isComplete: sleepLog)
                    }
                    if let assessment = event.assessmentCompleted {
                        AdvancementStatusBadge(label: "AS", isComplete: assessment)
                    }
                    if event.bypassedTimeCheck {
                        Text("bypassed")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.orange)
                            .cornerRadius(2)
                    }
                    if event.debugMode {
                        Text("debug")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.purple)
                            .cornerRadius(2)
                    }
                }
            }

            Spacer()

            // Time
            Text(timeAgo)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Small badge showing completion status for day advancement events
private struct AdvancementStatusBadge: View {
    let label: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isComplete ? "checkmark" : "xmark")
                .font(.system(size: 6, weight: .bold))
            Text(label)
                .font(.system(size: 8, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 3)
        .padding(.vertical, 1)
        .background(isComplete ? Color.green : Color.red)
        .cornerRadius(2)
    }
}

// MARK: - Preview

#if DEBUG
struct UnifiedDebugPanel_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedDebugPanel()
            .environmentObject(ThemeManager.shared)
            .environmentObject(QuestionnaireManager.shared)
    }
}
#endif
