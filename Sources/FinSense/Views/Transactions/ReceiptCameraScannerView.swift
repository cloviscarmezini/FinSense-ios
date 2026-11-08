// Sources/FinSense/Views/Transactions/ReceiptCameraScannerView.swift
import SwiftUI
import UIKit
import PhotosUI

public struct ReceiptCameraScannerView: UIViewControllerRepresentable {
    public var onImageCaptured: (UIImage) -> Void
    public var onCancel: () -> Void

    public init(
        onImageCaptured: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onImageCaptured = onImageCaptured
        self.onCancel = onCancel
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = context.coordinator
            return picker
        } else {
            // Em simulador ou sem câmera, usa galeria de fotos como fallback
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    public final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        let parent: ReceiptCameraScannerView

        init(parent: ReceiptCameraScannerView) {
            self.parent = parent
        }

        // UIImagePickerControllerDelegate
        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            } else {
                parent.onCancel()
            }
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }

        // PHPickerViewControllerDelegate
        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                parent.onCancel()
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self?.parent.onImageCaptured(image)
                    } else {
                        self?.parent.onCancel()
                    }
                }
            }
        }
    }
}
