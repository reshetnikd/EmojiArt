//
//  EmojiArt.swift
//  EmojiArt
//
//  Created by Dmitry Reshetnik on 17.03.2021.
//

import Foundation

struct EmojiArt: Codable {
    struct Emoji: Identifiable, Codable, Hashable {
        let text: String
        let id: Int
        var x: Int // offset from center
        var y: Int // offset from center
        var size: Int
        
        fileprivate init(text: String, id: Int, x: Int, y: Int, size: Int) {
            self.text = text
            self.id = id
            self.x = x
            self.y = y
            self.size = size
        }
    }
    
    private var uniqueEmojiID = 0
    
    var backgroundURL: URL?
    var emojis: [Emoji] = []
    
    var json: Data? {
        try? JSONEncoder().encode(self)
    }
    
    init() {
        // memberwise initializer
    }
    
    init?(json: Data?) {
        if json != nil, let newEmojiArt = try? JSONDecoder().decode(EmojiArt.self, from: json!) {
            self = newEmojiArt
        } else {
            return nil
        }
    }
    
    mutating func addEmoji(_ text: String, x: Int, y: Int, size: Int) {
        uniqueEmojiID += 1
        emojis.append(Emoji(text: text, id: uniqueEmojiID, x: x, y: y, size: size))
    }
}
