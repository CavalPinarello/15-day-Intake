import SwiftUI

@main
struct Sleep360App: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(healthKitManager)
                .onAppear {
                    // Request HealthKit authorization on app launch
                    if authManager.isAuthenticated {
                        Task {
                            await healthKitManager.requestAuthorization()
                        }
                    }
                }
        }
    }
}