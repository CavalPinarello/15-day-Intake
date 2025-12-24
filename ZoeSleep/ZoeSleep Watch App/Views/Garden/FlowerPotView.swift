//
//  FlowerPotView.swift
//  ZoeSleep Watch App
//
//  A single flower pot with bloom animation.
//  Each pot represents one day of the week.
//

import SwiftUI

// MARK: - Flower Pot View

/// A single flower pot that blooms based on daily compliance
struct FlowerPotView: View {
    let flower: DayFlower

    @State private var bloomScale: CGFloat = 1.0
    @State private var swayRotation: Double = 0
    @State private var petalRotation: Double = 0

    private let palette = WatchCircadianPalette.current

    var body: some View {
        VStack(spacing: 0) {
            // Flower area
            ZStack {
                // Stem (if growing)
                if flower.bloomState.stemHeight > 0 {
                    stemShape
                }

                // Flower head
                flowerHead
                    .scaleEffect(bloomScale)
                    .rotationEffect(.degrees(swayRotation))
            }
            .frame(width: 20, height: 24)

            // Pot
            potShape
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Stem

    private var stemShape: some View {
        Capsule()
            .fill(Color.green.opacity(0.8))
            .frame(width: 2, height: 12 * flower.bloomState.stemHeight)
            .offset(y: 6 - (6 * flower.bloomState.stemHeight))
    }

    // MARK: - Flower Head

    @ViewBuilder
    private var flowerHead: some View {
        switch flower.bloomState {
        case .empty:
            // Empty - no flower
            EmptyView()

        case .seed:
            // Seed - small brown dot
            Circle()
                .fill(Color.brown.opacity(0.4))
                .frame(width: 6, height: 6)
                .offset(y: 6)

        case .sprout:
            // Sprout - small green leaf
            Image(systemName: "leaf.fill")
                .font(.system(size: 10))
                .foregroundColor(.green.opacity(0.7))
                .offset(y: 2)

        case .budding:
            // Bud - closed flower shape
            Capsule()
                .fill(flower.flowerColor.opacity(0.8))
                .frame(width: 8, height: 12)
                .offset(y: -2)

        case .blooming:
            // Blooming - partial petals
            bloomingFlower(petalCount: 4, size: 12)
                .offset(y: -4)

        case .fullBloom:
            // Full bloom - all petals with center
            bloomingFlower(petalCount: 6, size: 14)
                .rotationEffect(.degrees(petalRotation))
                .offset(y: -5)
        }
    }

    // MARK: - Blooming Flower

    private func bloomingFlower(petalCount: Int, size: CGFloat) -> some View {
        ZStack {
            // Petals
            ForEach(0..<petalCount, id: \.self) { i in
                Ellipse()
                    .fill(flower.flowerColor)
                    .frame(width: size * 0.5, height: size)
                    .offset(y: -size * 0.35)
                    .rotationEffect(.degrees(Double(i) * (360.0 / Double(petalCount))))
            }

            // Center
            Circle()
                .fill(Color.yellow)
                .frame(width: size * 0.4, height: size * 0.4)
        }
    }

    // MARK: - Pot

    private var potShape: some View {
        ZStack {
            // Pot body
            TrapezoidShape()
                .fill(flower.isToday ? Color.orange.opacity(0.8) : Color.brown.opacity(0.6))
                .frame(width: 16, height: 10)

            // Pot rim
            RoundedRectangle(cornerRadius: 1)
                .fill(flower.isToday ? Color.orange : Color.brown.opacity(0.8))
                .frame(width: 18, height: 3)
                .offset(y: -3.5)
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        guard flower.bloomState.shouldAnimate else { return }

        // Full bloom rotation
        if flower.bloomState == .fullBloom {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                bloomScale = 1.1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4)) {
                    bloomScale = 1.0
                }
            }
        }

        // Gentle sway
        withAnimation(
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: true)
        ) {
            swayRotation = 5
        }
    }
}

// MARK: - Trapezoid Shape (for pot)

struct TrapezoidShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset: CGFloat = 2

        path.move(to: CGPoint(x: inset, y: 0))
        path.addLine(to: CGPoint(x: rect.width - inset, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#if DEBUG
struct FlowerPotView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 8) {
            ForEach(BloomState.allCases, id: \.rawValue) { state in
                FlowerPotView(flower: DayFlower(
                    date: "2024-12-23",
                    dayOfWeek: "Mon",
                    bloomState: state,
                    checkInsCompleted: state.rawValue,
                    tasksCompleted: 0,
                    totalTasks: 0,
                    isToday: state == .budding
                ))
            }
        }
        .padding()
        .background(Color.black)
    }
}
#endif
