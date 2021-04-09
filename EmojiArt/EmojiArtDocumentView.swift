//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Dmitry Reshetnik on 17.03.2021.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    @GestureState private var gestureZoomScaleForEmoji: CGFloat = 1.0
    @GestureState private var gestureZoomScale: CGFloat = 1.0
    @GestureState private var gesturePanOffset: CGSize = .zero
    @GestureState private var gestureEmojiOffset: CGSize = .zero
    @GestureState private var isDetectingLongPress: Bool = false
    @State private var selectedEmojis: Set<EmojiArt.Emoji> = []
    @State private var chosenPalette: String = ""
    @State private var explainBackgroundPaste: Bool = false
    @State private var confirmBackgroundPaste: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    private let defaultEmojiSize: CGFloat = 40.0
    
    private var zoomScale: CGFloat {
        document.steadyStateZoomScale * gestureZoomScale
    }
    
    private var panOffset: CGSize {
        (document.steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private var pickImage: some View {
        HStack {
            Image(systemName: "photo").imageScale(.large).foregroundColor(.accentColor).onTapGesture {
                imagePickerSourceType = .photoLibrary
                showImagePicker = true
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Image(systemName: "camera").imageScale(.large).foregroundColor(.accentColor).onTapGesture {
                    imagePickerSourceType = .camera
                    showImagePicker = true
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: imagePickerSourceType) { image in
                if image != nil {
                    DispatchQueue.main.async {
                        document.backgroundURL = image!.storeInFilesystem()
                    }
                }
                
                showImagePicker = false
            }
        }
    }
    
    var isLoading: Bool {
        document.backgroundURL != nil && document.backgroundImage == nil
    }
    
    var body: some View {
        VStack {
            HStack {
                PaletteChooser(document: document, chosenPalette: $chosenPalette)
                
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(chosenPalette.map { String($0) }, id: \.self) { emoji in
                            Text(emoji)
                                .font(Font.system(size: defaultEmojiSize))
                                .onDrag {
                                    NSItemProvider(object: emoji as NSString)
                                }
                        }
                    }
                }
                .onAppear {
                    chosenPalette = document.defaultPalette
                }
            }
            
            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .foregroundColor(.white)
                        .overlay(OptionalImage(uiImage: document.backgroundImage).scaleEffect(zoomScale).offset(panOffset))
                        .gesture(doubleTapToZoom(in: geometry.size).exclusively(before: tapToDeselectAllEmojis()))
                    
                    if isLoading {
                        Image(systemName: "hourglass").imageScale(.large).spinning()
                    } else {
                        ForEach(document.emojis) { emoji in
                            Text(emoji.text)
                                .border(inSelected(emoji) ? Color.black : Color.clear)
                                .font(animatableWithSize: emoji.fontSize * zoomScale)
                                .position(position(for: emoji, in: geometry.size))
                                .opacity(isDetectingLongPress ? 0.4 : 1.0)
                                .gesture(tapToSelectEmoji(emoji).simultaneously(with: longPressToDelete(emoji)))
                                .gesture(dragSelectedEmoji(for: emoji))
                        }
                    }
                }
                .clipped()
                .gesture(zoomGesture())
                .gesture(panGesture())
                .edgesIgnoringSafeArea([.horizontal, .bottom])
                .onReceive(document.$backgroundImage) { image in
                    zoomToFit(image, in: geometry.size)
                }
                .onDrop(of: ["public.image", "public.text"], isTargeted: nil) { providers, location in
                    var location = geometry.convert(location, from: .global)
                    location = CGPoint(x: location.x - geometry.size.width/2, y: location.y - geometry.size.height/2)
                    location = CGPoint(x: location.x - panOffset.width, y: location.y - panOffset.height)
                    location = CGPoint(x: location.x / zoomScale, y: location.y / zoomScale)
                    return drop(providers: providers, at: location)
                }
                .navigationBarItems(leading: pickImage, trailing: Button(action: {
                    if let url = UIPasteboard.general.url, url != document.backgroundURL {
                        confirmBackgroundPaste = true
                    } else {
                        explainBackgroundPaste = true
                    }
                }, label: {
                    Image(systemName: "doc.on.clipboard")
                        .imageScale(.large)
                        .alert(isPresented: $explainBackgroundPaste) {
                            Alert(
                                title: Text("Paste Background"),
                                message: Text("Copy the URL of on image to the clip board and touch this button to make it the background of your document."),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                }))
            }
            .zIndex(-1)
        }
        .alert(isPresented: $confirmBackgroundPaste) {
            Alert(
                title: Text("Paste Background"),
                message: Text("Replace your background with \(UIPasteboard.general.url?.absoluteString ?? "nothing")?"),
                primaryButton: .default(Text("OK")) {
                    document.backgroundURL = UIPasteboard.general.url
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func dragSelectedEmoji(for emoji: EmojiArt.Emoji) -> some Gesture {
        DragGesture()
            .updating($gestureEmojiOffset) { latestDragGestureValue, gestureEmojiOffset, transaction in
                gestureEmojiOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                let translation = finalDragGestureValue.translation / zoomScale
                document.moveEmoji(emoji, by: translation)
            }
    }
    
    private func longPressToDelete(_ emoji: EmojiArt.Emoji) -> some Gesture {
        LongPressGesture(minimumDuration: 2.0)
            .updating($isDetectingLongPress) { currentState, gestureState, transaction in
                gestureState = currentState
            }
            .onEnded { _ in
                document.removeEmoji(emoji)
            }
    }
    
    private func tapToSelectEmoji(_ emoji: EmojiArt.Emoji) -> some Gesture {
        TapGesture()
            .onEnded {
                withAnimation {
                    selectedEmojis.toggleMathing(emoji)
                }
            }
    }
    
    private func tapToDeselectAllEmojis() -> some Gesture {
        TapGesture()
            .onEnded {
                withAnimation {
                    selectedEmojis.removeAll()
                }
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, transaction in
                gesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                document.steadyStatePanOffset = document.steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating(selectedEmojis.isEmpty ? $gestureZoomScale : $gestureZoomScaleForEmoji) { latestGestureScale, gestureZoomScale, transaction in
                gestureZoomScale = latestGestureScale
            }
            .onEnded { finalGestureScale in
                if selectedEmojis.isEmpty {
                    document.steadyStateZoomScale *= finalGestureScale
                } else {
                    selectedEmojis.forEach { (emoji) in
                        document.scaleEmoji(emoji, by: finalGestureScale)
                    }
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            document.steadyStatePanOffset = .zero
            document.steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    private func inSelected(_ emoji: EmojiArt.Emoji) -> Bool {
        selectedEmojis.contains(matching: emoji)
    }
    
    private func position(for emoji: EmojiArt.Emoji, in size: CGSize) -> CGPoint {
        var location = emoji.location
        location = CGPoint(x: location.x * zoomScale, y: location.y * zoomScale)
        location = CGPoint(x: location.x + size.width/2, y: location.y + size.height/2)
        location = CGPoint(x: location.x + panOffset.width, y: location.y + panOffset.height)
        
        if inSelected(emoji) {
            location = CGPoint(x: location.x + gestureEmojiOffset.width, y: location.y + gestureEmojiOffset.height)
        }
        return location
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var found = providers.loadFirstObject(ofType: URL.self) { url in
            document.backgroundURL = url
        }
        
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                document.addEmoji(string, at: location, size: defaultEmojiSize)
            }
        }
        return found
    }
}
