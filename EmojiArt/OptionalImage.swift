//
//  OptionalImage.swift
//  EmojiArt
//
//  Created by Dmitry Reshetnik on 19.03.2021.
//

import SwiftUI

struct OptionalImage: View {
    var uiImage: UIImage?
    
    var body: some View {
        Group {
            if uiImage != nil {
                Image(uiImage: uiImage!)
            }
        }
    }
}
