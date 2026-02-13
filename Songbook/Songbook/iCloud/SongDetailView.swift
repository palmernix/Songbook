import SwiftUI

struct SongDetailView: View {
    let folderURL: URL
    @State var songFile: SongFile

    @Environment(EditorCoordinator.self) private var coordinator
    @State private var showNewEntrySheet = false
    @State private var navigationPath = NavigationPath()

    init(folderURL: URL, initialSongFile: SongFile) {
        self.folderURL = folderURL
        self._songFile = State(initialValue: initialSongFile)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.warmBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    divider

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            addButton
                            entryGrid
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationBarHidden(true)
            .foregroundStyle(Color.darkInk)
            .navigationDestination(for: SongEntry.ID.self) { entryID in
                if let index = songFile.entries.firstIndex(where: { $0.id == entryID }) {
                    let entry = songFile.entries[index]
                    switch entry.type {
                    case .lyrics:
                        LyricsEntryEditor(songFile: $songFile, entryID: entryID, folderURL: folderURL)
                    case .notes:
                        NotesEntryEditor(songFile: $songFile, entryID: entryID, folderURL: folderURL)
                    case .audio:
                        AudioEntryEditor(songFile: $songFile, entryID: entryID, folderURL: folderURL)
                    case .video:
                        VideoEntryEditor(songFile: $songFile, entryID: entryID, folderURL: folderURL)
                    }
                }
            }
            .sheet(isPresented: $showNewEntrySheet) {
                newEntrySheet
            }
        }
    }

    private var header: some View {
        ZStack {
            Text(songFile.title)
                .font(.custom("Cochin", size: 30))
                .lineLimit(1)

            HStack {
                Button { coordinator.closeSong() } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.darkInk)
                }

                Spacer()
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

    private var addButton: some View {
        Button { showNewEntrySheet = true } label: {
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
        .accessibilityLabel("Add Entry")
    }

    private var entryGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(songFile.entries) { entry in
                Button {
                    navigationPath.append(entry.id)
                } label: {
                    EntryCard(entry: entry)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        deleteEntry(entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var newEntrySheet: some View {
        NavigationStack {
            List {
                Button {
                    addEntry(type: .lyrics, title: "Lyrics")
                    showNewEntrySheet = false
                } label: {
                    Label {
                        Text("New Lyrics")
                            .font(.body.weight(.medium))
                    } icon: {
                        Image(systemName: "text.quote")
                    }
                }

                Button {
                    addEntry(type: .notes, title: "Notes")
                    showNewEntrySheet = false
                } label: {
                    Label {
                        Text("New Notes")
                            .font(.body.weight(.medium))
                    } icon: {
                        Image(systemName: "note.text")
                    }
                }

                Button {
                    addEntry(type: .audio, title: "Audio")
                    showNewEntrySheet = false
                } label: {
                    Label {
                        Text("New Audio")
                            .font(.body.weight(.medium))
                    } icon: {
                        Image(systemName: "waveform")
                    }
                }

                Button {
                    addEntry(type: .video, title: "Video")
                    showNewEntrySheet = false
                } label: {
                    Label {
                        Text("New Video")
                            .font(.body.weight(.medium))
                    } icon: {
                        Image(systemName: "video")
                    }
                }
            }
            .foregroundStyle(.white)
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showNewEntrySheet = false }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .presentationDetents([.fraction(0.39)])
        .scrollDisabled(true)
    }

    private func addEntry(type: EntryType, title: String) {
        let entry = SongEntry(type: type, title: title)
        songFile.entries.append(entry)
        songFile.updatedAt = Date()
        saveToDisk()
    }

    private func deleteEntry(_ entry: SongEntry) {
        songFile.entries.removeAll { $0.id == entry.id }
        songFile.updatedAt = Date()
        saveToDisk()
    }

    private func saveToDisk() {
        let copy = songFile
        let url = folderURL
        Task.detached {
            try? await iCloudScanService.writeSongFile(copy, to: url)
        }
    }
}

// MARK: - EntryCard

private struct EntryCard: View {
    let entry: SongEntry

    private var iconName: String {
        switch entry.type {
        case .lyrics: "text.quote"
        case .notes: "note.text"
        case .audio: "waveform"
        case .video: "video.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(Color.darkInk.opacity(0.4))

            Text(entry.title)
                .font(.system(.body, design: .serif, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(entry.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - LyricsEntryEditor

private struct LyricsEntryEditor: View {
    @Binding var songFile: SongFile
    let entryID: UUID
    let folderURL: URL

    private var entryIndex: Int? {
        songFile.entries.firstIndex(where: { $0.id == entryID })
    }

    var body: some View {
        if let index = entryIndex {
            LyricsView(
                title: $songFile.entries[index].title,
                text: $songFile.entries[index].text,
                onSave: {
                    songFile.entries[index].updatedAt = Date()
                    songFile.updatedAt = Date()
                    let copy = songFile
                    let url = folderURL
                    Task.detached {
                        try? await iCloudScanService.writeSongFile(copy, to: url)
                    }
                }
            )
        }
    }
}

// MARK: - NotesEntryEditor

private struct NotesEntryEditor: View {
    @Binding var songFile: SongFile
    let entryID: UUID
    let folderURL: URL

    private var entryIndex: Int? {
        songFile.entries.firstIndex(where: { $0.id == entryID })
    }

    var body: some View {
        if let index = entryIndex {
            NotesView(
                title: $songFile.entries[index].title,
                text: $songFile.entries[index].text,
                onSave: {
                    songFile.entries[index].updatedAt = Date()
                    songFile.updatedAt = Date()
                    let copy = songFile
                    let url = folderURL
                    Task.detached {
                        try? await iCloudScanService.writeSongFile(copy, to: url)
                    }
                }
            )
        }
    }
}

// MARK: - AudioEntryEditor

private struct AudioEntryEditor: View {
    @Binding var songFile: SongFile
    let entryID: UUID
    let folderURL: URL

    private var entryIndex: Int? {
        songFile.entries.firstIndex(where: { $0.id == entryID })
    }

    var body: some View {
        if let index = entryIndex {
            AudioView(
                title: $songFile.entries[index].title,
                audioData: $songFile.entries[index].audioData,
                onSave: {
                    songFile.entries[index].updatedAt = Date()
                    songFile.updatedAt = Date()
                    let copy = songFile
                    let url = folderURL
                    Task.detached {
                        try? await iCloudScanService.writeSongFile(copy, to: url)
                    }
                }
            )
        }
    }
}

// MARK: - VideoEntryEditor

private struct VideoEntryEditor: View {
    @Binding var songFile: SongFile
    let entryID: UUID
    let folderURL: URL

    private var entryIndex: Int? {
        songFile.entries.firstIndex(where: { $0.id == entryID })
    }

    var body: some View {
        if let index = entryIndex {
            VideoView(
                title: $songFile.entries[index].title,
                videoData: $songFile.entries[index].videoData,
                onSave: {
                    songFile.entries[index].updatedAt = Date()
                    songFile.updatedAt = Date()
                    let copy = songFile
                    let url = folderURL
                    Task.detached {
                        try? await iCloudScanService.writeSongFile(copy, to: url)
                    }
                }
            )
        }
    }
}
