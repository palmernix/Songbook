import Foundation

enum EntryType: String, Codable {
    case lyrics
    case notes
    case audio
}

struct SongEntry: Identifiable, Hashable, Codable {
    var id: UUID
    var type: EntryType
    var title: String
    var text: String
    var audioData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), type: EntryType, title: String, text: String = "", audioData: Data? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.type = type
        self.title = title
        self.text = text
        self.audioData = audioData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct SongFile: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var entries: [SongEntry]
    var createdAt: Date
    var updatedAt: Date
    var fileURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, title, entries, createdAt, updatedAt
        case text // legacy
    }

    init(id: UUID = UUID(), title: String, entries: [SongEntry]? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), fileURL: URL? = nil) {
        self.id = id
        self.title = title
        self.entries = entries ?? [SongEntry(type: .lyrics, title: "Lyrics")]
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.fileURL = fileURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        fileURL = nil

        if let entries = try? container.decode([SongEntry].self, forKey: .entries) {
            self.entries = entries
        } else {
            let text = (try? container.decode(String.self, forKey: .text)) ?? ""
            self.entries = [SongEntry(type: .lyrics, title: "Lyrics", text: text, createdAt: createdAt, updatedAt: updatedAt)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(entries, forKey: .entries)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
