//
//  ShortcutTextField.swift
//  Syntra
//
//  Created by occlusion on 5/4/25.
//


import SwiftUI
import AppKit


struct ShortcutTextField: NSViewRepresentable {
    @Binding var shortcut: Shortcut

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }


    func makeNSView(context: Context) -> ShortcutNSTextField {
        let tf = ShortcutNSTextField()
        tf.delegate = context.coordinator
        tf.isBordered    = false
        tf.isEditable    = false
        tf.isSelectable  = false
        tf.font          = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        tf.placeholderString = "Press shortcut…"
        return tf
    }

    func updateNSView(_ nsView: ShortcutNSTextField, context: Context) {
        nsView.stringValue = shortcut.key.isEmpty ? "" : format(shortcut)
    }

    public func format(_ sc: Shortcut) -> String {
        var parts: [String] = []
        if sc.modifiers.contains(.command) { parts.append("⌘") }
        if sc.modifiers.contains(.option)  { parts.append("⌥") }
        if sc.modifiers.contains(.shift)   { parts.append("⇧") }
        if sc.modifiers.contains(.control) { parts.append("⌃") }
        parts.append(sc.key.uppercased())
        return parts.joined()
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ShortcutTextField
        init(_ parent: ShortcutTextField) {
            self.parent = parent
        }
        func controlTextDidBeginEditing(_ obj: Notification) {
            // Clear existing value when focus begins
            parent.shortcut = Shortcut()
        }
    }
}

class ShortcutNSTextField: NSTextField {
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // 1. Ignore plain key presses without modifiers (i.e., only characters)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isEmpty else { return }

        // 2. Only accept letters, numbers, or function keys when modifiers are present
        guard
            let chars = event.charactersIgnoringModifiers?.uppercased(),
            let first = chars.first,
            (first.isLetter || first.isNumber) || chars.hasPrefix("F")
        else {
            return
        }

        // 3. Build and display the shortcut
        let sc = Shortcut(key: String(first), modifiers: flags)
        self.stringValue = (delegate as? ShortcutTextField.Coordinator)?
            .parent.format(sc) ?? ""
        (delegate as? ShortcutTextField.Coordinator)?
            .parent.shortcut = sc
    }
    /// ignore modifier-only changes
    override func flagsChanged(with event: NSEvent) {
        // no-op
    }

    /// Ensure we capture key equivalents too
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        keyDown(with: event)
        return true
    }

    /// Prevent any default text insertion
    override func insertText(_ insertString: Any) {
        // ignore default insertion
    }
}