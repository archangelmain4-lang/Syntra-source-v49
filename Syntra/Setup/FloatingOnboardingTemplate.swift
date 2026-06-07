//
//  FloatingOnboardingTemplate.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import SwiftUI
import Carbon

extension UInt16{
    
    var keyCodeToString: String {
        switch self {
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        case 0: return "a"
        case 11: return "b"
        case 8: return "c"
        case 2: return "d"
        case 14: return "e"
        case 3: return "f"
        case 5: return "g"
        case 4: return "h"
        case 34: return "i"
        case 38: return "j"
        case 40: return "k"
        case 37: return "l"
        case 46: return "m"
        case 45: return "n"
        case 31: return "o"
        case 35: return "p"
        case 12: return "q"
        case 15: return "r"
        case 1: return "s"
        case 17: return "t"
        case 32: return "u"
        case 9: return "v"
        case 13: return "w"
        case 7: return "x"
        case 16: return "y"
        case 6: return "z"
        default: return ""
        }
    }
}

struct FloatingOnboardingTemplate: View {
    let title: String
    let instruction: String
    let shortcut: Shortcut?
    let optionalText: String?
    let hasClickableLink: Bool
    let hasMultipleLinks: Bool
    let showContinueButton: Bool
    let buttonText: String
    let onShortcutAdjust: () -> Void
    let onNeedHelp: () -> Void
    let onFinish: () -> Void
    let onLinkClick: (() -> Void)?
    let onDiscordClick: (() -> Void)?
    // let onSlackClick: (() -> Void)?
    let onXClick: (() -> Void)?
    let onShortcutUpdate: ((Shortcut) -> Void)?
    
    @State private var showTitle = false
    @State private var showInstruction = false
    @State private var showOptionalText = false
    @State private var showNeedHelp = false
    @State private var isEditingShortcut = false
    @State private var localShortcut: Shortcut = Shortcut()
    @State private var keyEventMonitor: Any?
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            VStack(alignment: .leading, spacing: 16) {
                // Title with potential clickable link
                if hasClickableLink {
                    HStack(spacing: 0) {
                        Text("Done! First, let's try AI Assist on ")
                            .font(Font.custom("SF Pro Display", size: 15).weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Button(action: onLinkClick ?? {}) {
                            Text("this link")
                                .font(Font.custom("SF Pro Display", size: 15).weight(.semibold))
                                .foregroundColor(.primary)
                                .underline()
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(".")
                            .font(Font.custom("SF Pro Display", size: 15).weight(.semibold))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(showTitle ? 1 : 0)
                    .offset(x: showTitle ? 0 : -20)
                    .animation(.easeOut(duration: 0.6), value: showTitle)
                } else if hasMultipleLinks {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(Font.custom("SF Pro Display", size: 15).weight(.semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Join the communities below to see the next evolutions:")
                                .font(Font.custom("SF Pro Display", size: 12))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Individual clickable links
                            HStack(alignment: .center, spacing: 4) {
                                Button(action: onDiscordClick ?? {}) {
                                    Text("Discord")
                                        .font(Font.custom("SF Pro Display", size: 11))
                                        .foregroundColor(.secondary)
                                        .underline()
                                }
                                .buttonStyle(PlainButtonStyle())
                                
//                                Button(action: onSlackClick ?? {}) {
//                                    Text("Slack")
//                                        .font(Font.custom("SF Pro Display", size: 11))
//                                        .foregroundColor(.secondary)
//                                        .underline()
//                                }
//                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: onXClick ?? {}) {
                                    Text("X")
                                        .font(Font.custom("SF Pro Display", size: 11))
                                        .foregroundColor(.secondary)
                                        .underline()
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Text("\nTo access settings, click the Syntra icon in the status bar at the top. The possibilities are endless from here on out.")
                                .font(Font.custom("SF Pro Display", size: 12))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(showTitle ? 1 : 0)
                    .offset(x: showTitle ? 0 : -20)
                    .animation(.easeOut(duration: 0.6), value: showTitle)
                } else {
                    Text(title)
                        .font(Font.custom("SF Pro Display", size: 15).weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(showTitle ? 1 : 0)
                        .offset(x: showTitle ? 0 : -20)
                        .animation(.easeOut(duration: 0.6), value: showTitle)
                }
                
                // Instruction with optional shortcut button
                if let shortcut = shortcut {
                    HStack(spacing: 4) {
                        Text(instruction)
                            .font(Font.custom("SF Pro Display", size: 12))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            isEditingShortcut = true
                            localShortcut = shortcut
                            startKeyboardMonitoring()
                        }) {
                            HStack(alignment: .center, spacing: 10) {
                                Text(isEditingShortcut ? "Press shortcut..." : shortcutDisplayText(for: localShortcut.key.isEmpty ? shortcut : localShortcut))
                                    .font(Font.custom("SF Pro", size: 10).weight(.bold).italic())
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(height: 15, alignment: .center)
                            .background(isEditingShortcut ? Color.blue.opacity(0.5) : Color(red: 1, green: 0.55, blue: 0.24).opacity(0.5))
                            .cornerRadius(7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .inset(by: 1)
                                    .stroke(isEditingShortcut ? Color.blue : Color(red: 1, green: 0.55, blue: 0.24), lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(" to see the magic.")
                            .font(Font.custom("SF Pro Display", size: 12))
                            .foregroundColor(.secondary)
                    }
                    .opacity(showInstruction ? 1 : 0)
                    .offset(x: showInstruction ? 0 : -20)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: showInstruction)
                } else {
                    Text(instruction)
                        .font(Font.custom("SF Pro Display", size: 12))
                        .foregroundColor(.secondary)
                        .opacity(showInstruction ? 1 : 0)
                        .offset(x: showInstruction ? 0 : -20)
                        .animation(.easeOut(duration: 0.6).delay(0.2), value: showInstruction)
                }
                
                // Optional adjustment text
                if let optionalText = optionalText {
                    Text(optionalText)
                        .font(Font.custom("SF Pro Display", size: 12))
                        .foregroundColor(.secondary)
                        .opacity(showOptionalText ? 1 : 0)
                        .offset(x: showOptionalText ? 0 : -20)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: showOptionalText)
                }
                
                Spacer()
            }
            .padding()
            
            // Bottom section with Need Help or Continue button
            HStack {
                Spacer()
                
                if showContinueButton {
                    Button(action: onShortcutAdjust) {
                        HStack(alignment: .center, spacing: 2) {
                            Text(buttonText)
                                .font(Font.custom("SF Pro Display", size: 13).weight(.semibold))
                                .foregroundColor(Color(red: 0.33, green: 0.2, blue: 0.04))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .center)
                        .background(Color(red: 1, green: 0.83, blue: 0.64).opacity(0.75))
                        .cornerRadius(100)
                        .shadow(color: Color(red: 1, green: 0.59, blue: 0.24).opacity(0.25), radius: 12, x: 0, y: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 100)
                                .inset(by: 0.5)
                                .stroke(Color(red: 0.99, green: 0.63, blue: 0.22).opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(showNeedHelp ? 1 : 0)
                    .offset(x: showNeedHelp ? 0 : -20)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: showNeedHelp)
                } else {
                    Button(action: onNeedHelp) {
                        HStack(alignment: .top, spacing: 4) {
                            ZStack() {
                                Text("?")
                                    .font(Font.custom("SF Pro", size: 10.40).weight(.medium))
                                    .lineSpacing(12.80)
                                    .foregroundColor(.secondary)
                                    .offset(x: 0.10, y: -0.30)
                            }
                            .frame(width: 16, height: 16)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(80)
                            
                            Text("Need Help")
                                .font(Font.custom("SF Pro Display", size: 13).weight(.semibold))
                                .lineSpacing(16)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(showNeedHelp ? 1 : 0)
                    .offset(x: showNeedHelp ? 0 : -20)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: showNeedHelp)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 324, height: 242)
        .background(.regularMaterial)
        .cornerRadius(20)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .inset(by: 0.5)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .onAppear {
            // Delay text animations by 1 second to prevent flicker
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showTitle = true
                showInstruction = true
                showOptionalText = true
                showNeedHelp = true
            }
            
            // Initialize local shortcut
            if let shortcut = shortcut {
                localShortcut = shortcut
            }
        }
        .onDisappear {
            // Clean up keyboard monitoring
            stopKeyboardMonitoring()
        }
        .onChange(of: shortcut) { newShortcut in
            // Update local shortcut when prop changes
            if let newShortcut = newShortcut {
                localShortcut = newShortcut
            }
        }
    }
    
    private func shortcutDisplayText(for shortcut: Shortcut) -> String {
        var components: [String] = []
        
        if shortcut.modifiers.contains(.command) { components.append("⌘") }
        if shortcut.modifiers.contains(.option) { components.append("⌥") }
        if shortcut.modifiers.contains(.shift) { components.append("⇧") }
        if shortcut.modifiers.contains(.control) { components.append("⌃") }
        
        if !shortcut.key.isEmpty {
            components.append(shortcut.key.uppercased())
        }
        
        return components.joined()
    }
    
    private func startKeyboardMonitoring() {
        // Stop any existing monitor
        stopKeyboardMonitoring()
        
        // Create local event monitor for when the window has focus
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Check if we have modifier keys
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // Only accept if there are modifiers
            if !flags.isEmpty {
                // Check if it's a valid key
                let chars = event.keyCode.keyCodeToString
                if let first = chars.first,
                   (first.isLetter || first.isNumber) || chars.hasPrefix("F") {
                    
                    // Create new shortcut
                    let newShortcut = Shortcut(key: String(first), modifiers: flags)
                    
                    DispatchQueue.main.async {
                        self.localShortcut = newShortcut
                        self.onShortcutUpdate?(newShortcut)
                        self.isEditingShortcut = false
                        self.stopKeyboardMonitoring()
                    }
                    
                    return nil // Consume the event
                }
            }
            
            // Check for Escape key to cancel
            if event.keyCode == 53 { // Escape key
                DispatchQueue.main.async {
                    self.isEditingShortcut = false
                    self.localShortcut = Shortcut() // Reset
                    self.stopKeyboardMonitoring()
                }
                return nil
            }
            
            return event
        }
    }
    
    private func stopKeyboardMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
}

enum OnboardingStep: Int, CaseIterable {
    case aiAssist = 0
    case autoRead = 1
    case quickCapture = 2
    case captureThought = 3
    case testNotes = 4
    case connectAccount = 5
    case complete = 6
    
    var title: String {
        switch self {
        case .aiAssist:
            return "You're set! First, let's try AI Assist on this link."
        case .autoRead:
            return "Great, Syntra automatically reads your screen — you don't need to copy and paste into ChatGPT!"
        case .quickCapture:
            return ""
        case .captureThought:
            return ""
        case .testNotes:
            return "Now try Explain Screen"
        case .connectAccount:
            return "Connect Your Account"
        case .complete:
            return "✅ You're now on Syntra!"
        }
    }
    
    var instruction: String {
        switch self {
        case .aiAssist:
            return "Press "
        case .autoRead:
            return "Try asking \"explain this in simple steps\" or \"create an intro to this topic for a colleague\""
        case .quickCapture:
            return "Press "
        case .captureThought:
            return "And press enter — no need to tag, you'll find it with AI search anyways"
        case .testNotes:
            return "Press "
        case .connectAccount:
            return "To track your notes, recall them at the right time, and sync apps for your AI to Use"
        case .complete:
            return ""
        }
    }
    
    var shortcut: Shortcut? {
        switch self {
        case .aiAssist:
            return InputEventManager.shared.model.aiAssistShortcut
        case .autoRead:
            return nil
        case .quickCapture:
            return nil
        case .captureThought:
            return nil
        case .testNotes:
            return nil
        case .connectAccount:
            return nil
        case .complete:
            return nil
        }
    }
    
    var optionalText: String? {
        switch self {
        case .aiAssist:
            return "(Or click the button above to adjust the shortcut)"
        case .autoRead:
            return nil
        case .quickCapture:
            return nil
        case .captureThought:
            return nil
        case .testNotes:
            return "Syntra will look at the current screen and answer automatically."
        case .connectAccount:
            return nil
        case .complete:
            return nil
        }
    }
    
    var hasClickableLink: Bool {
        return self == .aiAssist
    }
    
    var hasMultipleLinks: Bool {
        return self == .complete
    }
}

struct FloatingOnboarding: View {
    
    @State private var currentStep: OnboardingStep = .aiAssist
    @State private var showShortcutAdjustment = false
    @State private var eventMonitor: Any?
    @ObservedObject var inputEventModel = InputEventManager.shared.model
    
    // MARK: - TEMPORARY TESTING FLAG
    // TODO: Set to false or remove this flag when testing is complete
    private let forceShowFloatingOnboardingForTesting = false
    
    let onFinish: () -> Void
    
    var body: some View {
        FloatingOnboardingTemplate(
            title: currentStep.title,
            instruction: currentStep.instruction,
            shortcut: currentStepShortcut(),
            optionalText: currentStep.optionalText,
            hasClickableLink: currentStep.hasClickableLink,
            hasMultipleLinks: currentStep.hasMultipleLinks,
            showContinueButton: currentStep == .autoRead || currentStep == .captureThought || currentStep == .connectAccount || currentStep == .complete,
            buttonText: currentStep == .autoRead ? "Continue" : currentStep == .captureThought ? "Continue" : currentStep == .connectAccount ? "Connect Account" : "Onwards!",
            onShortcutAdjust: {
                if currentStep == .aiAssist {
                    showShortcutAdjustment = true
                } else if currentStep == .connectAccount {
                    // Start the authentication flow. The onboarding will advance automatically
                    // once the callback is received (see .authCallbackReceived observer below).
                    AuthManager.shared.startAuthFlow()
                } else {
                    advanceToNextStep()
                }
            },
            onNeedHelp: {
                // Handle need help
            },
            onFinish: onFinish,
            onLinkClick: {
                // Open Syntra documentation
                if let url = URL(string: "https://syntra.cc/documents") {
                    NSWorkspace.shared.open(url)
                }
                advanceToNextStep()
            },
            onDiscordClick: {
                // Open Syntra status / community
                if let url = URL(string: "https://status.syntra.cc") {
                    NSWorkspace.shared.open(url)
                }
            },
            onXClick: {
                // Open Syntra on the web
                if let url = URL(string: "https://syntra.cc") {
                    NSWorkspace.shared.open(url)
                }
            },
            onShortcutUpdate: { newShortcut in
                // Update the appropriate shortcut based on current step
                switch currentStep {
                case .aiAssist:
                    inputEventModel.aiAssistShortcut = newShortcut
                case .quickCapture:
                    break
                case .testNotes:
                    break
                default:
                    break
                }
            }
        )
        .onAppear {
            // If the user is already signed in to Syntra, skip the "Connect Account" step on first render.
            if currentStep == .connectAccount && AuthManager.shared.model.isAuthenticated {
                advanceToNextStep()
            }
            startShortcutMonitoring()

            NotificationCenter.default.addObserver(forName: .shortcutTriggered, object: nil, queue: .main) { notif in
                guard let type = notif.userInfo?["type"] as? String else { return }
                if type == "aiAssist" && currentStep == .aiAssist {
                    advanceToNextStep()
                }
            }

            // Advance when authentication completes during the "Connect Account" step.
            NotificationCenter.default.addObserver(forName: .authCallbackReceived, object: nil, queue: .main) { _ in
                if currentStep == .connectAccount {
                    advanceToNextStep()
                }
            }
        }
        .onDisappear {
            stopShortcutMonitoring()
            NotificationCenter.default.removeObserver(self, name: .shortcutTriggered, object: nil)
            NotificationCenter.default.removeObserver(self, name: .authCallbackReceived, object: nil)
        }
    }
    
    private func currentStepShortcut() -> Shortcut? {
        switch currentStep {
        case .aiAssist:
            return inputEventModel.aiAssistShortcut
        case .autoRead:
            return nil
        case .quickCapture:
            return nil
        case .captureThought:
            return nil
        case .testNotes:
            return nil
        case .connectAccount:
            return nil
        case .complete:
            return nil
        }
    }
    
    private func advanceToNextStep() {
        if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
            // Quick Capture / capture-thought notes flow is removed.
            if currentStep == .quickCapture || currentStep == .captureThought || currentStep == .testNotes {
                advanceToNextStep()
                return
            }
            // Skip the "Connect Account" step entirely if the user is already signed in.
            if currentStep == .connectAccount && AuthManager.shared.model.isAuthenticated {
                advanceToNextStep()
            }
        } else {
            onFinish()
        }
    }
    
    private func startShortcutMonitoring() {
        // If global hotkeys are active, rely on them to handle shortcuts.
        guard !InputEventManager.shared.isListening else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            return handleKeyEvent(event)
        }
    }
    
    private func stopShortcutMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        let pressedModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let pressedKey = event.keyCode.keyCodeToString
        
        // Always allow toggling of overlays, irrespective of the current step
        if shortcutMatches(pressedKey: pressedKey, pressedModifiers: pressedModifiers, targetShortcut: inputEventModel.aiAssistShortcut) {
            // Toggle AI Assist overlay
            QuickCaptureOverlay.instance.stop()
            AutoContextOverlay.instance.stop()
            AIAssistOverlayManager.shared.toggleFromGlobalShortcut()
            NotificationCenter.default.post(name: .shortcutTriggered, object: nil, userInfo: ["type": "aiAssist"])
            // Advance only if on the AI Assist step
            if currentStep == .aiAssist {
                DispatchQueue.main.async { advanceToNextStep() }
            }
            return nil
        }
        
        return event
    }
    
    private func shortcutMatches(pressedKey: String, pressedModifiers: NSEvent.ModifierFlags, targetShortcut: Shortcut) -> Bool {
        // Convert target shortcut modifiers to NSEvent.ModifierFlags
        var targetModifiers: NSEvent.ModifierFlags = []
        
        if targetShortcut.modifiers.contains(.command) {
            targetModifiers.insert(.command)
        }
        if targetShortcut.modifiers.contains(.shift) {
            targetModifiers.insert(.shift)
        }
        if targetShortcut.modifiers.contains(.option) {
            targetModifiers.insert(.option)
        }
        if targetShortcut.modifiers.contains(.control) {
            targetModifiers.insert(.control)
        }
        
        return pressedKey.lowercased() == targetShortcut.key.lowercased() && 
               pressedModifiers == targetModifiers
    }
    
}

struct ShortcutButton: View {
    let shortcut: Shortcut
    let isEditing: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(isEditing ? "Press shortcut..." : shortcutDisplayText(for: shortcut))
                    .font(.system(size: 13))
                    .foregroundColor(isEditing ? .secondary : .primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isEditing ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.1))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isEditing ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func shortcutDisplayText(for shortcut: Shortcut) -> String {
        var components: [String] = []
        
        if shortcut.modifiers.contains(.command) { components.append("⌘") }
        if shortcut.modifiers.contains(.option) { components.append("⌥") }
        if shortcut.modifiers.contains(.shift) { components.append("⇧") }
        if shortcut.modifiers.contains(.control) { components.append("⌃") }
        
        if !shortcut.key.isEmpty {
            components.append(shortcut.key.uppercased())
        }
        
        return components.isEmpty ? "Click to set shortcut" : components.joined()
    }
}

#Preview {
    FloatingOnboarding {
        print("Finished")
    }
} 
