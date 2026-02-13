import SwiftUI
import SwiftData

// MARK: - Coordinator

@Observable
private class SwiftDataCoordinator {
    var song: Song?

    func openSong(_ song: Song) {
        withAnimation {
            self.song = song
        }
    }

    func closeSong() {
        withAnimation {
            song = nil
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    @State private var coordinator = SwiftDataCoordinator()

    var body: some View {
        Group {
            if let song = coordinator.song {
                SwiftDataSongDetailView(song: song, coordinator: coordinator)
                    .id(song.id)
                    .transition(.move(edge: .trailing))
            } else {
                SwiftDataBrowseView(coordinator: coordinator)
                    .transition(.move(edge: .leading))
            }
        }
    }
}

// MARK: - Browse View

private struct SwiftDataBrowseView: View {
    var coordinator: SwiftDataCoordinator

    @Environment(\.modelContext) private var context
    @Query(sort: \Song.updatedAt, order: .reverse) private var songs: [Song]

    @State private var showNewSongSheet = false
    @State private var newTitle = ""

    var body: some View {
        ZStack {
            Color.warmBg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                divider

                ScrollView {
                    LazyVStack(spacing: 12) {
                        addButton

                        ForEach(songs) { song in
                            Button {
                                coordinator.openSong(song)
                            } label: {
                                SongCard(title: song.title, updatedAt: song.updatedAt)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive, action: { delete(song) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
        .foregroundStyle(Color.darkInk)
        .sheet(isPresented: $showNewSongSheet) {
            newSongSheet
        }
    }

    private var header: some View {
        Text("Songbook")
            .font(.custom("Cochin", size: 36))
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
        Button {
            newTitle = ""
            showNewSongSheet = true
        } label: {
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
        .accessibilityLabel("New Song")
    }

    private var newSongSheet: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $newTitle)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle("New Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showNewSongSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSong(title: newTitle.isEmpty ? "Untitled" : newTitle)
                        showNewSongSheet = false
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.fraction(0.35)])
    }

    private func createSong(title: String) {
        let song = Song(title: title)
        context.insert(song)
        do {
            try context.save()
            print("[SwiftData] Created song: \(title)")
        } catch {
            print("[SwiftData] Save failed: \(error)")
        }
    }

    private func delete(_ song: Song) {
        context.delete(song)
        do {
            try context.save()
        } catch {
            print("[SwiftData] Delete failed: \(error)")
        }
    }
}

// MARK: - Song Detail View

private struct SwiftDataSongDetailView: View {
    @Bindable var song: Song
    var coordinator: SwiftDataCoordinator

    @Environment(\.modelContext) private var context
    @State private var showNewEntrySheet = false
    @State private var navigationPath = NavigationPath()

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
            .navigationDestination(for: UUID.self) { entryID in
                if let index = song.entries.firstIndex(where: { $0.id == entryID }) {
                    let entry = song.entries[index]
                    switch entry.type {
                    case .lyrics:
                        SwiftDataLyricsEditor(song: song, entryID: entryID)
                    case .notes:
                        SwiftDataNotesEditor(song: song, entryID: entryID)
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
            Text(song.title)
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
            ForEach(song.entries) { entry in
                Button {
                    navigationPath.append(entry.id)
                } label: {
                    SwiftDataEntryCard(entry: entry)
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
        .presentationDetents([.fraction(0.35)])
    }

    private func addEntry(type: EntryType, title: String) {
        let entry = SongEntry(type: type, title: title)
        song.entries.append(entry)
        song.updatedAt = Date()
        try? context.save()
    }

    private func deleteEntry(_ entry: SongEntry) {
        song.entries.removeAll { $0.id == entry.id }
        song.updatedAt = Date()
        try? context.save()
    }
}

// MARK: - Entry Card

private struct SwiftDataEntryCard: View {
    let entry: SongEntry

    private var iconName: String {
        switch entry.type {
        case .lyrics: "text.quote"
        case .notes: "note.text"
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

// MARK: - Entry Editors

private struct SwiftDataLyricsEditor: View {
    @Bindable var song: Song
    let entryID: UUID
    @Environment(\.modelContext) private var context

    private var entryIndex: Int? {
        song.entries.firstIndex(where: { $0.id == entryID })
    }

    var body: some View {
        if let index = entryIndex {
            LyricsView(
                title: $song.entries[index].title,
                text: $song.entries[index].text,
                onSave: {
                    song.entries[index].updatedAt = Date()
                    song.updatedAt = Date()
                    try? context.save()
                }
            )
        }
    }
}

private struct SwiftDataNotesEditor: View {
    @Bindable var song: Song
    let entryID: UUID
    @Environment(\.modelContext) private var context

    private var entryIndex: Int? {
        song.entries.firstIndex(where: { $0.id == entryID })
    }

    var body: some View {
        if let index = entryIndex {
            NotesView(
                title: $song.entries[index].title,
                text: $song.entries[index].text,
                onSave: {
                    song.entries[index].updatedAt = Date()
                    song.updatedAt = Date()
                    try? context.save()
                }
            )
        }
    }
}
