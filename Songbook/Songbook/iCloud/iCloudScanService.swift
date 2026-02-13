import Foundation

enum iCloudScanService {

    /// Scans a single folder level — no recursion. Call again when the user navigates into a subfolder.
    static func scanShallow(at url: URL) async throws -> FolderNode {
        try await Task.detached {
            try _scanShallow(at: url)
        }.value
    }

    /// Lists immediate children of a folder. Each child is checked for .songbook (song vs category).
    private nonisolated static func _scanShallow(at url: URL) throws -> FolderNode {
        print("[Scan] Scanning folder: \(url.path)")

        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
        } catch {
            print("[Scan] ERROR listing contents of \(url.path): \(error)")
            throw error
        }

        print("[Scan] Found \(contents.count) items in \(url.lastPathComponent)")
        for item in contents {
            let vals = try? item.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            print("[Scan]   - \(item.lastPathComponent) (isDir=\(vals?.isDirectory ?? false), isPkg=\(vals?.isPackage ?? false))")
        }

        let subdirectories = contents
            .filter { child in
                guard let vals = try? child.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]) else { return false }
                return vals.isDirectory == true && vals.isPackage != true
            }

        print("[Scan] \(subdirectories.count) subdirectories after filtering")

        let children: [FolderNode] = subdirectories.compactMap { dir in
            // Check if this child folder contains a .songbook file
            if let songbookURL = findSongbookFile(in: dir) {
                print("[Scan]   \(dir.lastPathComponent) -> SONG (file: \(songbookURL.lastPathComponent))")
                let songFile = try? readSongFile(at: songbookURL)
                return FolderNode(name: dir.lastPathComponent, url: dir, children: [], songFile: songFile)
            }
            print("[Scan]   \(dir.lastPathComponent) -> FOLDER")
            return FolderNode(name: dir.lastPathComponent, url: dir, children: [])
        }
        .sorted { a, b in
            let dateA = a.songFile?.updatedAt ?? (try? a.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let dateB = b.songFile?.updatedAt ?? (try? b.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return dateA > dateB
        }

        print("[Scan] Result: \(children.count) children (\(children.filter { $0.isSong }.count) songs, \(children.filter { !$0.isSong }.count) folders)")
        return FolderNode(
            name: url.lastPathComponent,
            url: url,
            children: children
        )
    }

    /// Finds the first `.songbook` file in a directory's contents.
    private nonisolated static func findSongbookFile(in folderURL: URL) -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            print("[Scan] findSongbookFile: could not list contents of \(folderURL.lastPathComponent)")
            return nil
        }
        let songbookFiles = contents.filter { $0.pathExtension == "songbook" }
        if !songbookFiles.isEmpty {
            print("[Scan] findSongbookFile: found \(songbookFiles.map { $0.lastPathComponent }) in \(folderURL.lastPathComponent)")
        }
        return songbookFiles.first
    }

    /// Returns the canonical songbook file URL for a folder: `<folderName>.songbook`
    private nonisolated static func songbookFileURL(in folderURL: URL) -> URL {
        let name = folderURL.lastPathComponent
        return folderURL.appendingPathComponent("\(name).songbook")
    }

    private nonisolated static func readSongFile(at url: URL) throws -> SongFile {
        let data = try Data(contentsOf: url)
        var songFile = try SongFile.decoder.decode(SongFile.self, from: data)
        songFile.fileURL = url
        return songFile
    }

    static func writeSongFile(_ songFile: SongFile, to folderURL: URL) async throws {
        try await Task.detached {
            let songbookURL = songbookFileURL(in: folderURL)
            print("[Write] Writing songbook file to: \(songbookURL.path)")
            let data = try SongFile.encoder.encode(songFile)
            try data.write(to: songbookURL, options: .atomic)
            print("[Write] Success: \(songbookURL.lastPathComponent)")
        }.value
    }

    static func createSongFolder(titled title: String, in parentURL: URL) async throws -> SongFile {
        try await Task.detached {
            let sanitized = title.replacingOccurrences(of: "/", with: "-")
            let folderURL = parentURL.appendingPathComponent(sanitized)
            print("[CreateSong] Creating folder: \(folderURL.path)")
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            let fileURL = songbookFileURL(in: folderURL)
            print("[CreateSong] Writing songbook file: \(fileURL.path)")
            let songFile = SongFile(title: title, fileURL: fileURL)
            let data = try SongFile.encoder.encode(songFile)
            try data.write(to: fileURL, options: .atomic)
            print("[CreateSong] Success: \(fileURL.lastPathComponent)")
            return songFile
        }.value
    }

    static func makeSongInPlace(at folderURL: URL) async throws -> SongFile {
        try await Task.detached {
            let title = folderURL.lastPathComponent
            let fileURL = songbookFileURL(in: folderURL)
            print("[MakeSong] Creating songbook file at: \(fileURL.path)")
            let songFile = SongFile(title: title, fileURL: fileURL)
            let data = try SongFile.encoder.encode(songFile)
            try data.write(to: fileURL, options: .atomic)
            let exists = FileManager.default.fileExists(atPath: fileURL.path)
            print("[MakeSong] Success: \(fileURL.lastPathComponent), verified exists: \(exists)")
            return songFile
        }.value
    }

    static func deleteSongFolder(at url: URL) async throws {
        try await Task.detached {
            try FileManager.default.removeItem(at: url)
        }.value
    }
}
