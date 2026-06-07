//
//  ExternalWindowOverlayManager.swift
//  ProtoType1
//
//  Created by occlusion on 4/29/25.
//

import Cocoa
import Carbon

/// Manages an always‐on‐top overlay that tracks another app's main window.
class ExternalWindowOverlayManager {

    private var overlayWindow: MainWindow

    private var targetWindowElement: AXUIElement?
    private var observer: AXObserver?

    private var displayLink: CVDisplayLink?
    
    static let instance = ExternalWindowOverlayManager()
    
    private var isFullScreen = false
    
    init() {
        overlayWindow = ExternalWindowOverlayManager.makeOverlayWindow()
    }

    private static func makeOverlayWindow() -> MainWindow {
        let window = MainWindow(rect: NSRect(x: 0, y: 0, width: 100, height: 100))
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.sharingType = .none
        return window
    }

    func start() {
        if overlayWindow.isVisible { overlayWindow.close() }
        overlayWindow = ExternalWindowOverlayManager.makeOverlayWindow()
        updateFrame()
        NSApp.activate(ignoringOtherApps: true)
        overlayWindow.makeKeyAndOrderFront(nil)
        overlayWindow.orderFrontRegardless()
    }
    
    func stop(){
        if overlayWindow.isVisible{
            overlayWindow.orderOut(nil)
        }
    }
    
    
    func toggle(){
        if overlayWindow.isVisible{
            stop()
        }else{
            // Capture the current foreground window before showing the overlay
            Task {
               let results =  try await WindowCaptureManager.shared.captureAndProcessText()
                if !results.isEmpty {
                    print("Successfully captured and processed text from foreground window. Found \(results.count) text elements.")
                    
                    // Combine all text into a single string
                    let combinedText = results.map { $0.text }.joined(separator: " || ")
                    print("Combined text: \(combinedText)")
                } else {
                    print("No text found in foreground window")
                }
            }
            start()
        }
    }
    
    
    private func updateFrame() {
 
        DispatchQueue.main.async {
            var x = 0 as CGFloat, y = 0 as CGFloat, w = 0 as CGFloat, h = 0 as CGFloat
            var padding = NSEdgeInsets()
            if let screen = NSScreen.main{

                padding = NSEdgeInsets()
                x = 0
                y = 40
                w = screen.frame.size.width
                h = screen.frame.size.height
            }

            
            
            
            if let screenFrame = NSScreen.main?.frame {
                y = screenFrame.height - y - h
            }
            
            let origin = CGPoint(
                x: x - padding.left,
                y: y - padding.bottom
            )
            let size = CGSize(
                width: w + padding.left + padding.right,
                height: h + padding.top + padding.bottom
            )


            
            
            let frame = NSRect(origin: origin, size: size)
            
            
            if self.overlayWindow.frame != frame {
                self.overlayWindow.setFrame(frame, display: true)
            }
        }
    }


}
