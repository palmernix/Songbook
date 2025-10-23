import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Song.updatedAt, order: .reverse) private var songs: [Song]

    @State private var search = ""
    @State private var showNewSongSheet = false
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            Group {
                if filteredSongs.isEmpty {
                    ContentUnavailableView("No songs yet",
                                           systemImage: "music.note.list",
                                           description: Text("Tap + to create your first song."))
                } else {
                    List {
                        ForEach(filteredSongs) { song in
                            NavigationLink(value: song) {
                                SongCard(song: song)
                            }
                            .contextMenu {
                                Button(role: .destructive) { delete(song) } label {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteOffsets)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("LyricSheets")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newTitle = ""
                        showNewSongSheet = true
                    } label {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("New Song")
                }
            }
            .navigationDestination(for: Song.self) { song in
                EditorView(song: song)
            }
            .searchable(text: $search, placement: .navigationBarDrawer, prompt: "Search titles")
            .sheet(isPresented: $showNewSongSheet) {
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
        }
    }

    private var filteredSongs: [Song] {
        guard !search.isEmpty else { return songs }
        return songs.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    private func createSong(title: String) {
        let song = Song(title: title)
        context.insert(song)
        try? context.save()
    }

    private func delete(_ song: Song) {
        context.delete(song)
        try? context.save()
    }

    private func deleteOffsets(_ offsets: IndexSet) {
        for idx in offsets { context.delete(filteredSongs[idx]) }
        try? context.save()
    }
}

private struct SongCard: View {
    let song: Song
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(song.title.isEmpty ? "Untitled" : song.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(Self.dateFormatter.string(from: song.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(snippet(from: song.text))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }

    private func snippet(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}