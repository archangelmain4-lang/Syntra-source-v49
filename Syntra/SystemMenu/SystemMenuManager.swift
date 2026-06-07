//
//  SystemMenuManager.swift
//  Syntra
//
//  Created by occlusion on 5/5/25.
//

import Cocoa
import Sparkle

class SystemMenuManager {
    var statusItem: NSStatusItem!

    static let shared = SystemMenuManager()
    var showSettings:(()->Void)? = nil

    func setup(){
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            let icon = NSImage(named: "icon_template")
            icon?.isTemplate = true
            icon?.size = NSSize(width: 18, height: 18)
            button.image = icon
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        
        let item1 = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent:"")
        item1.target = self
    
        let item2 = NSMenuItem(title: "Check For Update...", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent:"")
        item2.target = AppDelegate.shared.updaterController
    
        let item3 = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent:"")
        item3.target = self
    
        menu.addItem(item1)
        menu.addItem(item2)
        menu.addItem(.separator())
        menu.addItem(item3)
        
        statusItem.menu = menu

    }
    
    
    @objc private func openSettings() {
        showSettings?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
    
}
