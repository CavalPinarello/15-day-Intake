//
//  Sleep360_Watch_AppApp.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Main app entry point for Apple Watch
//

import SwiftUI
import WatchKit
import WatchConnectivity

@main
struct Sleep360_Watch_App: App {
    @StateObject private var watchConnectivity = WatchConnectivityManager()
    @StateObject private var healthManager = HealthKitWatchManager()
    @State private var isAuthenticated = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchConnectivity)
                .environmentObject(healthManager)
                .onAppear {
                    setupWatch()
                }
        }
    }
    
    private func setupWatch() {
        // Initialize watch connectivity
        watchConnectivity.activate()
        
        // Request HealthKit permissions
        healthManager.requestPermissions()
        
        // Check authentication status
        checkAuthenticationStatus()
    }
    
    private func checkAuthenticationStatus() {
        // Check if user is authenticated via iPhone sync
        isAuthenticated = watchConnectivity.isUserAuthenticated
    }
}

struct ContentView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @State private var currentTab: WatchTab = .questionnaire

    enum WatchTab {
        case questionnaire
        case treatment
        case recommendations
        case health
    }

    var body: some View {
        TabView(selection: $currentTab) {
            QuestionnaireView()
                .tag(WatchTab.questionnaire)
                .tabItem {
                    Image(systemName: "questionmark.circle")
                    Text("Questions")
                }

            TreatmentTasksView()
                .tag(WatchTab.treatment)
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("Tasks")
                }

            RecommendationsView()
                .tag(WatchTab.recommendations)
                .tabItem {
                    Image(systemName: "heart.circle")
                    Text("Tips")
                }

            HealthSummaryView()
                .tag(WatchTab.health)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Health")
                }
        }
        .onAppear {
            // Request latest data from iPhone
            watchConnectivity.requestDataFromiPhone()
        }
    }
}

struct HealthSummaryView: View {
    @EnvironmentObject var healthManager: HealthKitWatchManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Health Summary")
                .font(.headline)
                .padding(.bottom)
            
            if let sleepData = healthManager.lastNightSleep {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Night's Sleep")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(sleepData.duration, specifier: "%.1f") hours")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .padding(.bottom)
            }
            
            Button("Sync Health Data") {
                healthManager.syncHealthData()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}