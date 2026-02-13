import SwiftUI
import SwiftData

extension Color {
    static let warmBg = Color(red: 0.96, green: 0.95, blue: 0.93)
}

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Song.updatedAt, order: .reverse) private var songs: [Song]

    @State private var search = ""
    @State private var showNewSongSheet = false
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.warmBg.ignoresSafeArea()

                if filteredSongs.isEmpty {
                    ContentUnavailableView("No songs yet",
                                           systemImage: "music.note.list",
                                           description: Text("Tap + to create your first song."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredSongs) { song in
                                NavigationLink(value: song) {
                                    SongCard(song: song)
                                }
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
            .navigationTitle("Songbook")
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
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    EditButton()
                        .foregroundStyle(.indigo)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: {
                        newTitle = ""
                        showNewSongSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .tint(.indigo)
                    .accessibilityLabel("New Song")
                }
            }
            .toolbarBackground(Color.warmBg, for: .navigationBar)
        }
        .tint(.indigo)
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
}

private struct SongCard: View {
    let song: Song

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [.indigo.opacity(0.7), .indigo.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(song.title.isEmpty ? "Untitled" : song.title)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(Self.relativeDateFormatter.localizedString(
                        for: song.updatedAt, relativeTo: Date()))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .padding(.bottom, 6)

                Text(snippet(from: song.text))
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .lineSpacing(3)
            }
            .padding(.leading, 12)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }

    private func snippet(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}
