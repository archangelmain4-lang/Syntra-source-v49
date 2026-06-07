//
//  InputEventManager.swift
//  Syntra
//
//  Global hotkey listener. Carbon handles the app-wide shortcut so ⇧⌘1 works
//  from any app without repeatedly prompting for Accessibility.
//  Accessibility is still needed for reading selected text / screen context,
//  but it is requested only by the permission flow, never in a launch loop.
//

import Cocoa
import Carbon
import SwiftUI

extension Notification.Name {
    static let shortcutTriggered = Notification.Name("ShortcutTriggered")
}

class InputEventModel: ObservableObject{
    @AppStorage("AIAssistShortcut") var aiAssistShortcut: Shortcut = Shortcut(key: "1", modifiers: [.command, .shift])
    // ⇧⌘2 → region screenshot, attached to AI Assist
    @AppStorage("ScreenshotShortcut_v2") var screenshotShortcut: Shortcut = Shortcut(key: "2", modifiers: [.command, .shift])
}

class InputEventManager: NSObject {

    let model = InputEventModel()

    static let shared = InputEventManager()

    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?
    var requestCallback:((Shortcut)->Bool)? = nil {
        didSet {
            if requestCallback != nil {
                unregisterHotKeys()
                registeredFingerprint = ""
            } else if oldValue != nil {
                setup()
            }
        }
    }

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var hotKeyHandler: EventHandlerRef?
    private var localRecorderMonitor: Any?
    private var registeredFingerprint = ""
    private var lastHandledHotKey: (id: UInt32, time: CFAbsoluteTime)?
    private let hotKeySignature = OSType(0x53594E54) // "SYNT"
    private let relevantModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]

    var isListening: Bool { !hotKeyRefs.isEmpty }

    deinit{
        cleanup()
    }

    func setup(){
        debugLog("setup() activationPolicy=\(NSApp.activationPolicy().debugName) trusted=\(AXIsProcessTrusted())")
        installLocalRecorderMonitorIfNeeded()
        installEventTapFallbackIfAllowed()

        let fingerprint = shortcutsFingerprint()
        guard fingerprint != registeredFingerprint || hotKeyRefs.isEmpty else { return }

        unregisterHotKeys()
        installCarbonHandlerIfNeeded()
        registerCarbonHotKeys()
        registeredFingerprint = fingerprint
    }

    func cleanup(){
        unregisterHotKeys()
        if let hotKeyHandler = hotKeyHandler {
            RemoveEventHandler(hotKeyHandler)
            self.hotKeyHandler = nil
        }
        registeredFingerprint = ""

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let localRecorderMonitor = localRecorderMonitor {
            NSEvent.removeMonitor(localRecorderMonitor)
            self.localRecorderMonitor = nil
        }
    }

    private func shortcutsFingerprint() -> String {
        [model.aiAssistShortcut, model.screenshotShortcut]
            .map { "\($0.key):\($0.modifiers.rawValue)" }
            .joined(separator: "|")
    }

    private func installLocalRecorderMonitorIfNeeded() {
        guard localRecorderMonitor == nil else { return }
        localRecorderMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let cb = self.requestCallback else { return event }
            let shortcut = self.shortcut(from: event)
            if cb(shortcut) {
                self.requestCallback = nil
                return nil
            }
            return nil
        }
    }

    private func shortcut(from event: NSEvent) -> Shortcut {
        let key = normalizedKey(from: event)
        return Shortcut(key: key, modifiers: event.modifierFlags.intersection(relevantModifiers))
    }

    private func normalizedKey(from event: NSEvent) -> String {
        if let mapped = keyCodeString(event.keyCode) { return mapped.uppercased() }
        let raw = event.charactersIgnoringModifiers ?? CGKeyCode(event.keyCode).toString() ?? ""
        return String(raw.uppercased().prefix(1))
    }

    private func keyCodeString(_ keyCode: UInt16) -> String? {
        switch keyCode {
        case 18: return "1"; case 19: return "2"; case 20: return "3"; case 21: return "4"; case 23: return "5"
        case 22: return "6"; case 26: return "7"; case 28: return "8"; case 25: return "9"; case 29: return "0"
        case 0: return "A"; case 11: return "B"; case 8: return "C"; case 2: return "D"; case 14: return "E"
        case 3: return "F"; case 5: return "G"; case 4: return "H"; case 34: return "I"; case 38: return "J"
        case 40: return "K"; case 37: return "L"; case 46: return "M"; case 45: return "N"; case 31: return "O"
        case 35: return "P"; case 12: return "Q"; case 15: return "R"; case 1: return "S"; case 17: return "T"
        case 32: return "U"; case 9: return "V"; case 13: return "W"; case 7: return "X"; case 16: return "Y"; case 6: return "Z"
        default: return nil
        }
    }

    private func installCarbonHandlerIfNeeded() {
        guard hotKeyHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            let manager = Unmanaged<InputEventManager>.fromOpaque(userData).takeUnretainedValue()
            guard manager.requestCallback == nil else { return noErr }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr, hotKeyID.signature == manager.hotKeySignature else { return noErr }
            manager.debugLog("Carbon shortcut fired id=\(hotKeyID.id)")
            manager.handleHotKey(id: hotKeyID.id)
            return noErr
        }, 1, &eventType, userData, &hotKeyHandler)
    }

    /// Carbon is the primary global shortcut path. This Accessibility-backed
    /// event tap is a silent fallback for browsers/full-screen spaces where a
    /// front app sometimes consumes ⇧⌘1 before Carbon surfaces it.
    /// It never prompts; it only activates after the user has already granted
    /// Accessibility in the normal setup flow.
    private func installEventTapFallbackIfAllowed() {
        guard eventTap == nil, AXIsProcessTrusted() else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userData = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userData in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let userData {
                        let manager = Unmanaged<InputEventManager>.fromOpaque(userData).takeUnretainedValue()
                        if let eventTap = manager.eventTap {
                            CGEvent.tapEnable(tap: eventTap, enable: true)
                        }
                    }
                    return Unmanaged.passUnretained(event)
                }
                guard type == .keyDown,
                      let userData else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<InputEventManager>.fromOpaque(userData).takeUnretainedValue()
                guard manager.requestCallback == nil else { return Unmanaged.passUnretained(event) }
                if let id = manager.hotKeyID(for: event) {
                    manager.debugLog("EventTap shortcut fired id=\(id)")
                    manager.handleHotKey(id: id)
                    return nil
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: userData
        ) else { return }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func registerCarbonHotKeys() {
        let shortcuts: [(UInt32, Shortcut)] = [
            (1, model.aiAssistShortcut),
            (1, Shortcut(key: "1", modifiers: [.command, .shift])),
            (3, model.screenshotShortcut)
        ]
        var registered = Set<String>()

        for (id, shortcut) in shortcuts {
            let key = shortcut.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty,
                  let keyCode = key.firstCGKeyCode else { continue }
            let signature = "\(keyCode)-\(shortcut.modifiers.intersection(relevantModifiers).rawValue)"
            guard !registered.contains(signature) else { continue }
            registered.insert(signature)

            var hotKeyID = EventHotKeyID(signature: hotKeySignature, id: id)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(keyCode),
                carbonModifiers(for: shortcut.modifiers),
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                hotKeyRefs.append(ref)
            } else {
                print("⚠️ Failed to register shortcut \(shortcut.key) status=\(status)")
            }
        }
    }

    private func unregisterHotKeys() {
        for ref in hotKeyRefs { UnregisterEventHotKey(ref) }
        hotKeyRefs.removeAll()
    }

    private func carbonModifiers(for flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }

    private func hotKeyID(for event: CGEvent) -> UInt32? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.modifierFlags.intersection(relevantModifiers)
        let shortcuts: [(UInt32, Shortcut)] = [
            (1, model.aiAssistShortcut),
            (1, Shortcut(key: "1", modifiers: [.command, .shift])),
            (3, model.screenshotShortcut)
        ]
        return shortcuts.first { _, shortcut in
            guard let shortcutKeyCode = shortcut.key.firstCGKeyCode else { return false }
            return shortcutKeyCode == keyCode && shortcut.modifiers.intersection(relevantModifiers) == flags
        }?.0
    }

    private func handleHotKey(id: UInt32) {
        debugLog("handleHotKey(id=\(id)) received")
        let now = CFAbsoluteTimeGetCurrent()
        if let lastHandledHotKey,
           lastHandledHotKey.id == id,
           now - lastHandledHotKey.time < 0.35 {
            debugLog("handleHotKey(id=\(id)) ignored duplicate")
            return
        }
        lastHandledHotKey = (id, now)

        DispatchQueue.main.async {
            self.debugLog("dispatching hotkey id=\(id) activationPolicy=\(NSApp.activationPolicy().debugName)")
            switch id {
            case 1:
                AIAssistOverlayManager.shared.toggleFromGlobalShortcut()
                self.debugLog("posting shortcutTriggered notification type=aiAssist")
                NotificationCenter.default.post(name: .shortcutTriggered, object: nil, userInfo: ["type": "aiAssist"])
            case 3:
                AIAssistOverlayManager.shared.captureScreenshot()
                self.debugLog("posting shortcutTriggered notification type=screenshot")
                NotificationCenter.default.post(name: .shortcutTriggered, object: nil, userInfo: ["type": "screenshot"])
            default:
                break
            }
        }
    }

    private func debugLog(_ message: String) {
        print("[SyntraShortcut] \(message)")
    }
}

private extension NSApplication.ActivationPolicy {
    var debugName: String {
        switch self {
        case .regular: return "regular"
        case .accessory: return "accessory"
        case .prohibited: return "prohibited"
        @unknown default: return "unknown(\(rawValue))"
        }
    }
}
