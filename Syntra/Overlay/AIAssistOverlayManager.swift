//
//  AIAssistOverlayManager.swift
//  Syntra
//
//  Manages a single floating AI-assist chat overlay window. No dormant pill,
//  no separate shapes — just a clean window that opens, closes, and grows
//  taller when a chat is active.
//

import Cocoa
import SwiftUI
import Carbon
import Combine

final class AIAssistOverlayManager: ObservableObject {

    // MARK: - Singleton
    static let shared = AIAssistOverlayManager()

    // MARK: - Published properties
    @Published var isVisible: Bool = false
    @Published var isAnimating: Bool = false

    // MARK: - Sizing
    private let fullCompactSize = NSSize(width: 520, height: 200)
    private let fullExpandedSize = NSSize(width: 520, height: 620)
    private let windowMargin: CGFloat = 12
    private var fullSize: NSSize { isChatActive ? fullExpandedSize : fullCompactSize }
    private(set) var isChatActive: Bool = false
    private var lastGlobalHideTime: CFAbsoluteTime = 0

    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    private let contextManager = AIContextManager.shared
    private var preOverlayActivationPolicy: NSApplication.ActivationPolicy?
    private var visionRefreshTimer: Timer?

    lazy var windowViewController = AIAssistWindowController()
    deinit { NotificationCenter.default.removeObserver(self); stopVisionRefreshTimer() }

    // MARK: - Reset / stop

    private func resetState() {
        let snapshot = AIConnectionManager.shared.visibleConversationSnapshot()
        if !snapshot.isEmpty {
            ChatHistoryStore.shared.save(messages: snapshot)
        }
        AIConnectionManager.shared.clearConversation()
        Task { @MainActor in
            AIConnectionManager.shared.isReceiving = false
        }
    }

    func stop() {
        closeCurrentOverlayWindow(reason: "stop()")
        windowViewController = AIAssistWindowController()
        restoreActivationPolicyAfterHide()
        stopVisionRefreshTimer()
        resetState()
        isChatActive = false
        isVisible = false
        isAnimating = false
    }

    // MARK: - Toggle / show

    func toggle() {
        guard let window = windowViewController.window else { show(recreateWindow: true); return }
        if window.isVisible {
            stop()
            return
        }
        show(recreateWindow: true)
    }

    /// Global ⇧⌘1 behavior: Spotlight/Raycast-style launcher. Always bring
    /// Syntra to the current app/Space and place its top-left at the cursor.
    func toggleFromGlobalShortcut() {
        print("Shortcut Fired")
        let window = windowViewController.window
        logWindowState("toggleFromGlobalShortcut() entry", window: window)

        if let window, shouldHideVisibleOverlay(window) {
            hideFromGlobalShortcut(window)
            return
        }

        stopVisionRefreshTimer()
        isAnimating = false

        // Capture FIRST, while Syntra is still hidden, then show the existing
        // window (do NOT recreate — recreation broke the appear-on-any-app
        // behavior). collectionBehavior=.canJoinAllSpaces already ensures the
        // window follows the active Space.
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            try? await self.contextManager.captureCurrentContext(captureImage: true, performOCR: false)
            await MainActor.run {
                self.show(captureContext: false, anchoredToCursor: true, recreateWindow: false)
            }
        }
    }

    private func hideFromGlobalShortcut(_ window: NSWindow) {
        lastGlobalHideTime = CFAbsoluteTimeGetCurrent()
        isVisible = false
        isAnimating = true
        stopVisionRefreshTimer()
        debugLog("Shortcut fired while visible → hiding overlay")

        let startFrame = window.frame
        var endFrame = startFrame
        endFrame.origin.y += 10 // gentle lift while fading out

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.32, 0.0, 0.24, 1.0)
            ctx.allowsImplicitAnimation = true
            window.animator().alphaValue = 0
            window.animator().setFrame(endFrame, display: true)
        }, completionHandler: { [weak self, weak window] in
            guard let self else { return }
            if let hiddenWindow = window {
                hiddenWindow.setFrame(startFrame, display: false)
                hiddenWindow.alphaValue = 1
                self.closeOverlayWindow(hiddenWindow, reason: "global shortcut hide")
                if let currentWindow = self.windowViewController.window, currentWindow === hiddenWindow {
                    self.windowViewController = AIAssistWindowController()
                }
            }
            self.isAnimating = false
            self.restoreActivationPolicyAfterHide()
            self.debugLog("Overlay hidden by ⇧⌘1")
        })
    }

    /// Used by the global ⇧⌘1 shortcut. It should always bring Syntra to the
    /// current desktop/browser/app instead of hiding an already-open window.
    func summon(anchoredToCursor: Bool = false) {
        guard let window = windowViewController.window else { show(anchoredToCursor: anchoredToCursor, recreateWindow: true); return }
        guard window.isVisible else { show(anchoredToCursor: anchoredToCursor, recreateWindow: true); return }

        debugLog("summon(anchoredToCursor=\(anchoredToCursor))")
        promoteActivationPolicyForOverlay()

        configureWindowLevel(window)
        let target = anchoredToCursor ? cursorAnchoredFrame(size: fullSize) : frameForSummon(window.frame)
        if target != window.frame {
            window.setFrame(target, display: true)
        }
        window.alphaValue = 1
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        NSApp.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        isVisible = true
        logWindowState("summon() complete", window: window)
    }

    /// Grow taller when a chat begins; shrink back when cleared.
    func setChatActive(_ active: Bool) {
        guard active != isChatActive else { return }
        isChatActive = active
        guard let window = windowViewController.window,
              window.isVisible else { return }
        let current = window.frame
        let targetHeight = (active ? fullExpandedSize : fullCompactSize).height
        var target = current
        target.size.height = targetHeight
        target = clampKeepingBottomLeft(target)
        // Keep the user's chosen bottom-left position fixed. The panel should
        // spring open upward from where it already is, never jump around screen.
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.46
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.94, 0.18, 1.0)
            window.animator().setFrame(target, display: true)
        })
    }

    func show(captureContext: Bool = true, anchoredToCursor: Bool = true, recreateWindow: Bool = false) {
        if recreateWindow || windowViewController.window == nil {
            recreateOverlayWindow()
        }
        guard let window = windowViewController.window else { return }
        logWindowState("show(captureContext=\(captureContext), anchoredToCursor=\(anchoredToCursor), recreateWindow=\(recreateWindow)) entry", window: window)
        if window.isVisible {
            summon(anchoredToCursor: anchoredToCursor)
            return
        }
        if isAnimating {
            debugLog("show() ignored while animation is in progress")
            return
        }

        let mousePoint = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mousePoint, $0.frame, false) } ?? NSScreen.main
        var target = anchoredToCursor ? cursorAnchoredFrame(size: fullSize, on: screen) : defaultFullFrame(near: mousePoint, on: screen)
        target.size = fullSize

        let finalFrame = target
        var startFrame = target
        startFrame.origin.y -= 12 // start slightly below, ease upward
        window.setFrame(startFrame, display: true)
        window.alphaValue = 0
        configureWindowLevel(window)
        promoteActivationPolicyForOverlay()
        NSApp.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)

        isAnimating = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.32
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.84, 0.24, 1.0)
            ctx.allowsImplicitAnimation = true
            window.animator().setFrame(finalFrame, display: true)
            window.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.isAnimating = false
            guard self.isVisible, window.isVisible else { return }
            self.summon(anchoredToCursor: false)
        })

        isVisible = true
        logWindowState("show() displayed", window: window)

        if captureContext {
            debugLog("show() skipped post-display capture to avoid capturing Syntra")
        }
        // Never start a screen capture after the overlay is visible; the saved
        // pre-open capture is the source of truth for this turn.
        stopVisionRefreshTimer()
    }

    // MARK: - Vision Mode

    private func startVisionRefreshTimerIfNeeded() {
        stopVisionRefreshTimer()
        guard SettingsModel.shared.visionModeEnabled else { return }
        let interval = max(1.0, SettingsModel.shared.visionRefreshInterval)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self,
                  let window = self.windowViewController.window,
                  window.isVisible else { return }
            Task { await self.contextManager.refreshCurrentContext(captureImage: true, maxAge: 0.5) }
        }
        RunLoop.main.add(timer, forMode: .common)
        visionRefreshTimer = timer
        debugLog("Vision refresh timer started (interval=\(interval)s)")
    }

    private func stopVisionRefreshTimer() {
        visionRefreshTimer?.invalidate()
        visionRefreshTimer = nil
    }

    // MARK: - Helpers

    private func configureWindowLevel(_ window: NSWindow) {
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.canHide = false
    }

    var recentlyHiddenByGlobalShortcut: Bool {
        CFAbsoluteTimeGetCurrent() - lastGlobalHideTime < 0.75
    }

    private func recreateOverlayWindow() {
        debugLog("Recreating overlay window for fresh active-Space attach")
        closeCurrentOverlayWindow(reason: "recreateOverlayWindow()")
        windowViewController = AIAssistWindowController()
    }

    private func shouldHideVisibleOverlay(_ window: NSWindow) -> Bool {
        window.isVisible && NSApp.isActive && (window.isKeyWindow || window.isMainWindow)
    }

    private func closeCurrentOverlayWindow(reason: String) {
        guard let window = windowViewController.window else { return }
        closeOverlayWindow(window, reason: reason)
    }

    private func closeOverlayWindow(_ window: NSWindow, reason: String) {
        debugLog("Closing overlay window for \(reason)")
        window.orderOut(nil)
        window.close()
        isVisible = false
        isAnimating = false
    }

    private func activationPolicyName(_ policy: NSApplication.ActivationPolicy) -> String {
        switch policy {
        case .regular: return "regular"
        case .accessory: return "accessory"
        case .prohibited: return "prohibited"
        @unknown default: return "unknown(\(policy.rawValue))"
        }
    }

    private func promoteActivationPolicyForOverlay() {
        let current = NSApp.activationPolicy()
        debugLog("activationPolicy before activation=\(activationPolicyName(current))")
        guard current != .regular else { return }
        if preOverlayActivationPolicy == nil {
            preOverlayActivationPolicy = current
        }
        NSApp.setActivationPolicy(.regular)
        debugLog("activationPolicy switched to \(activationPolicyName(NSApp.activationPolicy()))")
    }

    private func restoreActivationPolicyAfterHide() {
        guard let previous = preOverlayActivationPolicy else { return }
        preOverlayActivationPolicy = nil
        NSApp.setActivationPolicy(previous)
        debugLog("activationPolicy restored to \(activationPolicyName(NSApp.activationPolicy()))")
    }

    private func debugLog(_ message: String) {
        print("[SyntraOverlay] \(message)")
    }

    private func logWindowState(_ prefix: String, window: NSWindow?) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
        debugLog("\(prefix) | activationPolicy=\(activationPolicyName(NSApp.activationPolicy())) mouse=\(mouse) activeScreen=\(String(describing: screen?.localizedName)) visible=\(window?.isVisible ?? false) frame=\(String(describing: window?.frame)) windowScreen=\(String(describing: window?.screen?.localizedName))")
        print("App Active:", NSApp.isActive)
        print("Window Visible:", window?.isVisible ?? false)
        print("Window Occluded:", String(describing: window?.occlusionState))
        print("Window Screen:", String(describing: window?.screen))
        if let window { print("Window Number:", window.windowNumber) }
    }

    func refreshScreenContextAndSummon() {
        closeCurrentOverlayWindow(reason: "refreshScreenContextAndSummon() pre-capture")
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            try? await self.contextManager.captureCurrentContext(captureImage: true, performOCR: false)
            await MainActor.run {
                self.show(captureContext: false, anchoredToCursor: true, recreateWindow: true)
            }
        }
    }

    private func defaultFullFrame(near point: NSPoint, on screen: NSScreen?) -> NSRect {
        let s = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var frame = NSRect(origin: .zero, size: fullSize)
        frame.origin.x = min(max(point.x - fullSize.width / 2, s.minX + 12), s.maxX - fullSize.width - 12)
        frame.origin.y = min(max(point.y - fullSize.height + 40, s.minY + 12), s.maxY - fullSize.height - 12)
        return frame
    }

    private func cursorAnchoredFrame(size: NSSize, on screen: NSScreen? = nil) -> NSRect {
        let point = NSEvent.mouseLocation
        let s = screen?.visibleFrame
            ?? NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var frame = NSRect(x: point.x, y: point.y - size.height, width: size.width, height: size.height)
        frame.origin.x = min(max(frame.origin.x, s.minX + windowMargin), s.maxX - size.width - windowMargin)
        frame.origin.y = min(max(frame.origin.y, s.minY + windowMargin), s.maxY - size.height - windowMargin)
        return frame
    }

    private func clampToScreen(_ frame: NSRect, around point: NSPoint) -> NSRect {
        let s = (NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var f = frame
        f.origin.x = min(max(f.origin.x, s.minX + 8), s.maxX - f.width - 8)
        f.origin.y = min(max(f.origin.y, s.minY + 8), s.maxY - f.height - 8)
        return f
    }

    private func clampToVisibleScreenIfNeeded(_ frame: NSRect) -> NSRect {
        if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) { return frame }
        return clampToScreen(frame, around: NSEvent.mouseLocation)
    }

    private func frameForSummon(_ frame: NSRect) -> NSRect {
        if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
            return clampKeepingBottomLeft(frame)
        }
        let mousePoint = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mousePoint, $0.frame, false) } ?? NSScreen.main
        var target = defaultFullFrame(near: mousePoint, on: screen)
        target.size = fullSize
        return target
    }

    private func clampKeepingBottomLeft(_ frame: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(frame) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var f = frame
        f.origin.x = min(max(f.origin.x, visible.minX + windowMargin), visible.maxX - f.width - windowMargin)
        f.origin.y = min(max(f.origin.y, visible.minY + windowMargin), visible.maxY - f.height - windowMargin)
        return f
    }

    // MARK: - Screenshot helpers

    func captureScreenshot() {
        Task {
            let window = windowViewController.window
            await MainActor.run {
                if !(window?.isVisible ?? false) {
                    self.show()
                }
            }
            try? await Task.sleep(nanoseconds: 200_000_000)

            if let data = await ScreenshotCapture.captureHidingWindow(window, mode: .interactive) {
                await MainActor.run {
                    AIConnectionManager.shared.pendingImages.append(data)
                }
            }
        }
    }
}
