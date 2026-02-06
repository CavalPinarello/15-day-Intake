//
//  ProfileImagePicker.swift
//  Zoe Sleep
//
//  Image picker component supporting photo library and camera (selfie).
//  Uses PHPickerViewController for library and UIImagePickerController for camera.
//

import SwiftUI
import PhotosUI
import AVFoundation

/// Profile image picker with options for photo library and camera
struct ProfileImagePicker: View {
    @Binding var selectedImage: UIImage?
    @State private var showingActionSheet = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        Button(action: {
            showingActionSheet = true
        }) {
            // This view is typically embedded in the avatar view
            EmptyView()
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showingActionSheet) {
            Button("Photo Library") {
                checkPhotoLibraryPermission()
            }
            Button("Take Selfie") {
                checkCameraPermission()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoLibraryPicker(selectedImage: $selectedImage)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(selectedImage: $selectedImage)
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(permissionAlertMessage)
        }
    }

    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            showingPhotoPicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        showingPhotoPicker = true
                    } else {
                        permissionAlertMessage = "Please allow access to your photos in Settings to select a profile picture."
                        showingPermissionAlert = true
                    }
                }
            }
        default:
            permissionAlertMessage = "Please allow access to your photos in Settings to select a profile picture."
            showingPermissionAlert = true
        }
    }

    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        permissionAlertMessage = "Please allow camera access in Settings to take a selfie."
                        showingPermissionAlert = true
                    }
                }
            }
        default:
            permissionAlertMessage = "Please allow camera access in Settings to take a selfie."
            showingPermissionAlert = true
        }
    }
}

// MARK: - Photo Library Picker

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker

        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let result = results.first else { return }

            result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image
                    }
                }
            }
        }
    }
}

// MARK: - Camera Picker

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front  // Front camera for selfie
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.dismiss()

            if let image = info[.originalImage] as? UIImage {
                DispatchQueue.main.async {
                    self.parent.selectedImage = image
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
