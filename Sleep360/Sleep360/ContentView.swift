import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    
    var body: some View {
        NavigationView {
            if authManager.isAuthenticated {
                MainDashboardView()
            } else {
                AuthenticationView()
            }
        }
        .onAppear {
            authManager.checkAuthenticationStatus()
        }
    }
}

struct MainDashboardView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    
    @State private var currentDay: Int = 1
    @State private var showingHealthKit = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Sleep 360°")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("15-Day Journey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Sign Out") {
                    authManager.signOut()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // Current Day Progress
            VStack(spacing: 16) {
                Text("Day \(currentDay) of 15")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                ProgressView(value: Double(currentDay), total: 15.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                Text("\(Int((Double(currentDay) / 15.0) * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // HealthKit Status
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: healthKitManager.isAuthorized ? "heart.fill" : "heart")
                        .foregroundColor(healthKitManager.isAuthorized ? .green : .gray)
                    
                    Text(healthKitManager.isAuthorized ? "HealthKit Connected" : "HealthKit Not Connected")
                        .font(.subheadline)
                    
                    Spacer()
                }
                
                if !healthKitManager.isAuthorized {
                    Button(action: {
                        showingHealthKit = true
                    }) {
                        Text("Connect HealthKit")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Main Actions
            VStack(spacing: 16) {
                NavigationLink(destination: QuestionnaireView(currentDay: $currentDay)) {
                    HStack {
                        Image(systemName: "list.clipboard")
                        Text("Start Day \(currentDay) Questions")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                NavigationLink(destination: SleepDiaryView()) {
                    HStack {
                        Image(systemName: "moon.stars")
                        Text("Sleep Diary")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            
            Spacer()
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingHealthKit) {
            HealthKitIntegrationView()
        }
    }
}

struct QuestionnaireView: View {
    @Binding var currentDay: Int
    @State private var responses: [String: Any] = [:]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text("Day \(currentDay) Questionnaire")
                .font(.title)
                .padding()
            
            // Placeholder for questionnaire content
            ScrollView {
                VStack(spacing: 20) {
                    Text("Questions will be loaded here")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            Button(action: {
                // Submit responses
                currentDay = min(currentDay + 1, 15)
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Submit Responses")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Questionnaire")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SleepDiaryView: View {
    var body: some View {
        VStack {
            Text("Sleep Diary")
                .font(.title)
                .padding()
            
            ScrollView {
                VStack(spacing: 20) {
                    Text("Sleep diary entries will be displayed here")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .navigationTitle("Sleep Diary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
        .environmentObject(HealthKitManager())
}