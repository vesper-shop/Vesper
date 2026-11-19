#if os(iOS)
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The system camera. The shot is returned as JPEG carrying the camera's metadata, orientation
/// included, so publication reads it the way it reads a library photo.
struct Camera: UIViewControllerRepresentable {
    let capture: (Data) -> Void
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> CameraCoordinator {
        CameraCoordinator(camera: self)
    }
}

final class CameraCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let camera: Camera

    init(camera: Camera) {
        self.camera = camera
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.originalImage] as! UIImage
        let metadata = info[.mediaMetadata] as! [CFString: Any]
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image.cgImage!, metadata as CFDictionary)
        CGImageDestinationFinalize(destination)
        camera.capture(data as Data)
        camera.dismiss()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        camera.dismiss()
    }
}
#endif
