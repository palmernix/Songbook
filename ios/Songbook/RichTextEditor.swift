import SwiftUI
import UIKit

// MARK: - RichTextStorage (RTF Encoding/Decoding)

enum RichTextStorage {
    static func encode(_ attributedString: NSAttributedString) -> Data? {
        try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    static func decode(_ data: Data?) -> NSAttributedString? {
        guard let data else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }
}

// MARK: - Heading Level

enum HeadingLevel: String, CaseIterable {
    case h3 = "Heading 3"
    case h2 = "Heading 2"
    case h1 = "Heading 1"
    case body = "Body"

    var fontSize: CGFloat {
        switch self {
        case .h1: 28
        case .h2: 22
        case .h3: 18
        case .body: 17
        }
    }

    var fontWeight: UIFont.Weight {
        switch self {
        case .h1: .bold
        case .h2: .bold
        case .h3: .semibold
        case .body: .regular
        }
    }
}

// MARK: - RichTextContext

@Observable
class RichTextContext {
    var attributedText = NSAttributedString()
    var selectedRange = NSRange(location: 0, length: 0)

    var isBold = false
    var isItalic = false
    var isUnderline = false
    var currentHeadingLevel: HeadingLevel = .body
    var isBulletList = false

    weak var textView: UITextView?
    var onChangeHandler: (() -> Void)?

    private var isUpdatingFromTextView = false

    // MARK: - Formatting Commands

    func toggleBold() {
        guard let textView else { return }
        applySymbolicTrait(.traitBold, on: textView)
        isBold.toggle()
    }

    func toggleItalic() {
        guard let textView else { return }
        applySymbolicTrait(.traitItalic, on: textView)
        isItalic.toggle()
    }

    func toggleUnderline() {
        guard let textView else { return }
        let range = textView.selectedRange

        if range.length > 0 {
            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
            let currentStyle = mutable.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
            let newStyle: Int = currentStyle == 0 ? NSUnderlineStyle.single.rawValue : 0
            mutable.addAttribute(.underlineStyle, value: newStyle, range: range)
            textView.attributedText = mutable
            textView.selectedRange = range
        } else {
            var attrs = textView.typingAttributes
            let currentStyle = attrs[.underlineStyle] as? Int ?? 0
            attrs[.underlineStyle] = currentStyle == 0 ? NSUnderlineStyle.single.rawValue : 0
            textView.typingAttributes = attrs
        }
        isUnderline.toggle()
        notifyChange(textView)
    }

    func setHeading(_ level: HeadingLevel) {
        guard let textView else { return }
        let storage = textView.textStorage
        let text = storage.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange)

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: lineRange) { value, attrRange, _ in
            let oldFont = (value as? UIFont) ?? UIFont.systemFont(ofSize: level.fontSize)
            let descriptor = oldFont.fontDescriptor
            var traits = descriptor.symbolicTraits

            // Remove existing weight traits then apply heading weight
            traits.remove(.traitBold)
            if level.fontWeight == .bold || level.fontWeight == .semibold {
                traits.insert(.traitBold)
            }

            let newDescriptor = descriptor.withSymbolicTraits(traits) ?? descriptor
            let newFont = UIFont(descriptor: newDescriptor, size: level.fontSize)
            storage.addAttribute(.font, value: newFont, range: attrRange)
        }
        storage.endEditing()

        // Update typing attributes so new characters use the heading font
        var attrs = textView.typingAttributes
        let existingFont = (attrs[.font] as? UIFont) ?? UIFont.systemFont(ofSize: level.fontSize)
        var traits = existingFont.fontDescriptor.symbolicTraits
        traits.remove(.traitBold)
        if level.fontWeight == .bold || level.fontWeight == .semibold {
            traits.insert(.traitBold)
        }
        let desc = existingFont.fontDescriptor.withSymbolicTraits(traits) ?? existingFont.fontDescriptor
        attrs[.font] = UIFont(descriptor: desc, size: level.fontSize)
        textView.typingAttributes = attrs

        currentHeadingLevel = level
        textView.selectedRange = textView.selectedRange
        notifyChange(textView)
    }

    func toggleBullet() {
        guard let textView else { return }
        let storage = textView.textStorage
        let text = storage.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange)
        let lineText = text.substring(with: lineRange)

        storage.beginEditing()
        if lineText.hasPrefix("\u{2022}\t") {
            // Remove bullet
            let bulletRange = NSRange(location: lineRange.location, length: 2)
            storage.replaceCharacters(in: bulletRange, with: "")
            isBulletList = false
        } else {
            // Add bullet
            let bulletStr = NSAttributedString(string: "\u{2022}\t", attributes: textView.typingAttributes)
            storage.insert(bulletStr, at: lineRange.location)
            isBulletList = true
        }
        storage.endEditing()
        // Move cursor past the inserted bullet prefix
        let cursorPos = textView.selectedRange.location + 2
        textView.selectedRange = NSRange(location: cursorPos, length: 0)
        notifyChange(textView)
    }

    // MARK: - State Refresh

    func refreshState(from textView: UITextView) {
        let range = textView.selectedRange
        let attrs: [NSAttributedString.Key: Any]

        if range.length > 0 {
            attrs = textView.textStorage.attributes(at: range.location, effectiveRange: nil)
        } else if range.location > 0 {
            let text = textView.textStorage.string as NSString
            // If previous character is a newline, we're at the start of a line —
            // use typingAttributes so we reflect the heading set for this line
            if text.character(at: range.location - 1) == 0x0A {
                attrs = textView.typingAttributes
            } else {
                attrs = textView.textStorage.attributes(at: range.location - 1, effectiveRange: nil)
            }
        } else {
            attrs = textView.typingAttributes
        }

        if let font = attrs[.font] as? UIFont {
            let traits = font.fontDescriptor.symbolicTraits
            isBold = traits.contains(.traitBold)
            isItalic = traits.contains(.traitItalic)

            // Determine heading level from font size
            let size = font.pointSize
            if size >= 26 { currentHeadingLevel = .h1 }
            else if size >= 20 { currentHeadingLevel = .h2 }
            else if size >= 18 { currentHeadingLevel = .h3 }
            else { currentHeadingLevel = .body }
        } else {
            isBold = false
            isItalic = false
            currentHeadingLevel = .body
        }

        isUnderline = (attrs[.underlineStyle] as? Int ?? 0) != 0

        // Check if current line starts with bullet
        let text = textView.textStorage.string as NSString
        let lineRange = text.lineRange(for: NSRange(location: range.location, length: 0))
        let lineText = text.substring(with: lineRange)
        isBulletList = lineText.range(of: "^\t*\u{2022}\t", options: .regularExpression) != nil
    }

    // MARK: - Helpers

    private func applySymbolicTrait(_ trait: UIFontDescriptor.SymbolicTraits, on textView: UITextView) {
        let range = textView.selectedRange

        if range.length > 0 {
            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
            mutable.enumerateAttribute(.font, in: range) { value, attrRange, _ in
                guard let oldFont = value as? UIFont else { return }
                var traits = oldFont.fontDescriptor.symbolicTraits
                if traits.contains(trait) {
                    traits.remove(trait)
                } else {
                    traits.insert(trait)
                }
                if let newDescriptor = oldFont.fontDescriptor.withSymbolicTraits(traits) {
                    let newFont = UIFont(descriptor: newDescriptor, size: oldFont.pointSize)
                    mutable.addAttribute(.font, value: newFont, range: attrRange)
                }
            }
            textView.attributedText = mutable
            textView.selectedRange = range
        } else {
            var attrs = textView.typingAttributes
            let font = (attrs[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            var traits = font.fontDescriptor.symbolicTraits
            if traits.contains(trait) {
                traits.remove(trait)
            } else {
                traits.insert(trait)
            }
            if let newDescriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                attrs[.font] = UIFont(descriptor: newDescriptor, size: font.pointSize)
                textView.typingAttributes = attrs
            }
        }
        notifyChange(textView)
    }

    func notifyChange(_ textView: UITextView) {
        attributedText = textView.attributedText
        onChangeHandler?()
    }
}

// MARK: - RichTextEditor (UIViewRepresentable)

struct RichTextEditor: UIViewRepresentable {
    var context: RichTextContext
    var bottomInset: CGFloat = 0

    func makeUIView(context ctx: Context) -> UITextView {
        let tv = UITextView()
        tv.isScrollEnabled = true
        tv.backgroundColor = .clear
        tv.allowsEditingTextAttributes = true
        tv.font = UIFont.systemFont(ofSize: 17)
        tv.textColor = UIColor(Color.darkInk)
        tv.typingAttributes = Self.defaultAttributes
        tv.autocorrectionType = .no
        tv.inlinePredictionType = .no
        tv.spellCheckingType = .no
        tv.writingToolsBehavior = .none
        tv.contentInset.bottom = bottomInset
        tv.verticalScrollIndicatorInsets.bottom = bottomInset
        tv.delegate = ctx.coordinator

        // Swipe gestures for bullet indent/de-indent
        let swipeRight = UISwipeGestureRecognizer(target: ctx.coordinator, action: #selector(Coordinator.handleSwipeRight(_:)))
        swipeRight.direction = .right
        tv.addGestureRecognizer(swipeRight)

        let swipeLeft = UISwipeGestureRecognizer(target: ctx.coordinator, action: #selector(Coordinator.handleSwipeLeft(_:)))
        swipeLeft.direction = .left
        tv.addGestureRecognizer(swipeLeft)

        // Set initial content
        if context.attributedText.length > 0 {
            tv.attributedText = context.attributedText
        }

        context.textView = tv
        return tv
    }

    func updateUIView(_ uiView: UITextView, context ctx: Context) {
        guard !ctx.coordinator.isUpdating else { return }
        self.context.textView = uiView

        if uiView.contentInset.bottom != bottomInset {
            uiView.contentInset.bottom = bottomInset
            uiView.verticalScrollIndicatorInsets.bottom = bottomInset
        }

        // Only update if the attributed text actually changed (e.g. from external load)
        if uiView.attributedText != self.context.attributedText && self.context.attributedText.length > 0 {
            ctx.coordinator.isUpdating = true
            uiView.attributedText = self.context.attributedText
            ctx.coordinator.isUpdating = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(context: context)
    }

    static var defaultAttributes: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor(Color.darkInk)
        ]
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let context: RichTextContext
        var isUpdating = false
        private var savedLineFont: UIFont?
        private var pendingBodyReset = false
        init(context: RichTextContext) {
            self.context = context
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating else { return }
            isUpdating = true
            restoreLineFontIfNeeded(textView)
            applyPendingBodyReset(textView)
            context.notifyChange(textView)
            isUpdating = false
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            restoreLineFontIfNeeded(textView)
            applyPendingBodyReset(textView)
            context.selectedRange = textView.selectedRange
            context.refreshState(from: textView)
        }

        private func restoreLineFontIfNeeded(_ textView: UITextView) {
            guard let font = savedLineFont else { return }
            savedLineFont = nil
            let nsText = textView.textStorage.string as NSString
            let lineRange = nsText.lineRange(for: textView.selectedRange)
            let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)
            if lineText.isEmpty {
                var attrs = textView.typingAttributes
                attrs[.font] = font
                textView.typingAttributes = attrs
            }
        }

        private func applyPendingBodyReset(_ textView: UITextView) {
            guard pendingBodyReset else { return }
            pendingBodyReset = false
            var attrs = textView.typingAttributes
            attrs[.font] = UIFont.systemFont(ofSize: HeadingLevel.body.fontSize, weight: HeadingLevel.body.fontWeight)
            textView.typingAttributes = attrs
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Before deletion, save the current line's font so we can restore it if the line empties
            savedLineFont = nil
            if text.isEmpty && range.length > 0 {
                let nsText = textView.textStorage.string as NSString
                let lineRange = nsText.lineRange(for: textView.selectedRange)
                let lineContentEnd = lineRange.location + lineRange.length
                    - (nsText.substring(with: lineRange).hasSuffix("\n") ? 1 : 0)
                if lineContentEnd > lineRange.location {
                    savedLineFont = textView.textStorage.attribute(
                        .font, at: lineRange.location, effectiveRange: nil
                    ) as? UIFont
                }
            }

            // Backspace on empty bullet line — remove the bullet prefix
            if text.isEmpty && range.length > 0 {
                let nsText = textView.textStorage.string as NSString
                let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
                let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)
                if let bulletMatch = lineText.range(of: "^\t*\u{2022}\t", options: .regularExpression) {
                    let contentAfterBullet = String(lineText[bulletMatch.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if contentAfterBullet.isEmpty {
                        let prefixLength = (lineText as NSString).length
                        let removeRange = NSRange(location: lineRange.location, length: min(prefixLength, nsText.length - lineRange.location))
                        textView.textStorage.replaceCharacters(in: removeRange, with: "")
                        textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                        context.isBulletList = false
                        context.notifyChange(textView)
                        return false
                    }
                }
            }

            // Handle Return key for bullet continuation
            guard text == "\n" else { return true }

            let storage = textView.textStorage
            let nsText = storage.string as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)

            // Match indented bullets: optional tabs, then bullet+tab
            guard let bulletMatch = lineText.range(of: "^\t*\u{2022}\t", options: .regularExpression) else {
                // Let UITextView insert the newline, then reset to body on the next delegate callback
                pendingBodyReset = true
                return true
            }
            let bulletPrefix = String(lineText[bulletMatch])

            // If bullet line is empty (just indent+bullet+tab), remove bullet and don't add new one
            let contentAfterBullet = String(lineText[bulletMatch.upperBound...]).trimmingCharacters(in: .whitespaces)
            if contentAfterBullet.isEmpty {
                let prefixLength = bulletPrefix.count
                let removeRange = NSRange(location: lineRange.location, length: min(prefixLength, nsText.length - lineRange.location))
                storage.replaceCharacters(in: removeRange, with: "")
                textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                context.isBulletList = false
                context.notifyChange(textView)
                return false
            }

            // Auto-continue bullet on new line, preserving indent level
            let newBullet = NSAttributedString(string: "\n" + bulletPrefix, attributes: textView.typingAttributes)
            storage.replaceCharacters(in: range, with: newBullet)
            textView.selectedRange = NSRange(location: range.location + newBullet.length, length: 0)
            context.notifyChange(textView)
            return false
        }

        // MARK: - Bullet Indent/De-indent

        @objc func handleSwipeRight(_ gesture: UISwipeGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            let storage = textView.textStorage
            let nsText = storage.string as NSString
            let lineRange = nsText.lineRange(for: textView.selectedRange)
            let lineText = nsText.substring(with: lineRange)

            // Only indent bullet lines
            guard lineText.range(of: "^\t*\u{2022}\t", options: .regularExpression) != nil else { return }

            let tabStr = NSAttributedString(string: "\t", attributes: textView.typingAttributes)
            storage.insert(tabStr, at: lineRange.location)

            // Re-read modified line and place cursor after bullet prefix
            let updatedText = storage.string as NSString
            let updatedLineRange = updatedText.lineRange(for: NSRange(location: lineRange.location, length: 0))
            let updatedLineText = updatedText.substring(with: updatedLineRange)
            if let match = updatedLineText.range(of: "^\t*\u{2022}\t", options: .regularExpression) {
                let prefixLength = updatedLineText.distance(from: updatedLineText.startIndex, to: match.upperBound)
                textView.selectedRange = NSRange(location: updatedLineRange.location + prefixLength, length: 0)
            }
            context.notifyChange(textView)
        }

        @objc func handleSwipeLeft(_ gesture: UISwipeGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            let storage = textView.textStorage
            let nsText = storage.string as NSString
            let lineRange = nsText.lineRange(for: textView.selectedRange)
            let lineText = nsText.substring(with: lineRange)

            // Only de-indent if line starts with a tab before the bullet
            guard lineText.hasPrefix("\t") else { return }
            guard lineText.range(of: "^\t+\u{2022}\t", options: .regularExpression) != nil else { return }

            let removeRange = NSRange(location: lineRange.location, length: 1)
            storage.replaceCharacters(in: removeRange, with: "")

            // Re-read modified line and place cursor after bullet prefix
            let updatedText = storage.string as NSString
            let updatedLineRange = updatedText.lineRange(for: NSRange(location: lineRange.location, length: 0))
            let updatedLineText = updatedText.substring(with: updatedLineRange)
            if let match = updatedLineText.range(of: "^\t*\u{2022}\t", options: .regularExpression) {
                let prefixLength = updatedLineText.distance(from: updatedLineText.startIndex, to: match.upperBound)
                textView.selectedRange = NSRange(location: updatedLineRange.location + prefixLength, length: 0)
            }
            context.notifyChange(textView)
        }
    }
}

// MARK: - FormattingToolbar

struct FormattingToolbar: View {
    var context: RichTextContext
    var showBullets: Bool = true
    var onInspire: (() -> Void)? = nil
    var isGenerating: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            headingMenu
            Divider().frame(height: 20).padding(.horizontal, 4)
            formatButton(icon: "bold", isActive: context.isBold) { context.toggleBold() }
            formatButton(icon: "italic", isActive: context.isItalic) { context.toggleItalic() }
            formatButton(icon: "underline", isActive: context.isUnderline) { context.toggleUnderline() }
            if showBullets {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 0.5, height: 20)
                    .padding(.horizontal, 4)
                formatButton(icon: "list.bullet", isActive: context.isBulletList) { context.toggleBullet() }
            }
            if let onInspire {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 0.5, height: 20)
                    .padding(.horizontal, 4)
                Button(action: onInspire) {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Inspire", systemImage: "sparkles")
                            .font(.subheadline.weight(.medium))
                    }
                }
                .foregroundStyle(Color(.label))
                .disabled(isGenerating)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var headingMenu: some View {
        Menu {
            ForEach(HeadingLevel.allCases, id: \.self) { level in
                Button {
                    context.setHeading(level)
                } label: {
                    HStack {
                        Text(level.rawValue)
                        if context.currentHeadingLevel == level {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(context.currentHeadingLevel.rawValue)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(Color(.label))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        }
    }

    private func formatButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(isActive ? Color.accentColor : Color(.label))
                .frame(width: 34, height: 28)
        }
    }
}
