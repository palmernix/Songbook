import SwiftUI

@Observable
class EditorCoordinator {
    var songFile: SongFile?
    var folderURL: URL?
    var rootFolderURL: URL?

    func setRootFolder(_ url: URL) {
        if rootFolderURL != url {
            rootFolderURL = url
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
        ZStack {
            BrowseView(settingsStore: settingsStore)

            if let songFile = coordinator.songFile,
               let folderURL = coordinator.folderURL {
                SongDetailView(folderURL: folderURL, initialSongFile: songFile)
                    .id(songFile.id)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }
        }
        .environment(coordinator)
    }
}
