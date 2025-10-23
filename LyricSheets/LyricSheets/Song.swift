import Foundation
import SwiftData

@Model
final class Song {
    @Attribute(.unique) var id: UUID
    var title: String
    var text: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, text: String = "") {
        self.id = id
        self.title = title
        self.text = text
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}