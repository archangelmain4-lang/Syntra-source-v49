//
//  SyntraApp.swift
//  Syntra
//
//  Created by Teju Sharma on 4/26/25.
//

import SwiftUI
import AppKit
import Carbon
import Vision
import ScreenCaptureKit
import Sparkle
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    
    static var shared: AppDelegate!
    var settingsWindow: SettingsWindowController?
    var setupWindow = SetupWindowController()
    let updaterController: SPUStandardUpdaterController
 
    override init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()
        AppDelegate.shared = self
    }

    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        if !isPreview {
            Font.debugFontAvailability()
            _ = AuthManager.shared

            // Always start the global shortcut listener on every launch
            // (previous behavior only ran it after first-time setup).
            InputEventManager.shared.setup()

            setupWindow.showIfNeeded {
                // Re-register in case permissions were just granted.
                InputEventManager.shared.setup()
            }

            SystemMenuManager.shared.showSettings = { [weak self] in
                self?.showSettingsOnActiveSpace()
            }
            SystemMenuManager.shared.setup()

            // Allow the dormant pill (and anywhere else) to request settings.
            NotificationCenter.default.addObserver(
                forName: Notification.Name("OpenSettingsRequest"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.showSettingsOnActiveSpace()
            }

            // Auto-open the AI Assist overlay shortly after launch so users
            // see it without having to press the shortcut first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if !(AIAssistOverlayManager.shared.windowViewController.window?.isVisible ?? false) {
                    AIAssistOverlayManager.shared.toggle()
                }
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // When user re-activates Syntra (clicking dock, app switcher), surface
        // the assist overlay if it's not already visible.
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        guard !isPreview else { return }
        guard !AIAssistOverlayManager.shared.recentlyHiddenByGlobalShortcut else { return }
        // Ensure shortcuts are armed (idempotent).
        InputEventManager.shared.setup()
        if !(AIAssistOverlayManager.shared.windowViewController.window?.isVisible ?? false) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                guard !AIAssistOverlayManager.shared.recentlyHiddenByGlobalShortcut else { return }
                if !(AIAssistOverlayManager.shared.windowViewController.window?.isVisible ?? false) {
                    AIAssistOverlayManager.shared.toggle()
                }
            }
        }
    }
    

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources when app terminates
    }

    private func showSettingsOnActiveSpace() {
        settingsWindow?.close()
        settingsWindow = SettingsWindowController()
        settingsWindow?.show()
    }
    
}


@main
struct SyntraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { }
    }
}
