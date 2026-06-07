//
//  MarkdownTextView.swift
//  Syntra
//
//  Renders markdown text using AppKit for prose (inline code, bold, italics,
//  links, bullet lists, headings, inline + display math) while rendering
//  fenced ``` code blocks as proper SwiftUI cards with a language header,
//  rounded background, and a Copy button — mirroring the syntra.cc web UI.
//

import SwiftUI
import AppKit

// MARK: - Public entry point

struct MarkdownTextView: View {
    let text: String
    var font: NSFont = .systemFont(ofSize: 13, weight: .regular)
    var textColor: NSColor = .labelColor

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let segments = MarkdownSegmenter.segments(from: text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                switch seg {
                case .prose(let s):
                    MarkdownProseView(text: s, font: font, textColor: textColor)
                case .code(let lang, let body):
                    CodeBlockCard(language: lang, code: body, baseFontSize: font.pointSize)
                }
            }
        }
    }
}

// MARK: - Segmenter

enum MarkdownSegment {
    case prose(String)
    case code(language: String, body: String)
}

private enum MarkdownSegmenter {
    static func segments(from text: String) -> [MarkdownSegment] {
        var out: [MarkdownSegment] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        var prose: [String] = []

        func flushProse() {
            if !prose.isEmpty {
                out.append(.prose(prose.joined(separator: "\n")))
                prose.removeAll()
            }
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    body.append(lines[i])
                    i += 1
                }
                flushProse()
                out.append(.code(language: lang, body: body.joined(separator: "\n")))
                if i < lines.count { i += 1 } // skip closing fence
                continue
            }
            prose.append(line)
            i += 1
        }
        flushProse()
        return out
    }
}

// MARK: - Code block card

private struct CodeBlockCard: View {
    let language: String
    let code: String
    let baseFontSize: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @State private var copied = false

    private var displayLang: String {
        language.isEmpty ? "code" : language.lowercased()
    }

    private var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.11, blue: 0.13)
            : Color(red: 0.97, green: 0.97, blue: 0.98)
    }
    private var headerColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.black.opacity(0.04)
    }
    private var strokeColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }
    private var textColor: Color {
        colorScheme == .dark ? Color(white: 0.92) : Color(white: 0.12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text(displayLang)
                    .font(.system(size: baseFontSize - 2, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(code, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: baseFontSize - 3))
                        Text(copied ? "Copied" : "Copy")
                            .font(.system(size: baseFontSize - 3, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(headerColor)

            Divider().opacity(0.4)

            // Code body — horizontally scrollable so long lines don't wrap awkwardly.
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: baseFontSize - 0.5, weight: .regular, design: .monospaced))
                    .foregroundColor(textColor)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(bgColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(strokeColor, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Prose (everything that isn't a fenced code block)

/// NSTextView subclass that reports the laid-out text height as its
/// intrinsic content size so SwiftUI can size the wrapper correctly. Without
/// this, action buttons rendered below the text overlap long answers.
final class SizingTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        guard let lm = layoutManager, let tc = textContainer else {
            return super.intrinsicContentSize
        }
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc).size
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(used.height))
    }
    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }

    override func scrollWheel(with event: NSEvent) {
        // Let the parent SwiftUI ScrollView handle long AI answers. Otherwise
        // hovering over selectable prose can swallow wheel/trackpad scrolling.
        nextResponder?.scrollWheel(with: event)
    }
}

private struct MarkdownProseView: NSViewRepresentable {
    let text: String
    let font: NSFont
    let textColor: NSColor

    func makeNSView(context: Context) -> SizingTextView {
        let tv = SizingTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer?.lineFragmentPadding = 0
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.setContentHuggingPriority(.required, for: .vertical)
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        tv.linkTextAttributes = [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return tv
    }

    func updateNSView(_ tv: SizingTextView, context: Context) {
        tv.textStorage?.setAttributedString(Self.render(text: text, font: font, color: textColor))
        DispatchQueue.main.async {
            tv.invalidateIntrinsicContentSize()
        }
    }

    static func render(text: String, font: NSFont, color: NSColor) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let codeFont = NSFont.userFixedPitchFont(ofSize: font.pointSize - 0.5)
            ?? NSFont.monospacedSystemFont(ofSize: font.pointSize - 0.5, weight: .regular)
        let codeBgColor = NSColor(calibratedWhite: 0.5, alpha: 0.15)
        let mathBgColor = NSColor.systemTeal.withAlphaComponent(0.10)

        let lines = text.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Display math: $$...$$
            if trimmed.hasPrefix("$$") && trimmed.hasSuffix("$$") && trimmed.count > 4 {
                let body = String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
                let para = NSMutableParagraphStyle()
                para.alignment = .center
                para.paragraphSpacingBefore = 6
                para.paragraphSpacing = 6
                let mathFont = NSFont.userFixedPitchFont(ofSize: font.pointSize + 0.5)
                    ?? NSFont.monospacedSystemFont(ofSize: font.pointSize + 0.5, weight: .regular)
                out.append(NSAttributedString(
                    string: " " + body + " \n",
                    attributes: [
                        .font: mathFont,
                        .foregroundColor: color,
                        .backgroundColor: mathBgColor,
                        .paragraphStyle: para
                    ]
                ))
                i += 1
                continue
            }

            // Bullet line
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let body = String(trimmed.dropFirst(2))
                let para = NSMutableParagraphStyle()
                para.headIndent = 14
                para.firstLineHeadIndent = 0
                para.paragraphSpacing = 2
                let bullet = NSMutableAttributedString(
                    string: "• ",
                    attributes: [.font: font, .foregroundColor: color.withAlphaComponent(0.7), .paragraphStyle: para]
                )
                let bodyAttr = renderInline(line: body, font: font, color: color, codeFont: codeFont, codeBg: codeBgColor, mathBg: mathBgColor)
                bullet.append(bodyAttr)
                bullet.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: bullet.length))
                bullet.append(NSAttributedString(string: "\n"))
                out.append(bullet)
                i += 1
                continue
            }

            // Numbered list
            if let match = trimmed.range(of: #"^(\d+)\.\s+"#, options: .regularExpression) {
                let prefix = String(trimmed[match])
                let body = String(trimmed[match.upperBound...])
                let para = NSMutableParagraphStyle()
                para.headIndent = 18
                para.paragraphSpacing = 2
                let bullet = NSMutableAttributedString(
                    string: prefix,
                    attributes: [.font: font, .foregroundColor: color.withAlphaComponent(0.8), .paragraphStyle: para]
                )
                let bodyAttr = renderInline(line: body, font: font, color: color, codeFont: codeFont, codeBg: codeBgColor, mathBg: mathBgColor)
                bullet.append(bodyAttr)
                bullet.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: bullet.length))
                bullet.append(NSAttributedString(string: "\n"))
                out.append(bullet)
                i += 1
                continue
            }

            // Heading
            if trimmed.hasPrefix("# ") || trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let body = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                let size: CGFloat = font.pointSize + max(0, CGFloat(4 - level)) * 2
                let para = NSMutableParagraphStyle()
                para.paragraphSpacingBefore = 6
                para.paragraphSpacing = 4
                out.append(NSAttributedString(
                    string: body + "\n",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: size, weight: .semibold),
                        .foregroundColor: color,
                        .paragraphStyle: para
                    ]
                ))
                i += 1
                continue
            }

            // Default: inline render
            out.append(renderInline(line: line, font: font, color: color, codeFont: codeFont, codeBg: codeBgColor, mathBg: mathBgColor))
            out.append(NSAttributedString(string: "\n"))
            i += 1
        }

        // Trim trailing newline so spacing is tight.
        if out.string.hasSuffix("\n") {
            out.deleteCharacters(in: NSRange(location: out.length - 1, length: 1))
        }
        return out
    }

    private static func renderInline(line: String,
                                     font: NSFont,
                                     color: NSColor,
                                     codeFont: NSFont,
                                     codeBg: NSColor,
                                     mathBg: NSColor) -> NSAttributedString {
        let mathPattern = #"\$([^\$\n]+)\$"#
        var processed = line
        var mathSubs: [(placeholder: String, body: String)] = []
        if let regex = try? NSRegularExpression(pattern: mathPattern) {
            let matches = regex.matches(in: processed, range: NSRange(processed.startIndex..., in: processed))
            for (idx, m) in matches.enumerated().reversed() {
                guard m.numberOfRanges >= 2,
                      let bodyRange = Range(m.range(at: 1), in: processed),
                      let fullRange = Range(m.range, in: processed) else { continue }
                let body = String(processed[bodyRange])
                let placeholder = "⟦MATH\(idx)⟧"
                mathSubs.append((placeholder, body))
                processed.replaceSubrange(fullRange, with: placeholder)
            }
        }

        let base: NSMutableAttributedString
        if let attributed = try? AttributedString(
            markdown: processed,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            let ns = NSMutableAttributedString(attributedString: NSAttributedString(attributed))
            ns.addAttributes(
                [.font: font, .foregroundColor: color],
                range: NSRange(location: 0, length: ns.length)
            )
            ns.enumerateAttribute(.inlinePresentationIntent, in: NSRange(location: 0, length: ns.length)) { value, range, _ in
                if let raw = value as? Int,
                   InlinePresentationIntent(rawValue: UInt(raw)).contains(.code) {
                    ns.addAttributes([.font: codeFont, .backgroundColor: codeBg], range: range)
                }
            }
            base = ns
        } else {
            base = NSMutableAttributedString(string: processed, attributes: [.font: font, .foregroundColor: color])
        }

        for (placeholder, body) in mathSubs {
            let mathFont = NSFont.userFixedPitchFont(ofSize: font.pointSize)
                ?? NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
            let attr = NSAttributedString(
                string: body,
                attributes: [.font: mathFont, .foregroundColor: color, .backgroundColor: mathBg]
            )
            let raw = base.string as NSString
            let range = raw.range(of: placeholder)
            if range.location != NSNotFound {
                base.replaceCharacters(in: range, with: attr)
            }
        }

        return base
    }
}
