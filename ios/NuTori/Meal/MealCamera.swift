import Foundation
import NuToriCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// iOS の標準のカメラ（写真の撮影）。撮ったあとの「再撮影」「写真を使用」の段は標準のまま
struct MealCamera: UIViewControllerRepresentable {
    /// 「写真を使用」を押した。元の写真と、付帯情報から読んだ撮影時刻と時差
    let onUse: (_ original: Data, _ exif: PhotoExif) -> Void
    /// 撮らずに閉じた
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier]
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        var parent: MealCamera

        init(parent: MealCamera) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // 標準のカメラは、撮った写真を UIImage で、付帯情報を辞書で返すので、確かめて取り出す
            guard let image = info[.originalImage] as? UIImage,
                let original = image.jpegData(compressionQuality: 0.9)
            else {
                parent.onCancel()
                return
            }
            let exif =
                (info[.mediaMetadata] as? [String: Any]).map(PhotoMetadata.exif(fromProperties:))
                ?? PhotoExif.none
            parent.onUse(original, exif)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
