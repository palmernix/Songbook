import Foundation

struct FolderNode: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var children: [FolderNode]
    var songFile: SongFile?

    var isSong: Bool { songFile != nil }

    var allSongs: [FolderNode] {
        if isSong { return [self] }
        return children.flatMap { $0.allSongs }
    }
}

extension FolderNode: Hashable {
    static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
