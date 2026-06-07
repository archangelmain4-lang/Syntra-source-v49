import SwiftUI
import Combine
import AppKit

// MARK: - Final User-Facing SwiftUI View

/// A view that displays markdown text with a word-by-word fade-in animation.
/// It automatically adjusts its height to fit the content.
struct FadeInTextView: View {
    @Binding var text: String
    var wordDelay: TimeInterval = 0.05
    var fadeInDuration: TimeInterval = 0.4
    var font: NSFont = .systemFont(ofSize: 18)
    var foregroundColor: NSColor = .labelColor

    @State private var isHovering = false
    @State private var calculatedHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0){
            FadeInTextView_Rep(
                text: $text,
                height: $calculatedHeight,
                wordDelay: wordDelay,
                fadeInDuration: fadeInDuration,
                font: font,
                foregroundColor: foregroundColor
            )
            .frame(height: calculatedHeight)
            if isHovering && !text.isEmpty {
                HStack {
                    Button(action: copyTextToClipboard) {
                        Image("copy")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.leading, 8)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }

    func copyTextToClipboard() {
#if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
#endif
    }
}


// MARK: - NSViewRepresentable Implementation Detail

fileprivate struct FadeInTextView_Rep: NSViewRepresentable {

    @Binding var text: String
    @Binding var height: CGFloat

    var wordDelay: TimeInterval
    var fadeInDuration: TimeInterval
    var font: NSFont
    var foregroundColor: NSColor

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> IntrinsicSizingTextView {
        let textView = IntrinsicSizingTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 5, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = .width
        context.coordinator.textView = textView
        return textView
    }

    func updateNSView(_ nsView: IntrinsicSizingTextView, context: Context) {
        let coordinator = context.coordinator
        if text.hasPrefix(coordinator.currentText) && text.count > coordinator.currentText.count {
            coordinator.continueAnimation(with: text, font: font, textColor: foregroundColor, fadeInDuration: fadeInDuration, wordDelay: wordDelay)
        } else if text != coordinator.currentText {
            coordinator.startAnimation(text: text, font: font, textColor: foregroundColor, fadeInDuration: fadeInDuration, wordDelay: wordDelay)
        }
        context.coordinator.updateHeight()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var parent: FadeInTextView_Rep
        weak var textView: IntrinsicSizingTextView?

        var currentText: String = ""
        private var finalAttributedString: NSAttributedString?
        private var animationTimer: Timer?
        private var animationStartTime: TimeInterval = 0
        private var wordRanges: [NSRange] = []
        private var completedWordIndices: Set<Int> = []

        private var fadeInDuration: TimeInterval
        private var wordDelay: TimeInterval
        private var baseColor: NSColor
        private var baseFont: NSFont

        init(_ parent: FadeInTextView_Rep) {
            self.parent = parent
            self.fadeInDuration = parent.fadeInDuration
            self.wordDelay = parent.wordDelay
            self.baseColor = parent.foregroundColor
            self.baseFont = parent.font
        }

        deinit {
            animationTimer?.invalidate()
        }

        func updateHeight() {
            guard let textView = textView else { return }
            let newHeight = textView.intrinsicContentSize.height
            if abs(parent.height - newHeight) > 1 {
                DispatchQueue.main.async {
                    self.parent.height = newHeight
                }
            }
        }

        /// Parse markdown into NSAttributedString using Apple's built-in APIs (macOS 12+).
        /// Replaces the previously-used third-party `Down` library.
        private func createAttributedString(from markdown: String) -> NSAttributedString? {
            let options = AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )

            guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
                return NSAttributedString(string: markdown, attributes: [
                    .font: self.baseFont,
                    .foregroundColor: self.baseColor
                ])
            }

            let result = NSMutableAttributedString()

            for run in parsed.runs {
                let substring = String(parsed[run.range].characters)
                var attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: self.baseColor
                ]

                var isBold = false
                var isItalic = false
                var isCode = false

                if let intent = run.inlinePresentationIntent {
                    if intent.contains(.stronglyEmphasized) { isBold = true }
                    if intent.contains(.emphasized) { isItalic = true }
                    if intent.contains(.code) { isCode = true }
                }

                if isCode {
                    attrs[.font] = NSFont.userFixedPitchFont(ofSize: self.baseFont.pointSize * 0.9) ?? self.baseFont
                } else if isBold || isItalic {
                    var symbolic: NSFontDescriptor.SymbolicTraits = []
                    if isBold { symbolic.insert(.bold) }
                    if isItalic { symbolic.insert(.italic) }
                    let descriptor = self.baseFont.fontDescriptor.withSymbolicTraits(symbolic)
                    let styledFont = NSFont(descriptor: descriptor, size: self.baseFont.pointSize) ?? self.baseFont
                    attrs[.font] = styledFont
                } else {
                    attrs[.font] = self.baseFont
                }

                if let link = run.link {
                    attrs[.link] = link
                    attrs[.foregroundColor] = NSColor.linkColor
                }

                result.append(NSAttributedString(string: substring, attributes: attrs))
            }

            return result
        }

        private func findAnimationRanges(in text: String, offset: Int = 0) -> [NSRange] {
            var finalRanges: [NSRange] = []
            var rawWordRanges: [NSRange] = []
            text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { _, substringRange, _, _ in
                rawWordRanges.append(NSRange(substringRange, in: text))
            }
            if rawWordRanges.isEmpty { return !text.isEmpty ? [NSRange(location: offset, length: (text as NSString).length)] : [] }

            for (index, currentRange) in rawWordRanges.enumerated() {
                let startLocation = currentRange.location
                let endLocation = (index < rawWordRanges.count - 1) ? rawWordRanges[index + 1].location : (text as NSString).length
                finalRanges.append(NSRange(location: startLocation + offset, length: endLocation - startLocation))
            }
            return finalRanges
        }

        func startAnimation(text: String, font: NSFont, textColor: NSColor, fadeInDuration: TimeInterval, wordDelay: TimeInterval) {
            animationTimer?.invalidate()
            self.currentText = text
            self.fadeInDuration = fadeInDuration
            self.wordDelay = wordDelay
            self.baseColor = textColor
            self.baseFont = font
            self.completedWordIndices = []

            guard let attributedString = createAttributedString(from: text) else {
                textView?.string = ""
                updateHeight()
                return
            }

            self.finalAttributedString = attributedString
            self.wordRanges = findAnimationRanges(in: attributedString.string)

            let initialAttributedString = NSMutableAttributedString(attributedString: attributedString)
            initialAttributedString.addAttribute(.foregroundColor, value: NSColor.clear, range: initialAttributedString.entireRange)
            textView?.textStorage?.setAttributedString(initialAttributedString)
            updateHeight()

            self.animationStartTime = CACurrentMediaTime()
            if !wordRanges.isEmpty { startTimer() }
        }

        func continueAnimation(with newText: String, font: NSFont, textColor: NSColor, fadeInDuration: TimeInterval, wordDelay: TimeInterval) {
            animationTimer?.invalidate()
            animationTimer = nil

            guard let textView = textView, let textStorage = textView.textStorage else { return }

            let oldText = self.currentText

            self.currentText = newText
            self.fadeInDuration = fadeInDuration
            self.wordDelay = wordDelay
            self.baseColor = textColor
            self.baseFont = font

            guard let newFinalAttributedString = createAttributedString(from: newText) else { return }
            self.finalAttributedString = newFinalAttributedString

            let oldWordCount = findAnimationRanges(in: oldText).count
            self.wordRanges = findAnimationRanges(in: newFinalAttributedString.string)

            let displayString = NSMutableAttributedString(attributedString: newFinalAttributedString)

            displayString.beginEditing()
            for (index, range) in wordRanges.enumerated() {
                if index >= oldWordCount {
                    newFinalAttributedString.enumerateAttributes(in: range, options: []) { attributes, subRange, _ in
                        var newAttributes = attributes
                        let originalColor = (attributes[.foregroundColor] as? NSColor ?? self.baseColor)
                        newAttributes[.foregroundColor] = originalColor.withAlphaComponent(0)
                        displayString.setAttributes(newAttributes, range: subRange)
                    }
                }
            }
            displayString.endEditing()

            textStorage.beginEditing()
            textStorage.setAttributedString(displayString)
            textStorage.endEditing()
            updateHeight()

            self.completedWordIndices = Set(0..<oldWordCount)

            let timeElapsedForOldWords = TimeInterval(oldWordCount) * self.wordDelay
            self.animationStartTime = CACurrentMediaTime() - timeElapsedForOldWords

            if !wordRanges.isEmpty && self.completedWordIndices.count < self.wordRanges.count {
                startTimer()
            }
        }

        private func startTimer() {
            animationTimer?.invalidate()
            let timer = Timer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(updateFrame), userInfo: nil, repeats: true)
            animationTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        @objc private func updateFrame() {
            guard let textView = textView, let finalAttributedString = self.finalAttributedString else {
                animationTimer?.invalidate()
                return
            }
            updateHeight()

            let currentTime = CACurrentMediaTime()
            let elapsedTime = currentTime - animationStartTime
            var allWordsAreNowComplete = true

            textView.textStorage?.beginEditing()
            for (index, range) in wordRanges.enumerated() {
                if completedWordIndices.contains(index) { continue }
                allWordsAreNowComplete = false
                let wordStartTime = TimeInterval(index) * self.wordDelay
                var progress = max(0.0, min(1.0, (elapsedTime - wordStartTime) / self.fadeInDuration))
                if elapsedTime < wordStartTime { progress = 0.0 }
                if progress == 1.0 { completedWordIndices.insert(index) }

                finalAttributedString.enumerateAttributes(in: range, options: []) { attributes, subRange, _ in
                    var newAttributes = attributes
                    let originalColor = (attributes[.foregroundColor] as? NSColor ?? self.baseColor).usingColorSpace(.sRGB) ?? self.baseColor
                    newAttributes[.foregroundColor] = originalColor.withAlphaComponent(progress)
                    textView.textStorage?.setAttributes(newAttributes, range: subRange)
                }
            }
            textView.textStorage?.endEditing()

            if allWordsAreNowComplete && wordRanges.count == completedWordIndices.count {
                animationTimer?.invalidate()
                animationTimer = nil
            }
        }
    }
}

// MARK: - Helper Classes

fileprivate class IntrinsicSizingTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager, let textContainer = textContainer else { return super.intrinsicContentSize }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(usedRect.height + textContainerInset.height * 2))
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }
}

extension NSMutableAttributedString {
    var entireRange: NSRange { NSRange(location: 0, length: self.length) }
}


// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var demoText = ""

        let initialText = """
        # Fade-In TextView Demo
        This text view **smoothly** adjusts its height based on the content.

        * When new text is added, the view will grow taller.
        * The animation continues *seamlessly* from where it left off.
        """

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    FadeInTextView(
                        text: $demoText,
                        font: .systemFont(ofSize: 16, weight: .light)
                    )
                    .padding()
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                    .shadow(radius: 2)

                    HStack {
                        Button("Start Animation") {
                            demoText = ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                demoText = initialText
                            }
                        }
                        Button("Clear") { demoText = "" }
                    }
                    .padding(.top, 5)
                }
                .padding()
            }
            .onAppear { demoText = initialText }
        }
    }
    return PreviewWrapper().frame(width: 500, height: 400)
}
