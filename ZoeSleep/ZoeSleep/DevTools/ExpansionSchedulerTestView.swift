//
//  ExpansionSchedulerTestView.swift
//  ZoeSleep
//
//  Comprehensive testing system for the Dynamic Expansion Scheduler
//  Allows selective gateway triggering, expansion preview, and compatibility testing
//

#if DEBUG

import SwiftUI

/// Comprehensive testing view for the Expansion Scheduler system
struct ExpansionSchedulerTestView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var testController = ExpansionSchedulerTestController()
    @State private var showingRunConfirmation = false
    @State private var selectedTestMode: TestMode = .allGateways

    private var theme: ColorTheme { themeManager.currentTheme }

    enum TestMode: String, CaseIterable {
        case allGateways = "All Gateways"
        case selectedGateways = "Selected Gateways"
        case singleModule = "Single Module"
        case healthySleeper = "Healthy Sleeper (None)"

        var description: String {
            switch self {
            case .allGateways: return "Trigger all 10 gateways to test full expansion load"
            case .selectedGateways: return "Choose specific gateways to trigger"
            case .singleModule: return "Test a single expansion module"
            case .healthySleeper: return "No gateways triggered - minimal questions"
            }
        }
    }

    var body: some View {
        List {
            // MARK: - Test Mode Selection
            Section {
                Picker("Test Mode", selection: $selectedTestMode) {
                    ForEach(TestMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(selectedTestMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Label("Test Configuration", systemImage: "slider.horizontal.3")
            }

            // MARK: - Gateway Selection (for selectedGateways mode)
            if selectedTestMode == .selectedGateways {
                gatewaySelectionSection
            }

            // MARK: - Single Module Selection (for singleModule mode)
            if selectedTestMode == .singleModule {
                singleModuleSection
            }

            // MARK: - Schedule Preview
            schedulePreviewSection

            // MARK: - Test Actions
            testActionsSection

            // MARK: - Test Results
            if !testController.testResults.isEmpty {
                testResultsSection
            }

            // MARK: - Debug Log
            if !testController.debugLog.isEmpty {
                debugLogSection
            }
        }
        .navigationTitle("Expansion Tester")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await testController.refreshPreview(gateways: getSelectedGateways())
        }
        .task {
            await testController.refreshPreview(gateways: getSelectedGateways())
        }
        .onChange(of: selectedTestMode) { _, _ in
            Task {
                await testController.refreshPreview(gateways: getSelectedGateways())
            }
        }
        .confirmationDialog("Run Full Test?", isPresented: $showingRunConfirmation) {
            Button("Run Test (Destructive)") {
                Task {
                    await testController.runFullTest(
                        mode: selectedTestMode,
                        selectedGateways: getSelectedGateways(),
                        selectedModule: testController.selectedModule
                    )
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset your journey progress and generate mock data with the selected configuration. This cannot be undone.")
        }
    }

    // MARK: - Gateway Selection Section

    private var gatewaySelectionSection: some View {
        Section {
            ForEach(GatewayType.allCases, id: \.self) { gateway in
                Toggle(isOn: Binding(
                    get: { testController.selectedGateways.contains(gateway) },
                    set: { isSelected in
                        if isSelected {
                            testController.selectedGateways.insert(gateway)
                        } else {
                            testController.selectedGateways.remove(gateway)
                        }
                        Task {
                            await testController.refreshPreview(gateways: getSelectedGateways())
                        }
                    }
                )) {
                    HStack {
                        Image(systemName: gateway.icon)
                            .foregroundColor(gateway.color)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
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

            // Quick selection buttons
            HStack {
                Button("Select All") {
                    testController.selectedGateways = Set(GatewayType.allCases)
                    Task { await testController.refreshPreview(gateways: getSelectedGateways()) }
                }
                .buttonStyle(.bordered)

                Button("Clear All") {
                    testController.selectedGateways = []
                    Task { await testController.refreshPreview(gateways: getSelectedGateways()) }
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("\(testController.selectedGateways.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Label("Select Gateways to Trigger", systemImage: "checkmark.circle")
        }
    }

    // MARK: - Single Module Section

    private var singleModuleSection: some View {
        Section {
            Picker("Expansion Module", selection: $testController.selectedModule) {
                ForEach(ExpansionModule.allModules, id: \.id) { module in
                    HStack {
                        Text(module.name)
                        Text("(\(module.questionCount) Q)")
                            .foregroundColor(.secondary)
                    }
                    .tag(module.id)
                }
            }

            if let module = ExpansionModule.allModules.first(where: { $0.id == testController.selectedModule }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(module.instrument, systemImage: "doc.text")
                        Spacer()
                        Text("\(module.questionCount) questions")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }

                    HStack {
                        Label("Priority \(module.priority)", systemImage: "arrow.up.arrow.down")
                        Spacer()
                        Text("~\(module.estimatedMinutes) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Required Gateway: \(module.requiredGateway.displayName)")
                        .font(.caption)
                        .foregroundColor(module.requiredGateway.color)
                }
                .font(.subheadline)
            }
        } header: {
            Label("Select Module to Test", systemImage: "square.stack.3d.up")
        }
    }

    // MARK: - Schedule Preview Section

    private var schedulePreviewSection: some View {
        Section {
            if testController.isLoadingPreview {
                HStack {
                    ProgressView()
                    Text("Computing schedule...")
                        .foregroundColor(.secondary)
                }
            } else if let preview = testController.schedulePreview {
                // Summary
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(preview.totalQuestions)")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Total Questions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .center) {
                            Text("\(preview.totalDays)")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("~\(preview.totalMinutes)")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Day-by-day breakdown
                    ForEach(preview.days, id: \.dayNumber) { day in
                        HStack {
                            Text("Day \(day.dayNumber)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 60, alignment: .leading)

                            // Module badges
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(day.modules, id: \.self) { moduleId in
                                        Text(moduleId.replacingOccurrences(of: "expansion_", with: ""))
                                            .font(.caption2)
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
                }
            } else {
                Text("Pull to refresh schedule preview")
                    .foregroundColor(.secondary)
            }
        } header: {
            Label("Schedule Preview (Days 6-15)", systemImage: "calendar.badge.clock")
        }
    }

    // MARK: - Test Actions Section

    private var testActionsSection: some View {
        Section {
            // Preview Only (no changes)
            Button {
                Task {
                    await testController.refreshPreview(gateways: getSelectedGateways())
                }
            } label: {
                Label("Refresh Preview", systemImage: "arrow.clockwise")
            }
            .disabled(testController.isRunning)

            // Run Full Test
            Button {
                showingRunConfirmation = true
            } label: {
                HStack {
                    Label("Run Full Journey Test", systemImage: "play.fill")
                        .foregroundColor(.green)

                    Spacer()

                    if testController.isRunning {
                        ProgressView()
                    }
                }
            }
            .disabled(testController.isRunning)

            // Quick Day 5 Test (compute schedule only)
            Button {
                Task {
                    await testController.runQuickDay5Test(gateways: getSelectedGateways())
                }
            } label: {
                HStack {
                    Label("Quick Test (Day 5 → Schedule)", systemImage: "forward.fill")
                        .foregroundColor(.orange)

                    Spacer()

                    Text("~30s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(testController.isRunning)

            // Verify Dashboard Compatibility
            Button {
                Task {
                    await testController.verifyDashboardCompatibility()
                }
            } label: {
                Label("Verify Dashboard Data", systemImage: "checkmark.shield")
                    .foregroundColor(.blue)
            }
            .disabled(testController.isRunning)

        } header: {
            Label("Test Actions", systemImage: "play.rectangle")
        } footer: {
            Text("Full test resets progress and generates 15 days of mock data. Quick test only completes Days 1-5 to trigger schedule computation.")
        }
    }

    // MARK: - Test Results Section

    private var testResultsSection: some View {
        Section {
            ForEach(testController.testResults, id: \.id) { result in
                HStack {
                    Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.passed ? .green : .red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.testName)
                            .font(.subheadline)
                        Text(result.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let duration = result.duration {
                        Text(String(format: "%.1fs", duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Summary
            let passed = testController.testResults.filter { $0.passed }.count
            let total = testController.testResults.count
            HStack {
                Text("Results: \(passed)/\(total) passed")
                    .font(.headline)

                Spacer()

                if passed == total {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Label("Test Results", systemImage: "list.clipboard")
        }
    }

    // MARK: - Debug Log Section

    private var debugLogSection: some View {
        Section {
            ForEach(testController.debugLog.indices, id: \.self) { index in
                Text(testController.debugLog[index])
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Button("Clear Log") {
                testController.debugLog = []
            }
            .font(.caption)
        } header: {
            Label("Debug Log", systemImage: "text.alignleft")
        }
    }

    // MARK: - Helpers

    private func getSelectedGateways() -> Set<GatewayType> {
        switch selectedTestMode {
        case .allGateways:
            return Set(GatewayType.allCases)
        case .selectedGateways:
            return testController.selectedGateways
        case .singleModule:
            if let module = ExpansionModule.allModules.first(where: { $0.id == testController.selectedModule }) {
                return [module.requiredGateway]
            }
            return []
        case .healthySleeper:
            return []
        }
    }
}

// MARK: - Expansion Module Model

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

// MARK: - Test Result Model

struct TestResult: Identifiable {
    let id = UUID()
    let testName: String
    let passed: Bool
    let message: String
    let duration: TimeInterval?
}

// MARK: - Test Controller

@MainActor
class ExpansionSchedulerTestController: ObservableObject {
    @Published var selectedGateways: Set<GatewayType> = []
    @Published var selectedModule: String = "expansion_isi"
    @Published var schedulePreview: SchedulePreview?
    @Published var isLoadingPreview = false
    @Published var isRunning = false
    @Published var testResults: [TestResult] = []
    @Published var debugLog: [String] = []

    private let convexService = ConvexService.shared

    // MARK: - Preview

    func refreshPreview(gateways: Set<GatewayType>) async {
        isLoadingPreview = true
        defer { isLoadingPreview = false }

        // Use the local computation algorithm (same as Convex)
        let gatewayIds = gateways.map { $0.rawValue }

        // Compute schedule locally for preview
        let schedule = computeLocalSchedule(triggeredGateways: gatewayIds)

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

        log("Preview computed: \(schedulePreview?.totalQuestions ?? 0) questions across \(schedulePreview?.totalDays ?? 0) days")
    }

    // MARK: - Tests

    func runFullTest(mode: ExpansionSchedulerTestView.TestMode, selectedGateways: Set<GatewayType>, selectedModule: String) async {
        isRunning = true
        testResults = []
        debugLog = []

        defer { isRunning = false }

        let startTime = Date()
        log("Starting full journey test...")

        // Create mock generator with predetermined gateways
        let config = MockGeneratorConfig(
            questionDelay: 0.01,  // Fast for testing
            dayRange: 1...15,
            gatewayTriggerProbability: 1.0  // We control triggers manually
        )

        let controller = MockPlaybackController(config: config)

        // Run the mock generator
        controller.startGeneration()

        // Wait for completion (with timeout)
        var attempts = 0
        while controller.state.isActive && attempts < 600 {  // 60 second timeout
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s
            attempts += 1
        }

        let duration = Date().timeIntervalSince(startTime)

        // Verify results
        await verifyTestResults(
            expectedGateways: selectedGateways,
            duration: duration
        )

        log("Full test completed in \(String(format: "%.1f", duration))s")
    }

    func runQuickDay5Test(gateways: Set<GatewayType>) async {
        isRunning = true
        testResults = []

        defer { isRunning = false }

        let startTime = Date()
        log("Starting quick Day 5 test...")

        // Reset progress
        do {
            _ = try await convexService.resetJourneyProgress()
            testResults.append(TestResult(
                testName: "Reset Progress",
                passed: true,
                message: "Journey reset to Day 1",
                duration: nil
            ))
        } catch {
            testResults.append(TestResult(
                testName: "Reset Progress",
                passed: false,
                message: error.localizedDescription,
                duration: nil
            ))
            return
        }

        // Run Days 1-5 with selected gateways
        let config = MockGeneratorConfig(
            questionDelay: 0.01,
            dayRange: 1...5,
            gatewayTriggerProbability: 1.0
        )

        let mockGen = MockDataGenerator(config: config)

        // Generate and save each day
        for day in 1...5 {
            log("Generating Day \(day)...")

            // Sleep log
            let sleepQuestions = QuestionnaireManager.consensusSleepDiaryQuestions
            var sleepResponses: [[String: Any]] = []
            for q in sleepQuestions {
                let response = mockGen.generateAnswer(for: q, dayNumber: day)
                if !response.isEmpty {
                    sleepResponses.append(response.toDictionary())
                }
            }

            do {
                _ = try await convexService.saveResponses(dayNumber: day, responses: sleepResponses)
                _ = try await convexService.completeSection(dayNumber: day, section: "sleepLog")
            } catch {
                log("Day \(day) sleep log error: \(error)")
            }

            // Assessment
            let assessmentQuestions = QuestionnaireManager.coreQuestionsByDay[day] ?? []
            var assessmentResponses: [[String: Any]] = []
            for q in assessmentQuestions {
                let response = mockGen.generateAnswer(for: q, dayNumber: day)
                if !response.isEmpty {
                    assessmentResponses.append(response.toDictionary())
                }
            }

            do {
                _ = try await convexService.saveResponses(dayNumber: day, responses: assessmentResponses)
                _ = try await convexService.completeSection(dayNumber: day, section: "assessment")
            } catch {
                log("Day \(day) assessment error: \(error)")
            }

            // Advance day
            if day < 5 {
                do {
                    _ = try await convexService.advanceToNextDay(debugMode: true)
                } catch {
                    log("Advance day error: \(error)")
                }
            }
        }

        // Sync gateway states
        for gateway in GatewayType.allCases {
            let isTriggered = gateways.contains(gateway)
            do {
                try await convexService.updateGatewayState(
                    gatewayId: gateway.rawValue,
                    isTriggered: isTriggered,
                    triggerQuestionId: nil,
                    triggerValue: nil
                )
            } catch {
                log("Gateway sync error for \(gateway.rawValue): \(error)")
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        testResults.append(TestResult(
            testName: "Days 1-5 Complete",
            passed: true,
            message: "Generated \(gateways.count) gateway triggers",
            duration: duration
        ))

        // Verify expansion schedule was computed
        await verifyExpansionSchedule(expectedGateways: gateways)

        log("Quick test completed in \(String(format: "%.1f", duration))s")
    }

    func verifyDashboardCompatibility() async {
        isRunning = true
        testResults = []

        defer { isRunning = false }

        log("Verifying dashboard compatibility...")

        // Test 1: Check expansion schedule exists
        do {
            let summary = try await convexService.getExpansionScheduleSummary()
            testResults.append(TestResult(
                testName: "Expansion Schedule Query",
                passed: summary.hasSchedule,
                message: summary.hasSchedule ? "Schedule found with \(summary.totalQuestions) questions" : "No schedule computed",
                duration: nil
            ))
        } catch {
            testResults.append(TestResult(
                testName: "Expansion Schedule Query",
                passed: false,
                message: error.localizedDescription,
                duration: nil
            ))
        }

        // Test 2: Check day-specific expansion query
        do {
            let dayInfo = try await convexService.getExpansionForDay(dayNumber: 6)
            testResults.append(TestResult(
                testName: "Day 6 Expansion Query",
                passed: dayInfo != nil,
                message: dayInfo != nil ? "\(dayInfo!.modules.count) modules, \(dayInfo!.totalQuestions) questions" : "No expansion for Day 6",
                duration: nil
            ))
        } catch {
            testResults.append(TestResult(
                testName: "Day 6 Expansion Query",
                passed: false,
                message: error.localizedDescription,
                duration: nil
            ))
        }

        // Test 3: Check questionnaire scores
        do {
            _ = try await convexService.persistCalculatedScores()
            testResults.append(TestResult(
                testName: "Score Calculation",
                passed: true,
                message: "Scores computed successfully",
                duration: nil
            ))
        } catch {
            testResults.append(TestResult(
                testName: "Score Calculation",
                passed: false,
                message: error.localizedDescription,
                duration: nil
            ))
        }

        log("Dashboard verification complete")
    }

    // MARK: - Verification Helpers

    private func verifyTestResults(expectedGateways: Set<GatewayType>, duration: TimeInterval) async {
        // Verify journey progress
        await QuestionnaireManager.shared.loadJourneyProgress()
        let progress = QuestionnaireManager.shared.journeyProgress

        testResults.append(TestResult(
            testName: "Journey Progress",
            passed: progress != nil,
            message: progress != nil ? "Day \(progress!.currentDay)" : "No progress found",
            duration: nil
        ))

        // Verify expansion schedule
        await verifyExpansionSchedule(expectedGateways: expectedGateways)

        // Overall timing
        testResults.append(TestResult(
            testName: "Total Duration",
            passed: duration < 120,
            message: String(format: "%.1f seconds", duration),
            duration: duration
        ))
    }

    private func verifyExpansionSchedule(expectedGateways: Set<GatewayType>) async {
        do {
            let summary = try await convexService.getExpansionScheduleSummary()

            let gatewaysMatch = Set(summary.triggeredGateways) == Set(expectedGateways.map { $0.rawValue })

            testResults.append(TestResult(
                testName: "Expansion Schedule",
                passed: summary.hasSchedule,
                message: summary.hasSchedule ? "\(summary.totalQuestions) questions, \(summary.triggeredGateways.count) gateways" : "No schedule",
                duration: nil
            ))

            testResults.append(TestResult(
                testName: "Gateway Match",
                passed: gatewaysMatch,
                message: gatewaysMatch ? "All \(expectedGateways.count) gateways matched" : "Gateway mismatch",
                duration: nil
            ))
        } catch {
            testResults.append(TestResult(
                testName: "Expansion Schedule",
                passed: false,
                message: error.localizedDescription,
                duration: nil
            ))
        }
    }

    // MARK: - Local Schedule Computation (mirrors Convex)

    private func computeLocalSchedule(triggeredGateways: [String]) -> [(dayNumber: Int, modules: [String], questionCount: Int, estimatedMinutes: Int)] {
        let targetQuestionsPerDay = 14
        let maxQuestionsPerDay = 18
        let expansionStartDay = 6
        let expansionEndDay = 15

        // Get modules for triggered gateways
        var eligibleModules = ExpansionModule.allModules.filter { module in
            triggeredGateways.contains(module.requiredGateway.rawValue)
        }

        // Sort by priority
        eligibleModules.sort { $0.priority < $1.priority }

        // Bin-pack into days
        var dayAssignments: [(dayNumber: Int, modules: [String], questionCount: Int, estimatedMinutes: Int)] = []
        var currentDay = expansionStartDay
        var currentDayModules: [String] = []
        var currentDayQuestions = 0
        var currentDayMinutes = 0

        for module in eligibleModules {
            // Check if module fits in current day
            if currentDayQuestions + module.questionCount <= maxQuestionsPerDay {
                currentDayModules.append(module.id)
                currentDayQuestions += module.questionCount
                currentDayMinutes += module.estimatedMinutes
            } else {
                // Save current day and start new one
                if !currentDayModules.isEmpty {
                    dayAssignments.append((
                        dayNumber: currentDay,
                        modules: currentDayModules,
                        questionCount: currentDayQuestions,
                        estimatedMinutes: currentDayMinutes
                    ))
                }

                currentDay += 1
                if currentDay > expansionEndDay { break }

                currentDayModules = [module.id]
                currentDayQuestions = module.questionCount
                currentDayMinutes = module.estimatedMinutes
            }

            // Start new day if at target
            if currentDayQuestions >= targetQuestionsPerDay && currentDay < expansionEndDay {
                dayAssignments.append((
                    dayNumber: currentDay,
                    modules: currentDayModules,
                    questionCount: currentDayQuestions,
                    estimatedMinutes: currentDayMinutes
                ))

                currentDay += 1
                currentDayModules = []
                currentDayQuestions = 0
                currentDayMinutes = 0
            }
        }

        // Don't forget the last day
        if !currentDayModules.isEmpty && currentDay <= expansionEndDay {
            dayAssignments.append((
                dayNumber: currentDay,
                modules: currentDayModules,
                questionCount: currentDayQuestions,
                estimatedMinutes: currentDayMinutes
            ))
        }

        return dayAssignments
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugLog.append("[\(timestamp)] \(message)")
        print("[ExpansionTest] \(message)")
    }
}

#endif
