//
//  AuthenticationView.swift
//  Zoe Sleep for Longevity System
//
//  SwiftUI view for user authentication using Clerk
//

import SwiftUI
import Clerk

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.clerk) private var clerk
    @State private var showAuthView = false

    private var theme: ColorTheme { themeManager.currentTheme }

    // Brand colors - warm cream on dark background
    private let logoColor = Color(red: 0.96, green: 0.90, blue: 0.83) // #F5E6D3 warm cream

    var body: some View {
        ZStack {
            // Dark background for aurora to show on
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()

            // Aurora background - fully visible
            AuroraBorealisView()
                .ignoresSafeArea()

            // Gradient overlay - darker at top for logo, lighter at bottom
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.1),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // App Logo/Title
                VStack(spacing: 12) {
                    // Spiral crescent moon logo with glow
                    ZoeLogoSVG(size: 80, color: logoColor)
                        .shadow(color: logoColor.opacity(0.4), radius: 20, x: 0, y: 0)

                    Text("Zoé Sleep")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)

                    Text("Your comprehensive sleep journey")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 60)

                Spacer()

                // Main CTA - Sign In Button
                VStack(spacing: 24) {
                    // Sign In Button - opens Clerk AuthView
                    Button(action: {
                        showAuthView = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Sign In or Sign Up")
                                .fontWeight(.semibold)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // Info text
                    VStack(spacing: 8) {
                        Text("Continue with email, Google, or Apple")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        Text("Forgot your password? We'll help you reset it.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // App Info
                VStack(spacing: 4) {
                    Text("Your health data is protected and encrypted")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 20)
            }

            // Loading overlay
            if authManager.isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Signing in...")
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
            }
        }
        .sheet(isPresented: $showAuthView) {
            // Clerk's built-in AuthView handles sign-in, sign-up, password reset, and social logins
            AuthView()
        }
        .alert("Authentication Error", isPresented: .init(
            get: { authManager.errorMessage != nil },
            set: { if !$0 { authManager.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                authManager.errorMessage = nil
            }
        } message: {
            Text(authManager.errorMessage ?? "")
        }
    }
}

// MARK: - Main App View (Legacy - kept for compatibility)

struct MainAppView: View {
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // Main app content
                TabView {
                    // Health Data Sync Tab
                    HealthKitIntegrationView()
                        .tabItem {
                            Image(systemName: "heart.fill")
                            Text("Health Sync")
                        }

                    // Profile Tab
                    ProfileView()
                        .tabItem {
                            Image(systemName: "person.circle.fill")
                            Text("Profile")
                        }
                }
            } else {
                AuthenticationView()
            }
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    var theme: ColorTheme = ColorTheme.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // User Info
                if let user = authManager.user {
                    VStack(spacing: 8) {
                        // Profile Image placeholder
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(theme.primary)
                            .frame(width: 80, height: 80)

                        // Username
                        Text(user.username)
                            .font(.title2)
                            .bold()

                        // Email
                        if let email = user.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Current Day
                        Text("Day \(user.currentDay) of 10")
                            .font(.caption)
                            .foregroundColor(theme.primary)
                    }
                    .padding()
                }

                Spacer()

                // Sign Out Button
                Button(action: {
                    authManager.signOut()
                }) {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.error)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            }
            .navigationTitle("Profile")
        }
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
            .environmentObject(AuthenticationManager())
            .environmentObject(ThemeManager.shared)
    }
}
