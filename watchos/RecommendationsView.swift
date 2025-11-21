//
//  RecommendationsView.swift
//  Sleep 360 Platform - watchOS
//
//  Display physician recommendations on Apple Watch post-intake
//

import SwiftUI
import WatchKit

struct RecommendationsView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @State private var recommendations: [PhysicianRecommendation] = []
    @State private var isLoading = true
    @State private var selectedRecommendation: PhysicianRecommendation?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading recommendations...")
                        .onAppear {
                            loadRecommendations()
                        }
                } else if recommendations.isEmpty {
                    emptyStateView
                } else {
                    recommendationsList
                }
            }
            .navigationTitle("Recommendations")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var emptyStateView: View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No Recommendations Yet")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Complete your 15-day intake to receive personalized recommendations from your physician.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var recommendationsList: View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(recommendations) { recommendation in
                    RecommendationCard(recommendation: recommendation)
                        .onTapGesture {
                            selectedRecommendation = recommendation
                        }
                }
            }
            .padding()
        }
        .sheet(item: $selectedRecommendation) { recommendation in
            RecommendationDetailView(recommendation: recommendation)
        }
    }
    
    private func loadRecommendations() {
        // Request recommendations from iPhone/Convex
        watchConnectivity.requestRecommendations { recommendationsList in
            DispatchQueue.main.async {
                self.recommendations = recommendationsList
                self.isLoading = false
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: PhysicianRecommendation
    @State private var isCompleted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForCategory(recommendation.category))
                    .foregroundColor(colorForCategory(recommendation.category))
                
                Text(recommendation.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Text(recommendation.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            if let schedule = recommendation.schedule {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(schedule)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text(recommendation.category.rawValue.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(colorForCategory(recommendation.category).opacity(0.2))
                    .foregroundColor(colorForCategory(recommendation.category))
                    .cornerRadius(8)
                
                Spacer()
                
                Button(action: {
                    toggleCompletion()
                }) {
                    Text(isCompleted ? "Completed" : "Mark Done")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            isCompleted = recommendation.isCompleted
        }
    }
    
    private func iconForCategory(_ category: RecommendationCategory) -> String {
        switch category {
        case .sleep:
            return "bed.double.fill"
        case .exercise:
            return "figure.walk"
        case .nutrition:
            return "leaf.fill"
        case .stress:
            return "brain.head.profile"
        case .environment:
            return "house.fill"
        case .medication:
            return "pills.fill"
        }
    }
    
    private func colorForCategory(_ category: RecommendationCategory) -> Color {
        switch category {
        case .sleep:
            return .blue
        case .exercise:
            return .green
        case .nutrition:
            return .orange
        case .stress:
            return .purple
        case .environment:
            return .teal
        case .medication:
            return .red
        }
    }
    
    private func toggleCompletion() {
        isCompleted.toggle()
        // Send completion status to Convex via WatchConnectivity
        // Implementation would depend on your data sync strategy
    }
}

struct RecommendationDetailView: View {
    let recommendation: PhysicianRecommendation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(recommendation.title)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                
                if let details = recommendation.details {
                    Text("Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(details)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if let instructions = recommendation.instructions {
                    Text("Instructions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(instructions)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if let schedule = recommendation.schedule {
                    Text("Schedule")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(schedule)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarHidden(true)
    }
}

// Models for physician recommendations
struct PhysicianRecommendation: Identifiable, Codable {
    let id: String
    let title: String
    let summary: String
    let details: String?
    let instructions: String?
    let category: RecommendationCategory
    let schedule: String?
    let isCompleted: Bool
    let createdAt: Date
    let priority: Priority
    
    enum Priority: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
    }
}

enum RecommendationCategory: String, CaseIterable, Codable {
    case sleep = "sleep"
    case exercise = "exercise"
    case nutrition = "nutrition"
    case stress = "stress"
    case environment = "environment"
    case medication = "medication"
}