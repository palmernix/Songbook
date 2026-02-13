import SwiftUI

struct NotesView: View {
    @Binding var title: String
    @Binding var text: String
    var onSave: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.warmBg.ignoresSafeArea()

            VStack(spacing: 0) {
                titleRow
                editorCard
                bottomBar
            }
        }
        .navigationBarHidden(true)
        .onAppear { if title.isEmpty { title = "Untitled" } }
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

                Button {
                    save()
                } label: {
                    if isSaving { ProgressView() } else { Text("Save") }
                }
                .foregroundStyle(Color.darkInk)
                .fontWeight(.medium)
                .disabled(isSaving)
            }

            TextField("Title", text: $title)
                .font(.system(.title2, design: .serif, weight: .bold))
                .textInputAutocapitalization(.words)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var editorCard: some View {
        TextEditor(text: $text)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
    }

    private var bottomBar: some View {
        HStack {
            Spacer()
            Text(wordCountString)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var wordCountString: String {
        let count = text.split { $0.isWhitespace || $0.isNewline }.count
        return "\(count) words"
    }

    private func save() {
        isSaving = true
        onSave()
        isSaving = false
    }
}
