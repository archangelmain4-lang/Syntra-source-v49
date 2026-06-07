//
//  AIContextManager.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import Foundation
import Combine
import AppKit
import CoreGraphics
import Vision


/// Manages the capture of contextual information from the screen and system
class AIContextManager: ObservableObject {
    // Singleton
    static let shared = AIContextManager()
    
    // Published properties
    @Published var didChangeSelectedText = false
    @Published var selectedText = ""
    @Published var ocrText = ""
    @Published var imageBytes: Data?
    @Published var cursorContextDescription = ""
    /// The URL of the active tab in the user’s browser (Chrome or Safari). Empty string if unavailable.
    @Published var browserURL: String = ""

    private var lastCaptureDate: Date = .distantPast
    private var activeCaptureTask: Task<Void, Never>?

    private init() {}
    
    func refreshCurrentContext(captureImage: Bool = true, maxAge: TimeInterval = 1.4) async {
        if Date().timeIntervalSince(lastCaptureDate) < maxAge { return }
        if let activeCaptureTask {
            await activeCaptureTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            try? await self.captureCurrentContext(captureImage: captureImage)
        }
        activeCaptureTask = task
        await task.value
        activeCaptureTask = nil
    }

    func captureCurrentContext(captureImage: Bool = true, performOCR: Bool = true) async throws {
        let activeURL = detectActiveBrowserURL()
        await MainActor.run {
            self.selectedText = ""
            self.didChangeSelectedText = false
        }

        await MainActor.run {
            self.browserURL = activeURL
        }
        
        
        // Capture screenshot once and use it for both OCR and storage
        if captureImage && !PermissionManager.shared.screenCapturePermission {
            await MainActor.run {
                self.ocrText = ""
                self.imageBytes = nil
            }
            return
        }

        if let snapshot = await WindowCaptureManager.shared.captureCurrentWorkspaceContext() {
            let image = snapshot.image
            
            // Only store image if captureImage is true
            if captureImage {
                // IMPORTANT: do NOT draw the cursor ring on the model image.
                // The model was reporting "a blank interface with a blue ring"
                // because the cursor overlay was the most prominent feature.
                let imageData = WindowCaptureManager.shared.jpegData(from: image)

                await MainActor.run {
                    self.imageBytes = imageData
                }
                if let imageData {
                    print("[SyntraVision] final model image bytes=\(imageData.count)")
                    WindowCaptureManager.shared.dumpDebugModelImageData(imageData)
                } else {
                    print("[SyntraVision] jpegData() returned nil — model will get no image")
                }
            } else {
                await MainActor.run { self.imageBytes = nil }
            }
            
            let combinedText: String
            if performOCR {
                let ocrResults = await WindowCaptureManager.shared.performOCR(on: image)
                combinedText = ocrResults
                    .sorted { $0.boundingBoxRaw.origin.y < $1.boundingBoxRaw.origin.y }
                    .map { $0.text }
                    .joined(separator: " ")
            } else {
                combinedText = ""
            }
            await MainActor.run {
                self.ocrText = combinedText
                self.lastCaptureDate = Date()
                if let bounds = snapshot.windowBounds {
                    let title = snapshot.windowTitle.isEmpty ? "" : " titled \"\(snapshot.windowTitle)\""
                    self.cursorContextDescription = "Captured \(snapshot.ownerName)\(title) near the cursor (\(Int(bounds.width))×\(Int(bounds.height))). The image includes a blue ring marking the cursor target; use that first when the user asks what this/that/word/image means."
                } else {
                    self.cursorContextDescription = "The image includes a blue ring marking the cursor target when available; use that when the user asks what this/that is."
                }
            }
        } else {
            await MainActor.run {
                self.ocrText = ""
                self.imageBytes = nil
                self.cursorContextDescription = ""
            }
        }
  
    }

    private func detectActiveBrowserURL() -> String {
        if let frontmost = NSWorkspace.shared.frontmostApplication?.localizedName,
           let url = getBrowserURL(frontmost) {
            return url
        }
        let runningNames = NSWorkspace.shared.runningApplications.compactMap { $0.localizedName }
        let browsers = ["Google Chrome", "Safari", "Microsoft Edge", "Brave Browser", "Arc"]
        for browser in browsers where runningNames.contains(browser) {
            if let url = getBrowserURL(browser) { return url }
        }
        return ""
    }
    
    /// Capture text currently selected by the user using accessibility APIs
    func captureSelectedText() async throws -> String{
        DispatchQueue.main.async {
            self.didChangeSelectedText = false
        }
        // First try using the accessibility API
        if let selectedText = await getAllSelectedTextFromOtherApps(), !selectedText.isEmpty {
            await MainActor.run {
                self.didChangeSelectedText = true
                self.selectedText = selectedText
            }
            return selectedText
        }
        
        // Clear if no text found
        await MainActor.run {
            self.didChangeSelectedText = true
            self.selectedText = ""
        }
        return ""
    }

    
    
    /// Returns the selected text in other running apps (excluding self),
    /// even if they are not frontmost.
    func getAllSelectedTextFromOtherApps() async -> String? {
        guard PermissionManager.shared.accessibilityPermission else { return nil }
        if let window = NSWorkspace.shared.windowBehindSyntra(){
            if let text = findSelectedText(in: window.0), !text.isEmpty {
                return text
            }
            return await NSPasteboard.getSelectedText(wid: window.1)
        }
        
        return nil
    }
    
    
    /// Recursively search for an AXUIElement that has kAXSelectedTextAttribute.
    /// - Parameter element: Starting element (e.g. a window)
    /// - Returns: Found selected text or nil
    func findSelectedText(in element: AXUIElement) -> String? {

        var selected: AnyObject?
        let selErr = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selected
        )
        if selErr == .success, let txt = selected as? String, !txt.isEmpty {
            return txt
        }
        
        var children: CFTypeRef?
        let chErr = AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &children
        )
        if chErr == .success, let elems = children as? [AXUIElement] {
            for child in elems {
                if let found = findSelectedText(in: child) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Browser URL Helpers

    /// Returns the cleaned URL (without scheme or “www.”) of the active tab for the specified browser, if available.
    private func getBrowserURL(_ appName: String) -> String? {
        guard let scriptText = getScriptText(appName) else { return nil }

        var error: NSDictionary?
        guard let script = NSAppleScript(source: scriptText) else { return nil }

        guard let outputString = script.executeAndReturnError(&error).stringValue else {
            if let error = error {
                print("Get Browser URL request failed with error: \(error.description)")
            }
            return nil
        }

        // Clean URL output – remove protocol & unnecessary "www."
        if let url = URL(string: outputString), var host = url.host {
            if host.hasPrefix("www.") {
                host = String(host.dropFirst(4))
            }
            let resultURL = "\(host)\(url.path)"
            return resultURL
        }

        return nil
    }

    /// AppleScript source for fetching the front-most tab/document URL for supported browsers.
    private func getScriptText(_ appName: String) -> String? {
        switch appName {
        case "Google Chrome":
            return "tell app \"Google Chrome\" to get the url of the active tab of window 1"
        case "Safari":
            return "tell application \"Safari\" to return URL of front document"
        case "Microsoft Edge":
            return "tell app \"Microsoft Edge\" to get the url of the active tab of window 1"
        case "Brave Browser":
            return "tell app \"Brave Browser\" to get the url of the active tab of window 1"
        case "Arc":
            return "tell app \"Arc\" to get the url of the active tab of window 1"
        default:
            return nil
        }
    }
    
}

