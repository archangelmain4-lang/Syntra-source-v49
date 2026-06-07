//
//  MainWindow.swift
//  Syntra
//
//  Created by occlusion on 4/29/25.
//

import Cocoa
import SwiftUI

class ClickThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hit = super.hitTest(point), hit !== self {
            return hit
        }
        return nil
    }
}


class MainWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    convenience init(rect: NSRect){
        self.init(
            contentRect: rect,
            styleMask: [.resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        setup(rect: rect)
    }
    
    func setup(rect: NSRect){
        
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        
        let container = ClickThroughView(frame: rect)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.autoresizingMask = [.width, .height]
        contentView = container
        
        let hosting = NSHostingView(rootView: MainView())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        
    }
}


