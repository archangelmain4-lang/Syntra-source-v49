//
//  AIAssistView.swift
//  Syntra
//
//  Visual look ported from the Constella Horizon reference build:
//  - regularMaterial card with a soft orange gradient blob at the bottom
//  - single rounded white composer (no inner harsh-edged rectangle)
//  - conversation area expands above the composer when a chat is active
//
//  Syntra-only additions kept from prior versions:
//  - red traffic-light close dot (replaces icon_close)
//  - recent chats popover wired to ChatHistoryStore
//  - drag-and-drop image attachments
//

import SwiftUI
import Combine

// MARK: - Availability shims
private extension View {
    @ViewBuilder
    func scrollIndicatorsNeverIfAvailable() -> some View {
        if #available(macOS 13.0, *) { self.scrollIndicators(.never) } else { self }
    }
}

// MARK: - Transparent prompt input (one rounded surface, no inner rect)
private struct PromptTextView: NSViewRepresentable {
    @Binding var text: String
    var focused: Bool
    var colorScheme: ColorScheme
    var send: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, send: send) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false

        let tv = PromptNSTextView()
        tv.onSend = send
        tv.delegate = context.coordinator
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.isRichText = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.allowsUndo = true
        tv.textContainerInset = NSSize(width: 0, height: 3)
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainer?.widthTracksTextView = true
        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = true
        tv.autoresizingMask = [.width]
        tv.font = .systemFont(ofSize: 16, weight: .regular)

        scrollView.documentView = tv
        context.coordinator.textView = tv
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.send = send
        guard let tv = context.coordinator.textView else { return }
        tv.onSend = send
        tv.font = .systemFont(ofSize: 16, weight: .regular)
        tv.textColor = colorScheme == .dark ? .white : .black
        if tv.string != text { tv.string = text }
        if focused, tv.window?.firstResponder !== tv {
            DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        }
        scrollView.backgroundColor = .clear
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var send: () -> Void
        weak var textView: PromptNSTextView?

        init(text: Binding<String>, send: @escaping () -> Void) {
            _text = text
            self.send = send
        }

        func textDidChange(_ notification: Notification) {
            text = (notification.object as? NSTextView)?.string ?? ""
        }
    }
}

private final class PromptNSTextView: NSTextView {
    var onSend: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            super.keyDown(with: event)
            return
        }
        if (event.keyCode == 36 || event.keyCode == 76), !event.modifierFlags.contains(.shift) {
            onSend?()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let chars = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        switch chars {
        case "v": paste(self); return true
        case "c": copy(self); return true
        case "x": cut(self); return true
        case "a": selectAll(self); return true
        default: return super.performKeyEquivalent(with: event)
        }
    }
}

struct AIAssistView: View {
    var window: NSWindow?
    @Environment(\.colorScheme) private var colorScheme

    var lastMessages: [MessageData] { connectionManager.lastMessages }

    @State private var inputText: String = ""
    @State private var hasLastMessage = false
    @State private var showHistory: Bool = false
    @State private var showThinkingView: Bool = false
    @State private var showSelectedTextView: Bool = false
    @State private var showResultView: Bool = false
    @State private var smarterAnalysisExpanded: Bool = false

    @State var observation: NSKeyValueObservation? = nil
    @FocusState private var isTextFieldFocused: Bool

    @ObservedObject private var connectionManager = AIConnectionManager.shared
    @ObservedObject private var contextManager = AIContextManager.shared
    @ObservedObject private var overlayManager = AIAssistOverlayManager.shared
    @ObservedObject private var historyStore = ChatHistoryStore.shared

    @Namespace private var commandNamespace

    private var result: String { connectionManager.messageStream }
    private var isThinking: Bool { connectionManager.isReceiving }
    private var hasSelectedText: Bool { !contextManager.selectedText.isEmpty }
    private var isReceiving: Bool { showThinkingView || showResultView || hasLastMessage }

    var subBody: some View {
        VStack {
            if isReceiving {
                ZStack {
                    // Top-right controls: red dot (left), history, new chat (right)
                    VStack {
                        HStack {
                            Button {
                                AIAssistOverlayManager.shared.stop()
                            } label: {
                                Circle()
                                    .fill(Color(red: 1.0, green: 0.36, blue: 0.33))
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button { showHistory.toggle() } label: {
                                Image("icon_history")
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showHistory, arrowEdge: .bottom) {
                                ChatHistoryPopover(onPick: { convo in
                                    showHistory = false
                                    openConversation(convo)
                                })
                            }

                            Button {
                                ChatHistoryStore.shared.save(messages: connectionManager.visibleConversationSnapshot())
                                withAnimation(.interactiveSpring(response: 0.48, dampingFraction: 0.88, blendDuration: 0.12)) {
                                    connectionManager.clearConversation()
                                    hasLastMessage = false
                                    showResultView = false
                                    showThinkingView = false
                                    overlayManager.setChatActive(false)
                                }
                            } label: {
                                Image("icon_plus")
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding([.horizontal, .top])

                    ScrollViewReader { proxy in
                        FadingScrollView {
                            VStack(spacing: 0) {
                                ForEach(lastMessages) { message in
                                    VStack(spacing: 0) {
                                        Color.clear.frame(height: 4).zIndex(-1).id("scroll-padding-\(message.id)")
                                        Color.clear.frame(height: 8).zIndex(-1).id(message.topId)
                                        HStack {
                                            if message.isUser {
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 6) {
                                                    if !message.images.isEmpty {
                                                        messageImageGrid(message.images)
                                                    }
                                                    if !message.message.isEmpty {
                                                        Text(message.message)
                                                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : Color(red: 0, green: 0, blue: 0).opacity(0.91))
                                                            .font(.system(size: 12, weight: .light))
                                                            .fixedSize(horizontal: false, vertical: true)
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 8)
                                                            .background(Color(red: 0, green: 0, blue: 0).opacity(0.05))
                                                            .cornerRadius(12)
                                                            .frame(maxWidth: 320, alignment: .trailing)
                                                    }
                                                }
                                            } else {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    MarkdownTextView(
                                                        text: message.message,
                                                        font: .systemFont(ofSize: 13, weight: .regular),
                                                        textColor: colorScheme == .dark ? .white : .black
                                                    )
                                                    Button {
                                                        let pb = NSPasteboard.general
                                                        pb.clearContents()
                                                        pb.setString(message.message, forType: .string)
                                                    } label: {
                                                        Image("copy")
                                                            .renderingMode(.template)
                                                            .foregroundColor(.secondary)
                                                            .padding(4)
                                                            .contentShape(Rectangle())
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help("Copy")
                                                }
                                                .padding(.top, 4)
                                                .padding(.bottom, 12)
                                                Spacer()
                                            }
                                        }.id(message.id)
                                        Color.clear.frame(height: 12).zIndex(-1).id(message.bottomId)
                                    }.padding(.vertical, -4)
                                }

                                if showThinkingView {
                                    HStack {
                                        ShimmerTextView(
                                            text: "Thinking...",
                                            font: .system(size: 14).italic(),
                                            textColor: Color(white: 0.33),
                                            intensity: 0.8
                                        )
                                        Spacer()
                                    }
                                    .padding(.top, lastMessages.isEmpty ? 10 : 26)
                                    .padding(.bottom, 6)
                                    .transition(.opacity)
                                }

                                if !result.isEmpty && !lastMessages.isEmpty {
                                    Color.clear.frame(height: 4)
                                }

                                MarkdownTextView(
                                    text: result,
                                    font: .systemFont(ofSize: 13, weight: .regular),
                                    textColor: colorScheme == .dark ? .white : .black
                                )

                                Color.clear.frame(height: 18)
                            }
                            .padding(20)
                        }
                        .onChange(of: lastMessages) { _ in
                            withAnimation {
                                if let last = lastMessages.last {
                                    proxy.scrollTo(last.bottomId, anchor: .bottom)
                                }
                            }
                        }
                        .scrollIndicatorsNeverIfAvailable()
                    }
                    .padding(.top, 32)
                }
                .frame(maxHeight: 275)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .opacity
                ))
            }

            // Input bar — single rounded surface
            VStack {
                HStack {
                    ZStack(alignment: .leading) {
                        HStack {
                            if showSelectedTextView, isReceiving {
                                selectedTextView(false).padding(4)
                            }
                            Spacer()
                        }

                        if inputText.isEmpty {
                            Text("How can I help you?")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color.primary.opacity(0.35))
                                .padding(.leading, (showSelectedTextView && isReceiving) ? 60 : 0)
                                .allowsHitTesting(false)
                        }

                        PromptTextView(
                            text: $inputText,
                            focused: isTextFieldFocused,
                            colorScheme: colorScheme,
                            send: send
                        )
                        .padding(.leading, (showSelectedTextView && isReceiving) ? 60 : 0)
                        .frame(minHeight: 22, maxHeight: 110)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    if isReceiving {
                        Image("icon_command")
                            .padding(8)
                            .matchedGeometryEffect(id: "commandIcon", in: commandNamespace)
                    }
                }
                .frame(minHeight: 44)
                .padding(12)
                .background(Color(red: 1, green: 1, blue: 1).opacity(0.45))
                .cornerRadius(8)
                .shadow(color: Color(red: 0.78, green: 0.78, blue: 0.78, opacity: 0.10), radius: 11, y: 5)
                .layoutPriority(1)

                if !isReceiving {
                    HStack {
                        HStack(spacing: 8) {
                            smarterAnalysisView()
                            if showSelectedTextView {
                                selectedTextView(true)
                            }
                        }
                        Spacer()

                        // Recent chats button (top-right area for idle state)
                        Button { showHistory.toggle() } label: {
                            Image("icon_history")
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showHistory, arrowEdge: .bottom) {
                            ChatHistoryPopover(onPick: { convo in
                                showHistory = false
                                openConversation(convo)
                            })
                        }

                        Image("icon_command")
                            .padding(.vertical, 8)
                            .matchedGeometryEffect(id: "commandIcon", in: commandNamespace)
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 8)
                }

                // Attached image previews
                if !connectionManager.pendingImages.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(connectionManager.pendingImages.enumerated()), id: \.offset) { idx, img in
                            pendingImageChip(img, index: idx)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            }
            .padding(.vertical).padding(.horizontal, 8)
        }
    }

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(.regularMaterial).animation(nil, value: UUID())
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 540, height: 0)
                        .position(x: 270, y: 0)
                        .background(
                            EllipticalGradient(
                                stops: [
                                    Gradient.Stop(color: .white.opacity(0), location: 0.00),
                                    Gradient.Stop(color: Color(red: 1, green: 0.79, blue: 0.58).opacity(0.7), location: 0.55),
                                    Gradient.Stop(color: .white.opacity(0), location: 1.00),
                                ],
                                center: UnitPoint(x: 0.5, y: 0.95)
                            )
                            .animation(nil, value: UUID())
                            .frame(width: 1040, height: 120)
                            .blur(radius: 20)
                            .opacity(colorScheme == .dark ? 0.2 : 0.7)
                        )
                        .animation(nil, value: UUID())
                        .frame(width: 1040, height: 120)

                    subBody.layoutPriority(1)
                }
                .frame(width: 480)
                .cornerRadius(16)
                .padding()
                .onDrop(of: ["public.image", "public.file-url"], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                }
                .onChange(of: isThinking) { newValue in
                    withAnimation(.interactiveSpring(response: 0.46, dampingFraction: 0.88, blendDuration: 0.10)) { showThinkingView = newValue }
                }
                .onChange(of: hasSelectedText) { newValue in
                    withAnimation(.easeInOut(duration: 0.2)) { showSelectedTextView = newValue }
                }
                .onChange(of: result) { newValue in
                    withAnimation(.interactiveSpring(response: 0.46, dampingFraction: 0.88, blendDuration: 0.10)) { showResultView = !newValue.isEmpty }
                }
                .onChange(of: lastMessages) { newValue in
                    withAnimation(.interactiveSpring(response: 0.46, dampingFraction: 0.88, blendDuration: 0.10)) { hasLastMessage = !newValue.isEmpty }
                    overlayManager.setChatActive(!newValue.isEmpty || showThinkingView || showResultView)
                }
                .animation(.interactiveSpring(response: 0.46, dampingFraction: 0.88, blendDuration: 0.10), value: isReceiving)
                .onChange(of: showThinkingView) { _ in overlayManager.setChatActive(isReceiving) }
                .onChange(of: showResultView) { _ in overlayManager.setChatActive(isReceiving) }
                .onChange(of: contextManager.selectedText) { _ in
                    if window?.isVisible == true {
                        isTextFieldFocused = true
                        NSApp.activate(ignoringOtherApps: true)
                        window?.makeKeyAndOrderFront(nil)
                    }
                }
                .onChange(of: contextManager.didChangeSelectedText) { _ in
                    if window?.isVisible == true {
                        isTextFieldFocused = true
                        NSApp.activate(ignoringOtherApps: true)
                        window?.makeKeyAndOrderFront(nil)
                    }
                }
                .onChange(of: smarterAnalysisExpanded) { newValue in
                    if newValue {
                        print("[SyntraVision] Smarter analysis opened; using pre-overlay screen context to avoid capturing Syntra")
                    }
                }
                .onAppear {
                    observation = self.window?.observe(\.isVisible, options: [.new]) { _, change in
                        if change.newValue == true { didAppear() }
                    }
                }
            }
        }
    }

    func didAppear() { isTextFieldFocused = true }

    private func openConversation(_ convo: ChatHistoryStore.Conversation) {
        ChatHistoryStore.shared.save(messages: connectionManager.visibleConversationSnapshot())
        let restored: [MessageData] = convo.messages.map {
            MessageData(
                message: $0.content,
                isUser: $0.role == "user",
                images: $0.imagesBase64.compactMap { Data(base64Encoded: $0) }
            )
        }
        connectionManager.restoreConversation(restored)
        hasLastMessage = !restored.isEmpty
        showResultView = false
        showThinkingView = false
        isTextFieldFocused = true
    }

    private func selectedTextView(_ detail: Bool) -> some View {
        HStack(spacing: 4) {
            Image("icon_selected_text")
            if detail {
                Text("Selected text in use")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
            }
            Button {
                contextManager.selectedText = ""
            } label: {
                Image(systemName: "xmark").resizable().frame(width: 10, height: 10).foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.orange.opacity(0.5)).cornerRadius(16)
    }

    private func smarterAnalysisView() -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                smarterAnalysisExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "pano").font(.system(size: 12))
                if smarterAnalysisExpanded {
                    Text("Deeper Analysis")
                        .font(.system(size: 12))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .padding(.horizontal, smarterAnalysisExpanded ? 12 : 8)
            .padding(.vertical, 8)
            .background(Color(red: 0.96, green: 0.96, blue: 0.96).opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 100)
                    .stroke(Color.white.opacity(0.75), lineWidth: 0.5)
                    .opacity(smarterAnalysisExpanded ? 1 : 0)
            )
            .cornerRadius(100)
            .shadow(color: Color.white,
                    radius: smarterAnalysisExpanded ? 2 : 0,
                    x: smarterAnalysisExpanded ? 1 : 0, y: 0)
            .shadow(color: Color.white.opacity(0.25),
                    radius: smarterAnalysisExpanded ? 6 : 0,
                    x: 0, y: smarterAnalysisExpanded ? 4 : 0)
        }
        .buttonStyle(.plain)
    }

    private func pendingImageChip(_ data: Data, index: Int) -> some View {
        HStack(spacing: 6) {
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            Button {
                if connectionManager.pendingImages.indices.contains(index) {
                    connectionManager.pendingImages.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark")
                    .resizable().frame(width: 8, height: 8).foregroundStyle(.black.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(Color.black.opacity(0.06))
        .cornerRadius(14)
    }

    @ViewBuilder
    private func messageImageGrid(_ datas: [Data]) -> some View {
        let cols = min(max(datas.count, 1), 3)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: cols)
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(datas.enumerated()), id: \.offset) { _, d in
                if let img = NSImage(data: d) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 110, maxHeight: 110)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .frame(maxWidth: 340, alignment: .trailing)
    }

    private func imageDataFromURL(_ url: URL) -> Data? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        if url.pathExtension.lowercased() == "png" { return raw }
        if let img = NSImage(data: raw),
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return png
        }
        return raw
    }

    fileprivate func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                handled = true
                provider.loadObject(ofClass: NSImage.self) { obj, _ in
                    guard let img = obj as? NSImage,
                          let tiff = img.tiffRepresentation,
                          let rep = NSBitmapImageRep(data: tiff),
                          let png = rep.representation(using: .png, properties: [:]) else { return }
                    DispatchQueue.main.async {
                        connectionManager.pendingImages.append(png)
                        isTextFieldFocused = true
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                handled = true
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          let pngData = imageDataFromURL(url) else { return }
                    DispatchQueue.main.async {
                        connectionManager.pendingImages.append(pngData)
                        isTextFieldFocused = true
                    }
                }
            }
        }
        return handled
    }

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImage = !connectionManager.pendingImages.isEmpty
        guard !trimmed.isEmpty || hasImage else { return }

        Task { @MainActor in self.inputText = "" }

        Task {
            do {
                try await connectionManager.sendMessage(
                    trimmed,
                    smarterAnalysisEnabled: smarterAnalysisExpanded
                )
            } catch {
                await MainActor.run {
                    connectionManager.messageStream = "⚠️ Send failed: \(error.localizedDescription)"
                    connectionManager.isReceiving = false
                }
            }
        }
    }
}

// MARK: - Recent chats popover

struct ChatHistoryPopover: View {
    var onPick: (ChatHistoryStore.Conversation) -> Void
    @ObservedObject private var store = ChatHistoryStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent chats").font(.system(size: 12, weight: .semibold))
                Spacer()
                if !store.conversations.isEmpty {
                    Button("Clear") { store.clear() }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)

            Divider()

            if store.conversations.isEmpty {
                Text("No recent chats yet.\nStart a chat and press the + button to save it.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12).padding(.vertical, 16)
                    .frame(width: 280)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.conversations) { convo in
                            Button { onPick(convo) } label: {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(convo.title)
                                            .font(.system(size: 12, weight: .medium))
                                            .lineLimit(1).foregroundColor(.primary)
                                        Text(Self.relativeFormatter.localizedString(for: convo.createdAt, relativeTo: Date()))
                                            .font(.system(size: 10)).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button { store.delete(convo.id) } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10)).foregroundColor(.secondary)
                                    }.buttonStyle(.plain)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().opacity(0.4)
                        }
                    }
                }
                .frame(width: 280, height: 260)
            }
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short; return f
    }()
}

#Preview {
    AIAssistView(window: nil)
        .frame(width: 500, height: 320).background(.blue)
}
