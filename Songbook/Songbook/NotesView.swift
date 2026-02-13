import SwiftUI
import UIKit

struct NotesView: View {
    @Binding var title: String
    @Binding var text: String
    @Binding var formattedTextData: Data?
    var onSave: () -> Void
    var onBack: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var context = RichTextContext()
    @State private var didLoad = false

    private let toolbarHeight: CGFloat = 44

    var body: some View {
        ZStack {
            Color.warmBg.ignoresSafeArea()

            VStack(spacing: 0) {
                titleRow
                editorCard
            }
        }
        .navigationBarHidden(true)
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
            // Migrate plain text
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

    private var editorCard: some View {
        ZStack(alignment: .bottom) {
            RichTextEditor(context: context, bottomInset: toolbarHeight + 8)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            FormattingToolbar(context: context, showBullets: true)
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

    private var wordCountString: String {
        let count = context.attributedText.string.split { $0.isWhitespace || $0.isNewline }.count
        return "\(count) words"
    }
}
