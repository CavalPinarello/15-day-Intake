//
//  Config.swift
//  Sleep 360 Platform
//
//  Configuration file for API endpoints and authentication
//

import Foundation

struct Config {
    // ============================================
    // Backend Mode Configuration
    // ============================================
    // Set to true to use Convex directly (recommended)
    // Set to false to use the legacy REST API server
    static let useConvex = true

    // ============================================
    // Convex Configuration (Primary Backend)
    // ============================================
    // Get your deployment URL from: https://dashboard.convex.dev
    // Or run: cat .env.local | grep CONVEX_URL
    static let convexDeploymentURL = "https://enchanted-terrier-633.convex.cloud"

    // ============================================
    // Clerk Configuration (Authentication)
    // ============================================
    static let clerkPublishableKey = "pk_test_a25vd2luZy1pbnNlY3QtMTAuY2xlcmsuYWNjb3VudHMuZGV2JA"
    static let clerkDomain = "knowing-insect-10.clerk.accounts.dev"
    // Sign-in URL uses your web app (which has Clerk integrated)
    // For production, replace with your deployed web app URL
    static let clerkSignInURL = "\(webAppURL)/sign-in"
    static let clerkSignUpURL = "\(webAppURL)/sign-up"

    // ============================================
    // Legacy REST API Configuration
    // ============================================
    // Note: iOS Simulator uses 127.0.0.1 to reach Mac's localhost
    // Physical devices need the Mac's actual IP address on the local network
    #if targetEnvironment(simulator)
    static let apiBaseURL = "http://127.0.0.1:3001" // Simulator uses 127.0.0.1
    static let webAppURL = "http://127.0.0.1:3000"
    #else
    static let apiBaseURL = "http://10.0.0.136:3001" // Mac's local IP for physical device
    static let webAppURL = "http://10.0.0.136:3000"
    #endif

    // Legacy HealthKit API Endpoints (when useConvex = false)
    static let healthKitSyncEndpoint = "\(apiBaseURL)/api/health/sync"
    static let sleepDataEndpoint = "\(apiBaseURL)/api/health/sleep"
    static let activityDataEndpoint = "\(apiBaseURL)/api/health/activity"

    // Legacy Authentication Endpoints (when useConvex = false)
    static let authEndpoint = "\(apiBaseURL)/api/auth"
    static let userProfileEndpoint = "\(apiBaseURL)/api/users/profile"

    // ============================================
    // App Configuration
    // ============================================
    static let appName = "Sleep 360°"
    static let appVersion = "1.0.0"
    static let appBundleId = "com.sleep360.app"

    // Journey Configuration
    static let totalJourneyDays = 15
    static let sessionExpirationDays = 30

    #if DEBUG
    static let isDebugMode = true
    #else
    static let isDebugMode = false
    #endif
}