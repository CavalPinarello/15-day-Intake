//
//  AvatarView.swift
//  Zoe Sleep
//
//  Reusable avatar component with image loading and initials fallback.
//  Supports AsyncImage loading with placeholder and fallback states.
//

import SwiftUI

/// Configurable avatar sizes
enum AvatarSize: CGFloat {
    case xs = 24
    case sm = 32
    case md = 48
    case lg = 64
    case xl = 80

    var fontSize: CGFloat {
        switch self {
        case .xs: return 10
        case .sm: return 14
        case .md: return 18
        case .lg: return 24
        case .xl: return 28
        }
    }
}

/// Reusable avatar component that displays either a profile image or initials
struct AvatarView: View {
    let imageUrl: String?
    let name: String
    var size: AvatarSize = .md
    var gradient: LinearGradient?

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    /// Extract initials from name (up to 2 characters)
    private var initials: String {
        let parts = name.split(separator: " ")
        let firstInitial = parts.first?.prefix(1) ?? ""
        let lastInitial = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        let combined = "\(firstInitial)\(lastInitial)".uppercased()
        return combined.isEmpty ? "?" : combined
    }

    /// Default gradient for initials fallback
    private var defaultGradient: LinearGradient {
        gradient ?? LinearGradient(
            colors: [theme.primary.opacity(0.6), theme.primary.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Group {
            if let urlString = imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        // Loading placeholder
                        initialsView
                            .overlay(
                                ProgressView()
                                    .tint(.white.opacity(0.7))
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        // Show initials on failure
                        initialsView
                    @unknown default:
                        initialsView
                    }
                }
                .frame(width: size.rawValue, height: size.rawValue)
                .clipShape(Circle())
            } else {
                // No URL provided - show initials
                initialsView
            }
        }
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(defaultGradient)

            Text(initials)
                .font(.system(size: size.fontSize, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size.rawValue, height: size.rawValue)
    }
}

/// Preview provider for AvatarView
#Preview {
    VStack(spacing: 20) {
        // With image URL (will show initials if URL fails)
        AvatarView(
            imageUrl: "https://example.com/avatar.jpg",
            name: "John Doe",
            size: .lg
        )

        // Without image (shows initials)
        AvatarView(
            imageUrl: nil,
            name: "Jane Smith",
            size: .lg
        )

        // Various sizes
        HStack(spacing: 16) {
            AvatarView(imageUrl: nil, name: "XS", size: .xs)
            AvatarView(imageUrl: nil, name: "SM", size: .sm)
            AvatarView(imageUrl: nil, name: "MD", size: .md)
            AvatarView(imageUrl: nil, name: "LG", size: .lg)
            AvatarView(imageUrl: nil, name: "XL", size: .xl)
        }
    }
    .environmentObject(ThemeManager.shared)
}
