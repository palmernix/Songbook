import SwiftUI
import UIKit

struct LyricsView: View {
    @Binding var title: String
    @Binding var text: String
    @Binding var formattedTextData: Data?
    var onSave: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var context = RichTextContext()
    @State private var didLoad = false
    @State private var showInspire = false
    @State private var suggestion: String = ""
    @State private var showOptions = false
    @State private var inspireOptions: InspireOptions = .empty
    @State private var isGenerating = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.warmBg.ignoresSafeArea()

            VStack(spacing: 0) {
                titleRow
                editorCard
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showInspire) {
            SuggestionSheet(
                suggestion: $suggestion,
                isLoading: isGenerating,
                onRefine: {
                    showInspire = false
                    showOptions = true
                },
                onRegenerate: {
                    Task { await regenerateSuggestion() }
                },
                onInsert: {
                    insertSuggestion()
                    showInspire = false
                },
                onCancel: {
                    showInspire = false
                }
            )
            .presentationDetents([.fraction(0.35), .medium, .large])
        }
        .onAppear {
            if title.isEmpty { title = "Untitled" }
            loadFormattedText()
        }
        .onChange(of: title) { onSave() }
    }

    private func loadFormattedText() {
        guard !didLoad else { return }
        didLoad = true

        if let decoded = RichTextStorage.decode(formattedTextData) {
            context.attributedText = decoded
        } else if !text.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor(Color.darkInk)
            ]
            context.attributedText = NSAttributedString(string: text, attributes: attrs)
        }

        context.onChangeHandler = { [context] in
            text = context.attributedText.string
            formattedTextData = RichTextStorage.encode(context.attributedText)
            onSave()
        }
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(Color.darkInk)

                Spacer()

                Text(wordCountString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Button {
                    showOptions = true
                } label: {
                    if isGenerating {
                        ProgressView()
                            .padding(.horizontal, 4)
                    } else {
                        Label("Inspire", systemImage: "sparkles")
                            .font(.subheadline.weight(.medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.darkInk)
                .disabled(isGenerating)
                .sheet(isPresented: $showOptions) {
                    InspireOptionsSheet(options: inspireOptions) { chosen in
                        inspireOptions = chosen
                        Task { await inspire(using: chosen) }
                    }
                }
            }

            TextField("Title", text: $title)
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(Color.darkInk)
                .textInputAutocapitalization(.words)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private let toolbarHeight: CGFloat = 44

    private var editorCard: some View {
        ZStack(alignment: .bottom) {
            RichTextEditor(context: context, bottomInset: toolbarHeight + 8)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            FormattingToolbar(context: context, showBullets: false)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .glassEffect(.regular.tint(Color.warmBg), in: .capsule)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func inspire(using options: InspireOptions) async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            suggestion = try await APIClient.shared.suggest(
                userLyrics: currentLineAtCaret(),
                contextFocus: currentStanzaAtCaret(),
                contextFull: context.attributedText.string,
                options: options
            )

            showInspire = true
        } catch {
            suggestion = "Sorry, couldn't generate a suggestion right now. Please try again."
            showInspire = true
        }
    }

    private var wordCountString: String {
        let count = context.attributedText.string.split { $0.isWhitespace || $0.isNewline }.count
        return "\(count) words"
    }

    private func insertSuggestion() {
        guard !suggestion.isEmpty, let textView = context.textView else { return }

        let plainText = context.attributedText.string
        var insertText = suggestion
        if !plainText.hasSuffix(" ") && !suggestion.hasPrefix(" ") && !plainText.isEmpty {
            insertText = " " + insertText
        }

        let insertAttr = NSAttributedString(string: insertText, attributes: RichTextEditor.defaultAttributes)
        let location = textView.selectedRange.location
        textView.textStorage.insert(insertAttr, at: location)
        textView.selectedRange = NSRange(location: location + insertAttr.length, length: 0)
        context.notifyChange(textView)

        suggestion = ""
        showInspire = false
    }

    private func regenerateSuggestion() async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let s = try await APIClient.shared.suggest(
                userLyrics: currentLineAtCaret(),
                contextFocus: currentStanzaAtCaret(),
                contextFull: context.attributedText.string,
                options: inspireOptions
            )
            suggestion = s
        } catch {
            suggestion = "Sorry, couldn't generate a suggestion right now."
        }
    }

    private func currentLineAtCaret() -> String {
        let plainText = context.attributedText.string
        let ns = plainText as NSString
        let selection = context.selectedRange
        var pos = selection.location + selection.length
        pos = max(0, min(pos, ns.length))

        if pos > 0, ns.character(at: pos - 1) == 10 {
            return ""
        }

        let before = ns.substring(to: pos) as NSString
        let lastNL = before.range(of: "\n", options: .backwards)
        let lineStart = (lastNL.location == NSNotFound) ? 0 : lastNL.location + 1

        let raw = before.substring(from: lineStart)
        return raw.trimmingCharacters(in: .whitespaces)
    }

    private func currentStanzaAtCaret() -> String {
        let plainText = context.attributedText.string
        let lines = plainText.components(separatedBy: "\n")
        let selection = context.selectedRange

        let loc = min(selection.location, (plainText as NSString).length)
        let caret = plainText.index(plainText.startIndex, offsetBy: loc)
        let caretLineIndex = plainText[..<caret].reduce(0) { $1 == "\n" ? $0 + 1 : $0 }

        var start = caretLineIndex
        while start > 0 && !lines[start - 1].trimmingCharacters(in: .whitespaces).isEmpty {
            start -= 1
        }
        var end = caretLineIndex
        while end < lines.count - 1 && !lines[end + 1].trimmingCharacters(in: .whitespaces).isEmpty {
            end += 1
        }

        return lines[start...end].joined(separator: "\n")
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
            .minimumScaleFactor(0.8)
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
        tv.textColor = UIColor(Color.darkInk)
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
