//
//  AuthenticationView.swift
//  Sleep 360 Platform
//
//  SwiftUI view for user authentication
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSignUp = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // App Logo/Title
                VStack(spacing: 8) {
                    Text("Zoé Sleep")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.blue)

                    Text("Your comprehensive sleep journey")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)

                Spacer()

                // Authentication Form
                VStack(spacing: 16) {
                    if isSignUp {
                        // First Name
                        TextField("First Name (Optional)", text: $firstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        // Last Name
                        TextField("Last Name (Optional)", text: $lastName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    // Email
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    // Password
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    // Sign In/Up Button
                    Button(action: {
                        Task {
                            if isSignUp {
                                await authManager.signUp(
                                    email: email,
                                    password: password,
                                    firstName: firstName.isEmpty ? nil : firstName,
                                    lastName: lastName.isEmpty ? nil : lastName
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
                        .background(Color.blue)
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

                        // Sign in with Google
                        Button(action: {
                            Task {
                                await authManager.signInWithGoogle()
                                if let errorMessage = authManager.errorMessage {
                                    self.alertMessage = errorMessage
                                    self.showingAlert = true
                                }
                            }
                        }) {
                            HStack {
                                // Google logo placeholder
                                Circle()
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [.red, .blue, .green, .yellow]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 20, height: 20)
                                Text("Continue with Google")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(10)
                        }
                        .disabled(authManager.isLoading)
                    }

                    // Toggle Sign In/Up
                    Button(action: {
                        isSignUp.toggle()
                        // Clear fields when switching
                        firstName = ""
                        lastName = ""
                        authManager.errorMessage = nil
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // App Info
                VStack(spacing: 4) {
                    Text("Secure authentication powered by Clerk")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    Text("Your health data is protected and encrypted")
                        .font(.caption2)
                        .foregroundColor(.gray)
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

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // User Info
                if let user = authManager.user {
                    VStack(spacing: 8) {
                        // Profile Image
                        AsyncImage(url: URL(string: user.profileImageUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                        // User Name
                        Text("\(user.firstName ?? "") \(user.lastName ?? "")".trimmingCharacters(in: .whitespaces))
                            .font(.title2)
                            .bold()

                        // Email
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
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
                        .background(Color.red)
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
    }
}
