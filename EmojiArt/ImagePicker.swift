//
//  ImagePicker.swift
//  EmojiArt
//
//  Created by Dmitry Reshetnik on 09.04.2021.
//

import SwiftUI
import UIKit

typealias PikedImageHandler = (UIImage?) -> Void

struct ImagePicker: UIViewControllerRepresentable {
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var handlePickedImage: PikedImageHandler
        
        init(handlePickedImage: @escaping PikedImageHandler) {
            self.handlePickedImage = handlePickedImage
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            handlePickedImage(info[.originalImage] as? UIImage)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            handlePickedImage(nil)
        }
    }
    
    var sourceType: UIImagePickerController.SourceType
    var handlePickedImage: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // stub
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(handlePickedImage: handlePickedImage)
    }
}
