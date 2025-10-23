import SwiftUI
import SwiftData

struct EditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var song: Song

    @State private var isSaving = false
    @State private var showInspire = false
    @State private var suggestion: String = ""

    var body: some View {
        VStack(spacing: 0) {
            titleField
            Divider()
            TextEditor(text: $song.text)
                .font(.system(.body, design: .default))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
                .onChange(of: song.text) { _ in touch() }
            Divider()
            bottomBar
        }
        .navigationTitle("Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                } label: {
                    if isSaving { ProgressView() } else { Text("Save") }
                }
                .disabled(isSaving)
            }
        }
        .sheet(isPresented: $showInspire) {
            SuggestionSheet(suggestion: $suggestion, insert: insertSuggestion)
                .presentationDetents([.fraction(0.35)])
        }
        .onAppear { if song.title.isEmpty { song.title = "Untitled" } }
    }

    private var titleField: some View {
        TextField("Title", text: $song.title)
            .font(.title2.weight(.semibold))
            .textInputAutocapitalization(.words)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .onChange(of: song.title) { _ in touch() }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                Task { await inspire() }
            } label: {
                Label("Inspire", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)

            Spacer()

            Text(wordCountString)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    private var wordCountString: String {
        let count = song.text.split { $0.isWhitespace || $0.isNewline }.count
        return "\(count) words"
    }

    private func touch() {
        song.updatedAt = Date()
    }

    private func save() {
        isSaving = true
        defer { isSaving = false }
        try? context.save()
        // TODO: call API /ingest/snapshot here (later)
    }

    private func insertSuggestion() {
        guard !suggestion.isEmpty else { return }
        if !song.text.hasSuffix("\n") && !song.text.isEmpty { song.text.append("\n") }
        song.text.append(suggestion)
        suggestion = ""
        touch()
    }

    private func inspire() async {
        // For now, fake it; we’ll wire APIClient next
        suggestion = "... demo lyric suggestion from AI ..."
        showInspire = true
        // suggestion = await APIClient.shared.suggest(userLyrics: lastLine(), contextFocus: focusContext(), contextFull: song.text)
        // showInspire = true
    }

    // Helpers to capture context
    private func lastLine() -> String {
        song.text.split(separator: "\n").last.map(String.init) ?? ""
    }
    private func focusContext() -> String {
        let lines = song.text.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.suffix(8).joined(separator: "\n")
    }
}

private struct SuggestionSheet: View {
    @Binding var suggestion: String
    var insert: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Capsule().fill(.secondary.opacity(0.25)).frame(width: 40, height: 5).padding(.top, 8)
            Text("Suggestion").font(.headline)
            TextEditor(text: $suggestion)
                .frame(minHeight: 80)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Spacer()
                Button("Insert") { insert() }
                    .buttonStyle(.borderedProminent)
                    .disabled(suggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
    }
}