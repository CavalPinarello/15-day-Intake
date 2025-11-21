//
//  Config.swift
//  Sleep 360 Platform
//
//  Configuration file for API endpoints and authentication
//

import Foundation

struct Config {
    // Clerk Configuration
    static let clerkPublishableKey = "pk_test_a25vd2luZy1pbnNlY3QtMTAuY2xlcmsuYWNjb3VudHMuZGV2JA"
    
    // API Base URLs
    static let apiBaseURL = "http://localhost:3001" // Server URL
    static let webAppURL = "http://localhost:3000"  // Next.js client URL
    
    // HealthKit API Endpoints
    static let healthKitSyncEndpoint = "\(apiBaseURL)/api/health/sync"
    static let sleepDataEndpoint = "\(apiBaseURL)/api/health/sleep"
    static let activityDataEndpoint = "\(apiBaseURL)/api/health/activity"
    
    // Authentication Endpoints  
    static let authEndpoint = "\(apiBaseURL)/api/auth"
    static let userProfileEndpoint = "\(apiBaseURL)/api/users/profile"
    
    // App Configuration
    static let appName = "Sleep 360°"
    static let appVersion = "1.0.0"
    
    #if DEBUG
    static let isDebugMode = true
    #else
    static let isDebugMode = false
    #endif
}