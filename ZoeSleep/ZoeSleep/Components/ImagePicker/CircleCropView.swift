//
//  CircleCropView.swift
//  Zoe Sleep
//
//  Circle cropping view for profile pictures.
//  Supports pinch-to-zoom and pan gestures for positioning.
//

import SwiftUI

/// Circle crop view for creating circular profile pictures
struct CircleCropView: View {
    let image: UIImage
    @Binding var croppedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isProcessing = false

    private let cropSize: CGFloat = 280
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 3.0

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color.black.ignoresSafeArea()

                    // Image with gestures
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cropSize * scale, height: cropSize * scale)
                        .offset(offset)
                        .gesture(combinedGesture)

                    // Circular overlay mask
                    CircularCropOverlay(cropSize: cropSize)

                    // Processing overlay
                    if isProcessing {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                }
            }
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        cropImage()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(theme.accent)
                    .disabled(isProcessing)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var combinedGesture: some Gesture {
        SimultaneousGesture(magnificationGesture, dragGesture)
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                // Constrain offset to prevent image from going too far
                constrainOffset()
                lastOffset = offset
            }
    }

    private func constrainOffset() {
        let maxOffset = (cropSize * scale - cropSize) / 2
        offset.width = min(max(offset.width, -maxOffset), maxOffset)
        offset.height = min(max(offset.height, -maxOffset), maxOffset)
    }

    private func cropImage() {
        isProcessing = true

        DispatchQueue.global(qos: .userInitiated).async {
            let cropped = performCircularCrop()

            DispatchQueue.main.async {
                self.croppedImage = cropped
                self.isProcessing = false
                self.dismiss()
            }
        }
    }

    private func performCircularCrop() -> UIImage? {
        // Target output size (400x400 for good quality)
        let outputSize: CGFloat = 400

        // Calculate the visible portion of the image
        let imageSize = CGSize(width: image.size.width, height: image.size.height)
        let aspectRatio = imageSize.width / imageSize.height

        // Calculate crop rect in image coordinates
        let scaledImageSize: CGSize
        if aspectRatio > 1 {
            scaledImageSize = CGSize(width: cropSize * scale * aspectRatio, height: cropSize * scale)
        } else {
            scaledImageSize = CGSize(width: cropSize * scale, height: cropSize * scale / aspectRatio)
        }

        // Calculate crop origin
        let cropOriginX = (scaledImageSize.width - cropSize) / 2 - offset.width
        let cropOriginY = (scaledImageSize.height - cropSize) / 2 - offset.height

        // Convert to image coordinates
        let scaleFactorX = imageSize.width / scaledImageSize.width
        let scaleFactorY = imageSize.height / scaledImageSize.height

        let cropRect = CGRect(
            x: cropOriginX * scaleFactorX,
            y: cropOriginY * scaleFactorY,
            width: cropSize * scaleFactorX,
            height: cropSize * scaleFactorY
        )

        // Perform the crop
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return nil
        }

        // Create circular mask
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        let circularImage = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: outputSize, height: outputSize)

            // Create circular clip path
            context.cgContext.addEllipse(in: rect)
            context.cgContext.clip()

            // Draw the cropped image
            UIImage(cgImage: cgImage).draw(in: rect)
        }

        return circularImage
    }
}

// MARK: - Circular Crop Overlay

struct CircularCropOverlay: View {
    let cropSize: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2

            // Create a shape with a circular hole
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geometry.size))
                path.addEllipse(in: CGRect(
                    x: centerX - cropSize / 2,
                    y: centerY - cropSize / 2,
                    width: cropSize,
                    height: cropSize
                ))
            }
            .fill(style: FillStyle(eoFill: true))
            .foregroundColor(.black.opacity(0.6))

            // Circle border
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropSize, height: cropSize)
                .position(x: centerX, y: centerY)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview {
    CircleCropView(
        image: UIImage(systemName: "person.fill")!,
        croppedImage: .constant(nil)
    )
    .environmentObject(ThemeManager.shared)
}
