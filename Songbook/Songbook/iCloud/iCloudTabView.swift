import SwiftUI

@Observable
class EditorCoordinator {
    var songFile: SongFile?
    var folderURL: URL?
    var folderStack: [URL] = []

    var currentFolderURL: URL? { folderStack.last }
    var isInSubfolder: Bool { folderStack.count > 1 }

    func setRootFolder(_ url: URL) {
        if folderStack.isEmpty || folderStack.first != url {
            folderStack = [url]
        }
    }

    func navigateToFolder(_ url: URL) {
        withAnimation {
            folderStack.append(url)
        }
    }

    func navigateBackFromFolder() {
        guard folderStack.count > 1 else { return }
        withAnimation {
            folderStack.removeLast()
        }
    }

    func openSong(_ songFile: SongFile, folderURL: URL) {
        withAnimation {
            self.songFile = songFile
            self.folderURL = folderURL
        }
    }

    func closeSong() {
        withAnimation {
            songFile = nil
            folderURL = nil
        }
    }
}

struct iCloudTabView: View {
    var settingsStore: SettingsStore

    @State private var coordinator = EditorCoordinator()

    var body: some View {
        Group {
            if let songFile = coordinator.songFile,
               let folderURL = coordinator.folderURL {
                SongDetailView(folderURL: folderURL, initialSongFile: songFile)
                    .id(songFile.id)
                    .transition(.move(edge: .trailing))
            } else {
                BrowseView(settingsStore: settingsStore)
                    .transition(.move(edge: .leading))
            }
        }
        .environment(coordinator)
    }
}
