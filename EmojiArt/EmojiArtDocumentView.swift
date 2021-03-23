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
    @GestureState private var isDetectingLongPress: Bool = false
    @State private var steadyStateZoomScale: CGFloat = 1.0
    @State private var steadyStatePanOffset: CGSize = .zero
    @State private var selectedEmojis: Set<EmojiArt.Emoji> = []
    
    private let defaultEmojiSize: CGFloat = 40.0
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    // MARK: - Drawing Constants
    
    let radius: CGFloat = 8.0
    let width: CGFloat = 2.0
    
    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(EmojiArtDocument.palette.map { String($0) }, id: \.self) { emoji in
                        Text(emoji)
                            .font(Font.system(size: defaultEmojiSize))
                            .onDrag {
                                NSItemProvider(object: emoji as NSString)
                            }
                    }
                }
            }
            .padding(.horizontal)
            
            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .foregroundColor(.white)
                        .overlay(OptionalImage(uiImage: document.backgroundImage).scaleEffect(zoomScale).offset(panOffset))
                        .gesture(doubleTapToZoom(in: geometry.size).exclusively(before: tapToDeselectAllEmojis()))
                    
                    ForEach(document.emojis) { emoji in
                        Text(emoji.text)
                            .border(inSelected(emoji) ? Color.black : Color.clear)
                            .font(animatableWithSize: emoji.fontSize * zoomScale)
                            .position(position(for: emoji, in: geometry.size))
                            .opacity(isDetectingLongPress ? 0.4 : 1.0)
                            .gesture(tapToSelectEmoji(emoji).simultaneously(with: longPressToDelete(emoji)))
                    }
                }
                .clipped()
                .gesture(zoomGesture())
                .gesture(panGesture())
                .edgesIgnoringSafeArea([.horizontal, .bottom])
                .onDrop(of: ["public.image", "public.text"], isTargeted: nil) { providers, location in
                    var location = geometry.convert(location, from: .global)
                    location = CGPoint(x: location.x - geometry.size.width/2, y: location.y - geometry.size.height/2)
                    location = CGPoint(x: location.x - panOffset.width, y: location.y - panOffset.height)
                    location = CGPoint(x: location.x / zoomScale, y: location.y / zoomScale)
                    return drop(providers: providers, at: location)
                }
            }
        }
    }
    
    private func longPressToDelete(_ emoji: EmojiArt.Emoji) -> some Gesture {
        LongPressGesture(minimumDuration: 3.0)
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
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating(selectedEmojis.isEmpty ? $gestureZoomScale : $gestureZoomScaleForEmoji) { latestGestureScale, gestureZoomScale, transaction in
                gestureZoomScale = latestGestureScale
            }
            .onEnded { finalGestureScale in
                if selectedEmojis.isEmpty {
                    steadyStateZoomScale *= finalGestureScale
                } else {
                    selectedEmojis.forEach { (emoji) in
                        document.scaleEmoji(emoji, by: finalGestureScale)
                    }
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
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
        return location
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var found = providers.loadFirstObject(ofType: URL.self) { url in
            document.setBackgroundURL(url)
        }
        
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                document.addEmoji(string, at: location, size: defaultEmojiSize)
            }
        }
        return found
    }
}
