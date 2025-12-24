//
//  WeeklyGardenView.swift
//  ZoeSleep Watch App
//
//  A 7-pot garden visualization showing the week's progress.
//  Each flower blooms as daily check-ins are completed.
//

import SwiftUI

// MARK: - Weekly Garden View

/// The main garden visualization showing 7 flower pots (Mon-Sun)
struct WeeklyGardenView: View {
    let garden: WeeklyGarden

    private let palette = WatchCircadianPalette.current

    // Card background color derived from palette
    private var cardBackground: Color {
        palette.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Week header with streak
            headerView

            // 7 flower pots
            flowersRow

            // Day labels
            dayLabelsRow
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("This Week")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(palette.textSecondary)

            Spacer()

            // Streak badge
            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                Text("\(garden.currentStreak)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(palette.textPrimary)
            }
        }
    }

    // MARK: - Flowers Row

    private var flowersRow: some View {
        HStack(spacing: 4) {
            ForEach(garden.days) { day in
                FlowerPotView(flower: day)
                    .frame(width: 20)
            }
        }
    }

    // MARK: - Day Labels

    private var dayLabelsRow: some View {
        HStack(spacing: 4) {
            ForEach(garden.days) { day in
                Text(day.dayLetter)
                    .font(.system(size: 8, weight: day.isToday ? .bold : .regular))
                    .foregroundColor(day.isToday ? palette.accent : palette.textSecondary)
                    .frame(width: 20)
            }
        }
    }
}

// MARK: - Compact Garden View

/// A more compact version for smaller displays
struct CompactGardenView: View {
    let garden: WeeklyGarden

    private let palette = WatchCircadianPalette.current

    var body: some View {
        HStack(spacing: 3) {
            ForEach(garden.days) { day in
                CompactFlowerDot(flower: day)
            }
        }
    }
}

/// A simple dot indicator for compact view
struct CompactFlowerDot: View {
    let flower: DayFlower

    private let palette = WatchCircadianPalette.current

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(flower.isToday ? palette.accent.opacity(0.3) : Color.gray.opacity(0.2))
                .frame(width: 16, height: 16)

            // Bloom indicator
            Circle()
                .fill(bloomColor)
                .frame(width: bloomSize, height: bloomSize)
        }
    }

    private var bloomColor: Color {
        switch flower.bloomState {
        case .empty: return .clear
        case .seed: return Color.brown.opacity(0.5)
        case .sprout: return Color.green.opacity(0.6)
        case .budding: return flower.flowerColor.opacity(0.7)
        case .blooming: return flower.flowerColor.opacity(0.9)
        case .fullBloom: return flower.flowerColor
        }
    }

    private var bloomSize: CGFloat {
        switch flower.bloomState {
        case .empty: return 0
        case .seed: return 4
        case .sprout: return 6
        case .budding: return 8
        case .blooming: return 10
        case .fullBloom: return 12
        }
    }
}

// MARK: - Garden Card

/// A card wrapper for the garden with additional info
struct GardenCard: View {
    let garden: WeeklyGarden

    private let palette = WatchCircadianPalette.current

    var body: some View {
        VStack(spacing: 8) {
            WeeklyGardenView(garden: garden)

            // Progress summary
            HStack {
                // Check-ins
                Label("\(garden.totalCheckInsThisWeek)/21", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(palette.textSecondary)

                Spacer()

                // Blooming days
                Label("\(garden.bloomingDays) blooming", systemImage: "camera.macro")
                    .font(.system(size: 10))
                    .foregroundColor(palette.textSecondary)
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct WeeklyGardenView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            WeeklyGardenView(garden: .preview)

            Divider()

            CompactGardenView(garden: .preview)

            Divider()

            GardenCard(garden: .preview)
        }
        .padding()
        .background(Color.black)
    }
}
#endif
