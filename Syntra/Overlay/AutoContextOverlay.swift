//
//  AutoContextOverlay.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import Cocoa
import Carbon
import SwiftUI

/// Manages an always-on-top overlay for auto context notes positioned around the screen
class AutoContextOverlay {

    private var overlayWindow: AutoContextWindow

    private var targetWindowElement: AXUIElement?
    private var observer: AXObserver?

    static let instance = AutoContextOverlay()
    
    private var isFullScreen = false
    let contextManager = AutoContextManager()
    
    init() {
        overlayWindow = AutoContextOverlay.makeOverlayWindow(contextManager: contextManager)
    }

    private static func makeOverlayWindow(contextManager: AutoContextManager) -> AutoContextWindow {
        let window = AutoContextWindow(rect: NSRect(x: 0, y: 0, width: 100, height: 100), contextManager: contextManager)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.sharingType = .none
        return window
    }

    func start() {
        if overlayWindow.isVisible { overlayWindow.close() }
        overlayWindow = AutoContextOverlay.makeOverlayWindow(contextManager: contextManager)
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
    
    func getSelectedText() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()

        var selectedTextValue: AnyObject?
        let errorCode = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &selectedTextValue)
        
        if errorCode == .success {
            let selectedTextElement = selectedTextValue as! AXUIElement
            var selectedText: AnyObject?
            let textErrorCode = AXUIElementCopyAttributeValue(selectedTextElement, kAXSelectedTextAttribute as CFString, &selectedText)
            
            if textErrorCode == .success, let selectedTextString = selectedText as? String {
                return selectedTextString
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    func toggle(){
        if overlayWindow.isVisible{
            stop()
            // Disconnect WebSocket when stopping
            contextManager.disconnect()
        }else{
            print(getSelectedText())
            
            // Connect to WebSocket when starting
            contextManager.connect()

            // If the user has selected text in the currently focused UI element, use it right away
            if let highlighted = getSelectedText(),
               !highlighted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("Using highlighted text for context search: \(highlighted.prefix(120))…")
                contextManager.searchContext(screenOCR: highlighted)
            }
            
            // Capture the current foreground window before showing the overlay
            Task {
               let results =  try await WindowCaptureManager.shared.captureAndProcessText()
                if !results.isEmpty {
                    print("Successfully captured and processed text from foreground window. Found \(results.count) text elements.")
                    
                    // Combine all text into a single string
                    let combinedText = results.map { $0.text }.joined(separator: " || ")
                    print("Combined text: \(combinedText.prefix(250))…")
                    
                    // Search for context using the captured text (this may be a second request if we already used highlighted text)
                    contextManager.searchContext(screenOCR: combinedText)
                } else {
                    print("No text found in foreground window and no highlighted text available – skipping context search")
                }
            }
            start()
        }
    }
    
    private func updateFrame() {
        DispatchQueue.main.async {
            // 1. Determine current mouse position in global screen coordinates
            let mousePoint = NSEvent.mouseLocation
            
            // 2. Identify the screen containing the mouse (fallback to main)
            let targetScreen = NSScreen.screens.first { NSMouseInRect(mousePoint, $0.frame, false) } ?? NSScreen.main
            
            var x = 0 as CGFloat, y = 0 as CGFloat, w = 0 as CGFloat, h = 0 as CGFloat
            var padding = NSEdgeInsets()
            
            if let screen = targetScreen {
                padding = NSEdgeInsets()
                x = screen.frame.minX
                y = 40
                w = screen.frame.size.width
                h = screen.frame.size.height
                
                // Convert y coordinate to screen-relative coordinates
                y = screen.frame.height - y - h + screen.frame.minY
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

// Custom window class for AutoContext
class AutoContextWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    private let contextManager: AutoContextManager
    
    init(rect: NSRect, contextManager: AutoContextManager){
        self.contextManager = contextManager
        super.init(
            contentRect: rect,
            styleMask: [.resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        setup(rect: rect)
    }
    
    private func setup(rect: NSRect){
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        
        let container = ClickThroughView(frame: rect)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.autoresizingMask = [.width, .height]
        contentView = container
        
        // Pass the context manager to the view
        let hosting = NSHostingView(rootView: AutoContextView(contextManager: contextManager))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }
}

// SwiftUI view for AutoContext - only shows the overlay bubbles
struct AutoContextView: View {
    @ObservedObject var contextManager: AutoContextManager
    
    // Track the position offset for each card
    @State private var cardOffsets: [String: CGSize] = [:] // keyed by note.uniqueid
    @State private var draggingCardId: String? = nil
    
    var body: some View {
        VStack{
            GeometryReader { geo in
                ZStack {
                    // Display notes dynamically positioned
                    if !contextManager.contextNotes.isEmpty {
                        ForEach(Array(contextManager.contextNotes.prefix(3)).indices, id: \.self) { index in
                            let note = contextManager.contextNotes[index]
                            let basePosition = getPosition(for: index, in: geo.size)
                            let offset = cardOffsets[note.uniqueid] ?? .zero
                            let finalPosition = CGPoint(
                                x: basePosition.x + offset.width,
                                y: basePosition.y + offset.height
                            )

                            ContextCard(
                                text: note.title,
                                tags: note.tags,
                                menuItems: ["Tag A", "Tag B", "Tag C"],
                                onTagTap: { tag in
                                    print("Tag tapped: \(tag.name)")
                                },
                                onMenuSelect: { selection in
                                    print("Selected \(selection)")
                                },
                                isDragging: draggingCardId == note.uniqueid
                            )
                            .position(finalPosition)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        cardOffsets[note.uniqueid] = value.translation
                                        draggingCardId = note.uniqueid
                                        NSCursor.closedHand.set()
                                    }
                                    .onEnded { value in
                                        // Keep the final position
                                        cardOffsets[note.uniqueid] = value.translation
                                        draggingCardId = nil
                                        NSCursor.openHand.set()
                                    }
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: draggingCardId == note.uniqueid)
                        }
                    }
                    
                    // Loading indicator in bottom right
                    if contextManager.isLoading {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .cornerRadius(20)
                                .padding(.trailing, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
                .background(Color.clear)
            }
        }
        .padding(EdgeInsets(top: 40, leading: 80, bottom: 40, trailing: 80))
        .onChange(of: contextManager.contextNotes) { _ in
            // Reset positions when notes change
            cardOffsets = [:]
            draggingCardId = nil
        }
    }
    
    /// Calculate position for note cards based on index
    private func getPosition(for index: Int, in size: CGSize) -> CGPoint {
        switch index {
        case 0:
            return CGPoint(x: 160, y: size.height * 0.33)
        case 1:
            return CGPoint(x: size.width - 180, y: size.height * 0.4)
        case 2:
            return CGPoint(x: size.width - 300, y: size.height * 0.7)
        default:
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
    }
} 
