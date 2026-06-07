//
//  AIAssistWindowController.swift
//  Syntra
//
//  Created by occlusion on 6/1/25.
//


import Cocoa
import SwiftUI
import Combine
import Cocoa

/// A borderless window that allows moving its frame completely off-screen,
/// including transparent areas, by handling mouse events manually.
class KeyableBorderlessWindow: NSWindow {
    /// Stores the offset between the window's origin and the initial click point
    private var initialClickOffset: NSPoint = .zero

    override var canBecomeKey: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let chars = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        switch chars {
        case "v": return NSApp.sendAction(#selector(NSText.paste(_:)), to: firstResponder, from: self)
        case "c": return NSApp.sendAction(#selector(NSText.copy(_:)), to: firstResponder, from: self)
        case "x": return NSApp.sendAction(#selector(NSText.cut(_:)), to: firstResponder, from: self)
        case "a": return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: firstResponder, from: self)
        default: return super.performKeyEquivalent(with: event)
        }
    }

}

class AIAssistWindowController: NSWindowController {
    
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Print selected text debug info when window loads
        printWindowDebugInfo()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    var subscribers = Set<AnyCancellable>()
    
    // Add debug function for selected text
    private func printWindowDebugInfo() {
        let contextManager = AIContextManager.shared
        print("=== AI ASSIST WINDOW CONTROLLER DEBUG ===")
        print("Window loaded at: \(Date())")
        print("Has selected text: \(!contextManager.selectedText.isEmpty)")
        if !contextManager.selectedText.isEmpty {
            print("Selected text preview: \(String(contextManager.selectedText.prefix(50)))...")
        }
        print("========================================")
    }

    convenience init() {
        // 3) Calculate total window size (icon + padding)
        let totalSize = NSSize(width: 1000, height: 1000)
        
        
        // 4) Initialize NSWindow with contentRect, styleMask, backing and defer
        let window = KeyableBorderlessWindow(
            contentRect: NSRect(origin: .zero, size: totalSize),
            styleMask: [.borderless, .fullSizeContentView],             // make the window borderless
            backing: .buffered,
            defer: false
        )

        // 1) Create the SwiftUI icon view
        let iconView = AIAssistView(window: window)
        
        // 2) Wrap the SwiftUI view in an NSHostingController
        let hostingController = NSHostingController(rootView: iconView)

        // 5) Assign the contentViewController
        window.contentViewController = hostingController
        window.animationBehavior     = .none
//        window.animatesWhenResized   = true
        // 6) Make window transparent
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hidesOnDeactivate = false
        window.canHide = false
        window.isReleasedWhenClosed = false
        
        // 7) Float above EVERYTHING — including fullscreen apps and games.
        // CGShieldingWindowLevel renders over fullscreen contexts on macOS 12+.
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

        // 8) Raycast/Spotlight-style global overlay: available in all Spaces,
        // moved to the active Space, and allowed over fullscreen apps.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // 9) Add subtle shadow for depth
        window.hasShadow = false
        
        // 11) Center and show
        window.center()

        // No frame autosave/restore: the global launcher must always appear
        // on the current Space at the current cursor, never an older desktop.
        
        // 10) Allow dragging by clicking anywhere in background
        window.isMovableByWindowBackground = true
        
        // 12) Initialize the window controller with our window
        self.init(window: window)
        window.setContentSize(NSSize(width: 500, height: 400))
        
    }
    


}
