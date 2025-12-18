//
//  ZoeLogo.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Custom vector logo: Spiral crescent moon design
//  Extracted from brand guidelines PDF
//

import SwiftUI

/// The official Zoé logo - a spiral crescent moon design
/// representing sleep cycles and renewal
struct ZoeLogo: View {
    var size: CGFloat = 100
    var tealColor: Color = Color(red: 0.22, green: 0.65, blue: 0.69) // #38A5B0 brand teal

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 100
            let centerX = canvasSize.width / 2
            let centerY = canvasSize.height / 2

            // The logo consists of overlapping crescents creating a spiral effect
            // Main outer crescent
            let outerPath = createOuterCrescent(scale: scale, centerX: centerX, centerY: centerY)
            context.fill(outerPath, with: .color(tealColor))

            // Inner spiral crescent
            let innerPath = createInnerCrescent(scale: scale, centerX: centerX, centerY: centerY)
            context.fill(innerPath, with: .color(tealColor))
        }
        .frame(width: size, height: size)
    }

    private func createOuterCrescent(scale: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Path {
        var path = Path()

        // Outer circle parameters
        let outerRadius = 45 * scale
        let innerRadius = 32 * scale
        let offsetX = 12 * scale // Offset for crescent effect
        let offsetY = -5 * scale

        // Draw outer arc (full circle)
        path.addArc(
            center: CGPoint(x: centerX, y: centerY),
            radius: outerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )

        // Subtract inner circle (offset to create crescent)
        var innerCircle = Path()
        innerCircle.addArc(
            center: CGPoint(x: centerX + offsetX, y: centerY + offsetY),
            radius: innerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )

        // Create crescent by subtracting
        return path.subtracting(innerCircle)
    }

    private func createInnerCrescent(scale: CGFloat, centerX: CGFloat, centerY: CGFloat) -> Path {
        var path = Path()

        // Inner spiral crescent parameters
        let outerRadius = 25 * scale
        let innerRadius = 18 * scale
        let baseOffsetX = 10 * scale
        let baseOffsetY = -3 * scale
        let crescentOffsetX = 8 * scale
        let crescentOffsetY = -4 * scale

        // Position for inner crescent (nested inside the outer one)
        let innerCenterX = centerX + baseOffsetX
        let innerCenterY = centerY + baseOffsetY

        // Draw outer arc of inner crescent
        path.addArc(
            center: CGPoint(x: innerCenterX, y: innerCenterY),
            radius: outerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )

        // Subtract to create inner crescent
        var subtractCircle = Path()
        subtractCircle.addArc(
            center: CGPoint(x: innerCenterX + crescentOffsetX, y: innerCenterY + crescentOffsetY),
            radius: innerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )

        return path.subtracting(subtractCircle)
    }
}

/// A more accurate SVG-based logo recreation
struct ZoeLogoAccurate: View {
    var size: CGFloat = 100
    var tealColor: Color = Color(red: 0.22, green: 0.65, blue: 0.69)

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width, geometry.size.height) / 100

            ZStack {
                // Outer crescent (large moon)
                CrescentShape(
                    innerCircleOffset: CGSize(width: 25 * scale, height: -10 * scale),
                    innerRadiusRatio: 0.72
                )
                .fill(tealColor)
                .frame(width: 90 * scale, height: 90 * scale)
                .offset(x: 0, y: 0)

                // Inner crescent (small moon, creating spiral)
                CrescentShape(
                    innerCircleOffset: CGSize(width: 15 * scale, height: -8 * scale),
                    innerRadiusRatio: 0.70
                )
                .fill(tealColor)
                .frame(width: 50 * scale, height: 50 * scale)
                .offset(x: 18 * scale, y: -2 * scale)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(width: size, height: size)
    }
}

/// Crescent moon shape
struct CrescentShape: Shape {
    var innerCircleOffset: CGSize
    var innerRadiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRadiusRatio
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let innerCenter = CGPoint(
            x: center.x + innerCircleOffset.width,
            y: center.y + innerCircleOffset.height
        )

        var path = Path()
        path.addArc(center: center, radius: outerRadius, startAngle: .zero, endAngle: .degrees(360), clockwise: false)

        var innerPath = Path()
        innerPath.addArc(center: innerCenter, radius: innerRadius, startAngle: .zero, endAngle: .degrees(360), clockwise: false)

        return path.subtracting(innerPath)
    }
}

/// Logo with the "Zoé" text
struct ZoeLogoWithText: View {
    var logoSize: CGFloat = 80
    var fontSize: CGFloat = 32
    var tealColor: Color = Color(red: 0.22, green: 0.65, blue: 0.69)
    var textColor: Color = .white
    var spacing: CGFloat = 16

    var body: some View {
        HStack(spacing: spacing) {
            Text("Zoé")
                .font(.system(size: fontSize, weight: .light, design: .default))
                .foregroundColor(textColor)

            ZoeLogoAccurate(size: logoSize, tealColor: tealColor)
        }
    }
}

/// Preview provider
#Preview("Logo Variations") {
    VStack(spacing: 40) {
        // Basic logo
        ZoeLogoAccurate(size: 100)

        // Logo with text (like in the PDF)
        ZoeLogoWithText(logoSize: 80, fontSize: 36)
            .padding()
            .background(Color.black)
            .cornerRadius(16)

        // Different sizes
        HStack(spacing: 20) {
            ZoeLogoAccurate(size: 40)
            ZoeLogoAccurate(size: 60)
            ZoeLogoAccurate(size: 80)
        }

        // App icon preview (with background)
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color(red: 0.1, green: 0.1, blue: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            ZoeLogoAccurate(size: 60, tealColor: Color(red: 0.22, green: 0.65, blue: 0.69))
        }
        .frame(width: 100, height: 100)
        .cornerRadius(22)
    }
    .padding()
}
