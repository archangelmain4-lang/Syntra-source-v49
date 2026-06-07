//
//  ScreenshotCapture.swift
//  Syntra
//
//  Lightweight wrapper around macOS's built-in `/usr/sbin/screencapture` tool.
//  Provides both interactive region capture (user drags a rectangle, identical
//  to ⇧⌘4) and full-screen capture. Returns the image as PNG Data.
//

import Foundation
import AppKit

enum ScreenshotCapture {

    enum Mode {
        case interactive   // user drags a rectangle
        case fullScreen    // capture entire main display
    }

    /// Warm up screen-recording TCC exactly once per launch so the macOS
    /// permission prompt (when needed) appears a single time — not every
    /// time the user presses the snapshot button.
    private static let warmUpPermissionOnce: Void = {
        // Touches the TCC entry without forcing a modal if already granted.
        _ = CGPreflightScreenCaptureAccess()
    }()

    /// Capture a screenshot using the system `screencapture` binary.
    /// - Note: For interactive mode, this blocks the calling thread until the
    ///   user finishes their selection (or presses Esc, in which case nil is
    ///   returned). Always invoke from a background queue.
    static func capture(mode: Mode = .interactive) -> Data? {
        _ = warmUpPermissionOnce
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("syntra-shot-\(UUID().uuidString).png")

        let process = Process()
        process.launchPath = "/usr/sbin/screencapture"
        switch mode {
        case .interactive:
            // -i interactive, -x no sound, -t png
            process.arguments = ["-i", "-x", "-t", "png", tmp.path]
        case .fullScreen:
            process.arguments = ["-x", "-t", "png", tmp.path]
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("screencapture failed to launch: \(error)")
            return nil
        }

        guard FileManager.default.fileExists(atPath: tmp.path),
              let data = try? Data(contentsOf: tmp),
              !data.isEmpty else {
            // User cancelled (Esc) — no file written.
            return nil
        }

        try? FileManager.default.removeItem(at: tmp)
        return data
    }

    /// Convenience: hide the supplied window during capture so the overlay
    /// doesn't obscure the user's selection, then restore it.
    static func captureHidingWindow(_ window: NSWindow?, mode: Mode = .interactive) async -> Data? {
        let wasVisible = window?.isVisible ?? false
        if wasVisible { await MainActor.run { window?.orderOut(nil) } }
        // Tiny delay so the window actually disappears before screencapture starts.
        try? await Task.sleep(nanoseconds: 120_000_000)

        let data: Data? = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: capture(mode: mode))
            }
        }

        if wasVisible {
            await MainActor.run {
                window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        return data
    }
}
