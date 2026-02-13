import SwiftUI

struct BrowseView: View {
    var settingsStore: SettingsStore

    @Environment(EditorCoordinator.self) private var coordinator
    @State private var showSettings = false
    @State private var showFolderPicker = false

    var body: some View {
        Group {
            if let url = coordinator.currentFolderURL {
                BrowseFolderView(
                    folderURL: url,
                    folderName: url.lastPathComponent,
                    isRoot: !coordinator.isInSubfolder,
                    showSettings: $showSettings
                )
                .id(url)
            } else {
                noFolderState
            }
        }
        .onAppear { resolveURL() }
        .onChange(of: settingsStore.bookmarkData) { resolveURL() }
        .sheet(isPresented: $showSettings) {
            SettingsView(settingsStore: settingsStore)
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView { url in
                settingsStore.saveBookmark(for: url)
                resolveURL()
            }
        }
    }

    private func resolveURL() {
        guard let url = settingsStore.resolveBookmark() else {
            print("[BrowseView] resolveBookmark returned nil")
            coordinator.folderStack = []
            return
        }
        let gained = url.startAccessingSecurityScopedResource()
        print("[BrowseView] Resolved URL: \(url.path), securityAccess=\(gained)")
        coordinator.setRootFolder(url)
    }

    private var noFolderState: some View {
        ZStack {
            Color.warmBg.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("Songbook")
                        .font(.custom("Cochin", size: 36))

                    HStack {
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                                .font(.body)
                                .foregroundStyle(Color.darkInk.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 14)

                Rectangle()
                    .fill(Color.darkInk.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 24)

                Spacer()

                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.darkInk.opacity(0.2))
                    .padding(.bottom, 16)

                Button("Select iCloud Drive Folder") {
                    showFolderPicker = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.darkInk)

                Spacer()
            }
        }
    }

}

// MARK: - BrowseFolderView

struct BrowseFolderView: View {
    let folderURL: URL
    let folderName: String
    let isRoot: Bool
    @Binding var showSettings: Bool

    @Environment(EditorCoordinator.self) private var coordinator
    @State private var node: FolderNode?
    @State private var isLoading = true
    @State private var showNewSheet = false
    @State private var showDeleteConfirm = false
    @State private var nodeToDelete: FolderNode?
    @State private var newSongTitle = ""
    @State private var folderHasSongFile = false

    private var isEmpty: Bool {
        node?.children.isEmpty ?? true
    }

    var body: some View {
        ZStack {
            Color.warmBg.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(Color.darkInk)
            } else {
                VStack(spacing: 0) {
                    header
                    divider

                    if isEmpty {
                        emptyState
                    } else {
                        songList
                    }
                }
            }
        }
        .foregroundStyle(Color.darkInk)
        .task {
            await loadFolder()
        }
        .sheet(isPresented: $showNewSheet) {
            newSongSheet
        }
        .alert("Delete Song?", isPresented: $showDeleteConfirm, presenting: nodeToDelete) { toDelete in
            Button("Delete", role: .destructive) {
                Task {
                    try? await iCloudScanService.deleteSongFolder(at: toDelete.url)
                    await loadFolder()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { toDelete in
            Text("This will permanently delete \"\(toDelete.name)\" and its contents.")
        }
    }

    private func loadFolder() async {
        print("[BrowseFolderView] loadFolder called for: \(folderURL.path)")
        do {
            let result = try await iCloudScanService.scanShallow(at: folderURL)
            print("[BrowseFolderView] scan complete: \(result.children.count) children, isEmpty=\(result.children.isEmpty)")
            node = result
        } catch {
            print("[BrowseFolderView] scan error: \(error)")
            node = nil
        }
        isLoading = false

        let contents = try? FileManager.default.contentsOfDirectory(
            at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        folderHasSongFile = contents?.contains(where: { $0.pathExtension == "songbook" }) ?? false
    }

    private var header: some View {
        ZStack {
            Text(folderName)
                .font(.custom("Cochin", size: isRoot ? 36 : 30))
                .lineLimit(1)

            HStack {
                if !isRoot {
                    Button { coordinator.navigateBackFromFolder() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.darkInk)
                    }
                }

                Spacer()

                if isRoot {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .foregroundStyle(Color.darkInk.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.darkInk.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundStyle(Color.darkInk.opacity(0.2))

            if !folderHasSongFile {
                Button("Make This a Song") {
                    print("[BrowseFolderView] 'Make This a Song' tapped for: \(folderURL.path)")
                    Task {
                        do {
                            let result = try await iCloudScanService.makeSongInPlace(at: folderURL)
                            print("[BrowseFolderView] makeSongInPlace succeeded: \(result.title)")
                            coordinator.openSong(result, folderURL: folderURL)
                        } catch {
                            print("[BrowseFolderView] makeSongInPlace FAILED: \(error)")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.darkInk)
                .foregroundStyle(.white)
            }
            Spacer()
        }
    }

    private var songList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                Button { showNewSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.darkInk.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Song")

                ForEach(node?.children ?? []) { child in
                    if child.isSong {
                        Button {
                            if let sf = child.songFile {
                                coordinator.openSong(sf, folderURL: child.url)
                            }
                        } label: {
                            SongCard(
                                title: child.songFile?.title ?? child.name,
                                updatedAt: child.songFile?.updatedAt ?? Date()
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                nodeToDelete = child
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } else {
                        Button {
                            coordinator.navigateToFolder(child.url)
                        } label: {
                            FolderCard(name: child.name, itemCount: child.children.count)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private var newSongSheet: some View {
        NavigationStack {
            List {
                if !folderHasSongFile {
                    Button {
                        print("[Sheet] 'Make This a Song' tapped for: \(folderURL.path)")
                        Task {
                            do {
                                let result = try await iCloudScanService.makeSongInPlace(at: folderURL)
                                print("[Sheet] makeSongInPlace succeeded: \(result.title)")
                                coordinator.openSong(result, folderURL: folderURL)
                            } catch {
                                print("[Sheet] makeSongInPlace FAILED: \(error)")
                            }
                            showNewSheet = false
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Make This a Song")
                                    .font(.body.weight(.medium))
                                Text("Add a .songbook file to this folder")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "music.note")
                        }
                    }
                }

                Section {
                    TextField("Song title", text: $newSongTitle)
                        .textInputAutocapitalization(.words)

                    Button {
                        let title = newSongTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty else { return }
                        Task {
                            do {
                                let sanitized = title.replacingOccurrences(of: "/", with: "-")
                                let songFolderURL = folderURL.appendingPathComponent(sanitized)
                                let result = try await iCloudScanService.createSongFolder(titled: title, in: folderURL)
                                coordinator.openSong(result, folderURL: songFolderURL)
                            } catch {
                                print("[Sheet] createSongFolder FAILED: \(error)")
                            }
                            newSongTitle = ""
                            await loadFolder()
                            showNewSheet = false
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("New Song")
                                    .font(.body.weight(.medium))
                                Text("Create a new folder with a .songbook file")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "folder.badge.plus")
                        }
                    }
                    .disabled(newSongTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showNewSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
