import SwiftUI
import SwiftData

struct EditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var song: Song

    @State private var isSaving = false
    @State private var showInspire = false
    @State private var suggestion: String = ""
    @State private var showOptions = false
    @State private var inspireOptions: InspireOptions = .empty
    @State private var isGenerating = false
    @State private var selection: NSRange = .init(location: 0, length: 0)

    var body: some View {
        VStack(spacing: 0) {
            titleField
            Divider()
            CursorTextEditor(text: $song.text, selectedRange: $selection)
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
            SuggestionSheet(
                suggestion: $suggestion,
                isLoading: isGenerating,
                onRefine: {
                    // Close the suggestion sheet, open options prefilled with last choices
                    showInspire = false
                    showOptions = true
                },
                onRegenerate: {
                    Task { await regenerateSuggestion() }
                },
                onInsert: {
                    insertSuggestion()
                    showInspire = false   // dismiss after insert
                },
                onCancel: {
                    showInspire = false
                }
            )
            .presentationDetents([.fraction(0.35), .medium, .large])
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
                showOptions = true
            } label: {
                if isGenerating {
                    ProgressView()
                        .padding(.horizontal, 4)
                } else {
                    Label("Inspire", systemImage: "sparkles")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGenerating)

            Spacer()
            Text(wordCountString)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        // Present options first
        .sheet(isPresented: $showOptions) {
            InspireOptionsSheet(options: inspireOptions) { chosen in
                inspireOptions = chosen
                Task { await inspire(using: chosen) }
            }
        }
    }

    private func inspire(using options: InspireOptions) async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            suggestion = try await APIClient.shared.suggest(
                userLyrics: lastLine(), 
                contextFocus: focusContext(), 
                contextFull: song.text,
                options: options
            )

            showInspire = true
        } catch {
            // Handle the error - you might want to show an alert or set a default message
            suggestion = "Sorry, couldn't generate a suggestion right now. Please try again."
            showInspire = true
        }
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

        if !song.text.hasSuffix(" ") && !suggestion.hasPrefix(" ") && !song.text.isEmpty {
            song.text.append(" ")
        }     

        song.text.append(suggestion)
        suggestion = ""
        touch()
        showInspire = false
    }

    private func regenerateSuggestion() async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let s = try await APIClient.shared.suggest(
                userLyrics: currentLineAtCaret(),
                contextFocus: currentStanzaAtCaret(),
                contextFull: song.text,
                options: inspireOptions   // reuse last chosen options
            )
            suggestion = s
        } catch {
            suggestion = "⚠️ Sorry, couldn't generate a suggestion right now."
        }
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
    var isLoading: Bool = false
    var onRefine: () -> Void
    var onRegenerate: () -> Void
    var onInsert: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(.secondary.opacity(0.25))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("Suggestion")
                .font(.headline)

            // Read-only display (cleaner than editing the text in-place)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                Text(suggestion.isEmpty ? "— (no text yet) —" : suggestion)
                    .padding(12)
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .frame(minHeight: 80)

            HStack(spacing: 10) {
                Button("Refine") { onRefine() }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)

                Button {
                    onRegenerate()
                } label: {
                    if isLoading { ProgressView() } else { Text("Regenerate") }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)

                Button("Insert") { onInsert() }
                    .buttonStyle(.borderedProminent)
                    .disabled(suggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)

                Button("Cancel") { onCancel() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
            }
            .buttonStyle(.bordered)
            .font(.body)
            .minimumScaleFactor(0.8) // Shrinks text slightly if needed
            .lineLimit(1)
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
}

struct CursorTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.isScrollEnabled = true
        tv.backgroundColor = .clear
        tv.delegate = context.coordinator
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        if uiView.selectedRange != selectedRange { uiView.selectedRange = selectedRange }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: CursorTextEditor
        init(_ parent: CursorTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
        }
    }
}