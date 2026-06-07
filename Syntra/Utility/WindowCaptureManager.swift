//
//  WindowCaptureManager.swift
//  Syntra
//
//  Screen/context capture for macOS 12.5+. Uses CoreGraphics + Vision so normal
//  prompts can include selected text, visible screen text, and cursor context.
//

import AppKit
import CoreGraphics
import Vision

struct CaptureTextResult {
    let text: String
    let boundingBoxRaw: CGRect
}

struct ScreenContextSnapshot {
    let image: CGImage
    let windowBounds: CGRect?
    let cursorLocation: CGPoint
    let ownerName: String
    let windowTitle: String
}

extension NSWorkspace {
    func windowBehindSyntraDetails() -> (AXUIElement, CGWindowID, CGRect, String, String)? {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windows {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID != currentPID,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width > 80,
                  bounds.height > 60 else { continue }

            let appElement = AXUIElementCreateApplication(ownerPID)
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? "Active app"
            let title = window[kCGWindowName as String] as? String ?? ""
            return (appElement, windowID, bounds, ownerName, title)
        }

        return nil
    }

    func windowBehindSyntra() -> (AXUIElement, CGWindowID)? {
        guard let (element, windowID, _, _, _) = windowBehindSyntraDetails() else { return nil }
        return (element, windowID)
    }
}

class WindowCaptureManager {
    static let shared = WindowCaptureManager()
    private init() {}

    func captureMainDisplay() async -> CGImage? {
        if let image = CGWindowListCreateImage(.infinite, [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID, [.bestResolution, .nominalResolution]) {
            return image
        }
        return CGDisplayCreateImage(CGMainDisplayID())
    }

    /// Captures the real app/window underneath Syntra without hiding the Syntra
    /// overlay. This removes visible flicker while still giving AI
    /// the website/document/image the user is looking at.
    func captureWindowBehindSyntra() async -> CGImage? {
        guard let (_, windowID, _, _, _) = NSWorkspace.shared.windowBehindSyntraDetails() else { return nil }
        return CGWindowListCreateImage(
            .null,
            [.optionIncludingWindow],
            windowID,
            [.bestResolution, .nominalResolution, .boundsIgnoreFraming]
        )
    }

    /// Returns CGWindowIDs belonging to the current (Syntra) process — used to
    /// exclude our own overlays from any screen capture.
    private func ownWindowIDs() -> Set<CGWindowID> {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        guard let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else { return [] }
        var ids = Set<CGWindowID>()
        for w in windows {
            if let pid = w[kCGWindowOwnerPID as String] as? pid_t, pid == currentPID,
               let wid = w[kCGWindowNumber as String] as? CGWindowID {
                ids.insert(wid)
            }
        }
        return ids
    }

    /// Capture a region while excluding any Syntra-owned windows.
    private func captureRegionExcludingOwnWindows(_ region: CGRect) -> CGImage? {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return CGWindowListCreateImage(region, [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID, [.bestResolution, .nominalResolution])
        }
        // Build an ordered list of window IDs to include (front-to-back), skipping Syntra's own.
        let idsToInclude: [CGWindowID] = windows.compactMap { w in
            guard let pid = w[kCGWindowOwnerPID as String] as? pid_t, pid != currentPID,
                  let wid = w[kCGWindowNumber as String] as? CGWindowID else { return nil }
            return wid
        }
        guard !idsToInclude.isEmpty else {
            return CGWindowListCreateImage(region, [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID, [.bestResolution, .nominalResolution])
        }
        let pointer = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: idsToInclude.count)
        defer { pointer.deallocate() }
        for (i, wid) in idsToInclude.enumerated() {
            pointer[i] = UnsafeRawPointer(bitPattern: UInt(wid))
        }
        guard let array = CFArrayCreate(kCFAllocatorDefault, pointer, idsToInclude.count, nil) else {
            return CGWindowListCreateImage(region, [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID, [.bestResolution, .nominalResolution])
        }
        return CGImage(windowListFromArrayScreenBounds: region, windowArray: array, imageOption: [.bestResolution, .nominalResolution])
    }

    func captureCurrentWorkspaceContext() async -> ScreenContextSnapshot? {
        let cursor = NSEvent.mouseLocation

        // Permission diagnostics — log every time so we can see in Console.app
        let preflight = CGPreflightScreenCaptureAccess()
        print("[SyntraCapture] CGPreflightScreenCaptureAccess() = \(preflight)")
        if !preflight {
            let granted = CGRequestScreenCaptureAccess()
            print("[SyntraCapture] CGRequestScreenCaptureAccess() = \(granted)")
        }

        // Determine the display under the cursor.
        let displayID = displayIDForCursor(cursor)
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        print("[SyntraCapture] frontmost app at capture time: \(frontApp)")

        // PRIMARY: Capture the entire display under the cursor. This is what
        // Spotlight/Raycast/ChatGPT-Desktop-style tools do — full screen, real
        // content, no per-window guessing. Most reliable on macOS 12+.
        if let image = CGDisplayCreateImage(displayID) {
            print("[SyntraCapture] CGDisplayCreateImage OK display=\(displayID) size=\(image.width)x\(image.height)")
            dumpDebugCapture(image, label: "display-\(displayID)")
            let bounds = CGDisplayBounds(displayID)
            return ScreenContextSnapshot(
                image: image,
                windowBounds: bounds,
                cursorLocation: cursor,
                ownerName: frontApp,
                windowTitle: ""
            )
        }
        print("[SyntraCapture] CGDisplayCreateImage FAILED for display \(displayID)")

        // FALLBACK 1: Full on-screen window list (excludes Syntra’s own windows).
        if let image = CGWindowListCreateImage(.infinite, [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID, [.bestResolution, .nominalResolution]) {
            print("[SyntraCapture] CGWindowListCreateImage(.infinite) OK size=\(image.width)x\(image.height)")
            dumpDebugCapture(image, label: "fallback-full")
            return ScreenContextSnapshot(image: image, windowBounds: nil, cursorLocation: cursor, ownerName: frontApp, windowTitle: "")
        }

        // FALLBACK 2: Specific window behind Syntra.
        if let (_, windowID, bounds, ownerName, title) = NSWorkspace.shared.windowBehindSyntraDetails(),
           let image = CGWindowListCreateImage(.null, [.optionIncludingWindow], windowID, [.bestResolution, .nominalResolution, .boundsIgnoreFraming]) {
            print("[SyntraCapture] window-behind capture OK owner=\(ownerName) size=\(image.width)x\(image.height)")
            dumpDebugCapture(image, label: "behind-\(ownerName)")
            return ScreenContextSnapshot(image: image, windowBounds: bounds, cursorLocation: cursor, ownerName: ownerName, windowTitle: title)
        }

        print("[SyntraCapture] ALL capture paths failed")
        return nil
    }

    private func displayIDForCursor(_ cursor: CGPoint) -> CGDirectDisplayID {
        var displayID = CGMainDisplayID()
        var count: UInt32 = 0
        let quartzCursor = quartzPoint(fromAppKitMouseLocation: cursor)
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        if CGGetDisplaysWithPoint(quartzCursor, 16, &ids, &count) == .success, count > 0 {
            displayID = ids[0]
        }
        return displayID
    }

    /// Saves the most recent capture to ~/Library/Caches/Syntra/ so we can
    /// verify it does NOT contain the Syntra overlay itself.
    private func dumpDebugCapture(_ image: CGImage, label: String) {
        let fm = FileManager.default
        guard let cache = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let dir = cache.appendingPathComponent("Syntra", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("last_capture_\(label).jpg")
        if let data = jpegData(from: image) {
            try? data.write(to: url)
            print("[SyntraCapture] dumped \(image.width)x\(image.height) -> \(url.path)")
        }
    }

    func dumpDebugModelImageData(_ data: Data, label: String = "model-context") {
        let fm = FileManager.default
        guard let cache = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let dir = cache.appendingPathComponent("Syntra", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("last_capture_\(label).jpg")
        try? data.write(to: url)
        print("[SyntraCapture] dumped model image bytes=\(data.count) -> \(url.path)")
    }

    private func cursorRegionBounds(around cursor: CGPoint) -> CGRect {
        let quartzCursor = quartzPoint(fromAppKitMouseLocation: cursor)
        let screen = NSScreen.screens.first(where: { NSMouseInRect(cursor, $0.frame, false) })?.frame
            ?? NSScreen.main?.frame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let quartzScreenMin = quartzPoint(fromAppKitMouseLocation: CGPoint(x: screen.minX, y: screen.maxY))
        let width = min(screen.width, 1180)
        let height = min(screen.height, 820)
        var rect = CGRect(x: quartzCursor.x - width * 0.34, y: quartzCursor.y - height * 0.28, width: width, height: height)
        rect.origin.x = min(max(rect.origin.x, quartzScreenMin.x), quartzScreenMin.x + screen.width - width)
        rect.origin.y = min(max(rect.origin.y, quartzScreenMin.y), quartzScreenMin.y + screen.height - height)
        return rect
    }

    func jpegData(from cgImage: CGImage, maxDimension: CGFloat = 1600, cursorLocation: CGPoint? = nil, sourceBounds: CGRect? = nil) -> Data? {
        let sourceWidth = CGFloat(cgImage.width)
        let sourceHeight = CGFloat(cgImage.height)
        let scale = min(1, maxDimension / max(sourceWidth, sourceHeight))
        let targetSize = NSSize(width: sourceWidth * scale, height: sourceHeight * scale)
        let image = NSImage(size: targetSize)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: cgImage, size: NSSize(width: sourceWidth, height: sourceHeight))
            .draw(in: NSRect(origin: .zero, size: targetSize))

        if let cursorLocation, let sourceBounds {
            let quartzCursor = quartzPoint(fromAppKitMouseLocation: cursorLocation)
            let x = (quartzCursor.x - sourceBounds.minX) * (targetSize.width / max(sourceBounds.width, 1))
            let yFromTop = (quartzCursor.y - sourceBounds.minY) * (targetSize.height / max(sourceBounds.height, 1))
            let y = targetSize.height - yFromTop
            if x >= 0, y >= 0, x <= targetSize.width, y <= targetSize.height {
                let radius: CGFloat = 18
                let rect = NSRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                NSColor.white.withAlphaComponent(0.92).setFill()
                NSBezierPath(ovalIn: rect.insetBy(dx: -2, dy: -2)).fill()
                NSColor.systemBlue.setStroke()
                let ring = NSBezierPath(ovalIn: rect)
                ring.lineWidth = 4
                ring.stroke()
                NSColor.systemBlue.withAlphaComponent(0.20).setFill()
                NSBezierPath(ovalIn: rect.insetBy(dx: 5, dy: 5)).fill()
            }
        }

        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.72])
    }

    private func quartzPoint(fromAppKitMouseLocation point: CGPoint) -> CGPoint {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) else { return point }
        let localYFromBottom = point.y - screen.frame.minY
        let quartzY = screen.frame.minY + (screen.frame.height - localYFromBottom)
        return CGPoint(x: point.x, y: quartzY)
    }

    func performOCR(on image: CGImage) async -> [CaptureTextResult] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations.compactMap { observation -> CaptureTextResult? in
                    guard let text = observation.topCandidates(1).first?.string,
                          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                    return CaptureTextResult(text: text, boundingBoxRaw: observation.boundingBox)
                }
                continuation.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    func captureAndProcessText() async throws -> [CaptureTextResult] {
        guard let image = await captureMainDisplay() else { return [] }
        return await performOCR(on: image)
    }
}
