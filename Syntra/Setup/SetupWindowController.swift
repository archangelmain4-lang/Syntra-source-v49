//
//  PermissionWindowController.swift
//  Syntra
//
//  Created by occlusion on 5/4/25.
//

import Cocoa
import SwiftUI

class FloatingOnboardingWindowController: NSWindowController {
    
    var didFinishCallback: (() -> Void)? = nil
    private let anchorFrame: NSRect?
    
    init(anchorFrame: NSRect? = nil) {
        self.anchorFrame = anchorFrame
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 324, height: 242),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Make window background transparent so inner SwiftUI view handles blur and corner radius
        window.isOpaque = false
        window.backgroundColor = .clear
        
        // Configure window appearance
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        
        // Make window float above other apps
        window.level = .floating
        window.hasShadow = false
        
        var self_: FloatingOnboardingWindowController? = nil
        
        let floatingOnboarding = FloatingOnboarding {
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: "FinishSetup")
                self_?.didFinishCallback?()
                self_?.close()
            }
        }
        
        window.contentViewController = NSHostingController(rootView: floatingOnboarding)
        
        super.init(window: window)
        
        self_ = self
        
        // Position window relative to anchor if provided, else we'll position when showing
        if let anchor = anchorFrame {
            let windowSize = window.frame.size
            let x = anchor.midX - windowSize.width / 2
            let y = anchor.midY - windowSize.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // If no anchor frame provided, fallback to center of main screen
        if anchorFrame == nil, let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowSize = self.window?.frame.size ?? NSSize(width: 324, height: 242)
            let x = screenFrame.midX - windowSize.width / 2
            let y = screenFrame.midY - windowSize.height / 2
            self.window?.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showFloatingOnboarding(finishCallback: (() -> Void)? = nil) {
        didFinishCallback = finishCallback
        self.showWindow(self)
        
        // Center the window on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowSize = self.window?.frame.size ?? NSSize(width: 324, height: 242)
            let x = screenFrame.midX - windowSize.width / 2
            let y = screenFrame.midY - windowSize.height / 2
            
            self.window?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        self.window?.makeKeyAndOrderFront(self)
    }
}

class SetupWindowController: NSWindowController {
    
    var didFinishCallback: (() -> Void)? = nil
    
    // TODO: delete, set to false when testing is complete
    private let forceShowSetupForTesting = false
    private let forceShowFloatingOnboardingForTesting = false
    
    init() {
        // Calculate window size as percentage of screen
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        let windowWidth = screenFrame.width * 0.62
        let windowHeight = screenFrame.height * 0.64
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .resizable, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Make window background transparent so inner SwiftUI view handles blur and corner radius
        window.isOpaque = false
        window.backgroundColor = .clear
        
        // Hide title bar and configure window appearance
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        // Remove standard window buttons for cleaner look (optional)
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        
        var self_: SetupWindowController? = nil
        
        let permission = SetupView {
            DispatchQueue.main.async {
                // Close the main setup window
                self_?.close()
                
                // Show floating onboarding in a separate window, centered on screen
                let floatingController = FloatingOnboardingWindowController()
                floatingController.showFloatingOnboarding {
                    UserDefaults.standard.set(true, forKey: "HasSeenFloatingOnboarding")
                    NSApp.setActivationPolicy(.accessory)
                    self_?.didFinishCallback?()
                }
            }
        }
        
        window.contentViewController = NSHostingController(rootView: permission)

        // Set the calculated content size
        window.setContentSize(NSSize(width: windowWidth, height: windowHeight))

        super.init(window: window)
        
        self_ = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showSetting(){
        NSApp.setActivationPolicy(.regular)
        self.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        self.window?.center()
        self.window?.makeKeyAndOrderFront(self)
    }

    
    func showIfNeeded(finishCallback:(()->Void)? = nil){
        let finishSetup = UserDefaults.standard.bool(forKey: "FinishSetup")
        let shortcut = Shortcut(rawValue: UserDefaults.standard.string(forKey: "Shortcut") ?? "")
        
        // MARK: - TEMPORARY TESTING OVERRIDE
        // TODO: Remove or comment out this condition when testing is complete
        if forceShowSetupForTesting {
            didFinishCallback = finishCallback
            NSApp.setActivationPolicy(.regular)
            self.showWindow(self)
            NSApp.activate(ignoringOtherApps: true)
            self.window?.center()
            return
        }
        
        // Check if all permissions are granted
        let allPermissionsGranted = !PermissionManager.shared.isRequiredToShow
        
        // MARK: - ORIGINAL PRODUCTION LOGIC (updated to handle permission completion)
        // If all permissions are already granted, skip main setup and go directly to floating onboarding or finish
        if allPermissionsGranted && !finishSetup {
            // All permissions are granted but setup isn't marked as finished
            // This happens after restart from screen permission grant
            // Skip the main setup and go directly to floating onboarding
            print("  - All permissions granted, skipping main setup")
            let hasSeenFloatingOnboarding = UserDefaults.standard.bool(forKey: "HasSeenFloatingOnboarding")
            
            if !hasSeenFloatingOnboarding {
                print("  - Showing floating onboarding directly")
                let floatingController = FloatingOnboardingWindowController()
                floatingController.showFloatingOnboarding {
                    print("  - Floating onboarding completed")
                    UserDefaults.standard.set(true, forKey: "HasSeenFloatingOnboarding")
                    UserDefaults.standard.set(true, forKey: "FinishSetup")
                    NSApp.setActivationPolicy(.accessory)
                    finishCallback?()
                }
            } else {
                print("  - All permissions granted and floating onboarding seen, marking setup complete")
                UserDefaults.standard.set(true, forKey: "FinishSetup")
                finishCallback?()
            }
        }
        else if PermissionManager.shared.isRequiredToShow || !finishSetup {
            // Show main setup if permissions are missing or setup is not finished
            didFinishCallback = finishCallback
            NSApp.setActivationPolicy(.regular)
            self.showWindow(self)
            NSApp.activate(ignoringOtherApps: true)
            self.window?.center()
        }
        else{
            print("  - Setup not needed, checking floating onboarding...")
            // Check if we need to show floating onboarding
            let hasSeenFloatingOnboarding = UserDefaults.standard.bool(forKey: "HasSeenFloatingOnboarding")
            print("  - hasSeenFloatingOnboarding: \(hasSeenFloatingOnboarding)")
            
            // MARK: - TEMPORARY TESTING OVERRIDE FOR FLOATING ONBOARDING
            // TODO: Remove or comment out this condition when testing is complete
            if forceShowFloatingOnboardingForTesting || !hasSeenFloatingOnboarding {
                print("  - Showing floating onboarding")
                let floatingController = FloatingOnboardingWindowController()
                floatingController.showFloatingOnboarding {
                    print("  - Floating onboarding completed")
                    UserDefaults.standard.set(true, forKey: "HasSeenFloatingOnboarding")
                    NSApp.setActivationPolicy(.accessory)
                    finishCallback?()
                }
            } else {
                print("  - No setup needed, calling finish callback")
                finishCallback?()
            }
        }
    }
}
