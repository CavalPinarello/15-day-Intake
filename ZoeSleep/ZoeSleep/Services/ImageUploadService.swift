//
//  ImageUploadService.swift
//  Zoe Sleep
//
//  Service for handling image compression and upload to Convex storage.
//  Manages profile picture uploads for patients.
//

import UIKit

/// Service for uploading profile pictures to Convex storage
class ImageUploadService {
    static let shared = ImageUploadService()

    private let maxImageSize: CGFloat = 400  // Output size in pixels
    private let maxFileSizeKB: Int = 500     // Max file size in KB
    private let jpegQuality: CGFloat = 0.85  // Initial JPEG quality

    private init() {}

    // MARK: - Public Methods

    /// Upload a profile picture for the current user
    /// - Parameter image: The UIImage to upload
    /// - Returns: The URL of the uploaded image
    func uploadProfilePicture(_ image: UIImage) async throws -> String {
        // 1. Compress the image
        guard let compressedData = compressImage(image) else {
            throw ImageUploadError.compressionFailed
        }

        print("[ImageUpload] Compressed image size: \(compressedData.count / 1024) KB")

        // 2. Get upload URL from Convex
        let uploadUrl = try await ConvexService.shared.generateUploadUrl()
        print("[ImageUpload] Got upload URL")

        // 3. Upload to Convex storage
        let storageId = try await uploadToStorage(data: compressedData, uploadUrl: uploadUrl)
        print("[ImageUpload] Uploaded to storage with ID: \(storageId)")

        // 4. Save the profile picture reference
        let imageUrl = try await ConvexService.shared.saveProfilePicture(storageId: storageId)
        print("[ImageUpload] Saved profile picture URL: \(imageUrl)")

        return imageUrl
    }

    // MARK: - Private Methods

    /// Compress image to JPEG under max file size
    private func compressImage(_ image: UIImage) -> Data? {
        // First resize to target dimensions
        let resizedImage = resizeImage(image, targetSize: CGSize(width: maxImageSize, height: maxImageSize))

        // Try to compress with decreasing quality until under size limit
        var quality = jpegQuality
        var data = resizedImage.jpegData(compressionQuality: quality)

        while let imageData = data, imageData.count > maxFileSizeKB * 1024 && quality > 0.1 {
            quality -= 0.1
            data = resizedImage.jpegData(compressionQuality: quality)
            print("[ImageUpload] Reducing quality to \(quality), size: \(imageData.count / 1024) KB")
        }

        return data
    }

    /// Resize image maintaining aspect ratio
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size

        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        // Use the larger ratio to ensure image fills the target size
        let ratio = max(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { context in
            let origin = CGPoint(
                x: (targetSize.width - newSize.width) / 2,
                y: (targetSize.height - newSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: newSize))
        }

        return resized
    }

    /// Upload data to Convex storage URL
    private func uploadToStorage(data: Data, uploadUrl: String) async throws -> String {
        guard let url = URL(string: uploadUrl) else {
            throw ImageUploadError.invalidUploadUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageUploadError.uploadFailed
        }

        guard httpResponse.statusCode == 200 else {
            print("[ImageUpload] Upload failed with status: \(httpResponse.statusCode)")
            throw ImageUploadError.uploadFailed
        }

        // Parse response to get storage ID
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let storageId = json["storageId"] as? String else {
            throw ImageUploadError.invalidResponse
        }

        return storageId
    }
}

// MARK: - Error Types

enum ImageUploadError: LocalizedError {
    case compressionFailed
    case invalidUploadUrl
    case uploadFailed
    case invalidResponse
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress the image"
        case .invalidUploadUrl:
            return "Invalid upload URL received"
        case .uploadFailed:
            return "Failed to upload the image"
        case .invalidResponse:
            return "Invalid response from server"
        case .saveFailed:
            return "Failed to save the profile picture"
        }
    }
}
