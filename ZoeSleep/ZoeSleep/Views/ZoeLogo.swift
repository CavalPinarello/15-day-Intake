//
//  ZoeLogo.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Custom vector logo: Spiral crescent moon design
//  Based on official brand SVG (Frame 3.svg)
//

import SwiftUI

/// The official Zoé logo - a spiral crescent moon design
/// representing sleep cycles and renewal
/// This accurately recreates the SVG paths from the brand assets
struct ZoeLogo: View {
    var size: CGFloat = 100
    var color: Color = Color(red: 0.96, green: 0.90, blue: 0.83) // #F5E6D3 warm cream

    var body: some View {
        Canvas { context, canvasSize in
            // Original SVG viewBox: 0 0 1440 1449
            let scale = size / 1440

            // Outer crescent path
            let outerPath = createOuterCrescent(scale: scale)
            context.fill(outerPath, with: .color(color))

            // Inner crescent path (spiral effect)
            let innerPath = createInnerCrescent(scale: scale)
            context.fill(innerPath, with: .color(color))
        }
        .frame(width: size, height: size)
    }

    /// Creates the outer crescent moon shape
    /// SVG path: M388.995 722.405C388.995 1011.3...
    private func createOuterCrescent(scale: CGFloat) -> Path {
        var path = Path()

        // Outer arc (large circle on the left)
        // Center approximately at (721, 722), radius ~713
        let outerCenter = CGPoint(x: 721 * scale, y: 722 * scale)
        let outerRadius: CGFloat = 713 * scale

        // Inner arc (creates crescent by subtracting)
        // Center approximately at (911, 722), radius ~523
        let innerCenter = CGPoint(x: 1000 * scale, y: 700 * scale)
        let innerRadius: CGFloat = 540 * scale

        // Create outer circle
        path.addArc(center: outerCenter, radius: outerRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)

        // Subtract inner circle to create crescent
        var innerCircle = Path()
        innerCircle.addArc(center: innerCenter, radius: innerRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)

        return path.subtracting(innerCircle)
    }

    /// Creates the inner crescent (spiral element)
    /// SVG path: M1422.95 783.297H1428.16...
    private func createInnerCrescent(scale: CGFloat) -> Path {
        var path = Path()

        // Inner spiral crescent
        // Center approximately at (1061, 722), radius ~373
        let outerCenter = CGPoint(x: 1061 * scale, y: 722 * scale)
        let outerRadius: CGFloat = 373 * scale

        // Subtract circle to create inner crescent
        // Center approximately at (1247, 722), radius ~186
        let innerCenter = CGPoint(x: 1300 * scale, y: 700 * scale)
        let innerRadius: CGFloat = 220 * scale

        // Create outer circle of inner crescent
        path.addArc(center: outerCenter, radius: outerRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)

        // Subtract to create crescent shape
        var subtractCircle = Path()
        subtractCircle.addArc(center: innerCenter, radius: innerRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)

        return path.subtracting(subtractCircle)
    }
}

/// Precise SVG path-based logo recreation
/// Uses the exact SVG path data from Frame 3.svg, properly centered
struct ZoeLogoSVG: View {
    var size: CGFloat = 100
    var color: Color = Color(red: 0.96, green: 0.90, blue: 0.83) // #F5E6D3 warm cream

    // SVG content bounds (calculated from path coordinates)
    // X: 8.89 to 1431.33, Y: 8.89 to 1435.92
    // Content width: ~1422, height: ~1427, centered at (~720, ~722)
    private let contentWidth: CGFloat = 1422.44
    private let contentHeight: CGFloat = 1427.03
    private let contentCenterX: CGFloat = 720.11  // (8.89 + 1431.33) / 2
    private let contentCenterY: CGFloat = 722.405 // (8.89 + 1435.92) / 2

    var body: some View {
        Canvas { context, canvasSize in
            let targetSize = min(canvasSize.width, canvasSize.height)
            let scale = targetSize / max(contentWidth, contentHeight)

            // Calculate offset to center the content
            let offsetX = (canvasSize.width / 2) - (contentCenterX * scale)
            let offsetY = (canvasSize.height / 2) - (contentCenterY * scale)

            // Apply transform: translate to center, then scale
            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(x: offsetX, y: offsetY)
            transform = transform.scaledBy(x: scale, y: scale)

            // Draw outer crescent
            var outerPath = OuterCrescentShape().path(in: .infinite)
            outerPath = outerPath.applying(transform)
            context.fill(outerPath, with: .color(color))

            // Draw inner crescent
            var innerPath = InnerCrescentShape().path(in: .infinite)
            innerPath = innerPath.applying(transform)
            context.fill(innerPath, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

/// Outer crescent moon shape from SVG path
struct OuterCrescentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // SVG: M388.995 722.405C388.995 1011.3 622.747 1245.48 911.054 1245.48
        // C1178.85 1245.48 1399.51 1043.5 1429.6 783.286H1430.55
        // C1399.75 1148.83 1093.84 1435.92 721.014 1435.92
        // C327.709 1435.92 8.89014 1116.45 8.89014 722.405
        // C8.89014 328.358 327.709 8.8902 721.014 8.8902
        // C1114.32 8.8902 1405.4 301.303 1431.33 671.732H1430.68
        // C1405.25 406.611 1182.34 199.327 911.054 199.327
        // C622.747 199.327 388.995 433.509 388.995 722.405Z

        path.move(to: CGPoint(x: 388.995, y: 722.405))
        path.addCurve(
            to: CGPoint(x: 911.054, y: 1245.48),
            control1: CGPoint(x: 388.995, y: 1011.3),
            control2: CGPoint(x: 622.747, y: 1245.48)
        )
        path.addCurve(
            to: CGPoint(x: 1429.6, y: 783.286),
            control1: CGPoint(x: 1178.85, y: 1245.48),
            control2: CGPoint(x: 1399.51, y: 1043.5)
        )
        path.addLine(to: CGPoint(x: 1430.55, y: 783.286))
        path.addCurve(
            to: CGPoint(x: 721.014, y: 1435.92),
            control1: CGPoint(x: 1399.75, y: 1148.83),
            control2: CGPoint(x: 1093.84, y: 1435.92)
        )
        path.addCurve(
            to: CGPoint(x: 8.89014, y: 722.405),
            control1: CGPoint(x: 327.709, y: 1435.92),
            control2: CGPoint(x: 8.89014, y: 1116.45)
        )
        path.addCurve(
            to: CGPoint(x: 721.014, y: 8.8902),
            control1: CGPoint(x: 8.89014, y: 328.358),
            control2: CGPoint(x: 327.709, y: 8.8902)
        )
        path.addCurve(
            to: CGPoint(x: 1431.33, y: 671.732),
            control1: CGPoint(x: 1114.32, y: 8.8902),
            control2: CGPoint(x: 1405.4, y: 301.303)
        )
        path.addLine(to: CGPoint(x: 1430.68, y: 671.732))
        path.addCurve(
            to: CGPoint(x: 911.054, y: 199.327),
            control1: CGPoint(x: 1405.25, y: 406.611),
            control2: CGPoint(x: 1182.34, y: 199.327)
        )
        path.addCurve(
            to: CGPoint(x: 388.995, y: 722.405),
            control1: CGPoint(x: 622.747, y: 199.327),
            control2: CGPoint(x: 388.995, y: 433.509)
        )
        path.closeSubpath()

        return path
    }
}

/// Inner crescent shape (spiral element) from SVG path
struct InnerCrescentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // SVG: M1422.95 783.297H1428.16
        // C1399.17 960.271 1245.79 1095.34 1060.94 1095.34
        // C855.369 1095.34 688.744 928.361 688.744 722.416
        // C688.744 516.47 855.369 349.493 1060.94 349.493
        // C1249.33 349.493 1405.01 489.756 1429.68 671.743H1426.17
        // C1404.12 593.437 1332.3 536.02 1247.08 536.02
        // C1144.36 536.02 1061.07 619.469 1061.07 722.416
        // C1061.07 825.362 1144.36 908.811 1247.08 908.811
        // C1328.56 908.811 1397.78 856.354 1422.95 783.297Z

        path.move(to: CGPoint(x: 1422.95, y: 783.297))
        path.addLine(to: CGPoint(x: 1428.16, y: 783.297))
        path.addCurve(
            to: CGPoint(x: 1060.94, y: 1095.34),
            control1: CGPoint(x: 1399.17, y: 960.271),
            control2: CGPoint(x: 1245.79, y: 1095.34)
        )
        path.addCurve(
            to: CGPoint(x: 688.744, y: 722.416),
            control1: CGPoint(x: 855.369, y: 1095.34),
            control2: CGPoint(x: 688.744, y: 928.361)
        )
        path.addCurve(
            to: CGPoint(x: 1060.94, y: 349.493),
            control1: CGPoint(x: 688.744, y: 516.47),
            control2: CGPoint(x: 855.369, y: 349.493)
        )
        path.addCurve(
            to: CGPoint(x: 1429.68, y: 671.743),
            control1: CGPoint(x: 1249.33, y: 349.493),
            control2: CGPoint(x: 1405.01, y: 489.756)
        )
        path.addLine(to: CGPoint(x: 1426.17, y: 671.743))
        path.addCurve(
            to: CGPoint(x: 1247.08, y: 536.02),
            control1: CGPoint(x: 1404.12, y: 593.437),
            control2: CGPoint(x: 1332.3, y: 536.02)
        )
        path.addCurve(
            to: CGPoint(x: 1061.07, y: 722.416),
            control1: CGPoint(x: 1144.36, y: 536.02),
            control2: CGPoint(x: 1061.07, y: 619.469)
        )
        path.addCurve(
            to: CGPoint(x: 1247.08, y: 908.811),
            control1: CGPoint(x: 1061.07, y: 825.362),
            control2: CGPoint(x: 1144.36, y: 908.811)
        )
        path.addCurve(
            to: CGPoint(x: 1422.95, y: 783.297),
            control1: CGPoint(x: 1328.56, y: 908.811),
            control2: CGPoint(x: 1397.78, y: 856.354)
        )
        path.closeSubpath()

        return path
    }
}

/// Simple circle-based approximation for performance
/// Good for small sizes and animations
struct ZoeLogoSimple: View {
    var size: CGFloat = 100
    var color: Color = Color(red: 0.96, green: 0.90, blue: 0.83) // #F5E6D3 warm cream

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width, geometry.size.height) / 100

            ZStack {
                // Outer crescent (large moon)
                CrescentShape(
                    innerCircleOffset: CGSize(width: 22 * scale, height: -2 * scale),
                    innerRadiusRatio: 0.74
                )
                .fill(color)
                .frame(width: 90 * scale, height: 90 * scale)
                .offset(x: -5 * scale, y: 0)

                // Inner crescent (small moon, creating spiral)
                CrescentShape(
                    innerCircleOffset: CGSize(width: 16 * scale, height: -2 * scale),
                    innerRadiusRatio: 0.56
                )
                .fill(color)
                .frame(width: 52 * scale, height: 52 * scale)
                .offset(x: 18 * scale, y: 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(width: size, height: size)
    }
}

/// Crescent moon shape helper
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
    var logoColor: Color = Color(red: 0.96, green: 0.90, blue: 0.83) // #F5E6D3 warm cream
    var textColor: Color = .white
    var spacing: CGFloat = 16

    var body: some View {
        HStack(spacing: spacing) {
            Text("Zoé")
                .font(.system(size: fontSize, weight: .light, design: .default))
                .foregroundColor(textColor)

            ZoeLogoSVG(size: logoSize, color: logoColor)
        }
    }
}

/// Preview provider
#Preview("Logo Variations") {
    VStack(spacing: 40) {
        // SVG-accurate logo
        ZoeLogoSVG(size: 100)
            .background(Color.black.opacity(0.8))

        // Simple approximation
        ZoeLogoSimple(size: 100)
            .background(Color.black.opacity(0.8))

        // Logo with text (like in the PDF)
        ZoeLogoWithText(logoSize: 60, fontSize: 36)
            .padding()
            .background(Color(red: 0.05, green: 0.04, blue: 0.03))
            .cornerRadius(16)

        // Different sizes
        HStack(spacing: 20) {
            ZoeLogoSVG(size: 40)
            ZoeLogoSVG(size: 60)
            ZoeLogoSVG(size: 80)
        }
        .padding()
        .background(Color(red: 0.1, green: 0.08, blue: 0.05))
        .cornerRadius(12)

        // App icon preview (with background matching icon)
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.08, blue: 0.07),
                    Color(red: 0.05, green: 0.04, blue: 0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            ZoeLogoSVG(size: 60, color: Color(red: 0.96, green: 0.90, blue: 0.83))
        }
        .frame(width: 100, height: 100)
        .cornerRadius(22)
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
