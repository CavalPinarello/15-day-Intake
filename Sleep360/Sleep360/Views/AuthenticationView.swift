//
//  AuthenticationView.swift
//  Zoe Sleep for Longevity System
//
//  SwiftUI view for user authentication
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isSignUp = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // App Logo/Title
                VStack(spacing: 8) {
                    Text("Zoé Sleep")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(theme.primary)

                    Text("Your comprehensive sleep journey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                Spacer()

                // Authentication Form
                VStack(spacing: 16) {
                    // Username/Email field
                    TextField(isSignUp ? "Username" : "Username or Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if isSignUp {
                        // Email for sign up
                        TextField("Email", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    // Password
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    // Sign In/Up Button
                    Button(action: {
                        Task {
                            if isSignUp {
                                await authManager.signUp(
                                    email: username,
                                    password: password,
                                    username: email
                                )
                            } else {
                                await authManager.signIn(email: email, password: password)
                            }

                            if let errorMessage = authManager.errorMessage {
                                self.alertMessage = errorMessage
                                self.showingAlert = true
                            }
                        }
                    }) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isSignUp ? "Sign Up" : "Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)

                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.vertical, 8)

                    // Social Login Buttons
                    VStack(spacing: 12) {
                        // Sign in with Apple
                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = authManager.generateNonce()
                            },
                            onCompletion: { result in
                                Task {
                                    await authManager.handleSignInWithApple(result)
                                    if let errorMessage = authManager.errorMessage {
                                        self.alertMessage = errorMessage
                                        self.showingAlert = true
                                    }
                                }
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .cornerRadius(10)
                        .disabled(authManager.isLoading)

                    }

                    // Toggle Sign In/Up
                    Button(action: {
                        isSignUp.toggle()
                        // Clear fields when switching
                        username = ""
                        authManager.errorMessage = nil
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.footnote)
                            .foregroundColor(theme.primary)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // App Info
                VStack(spacing: 4) {
                    Text("Secure authentication powered by Clerk")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Your health data is protected and encrypted")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .alert("Authentication Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - Main App View

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
                        Text("Day \(user.currentDay) of 15")
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
            .environmentObject(ThemeManager())
    }
}

