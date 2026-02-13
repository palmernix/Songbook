import Foundation

enum PersistenceMode: String, CaseIterable {
    case swiftData
    case iCloud
}

@Observable
final class SettingsStore {
    private static let modeKey = "persistenceMode"
    private static let bookmarkKey = "iCloudBookmark"

    var persistenceMode: PersistenceMode {
        didSet { UserDefaults.standard.set(persistenceMode.rawValue, forKey: Self.modeKey) }
    }

    private(set) var bookmarkData: Data? {
        didSet { UserDefaults.standard.set(bookmarkData, forKey: Self.bookmarkKey) }
    }

    private(set) var isBookmarkStale = false

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.modeKey) ?? PersistenceMode.swiftData.rawValue
        self.persistenceMode = PersistenceMode(rawValue: raw) ?? .swiftData
        self.bookmarkData = UserDefaults.standard.data(forKey: Self.bookmarkKey)
    }

    func saveBookmark(for url: URL) {
        let gained = url.startAccessingSecurityScopedResource()
        defer { if gained { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            bookmarkData = data
            isBookmarkStale = false
        } catch {
            print("Failed to save bookmark: \(error)")
        }
    }

    func resolveBookmark() -> URL? {
        guard let data = bookmarkData else { return nil }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
            isBookmarkStale = stale
            if stale {
                // Try to re-save if we still have access
                saveBookmark(for: url)
            }
            return url
        } catch {
            print("Failed to resolve bookmark: \(error)")
            isBookmarkStale = true
            return nil
        }
    }

    var folderName: String? {
        resolveBookmark()?.lastPathComponent
    }
}
