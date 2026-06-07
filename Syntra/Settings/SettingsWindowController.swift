//
//  SettingsWindowController.swift
//  Syntra
//
//  Created by occlusion on 6/1/25.
//


import Cocoa
import SwiftUI
import Combine
import Cocoa


class SettingsWindowController: NSWindowController, NSWindowDelegate {
    
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    convenience init() {
        // 3) Calculate total window size (icon + padding)
        let totalSize = NSSize(width: 1000, height: 1000)
        
        
        // 4) Initialize NSWindow with contentRect, styleMask, backing and defer
        let window = KeyableBorderlessWindow(
            contentRect: NSRect(origin: .zero, size: totalSize),
            styleMask: [    .titled,
                            .fullSizeContentView,
                            .closable,
                            .miniaturizable,
                            .resizable],             // make the window borderless
            backing: .buffered,
            defer: false
        )
        

        // 1) Create the SwiftUI icon view
        let iconView = SettingsView(window: window)
        
        // 2) Wrap the SwiftUI view in an NSHostingController
        let hostingController = NSHostingController(rootView: iconView)

        window.titlebarAppearsTransparent = true
        // 5) Assign the contentViewController
        window.contentViewController = hostingController
        window.animationBehavior     = .utilityWindow
//        window.animatesWhenResized   = true
        // 6) Make window transparent
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        
        // 7) Float above fullscreen/browser windows like the assistant overlay.
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        
        // 9) Add subtle shadow for depth
        window.hasShadow = false
        
        // 11) Center and show
        window.center()

        // 10) Allow dragging by clicking anywhere in background
        window.isMovableByWindowBackground = true
        
        // 12) Initialize the window controller with our window
        self.init(window: window)
        window.setContentSize(NSSize(width: 500, height: 720))
        window.delegate = self

        
    }

    
    func show(){
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
        // Ensure a sensible size and that the window is fully visible on the
        // active screen/Space instead of resurrecting on an older desktop.
        if let win = self.window {
            win.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let desired = NSSize(width: 500, height: 720)
            var frame = win.frame
            let mousePoint = NSEvent.mouseLocation
            let activeScreen = NSScreen.screens.first { NSMouseInRect(mousePoint, $0.frame, false) } ?? NSScreen.main
            if let screen = activeScreen {
                let visible = screen.visibleFrame
                let w = min(desired.width, visible.width - 40)
                let h = min(desired.height, visible.height - 40)
                let x = visible.midX - w / 2
                let y = visible.midY - h / 2
                frame = NSRect(x: x, y: y, width: w, height: h)
            } else {
                frame.size = desired
            }
            win.setFrame(frame, display: true, animate: false)
            win.isReleasedWhenClosed = false
            win.orderFrontRegardless()
            win.makeKeyAndOrderFront(self)
            print("[SyntraSettings] App Active:", NSApp.isActive)
            print("[SyntraSettings] Window Visible:", win.isVisible)
            print("[SyntraSettings] Window Occluded:", win.occlusionState)
            print("[SyntraSettings] Window Screen:", String(describing: win.screen))
            print("[SyntraSettings] Window Number:", win.windowNumber)
        }
    }
    
    override func close() {
        super.close()

    }
    
    
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
