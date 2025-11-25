//
//  QuestionnaireView.swift
//  Sleep 360 Platform - watchOS
//
//  Watch-optimized questionnaire interface for 15-day intake journey
//

import SwiftUI
import WatchKit

struct QuestionnaireView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @State private var currentDay: Int = 1
    @State private var questions: [Question] = []
    @State private var currentQuestionIndex: Int = 0
    @State private var responses: [String: Any] = [:]
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading...")
                        .onAppear {
                            loadCurrentDay()
                        }
                } else if questions.isEmpty {
                    completedView
                } else {
                    questionnaireContent
                }
            }
            .navigationTitle("Day \(currentDay)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var questionnaireContent: View {
        VStack(spacing: 12) {
            // Progress indicator
            ProgressView(value: Double(currentQuestionIndex), total: Double(questions.count))
                .progressViewStyle(LinearProgressViewStyle())
                .padding(.horizontal)
            
            Text("\(currentQuestionIndex + 1) of \(questions.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Current question
            if currentQuestionIndex < questions.count {
                let question = questions[currentQuestionIndex]
                
                ScrollView {
                    VStack(spacing: 16) {
                        Text(question.text)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        questionInputView(for: question)
                    }
                }
                
                // Navigation buttons
                HStack {
                    if currentQuestionIndex > 0 {
                        Button("Back") {
                            currentQuestionIndex -= 1
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    Button(currentQuestionIndex == questions.count - 1 ? "Complete" : "Next") {
                        if currentQuestionIndex == questions.count - 1 {
                            completeQuestionnaire()
                        } else {
                            currentQuestionIndex += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isCurrentQuestionAnswered())
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private var completedView: View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("Day \(currentDay) Complete!")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Great job! Your responses have been saved.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Next Day") {
                advanceToNextDay()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    @ViewBuilder
    private func questionInputView(for question: Question) -> some View {
        switch question.type {
        case .scale:
            VStack {
                Text("Rate from 1-10")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: Binding(
                    get: { responses[question.id] as? Double ?? 5.0 },
                    set: { responses[question.id] = $0 }
                ), in: 1...10, step: 1)
                
                Text("\(Int(responses[question.id] as? Double ?? 5.0))")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
        case .radio:
            if let options = question.options {
                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            responses[question.id] = option
                        }) {
                            HStack {
                                Image(systemName: responses[question.id] as? String == option ? "checkmark.circle.fill" : "circle")
                                Text(option)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(responses[question.id] as? String == option ? .accentColor : .primary)
                    }
                }
            }
            
        case .checkbox:
            if let options = question.options {
                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            toggleCheckboxOption(option)
                        }) {
                            HStack {
                                Image(systemName: isOptionSelected(option) ? "checkmark.square.fill" : "square")
                                Text(option)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(isOptionSelected(option) ? .accentColor : .primary)
                    }
                }
            }
            
        case .text:
            TextField("Your answer", text: Binding(
                get: { responses[question.id] as? String ?? "" },
                set: { responses[question.id] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
        default:
            Text("Question type not supported on Watch")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
    }
    
    private func loadCurrentDay() {
        // Request current day and questions from iPhone via WatchConnectivity
        watchConnectivity.requestCurrentDayQuestions { day, questionsList in
            DispatchQueue.main.async {
                self.currentDay = day
                self.questions = questionsList
                self.isLoading = false
            }
        }
    }
    
    private func isCurrentQuestionAnswered() -> Bool {
        guard currentQuestionIndex < questions.count else { return false }
        let question = questions[currentQuestionIndex]
        return responses[question.id] != nil
    }
    
    private func completeQuestionnaire() {
        // Send responses to iPhone and Convex
        watchConnectivity.sendResponses(responses, forDay: currentDay) { success in
            DispatchQueue.main.async {
                if success {
                    // Clear questions to show completion view
                    self.questions = []
                }
            }
        }
    }
    
    private func advanceToNextDay() {
        watchConnectivity.advanceDay { newDay in
            DispatchQueue.main.async {
                self.currentDay = newDay
                self.responses = [:]
                self.currentQuestionIndex = 0
                self.loadCurrentDay()
            }
        }
    }
    
    private func toggleCheckboxOption(_ option: String) {
        var selectedOptions = responses[questions[currentQuestionIndex].id] as? [String] ?? []
        if selectedOptions.contains(option) {
            selectedOptions.removeAll { $0 == option }
        } else {
            selectedOptions.append(option)
        }
        responses[questions[currentQuestionIndex].id] = selectedOptions
    }
    
    private func isOptionSelected(_ option: String) -> Bool {
        let selectedOptions = responses[questions[currentQuestionIndex].id] as? [String] ?? []
        return selectedOptions.contains(option)
    }
}

// Question model for watch app
struct Question {
    let id: String
    let text: String
    let type: QuestionType
    let options: [String]?
    
    enum QuestionType: String, CaseIterable {
        case text
        case radio  
        case checkbox
        case scale
        case time
        case date
        
        // Note: Some question types like textarea, number, select are handled by iPhone app
        // Watch focuses on quick interaction types
    }
}