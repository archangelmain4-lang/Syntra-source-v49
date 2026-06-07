//
//  SetupView.swift
//  Syntra
//
//  Created by occlusion on 5/4/25.
//

import SwiftUI
import AppKit // Needed for NSEvent keyboard monitoring

struct SetupView: View {
    @AppStorage("FinishFirstTime") var finishFirstTime: Bool = false
    @AppStorage("FinishSetup") var finishSetup: Bool = false
    @AppStorage("Shortcut") private var shortcut: Shortcut = Shortcut(key: "", modifiers: [])
    @AppStorage("HasSeenWelcome") private var hasSeenWelcome: Bool = false

    @State private var showFloatingOnboarding: Bool = false
    @State private var animateToSmallWindow: Bool = false
    @State private var eventMonitor: Any? // Global keyboard listener during setup
    
    // MARK: - TEMPORARY: Skip to floating controller
    @State private var skiptofloating: Bool = false
    
    var didFinish: (() -> Void)? = nil

    @ObservedObject var model = PermissionManager.shared.model
    
    // MARK: - TEMPORARY: Force reset for testing
    init(didFinish: (() -> Void)? = nil) {
        self.didFinish = didFinish
    }

    var body: some View {
        VStack {
            // Check if we should skip to floating onboarding
            if skiptofloating {
                VStack {
                    Text("Skipping to Floating Onboarding...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding()
                }
                .onAppear {
                    // Small delay to show the message briefly, then proceed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        didFinish?()
                    }
                }
            } else {
                 if !finishFirstTime && !hasSeenWelcome {
                     WelcomeView {
                         finishFirstTime = true
                         hasSeenWelcome = true
                     }
                 }
                 else {
                     // Skip welcome if already seen, but make sure finishFirstTime is set
                     if !finishFirstTime && hasSeenWelcome {
                         // Auto-advance past welcome for returning users
                         Text("")
                             .onAppear {
                                 finishFirstTime = true
                             }
                     }
                     else if !model.accessibilityPermission{
                         PermissionTemplateView(
                             title: "To assist you anytime, \nSyntra needs \naccessibility access.",
                             subtitle: "Click Grant Access, enable Syntra Opus in System Settings → Privacy & Security → Accessibility, then click \"I enabled it — Continue\".",
                             isPermissionGranted: model.accessibilityPermission,
                             onGrantAccess: {
                                 PermissionManager.shared.requestAccessibilityPermission()
                             },
                             onNeedHelp: {
                                 if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                     NSWorkspace.shared.open(url)
                                 }
                             },
                             onNextStep: {
                                 PermissionManager.shared.refreshPermissions()
                             },
                             image: "ai-assist-ss",
                             manualContinueTitle: "I enabled it — Continue",
                             onManualContinue: {
                                 PermissionManager.shared.trustAccessibilityPermissionForSetup()
                             },
                             restartTitle: "Restart Syntra Opus",
                             onRestart: {
                                 PermissionManager.shared.restartApp()
                             }
                         )
                     }

                     else if !model.screenCapturePermission{
                         if model.screenCaptureRequireRestart{
                             // Special case for restart requirement
                             VStack {
                                 Text("Screen Recording Permission Required")
                                     .font(.system(size: 20, weight: .semibold)).padding()
                            
                                 Spacer()

                                  Text("If you already enabled Screen Recording, continue now. If Syntra Opus still cannot capture after setup, restart the app once.")
                                     .multilineTextAlignment(.center)
                                     .padding()

                                 Spacer()
                                  Button("I enabled it — Continue"){
                                      PermissionManager.shared.trustScreenCapturePermissionForSetup()
                                  }.padding(.bottom, 4)

                                  Button("Restart Syntra Opus"){
                                      PermissionManager.shared.restartApp()
                                 }.padding()
                             }
                         } else {
                             VStack(spacing: 0) {
                                 PermissionTemplateView(
                                     title: "Now to automatically analyze your screen (even images!), \nSyntra needs \nscreen access.",
                                     subtitle: "",
                                     isPermissionGranted: model.screenCapturePermission,
                                     onGrantAccess: {
                                         PermissionManager.shared.requestScreenCapturePermission()
                                     },
                                     onNeedHelp: {
                                         if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                                             NSWorkspace.shared.open(url)
                                         }
                                     },
                                     onNextStep: {},
                                     image: "slack-ss"
                                 )
                                 if model.userRequestedScreenCapture {
                                      Button("I enabled it — Continue") {
                                          PermissionManager.shared.trustScreenCapturePermissionForSetup()
                                     }
                                     .padding(.bottom, 16)
                                 }
                             }
                         }
                     }
                     else {
                        VStack {
                            Text("All Set!")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding()

                            Button("Continue"){
                                didFinish?()
                            }.padding()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .colorScheme(.light)
        .cornerRadius(20)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .inset(by: 0.5)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .onAppear {
            startGlobalShortcutMonitoring()
        }
        .onDisappear {
            stopGlobalShortcutMonitoring()
        }
    }

    // MARK: - Global Shortcut Monitoring
    private func startGlobalShortcutMonitoring() {
        // If global hotkeys are already active, avoid adding a duplicate local monitor.
        guard !InputEventManager.shared.isListening else { return }

        // Ensure we don't add multiple monitors
        stopGlobalShortcutMonitoring()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handleKeyEvent(event)
        }
    }

    private func stopGlobalShortcutMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        let pressedModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let pressedKey = event.keyCode.keyCodeToString

        // Shortcut references
        let aiAssistShortcut = InputEventManager.shared.model.aiAssistShortcut
        // Helper closure to match shortcuts
        func shortcutMatches(target: Shortcut) -> Bool {
            var targetModifiers: NSEvent.ModifierFlags = []
            if target.modifiers.contains(.command) { targetModifiers.insert(.command) }
            if target.modifiers.contains(.shift) { targetModifiers.insert(.shift) }
            if target.modifiers.contains(.option) { targetModifiers.insert(.option) }
            if target.modifiers.contains(.control) { targetModifiers.insert(.control) }
            return pressedKey.lowercased() == target.key.lowercased() && pressedModifiers == targetModifiers
        }

        if shortcutMatches(target: aiAssistShortcut) {
            QuickCaptureOverlay.instance.stop()
            AutoContextOverlay.instance.stop()
            AIAssistOverlayManager.shared.toggleFromGlobalShortcut()
            return nil
        }

        return event
    }
}

#Preview {
    SetupView()
}
