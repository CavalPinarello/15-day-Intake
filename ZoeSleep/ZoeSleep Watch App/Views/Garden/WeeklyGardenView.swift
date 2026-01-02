//
//  WeeklyGardenView.swift
//  ZoeSleep Watch App
//
//  REDESIGNED: Simple growing plant bars for better readability on small screens.
//  Each day shows a growing bar that fills up as check-ins are completed.
//

import SwiftUI

// MARK: - Weekly Garden View (Redesigned)

/// Simple 7-bar garden showing daily progress as growing plants
struct WeeklyGardenView: View {
    let garden: WeeklyGarden

    private let palette = WatchCircadianPalette.current

    private var cardBackground: Color {
        Color.white.opacity(0.08)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header with streak
            headerView

            // Growing bars
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(garden.days) { day in
                    GrowingPlantBar(day: day)
                }
            }
            .frame(height: 40)

            // Day labels
            dayLabels
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
        )
    }

    private var headerView: some View {
        HStack {
            Text("This Week")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            // Streak
            if garden.currentStreak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                    Text("\(garden.currentStreak)")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.orange)
            }
        }
    }

    private var dayLabels: some View {
        HStack(spacing: 6) {
            ForEach(garden.days) { day in
                Text(day.dayLetter)
                    .font(.system(size: 9, weight: day.isToday ? .bold : .regular))
                    .foregroundColor(day.isToday ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Growing Plant Bar

/// A single vertical bar that grows like a plant
struct GrowingPlantBar: View {
    let day: DayFlower

    @State private var animatedHeight: CGFloat = 0

    // Height based on bloom state (0 to 1)
    private var targetHeight: CGFloat {
        switch day.bloomState {
        case .empty: return 0.0
        case .seed: return 0.15
        case .sprout: return 0.35
        case .budding: return 0.55
        case .blooming: return 0.80
        case .fullBloom: return 1.0
        }
    }

    // Color based on growth stage
    private var barColor: Color {
        switch day.bloomState {
        case .empty: return .gray.opacity(0.2)
        case .seed: return .brown.opacity(0.6)
        case .sprout: return .green.opacity(0.7)
        case .budding: return Color(red: 0.4, green: 0.8, blue: 0.4)
        case .blooming: return day.flowerColor.opacity(0.85)
        case .fullBloom: return day.flowerColor
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: barWidth)

                // Growing bar
                if animatedHeight > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: barWidth, height: geo.size.height * animatedHeight)
                }

                // Bloom indicator at top (for full bloom)
                if day.bloomState == .fullBloom {
                    Circle()
                        .fill(day.flowerColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: day.flowerColor.opacity(0.6), radius: 3)
                        .offset(y: -(geo.size.height * animatedHeight) + 4)
                }

                // Today indicator ring
                if day.isToday {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
                        .frame(width: barWidth + 4, height: geo.size.height + 4)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double.random(in: 0...0.2))) {
                animatedHeight = targetHeight
            }
        }
    }

    private var barWidth: CGFloat { 14 }

    private var gradientColors: [Color] {
        switch day.bloomState {
        case .empty:
            return [.gray.opacity(0.2), .gray.opacity(0.2)]
        case .seed:
            return [.brown.opacity(0.4), .brown.opacity(0.6)]
        case .sprout:
            return [.brown.opacity(0.5), .green.opacity(0.6)]
        case .budding:
            return [.green.opacity(0.4), Color(red: 0.4, green: 0.8, blue: 0.4)]
        case .blooming:
            return [.green.opacity(0.5), day.flowerColor.opacity(0.8)]
        case .fullBloom:
            return [.green.opacity(0.4), day.flowerColor.opacity(0.9), day.flowerColor]
        }
    }
}

// MARK: - Compact Garden (Simplified Dots)

/// Minimal dot-based progress for very small spaces
struct CompactGardenView: View {
    let garden: WeeklyGarden

    var body: some View {
        HStack(spacing: 5) {
            ForEach(garden.days) { day in
                Circle()
                    .fill(dotColor(for: day))
                    .frame(width: 10, height: 10)
                    .overlay {
                        if day.isToday {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                        }
                    }
            }
        }
    }

    private func dotColor(for day: DayFlower) -> Color {
        switch day.bloomState {
        case .empty: return .gray.opacity(0.3)
        case .seed: return .brown.opacity(0.5)
        case .sprout: return .green.opacity(0.6)
        case .budding: return .green.opacity(0.8)
        case .blooming: return day.flowerColor.opacity(0.8)
        case .fullBloom: return day.flowerColor
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
        }
        .padding()
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
    }
}
#endif
