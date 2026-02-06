//
//  PhysicianModels.swift
//  Zoe Sleep
//
//  Data models for physician-related data retrieved from Convex.
//  Used for displaying assigned physician information in the Treatment Dashboard.
//

import Foundation

/// Represents the patient's assigned physician
struct AssignedPhysician: Codable, Identifiable {
    let id: String
    let fullName: String
    let title: String?
    let avatarUrl: String?
    let email: String
    let specialization: String?
    let assignedAt: Double

    /// Get initials from the physician's name
    var initials: String {
        let parts = fullName.split(separator: " ")
        let firstInitial = parts.first?.prefix(1) ?? ""
        let lastInitial = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        let combined = "\(firstInitial)\(lastInitial)".uppercased()
        return combined.isEmpty ? "?" : combined
    }

    /// Full display name with title if available
    var displayName: String {
        if let title = title, !title.isEmpty {
            return "\(title) \(fullName)"
        }
        return fullName
    }

    /// Assignment date formatted for display
    var assignedDateFormatted: String {
        let date = Date(timeIntervalSince1970: assignedAt / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

/// Response wrapper for Convex physician queries
struct PhysicianQueryResponse: Codable {
    let physician: AssignedPhysician?
}
