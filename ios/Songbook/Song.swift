import Foundation
import SwiftData

@Model
final class Song {
    @Attribute(.unique) var id: UUID
    var title: String
    var text: String = ""
    var entries: [SongEntry] = []
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, entries: [SongEntry]? = nil) {
        self.id = id
        self.title = title
        self.text = ""
        self.entries = entries ?? [SongEntry(type: .lyrics, title: "Lyrics")]
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
