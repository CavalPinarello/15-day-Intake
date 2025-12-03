//
//  QuestionnaireView.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Watch-optimized questionnaire interface for 15-day intake journey
//  Works standalone without iPhone connection
//

import SwiftUI
import WatchKit

// Question mode - determines which questions to show
enum QuestionMode {
    case sleepLog      // Stanford Sleep Log questions only
    case assessment    // Day-specific assessment questions only
    case all           // Both sleep log and assessment (legacy)
}

struct QuestionnaireView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var themeManager: WatchThemeManager
    @ObservedObject private var convexService = WatchConvexService.shared

    // Question mode - determines what to show
    var mode: QuestionMode = .all

    // Local storage for offline capability
    @AppStorage("watchCurrentDay") private var localCurrentDay: Int = 1
    @AppStorage("watchCompletedDays") private var completedDaysData: Data = Data()

    @State private var questions: [WatchQuestion] = []
    @State private var currentQuestionIndex: Int = 0
    @State private var responses: [String: Any] = [:]
    @State private var isLoading = true
    @State private var showingQuestions = false
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var lastRefreshTime: Date = Date()
    // Track which questions the user has actually interacted with (not just default values)
    @State private var userInteractedQuestions: Set<String> = []

    private var theme: WatchColorTheme { WatchColorTheme.shared }

    // Use Convex state if authenticated, otherwise local state
    private var currentDay: Int {
        convexService.isAuthenticated ? convexService.currentDay : localCurrentDay
    }

    private var completedDays: [Int] {
        if convexService.isAuthenticated {
            return convexService.completedDays
        }
        return (try? JSONDecoder().decode([Int].self, from: completedDaysData)) ?? []
    }

    /// Check if this specific section is completed (not the whole day)
    private var isSectionCompleted: Bool {
        switch mode {
        case .sleepLog:
            return convexService.sleepLogCompleted
        case .assessment:
            return convexService.assessmentCompleted
        case .all:
            // Legacy mode - check if full day is done
            return completedDays.contains(currentDay)
        }
    }

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading...")
                    .tint(theme.primary)
                    .onAppear {
                        loadCurrentDay()
                    }
            } else if isSectionCompleted && !showingQuestions {
                completedView
            } else if questions.isEmpty {
                noQuestionsView
            } else {
                questionnaireContent
            }
        }
        .onAppear {
            // Refresh from Convex when view appears
            refreshFromConvex()
        }
    }

    private func refreshFromConvex() {
        // Avoid refreshing too frequently (min 2 seconds between refreshes)
        guard Date().timeIntervalSince(lastRefreshTime) > 2 else { return }
        lastRefreshTime = Date()

        Task {
            guard convexService.isAuthenticated else { return }
            do {
                let state = try await convexService.fetchJourneyState()
                await MainActor.run {
                    // Update local storage to match Convex
                    localCurrentDay = state.currentDay
                    if let encoded = try? JSONEncoder().encode(state.completedDays) {
                        completedDaysData = encoded
                    }
                    // Reset questionnaire state if day changed
                    if !showingQuestions {
                        questions = []
                        currentQuestionIndex = 0
                        responses = [:]
                    }
                }
                print("[Watch Questionnaire] Refreshed: Day \(state.currentDay), Completed: \(state.completedDays)")
            } catch {
                print("[Watch Questionnaire] Refresh failed: \(error.localizedDescription)")
            }
        }
    }

    private var questionnaireContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                VStack(spacing: 0) {
                    // Progress bar inline - very compact
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 3)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(theme.primary)
                                    .frame(width: max(0, (geometry.size.width - 40) * CGFloat(currentQuestionIndex + 1) / CGFloat(max(1, questions.count))), height: 3)
                            }

                        Text("\(currentQuestionIndex + 1)/\(questions.count)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .fixedSize()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 2)

                    if currentQuestionIndex < questions.count {
                        let question = questions[currentQuestionIndex]

                        // Question text - compact
                        Text(question.text)
                            .font(.system(size: 13, weight: .medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 8)
                            .padding(.top, 2)

                        // Answer input area - leave room for nav buttons (28pt)
                        questionInputView(for: question)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 32)
                    }

                    Spacer(minLength: 0)
                }

                // Navigation buttons - anchored to bottom corners
                if currentQuestionIndex < questions.count {
                    VStack {
                        Spacer()
                        HStack {
                            // Back button (left)
                            if currentQuestionIndex > 0 {
                                Button {
                                    currentQuestionIndex -= 1
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(theme.primary)
                                }
                                .frame(width: 36, height: 28)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            }

                            Spacer()

                            // Next/Done button (right)
                            Button {
                                if currentQuestionIndex == questions.count - 1 {
                                    completeQuestionnaire()
                                } else {
                                    currentQuestionIndex += 1
                                    // Sync progress to Convex for cross-device sync
                                    syncProgressToConvex()
                                }
                            } label: {
                                if currentQuestionIndex == questions.count - 1 {
                                    Text("Done")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.black)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(width: currentQuestionIndex == questions.count - 1 ? 50 : 36, height: 28)
                            .background(theme.primary)
                            .cornerRadius(8)
                            .disabled(!isCurrentQuestionAnswered())
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 2)
                    }
                }
            }
        }
    }

    private var completedView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(theme.success)

                // Show appropriate title based on mode
                Text(completionTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(completionSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // If only sleep log was completed, show reminder to complete assessment on iPhone
                if mode == .sleepLog && !convexService.assessmentCompleted {
                    Divider()
                        .padding(.vertical, 4)

                    HStack(spacing: 6) {
                        Image(systemName: "iphone")
                            .font(.system(size: 14))
                            .foregroundColor(theme.primary)
                        Text("Assessment")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(theme.primary)

                    Text("Complete on iPhone")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if mode == .sleepLog && convexService.assessmentCompleted {
                    // Both done - day complete!
                    Divider()
                        .padding(.vertical, 4)

                    if currentDay < 15 {
                        Text("Day \(currentDay) Complete!")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.success)

                        Text("See you tomorrow")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Journey Complete!")
                            .font(.caption)
                            .foregroundColor(theme.success)
                    }
                } else if mode == .assessment || mode == .all {
                    // Day fully complete or assessment done
                    if currentDay < 15 {
                        Divider()
                            .padding(.vertical, 4)

                        Text("See you tomorrow")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("Day \(currentDay + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.primary)
                    } else {
                        Divider()
                            .padding(.vertical, 4)

                        Text("Journey Complete!")
                            .font(.caption)
                            .foregroundColor(theme.success)
                    }
                }

                // Debug: Reset button only shown in debug mode
                if themeManager.debugMode {
                    Divider()
                        .padding(.vertical, 4)

                    Button("Reset & Start Over") {
                        resetAllProgress()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .font(.caption2)
                }
            }
            .padding()
        }
    }

    // Computed property for completion title
    private var completionTitle: String {
        switch mode {
        case .sleepLog:
            return "Sleep Log Complete!"
        case .assessment:
            return "Assessment Complete!"
        case .all:
            return "Day \(currentDay) Complete!"
        }
    }

    // Computed property for completion subtitle
    private var completionSubtitle: String {
        switch mode {
        case .sleepLog:
            return "Great job logging your sleep"
        case .assessment:
            return "Day \(currentDay) done!"
        case .all:
            return "Great job!"
        }
    }

    private func resetAllProgress() {
        // Force clear all local data
        localCurrentDay = 1
        completedDaysData = Data()
        questions = []
        currentQuestionIndex = 0
        responses = [:]
        showingQuestions = false
        isLoading = false

        // Clear UserDefaults directly as backup
        UserDefaults.standard.removeObject(forKey: "watchCurrentDay")
        UserDefaults.standard.removeObject(forKey: "watchCompletedDays")
        UserDefaults.standard.synchronize()

        WKInterfaceDevice.current().play(.success)

        // Sync reset to Convex in background
        Task {
            await syncResetToConvex()
        }

        // Also notify iPhone via WatchConnectivity
        watchConnectivity.resetJourneyProgress { _, _ in }
    }

    private func syncResetToConvex() async {
        guard convexService.isAuthenticated else {
            print("[Watch] Not authenticated - reset saved locally only")
            return
        }

        do {
            let result = try await convexService.resetProgress()
            print("[Watch] Reset synced to Convex, new day: \(result.newDay)")
        } catch {
            print("[Watch] Failed to sync reset to Convex: \(error.localizedDescription)")
        }
    }

    private var noQuestionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40))
                .foregroundColor(theme.primary)

            Text("Day \(currentDay)")
                .font(.headline)

            Text("Ready to start")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Begin") {
                loadQuestions()
                showingQuestions = true
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
        }
        .padding()
    }

    @ViewBuilder
    private func questionInputView(for question: WatchQuestion) -> some View {
        switch question.type {
        case .scale:
            // Scale 1-10 with large value display and easy slider
            VStack(spacing: 6) {
                Text(String(format: "%.0f", responses[question.id] as? Double ?? 5.0))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primary)

                // Scale labels
                HStack {
                    Text("1")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("10")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)

                Slider(value: Binding(
                    get: { responses[question.id] as? Double ?? 5.0 },
                    set: { newValue in
                        responses[question.id] = newValue
                        markQuestionInteracted(question.id)
                    }
                ), in: 1...10, step: 1)
                .tint(theme.primary)
            }
            .padding(.horizontal, 4)

        case .radio:
            if let options = question.options {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                responses[question.id] = option
                                WKInterfaceDevice.current().play(.click)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: responses[question.id] as? String == option ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(responses[question.id] as? String == option ? theme.primary : .secondary)
                                    Text(option)
                                        .font(.system(size: 14))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(responses[question.id] as? String == option ? theme.primary.opacity(0.15) : Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

        case .checkbox:
            if let options = question.options {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                toggleCheckboxOption(question.id, option: option)
                                WKInterfaceDevice.current().play(.click)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: isOptionSelected(question.id, option: option) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 18))
                                        .foregroundColor(isOptionSelected(question.id, option: option) ? theme.primary : .secondary)
                                    Text(option)
                                        .font(.system(size: 14))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isOptionSelected(question.id, option: option) ? theme.primary.opacity(0.15) : Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

        case .text:
            TextField("Answer", text: Binding(
                get: { responses[question.id] as? String ?? "" },
                set: { responses[question.id] = $0 }
            ))
            .textFieldStyle(.automatic)
            .font(.system(size: 16))

        case .time:
            WatchTimePickerView(
                selectedTime: Binding(
                    get: {
                        if let dateValue = responses[question.id] as? Date {
                            return dateValue
                        }
                        return Date()
                    },
                    set: { newValue in
                        responses[question.id] = newValue
                        markQuestionInteracted(question.id)
                    }
                ),
                theme: theme,
                questionId: question.id,
                previousBedtime: getPreviousBedtime(for: question.id)
            )

        case .yesNo:
            // Large, easy-to-tap Yes/No buttons
            HStack(spacing: 16) {
                Button {
                    responses[question.id] = "Yes"
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("Yes")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(responses[question.id] as? String == "Yes" ? theme.primary : Color.gray.opacity(0.2))
                        )
                        .foregroundColor(responses[question.id] as? String == "Yes" ? .black : .primary)
                }
                .buttonStyle(.plain)

                Button {
                    responses[question.id] = "No"
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("No")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(responses[question.id] as? String == "No" ? theme.primary : Color.gray.opacity(0.2))
                        )
                        .foregroundColor(responses[question.id] as? String == "No" ? .black : .primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

        case .number:
            // Number input with progress bar, Digital Crown, and +/- buttons
            WatchNumberInputView(
                value: Binding(
                    get: { Int(responses[question.id] as? Double ?? 0) },
                    set: { newValue in
                        responses[question.id] = Double(newValue)
                        markQuestionInteracted(question.id)
                    }
                ),
                minValue: 0,
                maxValue: 20,
                theme: theme
            )

        case .singleSelect:
            // Same as radio - single selection from options
            if let options = question.options {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                responses[question.id] = option
                                WKInterfaceDevice.current().play(.click)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: responses[question.id] as? String == option ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(responses[question.id] as? String == option ? theme.primary : .secondary)
                                    Text(option)
                                        .font(.system(size: 14))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(responses[question.id] as? String == option ? theme.primary.opacity(0.15) : Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

        case .multiSelect:
            // Same as checkbox - multiple selection from options
            if let options = question.options {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                toggleCheckboxOption(question.id, option: option)
                                WKInterfaceDevice.current().play(.click)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: isOptionSelected(question.id, option: option) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 18))
                                        .foregroundColor(isOptionSelected(question.id, option: option) ? theme.primary : .secondary)
                                    Text(option)
                                        .font(.system(size: 14))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isOptionSelected(question.id, option: option) ? theme.primary.opacity(0.15) : Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

        case .info:
            // Information display - no input required
            // Mark as interacted immediately since it's just informational
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.green)

                Text(question.text)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .onAppear {
                markQuestionInteracted(question.id)
                responses[question.id] = "acknowledged"
            }

        case .year:
            // Year picker for date of birth
            WatchYearPickerView(
                selectedYear: Binding(
                    get: {
                        if let yearValue = responses[question.id] as? Int {
                            return yearValue
                        }
                        return 1990  // Default year
                    },
                    set: { newValue in
                        responses[question.id] = newValue
                        markQuestionInteracted(question.id)
                    }
                ),
                theme: theme
            )
        }
    }

    private func loadCurrentDay() {
        // Try to sync with Convex first
        Task {
            await syncWithConvex()
            await MainActor.run {
                loadQuestions()
                isLoading = false
            }
        }
    }

    private func syncWithConvex() async {
        // If not authenticated, try to auto-login with saved credentials
        if !convexService.isAuthenticated {
            // Check if we have saved credentials from previous session
            if let savedUsername = UserDefaults.standard.string(forKey: "lastUsername") {
                // For now, just mark as not authenticated - user needs to login via iPhone
                print("[Watch] Not authenticated - user should login via iPhone first")
            }
            return
        }

        do {
            let state = try await convexService.fetchJourneyState()
            await MainActor.run {
                // Update local storage to match Convex
                localCurrentDay = state.currentDay
                if let encoded = try? JSONEncoder().encode(state.completedDays) {
                    completedDaysData = encoded
                }
            }
            print("[Watch] Synced with Convex: Day \(state.currentDay), Completed: \(state.completedDays)")
        } catch {
            print("[Watch] Failed to sync with Convex: \(error.localizedDescription)")
            // Continue with local data
        }
    }

    private func loadQuestions() {
        // Reset state
        currentQuestionIndex = 0
        responses = [:]
        userInteractedQuestions = []

        // For Sleep Log, ALWAYS use the local SharedQuestionBank
        // (Convex sleep_diary_questions table may be empty or have wrong data)
        if mode == .sleepLog {
            questions = WatchQuestionBank.getSleepLogQuestions()
            print("[Watch] Loaded \(questions.count) Sleep Log questions from SharedQuestionBank")
            loadSavedProgress()
            return
        }

        // For Assessment, try Convex first but fall back to local questions
        Task {
            do {
                print("[Watch] Fetching questions from Convex for Day \(currentDay), mode: \(mode)...")
                let section = mode == .sleepLog ? "sleepLog" : (mode == .assessment ? "assessment" : "all")
                let questionsResponse = try await convexService.getQuestionsForUserDay(dayNumber: currentDay, section: section)

                // Convert Convex questions to WatchQuestion type
                var convertedQuestions: [WatchQuestion] = []

                if mode == .sleepLog || mode == .all {
                    convertedQuestions.append(contentsOf: questionsResponse.sleepLog.map { convertConvexToWatchQuestion($0) })
                }
                if mode == .assessment || mode == .all {
                    convertedQuestions.append(contentsOf: questionsResponse.assessment.map { convertConvexToWatchQuestion($0) })
                }

                // If Convex returned empty questions, fall back to local
                if convertedQuestions.isEmpty {
                    print("[Watch] Convex returned empty questions, using local fallback")
                    await MainActor.run {
                        questions = WatchQuestionBank.getQuestions(for: currentDay, mode: mode)
                        print("[Watch] Fallback: Using local questions (\(questions.count) questions)")
                        loadSavedProgress()
                    }
                    return
                }

                await MainActor.run {
                    questions = convertedQuestions
                    print("[Watch] Loaded \(questions.count) questions from Convex (sleep: \(questionsResponse.metadata.sleepLogCount), assessment: \(questionsResponse.metadata.assessmentCount))")
                    print("[Watch] Triggered gateways: \(questionsResponse.metadata.triggeredGateways.joined(separator: ", "))")

                    // Load saved progress from Convex for cross-device sync
                    loadSavedProgress()
                }
            } catch {
                print("[Watch] Error fetching questions from Convex: \(error.localizedDescription)")
                // Fallback to local questions if Convex fails
                await MainActor.run {
                    questions = WatchQuestionBank.getQuestions(for: currentDay, mode: mode)
                    print("[Watch] Fallback: Using local questions (\(questions.count) questions)")
                    loadSavedProgress()
                }
            }
        }
    }

    /// Convert a WatchConvexQuestion to WatchQuestion
    private func convertConvexToWatchQuestion(_ cq: WatchConvexQuestion) -> WatchQuestion {
        // Map Convex question type to WatchQuestionType
        let questionType: WatchQuestionType
        switch cq.type {
        case "time": questionType = .time
        case "scale": questionType = .scale
        case "number": questionType = .number
        case "yesNo": questionType = .yesNo
        case "singleSelect": questionType = .singleSelect
        case "multiSelect": questionType = .multiSelect
        case "text": questionType = .text
        case "info": questionType = .info
        case "year": questionType = .year
        default: questionType = .text
        }

        return WatchQuestion(
            id: cq.id,
            text: cq.text,
            type: questionType,
            options: cq.options,
            helpText: cq.helpText
        )
    }

    /// Load saved progress and responses from Convex for cross-device sync
    /// Note: This is best-effort - failures are logged but don't block the user
    private func loadSavedProgress() {
        guard convexService.isAuthenticated else { return }

        Task {
            let section = mode == .sleepLog ? "sleepLog" : "assessment"

            // First, load saved responses so we can validate progress against them
            var loadedResponseCount = 0
            do {
                let savedResponses = try await convexService.getSavedResponses(dayNumber: currentDay)
                await MainActor.run {
                    for (questionId, value) in savedResponses {
                        if let str = value.stringValue {
                            responses[questionId] = str
                        } else if let num = value.numberValue {
                            responses[questionId] = num
                        } else if let arr = value.arrayValue {
                            responses[questionId] = arr
                        }
                        // Mark loaded responses as interacted (user answered on another device)
                        userInteractedQuestions.insert(questionId)
                    }
                    loadedResponseCount = savedResponses.count
                    if !savedResponses.isEmpty {
                        print("[Watch] Loaded \(savedResponses.count) saved responses (marked as interacted)")
                    }
                }
            } catch {
                print("[Watch] Could not load saved responses (may not exist yet): \(error.localizedDescription)")
            }

            // Load question progress (which question user was on)
            // Wrapped in separate do-catch to not block response loading
            do {
                if let progress = try await convexService.getQuestionProgress(dayNumber: currentDay, section: section) {
                    await MainActor.run {
                        // Only resume if:
                        // 1. Session is not marked as completed
                        // 2. The saved question index is valid for current question set
                        // 3. We have at least some saved responses to support the progress
                        //    (prevents jumping to a stale position from old sessions)
                        let isValidProgress = !progress.completed &&
                                              progress.currentQuestionIndex < questions.count &&
                                              progress.currentQuestionIndex > 0 &&
                                              loadedResponseCount > 0

                        if isValidProgress {
                            currentQuestionIndex = progress.currentQuestionIndex
                            print("[Watch] Resuming \(section) at question \(currentQuestionIndex + 1)/\(questions.count) (last device: \(progress.lastDevice))")
                        } else if progress.currentQuestionIndex > 0 {
                            // Log why we're not resuming
                            print("[Watch] Ignoring stale progress for \(section): index=\(progress.currentQuestionIndex), completed=\(progress.completed), responseCount=\(loadedResponseCount)")
                        }
                    }
                }
            } catch {
                print("[Watch] Could not load question progress (may not exist yet): \(error.localizedDescription)")
            }
        }
    }

    /// Sync question progress to Convex after each question
    private func syncProgressToConvex() {
        guard convexService.isAuthenticated else { return }

        let section = mode == .sleepLog ? "sleepLog" : "assessment"

        Task {
            do {
                try await convexService.updateQuestionProgress(
                    dayNumber: currentDay,
                    section: section,
                    questionIndex: currentQuestionIndex,
                    totalQuestions: questions.count
                )
                print("[Watch] Synced progress: \(section) question \(currentQuestionIndex + 1)/\(questions.count)")
            } catch {
                print("[Watch] Failed to sync progress: \(error)")
            }
        }
    }

    private func isCurrentQuestionAnswered() -> Bool {
        guard currentQuestionIndex < questions.count else { return false }
        let question = questions[currentQuestionIndex]

        // For time, scale, and number questions:
        // Check if user has actually interacted with them (not just default values)
        // This prevents users from skipping through questions without answering
        if question.type == .time || question.type == .scale || question.type == .number {
            return userInteractedQuestions.contains(question.id)
        }

        return responses[question.id] != nil
    }

    /// Mark the current question as interacted by the user
    private func markQuestionInteracted(_ questionId: String) {
        userInteractedQuestions.insert(questionId)
    }

    /// Returns the previously answered bedtime to help set smart defaults for subsequent time questions
    private func getPreviousBedtime(for questionId: String) -> Date? {
        // For Stanford Sleep Diary, chain the time dependencies
        switch questionId {
        case "SD_LIGHTS_OUT":
            // Lights out is typically same as or shortly after getting into bed
            return responses["SD_GOT_INTO_BED"] as? Date
        case "SL_ASLEEP_TIME":
            // Fall asleep time is typically after lights out
            return responses["SD_LIGHTS_OUT"] as? Date ?? responses["SD_GOT_INTO_BED"] as? Date
        case "SL_WAKE_TIME":
            // Wake time is typically 7-8 hours after asleep time
            return responses["SL_ASLEEP_TIME"] as? Date ?? responses["SD_LIGHTS_OUT"] as? Date
        case "SD_OUT_OF_BED":
            // Out of bed is typically same or shortly after wake time
            return responses["SL_WAKE_TIME"] as? Date
        default:
            return nil
        }
    }

    private func completeQuestionnaire() {
        let dayToComplete = currentDay

        // Mark day as completed locally first (for offline support)
        var days = completedDays
        if !days.contains(dayToComplete) {
            days.append(dayToComplete)
            if let encoded = try? JSONEncoder().encode(days) {
                completedDaysData = encoded
            }
        }

        // Show completion immediately
        showingQuestions = false
        questions = []

        // Haptic feedback
        WKInterfaceDevice.current().play(.success)

        // Sync to Convex in background
        Task {
            await syncCompletionToConvex(dayNumber: dayToComplete)
        }

        // Also try to sync to iPhone via WatchConnectivity
        watchConnectivity.sendResponses(responses, forDay: dayToComplete) { _ in }
    }

    private func syncCompletionToConvex(dayNumber: Int) async {
        guard convexService.isAuthenticated else {
            print("[Watch] Not authenticated - completion saved locally only")
            return
        }

        do {
            // First save all responses
            var convexResponses: [[String: Any]] = []
            for (questionId, value) in responses {
                var response: [String: Any] = ["questionId": questionId]

                if let stringValue = value as? String {
                    response["responseValue"] = stringValue
                } else if let intValue = value as? Int {
                    // Year values (e.g., birth year) - store as string for date of birth
                    response["responseValue"] = String(intValue)
                } else if let numberValue = value as? Double {
                    response["responseNumber"] = numberValue
                } else if let dateValue = value as? Date {
                    // Convert Date to time string
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    response["responseValue"] = formatter.string(from: dateValue)
                } else if let arrayValue = value as? [String] {
                    response["responseArray"] = arrayValue
                }

                convexResponses.append(response)
            }

            if !convexResponses.isEmpty {
                _ = try await convexService.saveResponses(dayNumber: dayNumber, responses: convexResponses)
                print("[Watch] Saved \(convexResponses.count) responses to Convex")
            }

            // Mark the appropriate section as complete based on mode
            let sectionName: String
            switch mode {
            case .sleepLog:
                sectionName = "sleepLog"
            case .assessment:
                sectionName = "assessment"
            case .all:
                // Legacy mode: mark both sections as complete
                let sleepResult = try await convexService.completeSection(dayNumber: dayNumber, section: "sleepLog")
                print("[Watch] Sleep log marked complete: \(sleepResult.sleepLogCompleted)")
                let assessResult = try await convexService.completeSection(dayNumber: dayNumber, section: "assessment")
                print("[Watch] Assessment marked complete: \(assessResult.assessmentCompleted)")
                if assessResult.dayFullyCompleted {
                    print("[Watch] Day \(dayNumber) fully completed, advancing to day \(assessResult.currentDay)")
                    await MainActor.run {
                        localCurrentDay = assessResult.currentDay
                    }
                }
                return
            }

            // Complete the specific section
            let result = try await convexService.completeSection(dayNumber: dayNumber, section: sectionName)
            print("[Watch] Section '\(sectionName)' marked complete for day \(dayNumber)")
            print("[Watch] sleepLogCompleted: \(result.sleepLogCompleted), assessmentCompleted: \(result.assessmentCompleted)")

            if result.dayFullyCompleted {
                print("[Watch] Day \(dayNumber) fully completed, advancing to day \(result.currentDay)")
                await MainActor.run {
                    localCurrentDay = result.currentDay
                }
            }
        } catch {
            print("[Watch] Failed to sync completion to Convex: \(error.localizedDescription)")
            // Local state is already updated, so user experience is preserved
        }
    }

    private func toggleCheckboxOption(_ questionId: String, option: String) {
        var selectedOptions = responses[questionId] as? [String] ?? []
        if selectedOptions.contains(option) {
            selectedOptions.removeAll { $0 == option }
        } else {
            selectedOptions.append(option)
        }
        responses[questionId] = selectedOptions
    }

    private func isOptionSelected(_ questionId: String, option: String) -> Bool {
        let selectedOptions = responses[questionId] as? [String] ?? []
        return selectedOptions.contains(option)
    }
}

// MARK: - Watch Question Model

struct WatchQuestion {
    let id: String
    let text: String
    let type: WatchQuestionType
    let options: [String]?
    let helpText: String?

    init(id: String, text: String, type: WatchQuestionType, options: [String]? = nil, helpText: String? = nil) {
        self.id = id
        self.text = text
        self.type = type
        self.options = options
        self.helpText = helpText
    }
}

enum WatchQuestionType: String, CaseIterable {
    case text
    case radio
    case checkbox
    case scale
    case time
    case yesNo
    case number
    case singleSelect  // Same as radio, but named consistently with Convex
    case multiSelect   // Same as checkbox, but named consistently with Convex
    case info          // Display-only information, no input required
    case year          // Year picker for date of birth
}

// MARK: - Watch Question Bank (Uses Shared Question Definitions)

struct WatchQuestionBank {

    // MARK: - Convert SharedQuestion to WatchQuestion

    /// Converts a SharedQuestion from the shared question bank to a WatchQuestion
    private static func convertToWatchQuestion(_ shared: SharedQuestion) -> WatchQuestion {
        let watchType: WatchQuestionType
        switch shared.type {
        case .text:
            watchType = .text
        case .number, .numberScroll, .minutesScroll:
            watchType = .number
        case .time:
            watchType = .time
        case .date:
            watchType = .year  // Date of birth uses year picker
        case .scale:
            watchType = .scale
        case .yesNo, .yesNoDontKnow:
            watchType = .yesNo
        case .singleSelect:
            watchType = .radio
        case .multiSelect:
            watchType = .checkbox
        case .info:
            watchType = .text  // Display as text on watch
        }

        return WatchQuestion(
            id: shared.id,
            text: shared.text,
            type: watchType,
            options: shared.options
        )
    }

    /// Convert an array of SharedQuestions to WatchQuestions
    private static func convertToWatchQuestions(_ sharedQuestions: [SharedQuestion]) -> [WatchQuestion] {
        return sharedQuestions.map { convertToWatchQuestion($0) }
    }

    // MARK: - Get Sleep Log Questions Only
    /// Returns Stanford Sleep Log questions from the shared question bank
    static func getSleepLogQuestions() -> [WatchQuestion] {
        return convertToWatchQuestions(SharedQuestionBank.stanfordSleepLog)
    }

    // MARK: - Get Assessment Questions Only (day-specific)
    /// Returns day-specific assessment questions from the shared question bank
    static func getAssessmentQuestionsForDay(_ day: Int) -> [WatchQuestion] {
        let sharedQuestions = SharedQuestionBank.getAssessmentQuestionsForDay(day)
        return convertToWatchQuestions(sharedQuestions)
    }

    // MARK: - Get All Questions (legacy - combines both)
    static func getQuestionsForDay(_ day: Int) -> [WatchQuestion] {
        let sharedQuestions = SharedQuestionBank.getQuestionsForDay(day)
        return convertToWatchQuestions(sharedQuestions)
    }

    // MARK: - Get Questions by Mode
    static func getQuestions(for day: Int, mode: QuestionMode) -> [WatchQuestion] {
        switch mode {
        case .sleepLog:
            return getSleepLogQuestions()
        case .assessment:
            return getAssessmentQuestionsForDay(day)
        case .all:
            return getQuestionsForDay(day)
        }
    }
}

// MARK: - Watch Number Input View (with progress bar + Digital Crown)

struct WatchNumberInputView: View {
    @Binding var value: Int
    let minValue: Int
    let maxValue: Int
    let theme: WatchColorTheme

    // Digital Crown state
    @State private var crownValue: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar showing value position
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)

                    // Filled portion based on value
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.primary)
                        .frame(
                            width: geo.size.width * CGFloat(value - minValue) / CGFloat(max(1, maxValue - minValue)),
                            height: 6
                        )
                        .animation(.easeInOut(duration: 0.15), value: value)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 8)

            // Large number display
            Text("\(value)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(theme.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.1), value: value)

            // +/- stepper buttons
            HStack(spacing: 20) {
                Button {
                    if value > minValue {
                        value -= 1
                        crownValue = Double(value)
                        WKInterfaceDevice.current().play(.click)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(value > minValue ? theme.primary : theme.primary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .disabled(value <= minValue)

                Button {
                    if value < maxValue {
                        value += 1
                        crownValue = Double(value)
                        WKInterfaceDevice.current().play(.click)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(value < maxValue ? theme.primary : theme.primary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .disabled(value >= maxValue)
            }

            // Hint text
            Text("Rotate Crown or tap ±")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .focusable(true)
        .digitalCrownRotation(
            $crownValue,
            from: Double(minValue),
            through: Double(maxValue),
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            let newInt = Int(newValue.rounded())
            if newInt != value && newInt >= minValue && newInt <= maxValue {
                value = newInt
            }
        }
        .onAppear {
            crownValue = Double(value)
        }
    }
}

// MARK: - Watch Time Picker View

struct WatchTimePickerView: View {
    @Binding var selectedTime: Date
    let theme: WatchColorTheme
    var questionId: String = ""
    var previousBedtime: Date? = nil  // Used to calculate smart defaults for wake/asleep times

    @State private var hour12: Int = 10      // 1-12 format
    @State private var minute: Int = 0
    @State private var isPM: Bool = true     // AM/PM toggle
    @State private var hasInitialized: Bool = false

    private let hours12 = Array(1...12)
    private let minutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]

    // Smart defaults based on question and previous answers (Stanford Sleep Diary)
    private var smartDefault: (hour24: Int, minute: Int) {
        let calendar = Calendar.current

        switch questionId {
        // Q3: Bedtime Routine
        case "SD_GOT_INTO_BED":
            return (22, 0)   // 10:00 PM - when you got into bed

        case "SD_LIGHTS_OUT":
            // Typically 5-15 min after getting into bed
            if let gotIntoBed = previousBedtime {
                let adjustedTime = calendar.date(byAdding: .minute, value: 10, to: gotIntoBed) ?? gotIntoBed
                let components = calendar.dateComponents([.hour, .minute], from: adjustedTime)
                return (components.hour ?? 22, components.minute ?? 15)
            }
            return (22, 15)  // 10:15 PM

        // Q4: Sleep Onset
        case "SL_ASLEEP_TIME":
            // Typically 10-20 min after lights out
            if let lightsOut = previousBedtime {
                let adjustedTime = calendar.date(byAdding: .minute, value: 15, to: lightsOut) ?? lightsOut
                let components = calendar.dateComponents([.hour, .minute], from: adjustedTime)
                return (components.hour ?? 22, components.minute ?? 30)
            }
            return (22, 30)  // 10:30 PM

        // Q6: Morning Wake Time
        case "SL_WAKE_TIME":
            // Typically ~7-8 hours after asleep time
            if let asleepTime = previousBedtime {
                let adjustedTime = calendar.date(byAdding: .hour, value: 8, to: asleepTime) ?? asleepTime
                let components = calendar.dateComponents([.hour, .minute], from: adjustedTime)
                return (components.hour ?? 6, components.minute ?? 30)
            }
            return (6, 30)   // 6:30 AM

        case "SD_OUT_OF_BED":
            // Typically 5-15 min after final wake
            if let wakeTime = previousBedtime {
                let adjustedTime = calendar.date(byAdding: .minute, value: 10, to: wakeTime) ?? wakeTime
                let components = calendar.dateComponents([.hour, .minute], from: adjustedTime)
                return (components.hour ?? 6, components.minute ?? 45)
            }
            return (6, 45)   // 6:45 AM

        // Legacy IDs (keep for backward compatibility)
        case "SL_BEDTIME":
            return (22, 0)   // 10:00 PM

        default:
            return (22, 0)   // Default to 10 PM for sleep-related
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            // 12-hour picker with AM/PM
            HStack(spacing: 2) {
                // Hour picker (1-12)
                Picker("Hour", selection: $hour12) {
                    ForEach(hours12, id: \.self) { h in
                        Text("\(h)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 50, height: 70)
                .clipped()

                Text(":")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.primary)

                // Minute picker
                Picker("Minute", selection: $minute) {
                    ForEach(minutes, id: \.self) { m in
                        Text(String(format: "%02d", m))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 50, height: 70)
                .clipped()

                // AM/PM picker
                Picker("Period", selection: $isPM) {
                    Text("AM")
                        .font(.system(size: 16, weight: .semibold))
                        .tag(false)
                    Text("PM")
                        .font(.system(size: 16, weight: .semibold))
                        .tag(true)
                }
                .pickerStyle(.wheel)
                .frame(width: 44, height: 70)
                .clipped()
            }
        }
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true

            // Set smart default based on question
            let (defaultHour24, defaultMinute) = smartDefault

            // Convert 24h to 12h format
            if defaultHour24 == 0 {
                hour12 = 12
                isPM = false
            } else if defaultHour24 == 12 {
                hour12 = 12
                isPM = true
            } else if defaultHour24 > 12 {
                hour12 = defaultHour24 - 12
                isPM = true
            } else {
                hour12 = defaultHour24
                isPM = false
            }
            minute = defaultMinute

            // Apply the default immediately
            updateSelectedTime()
        }
        .onChange(of: hour12) { _, _ in
            updateSelectedTime()
            WKInterfaceDevice.current().play(.click)
        }
        .onChange(of: minute) { _, _ in
            updateSelectedTime()
            WKInterfaceDevice.current().play(.click)
        }
        .onChange(of: isPM) { _, _ in
            updateSelectedTime()
            WKInterfaceDevice.current().play(.click)
        }
    }

    private func updateSelectedTime() {
        // Convert 12h to 24h
        var hour24: Int
        if hour12 == 12 {
            hour24 = isPM ? 12 : 0
        } else {
            hour24 = isPM ? hour12 + 12 : hour12
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour24
        components.minute = minute
        if let newDate = Calendar.current.date(from: components) {
            selectedTime = newDate
        }
    }
}

// MARK: - Watch Year Picker View (for Date of Birth)

struct WatchYearPickerView: View {
    @Binding var selectedYear: Int
    let theme: WatchColorTheme

    @State private var hasInitialized: Bool = false

    // Years from 1920 to current year
    private var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((1920...currentYear).reversed())
    }

    var body: some View {
        VStack(spacing: 8) {
            // Year display with scroll wheel
            Picker("Year", selection: $selectedYear) {
                ForEach(years, id: \.self) { year in
                    Text("\(year)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 80)

            // Age indicator
            let currentYear = Calendar.current.component(.year, from: Date())
            let age = currentYear - selectedYear
            Text("Age: \(age)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.primary)
        }
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            // Default to 1990 if not set (age ~34)
            if selectedYear == 0 {
                selectedYear = 1990
            }
        }
        .onChange(of: selectedYear) { _, _ in
            WKInterfaceDevice.current().play(.click)
        }
    }
}

// MARK: - Color Extension for Watch

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

#Preview {
    QuestionnaireView()
        .environmentObject(WatchConnectivityManager())
        .environmentObject(WatchThemeManager.shared)
}
