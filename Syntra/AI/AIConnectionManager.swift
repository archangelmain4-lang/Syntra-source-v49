//
//  AIConnectionManager.swift
//  Syntra
//
//  Rewritten: talks directly to the user-selected provider (OpenAI / Google
//  Gemini / Anthropic / Azure OpenAI) using the API key stored in Settings.
//

import Foundation
import Combine
import AppKit

// MARK: - Public models (kept compatible with AIAssistView)

struct AIMessage: Codable {
    let role: String      // "user" | "assistant" | "system"
    let content: String
    /// Image payloads (PNG) associated with this message (user turns only).
    var images: [Data] = []
    let metadata: AIMessageMetadata?

    init(role: String, content: String, images: [Data] = [], metadata: AIMessageMetadata? = nil) {
        self.role = role
        self.content = content
        self.images = images
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey { case role, content, metadata }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try c.decode(String.self, forKey: .role)
        self.content = try c.decode(String.self, forKey: .content)
        self.metadata = try c.decodeIfPresent(AIMessageMetadata.self, forKey: .metadata)
        self.images = []
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(role, forKey: .role)
        try c.encode(content, forKey: .content)
        try c.encodeIfPresent(metadata, forKey: .metadata)
    }
}

struct AIMessageMetadata: Codable {
    let ocrText: String?
    let selectedText: String?

    init(ocrText: String? = nil, selectedText: String? = nil) {
        self.ocrText = ocrText
        self.selectedText = selectedText
    }
}

struct MessageData: Identifiable, Equatable {
    var topId = UUID()
    var id = UUID()
    var bottomId = UUID()
    var message = ""
    var isUser: Bool = false
    /// Image attachments (PNG data) shown with this message bubble.
    var images: [Data] = []

    static func == (lhs: MessageData, rhs: MessageData) -> Bool {
        lhs.id == rhs.id && lhs.message == rhs.message && lhs.isUser == rhs.isUser && lhs.images.count == rhs.images.count
    }
}

// MARK: - Connection Manager

class AIConnectionManager: ObservableObject {
    static let shared = AIConnectionManager()

    @Published var lastMessages = [MessageData]()
    @Published var messageStream: String = ""
    @Published var isConnected: Bool = true
    @Published var isReceiving: Bool = false
    /// Images (PNG) attached to the NEXT outgoing user message. Cleared after send.
    @Published var pendingImages: [Data] = []

    private let contextManager = AIContextManager.shared
    private var messageHistory: [AIMessage] = []
    private var currentTask: URLSessionDataTask?
    /// Image data attached to the in-flight turn.
    private var currentTurnImages: [Data] = []

    private init() {}

    // MARK: - Public API

    func clearConversation() {
        messageHistory.removeAll()
        DispatchQueue.main.async {
            self.lastMessages.removeAll()
            self.messageStream = ""
            self.isReceiving = false
        }
    }

    /// The complete visible transcript, including the currently streamed
    /// assistant answer. Use this before saving or switching chats so the most
    /// recent response is not lost just because it has not been followed by
    /// another user prompt yet.
    func visibleConversationSnapshot() -> [MessageData] {
        var snapshot = lastMessages
        let streamed = messageStream.trimmingCharacters(in: .whitespacesAndNewlines)
        if !streamed.isEmpty {
            snapshot.append(MessageData(message: messageStream, isUser: false))
        }
        return snapshot
    }

    /// Replace the entire visible conversation with a restored set of messages
    /// (used when reopening a chat from history). Also rebuilds the internal
    /// `messageHistory` so the next turn has full context.
    func restoreConversation(_ messages: [MessageData]) {
        let apply = {
            self.lastMessages = messages
            self.messageStream = ""
            self.isReceiving = false
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async { apply() } }
        messageHistory = messages.map {
            AIMessage(role: $0.isUser ? "user" : "assistant", content: $0.message, images: $0.images)
        }
    }

    func getConnectionStatus() -> String {
        let provider = SettingsModel.shared.apiProvider.rawValue
        let hasKey = !currentAPIKey().isEmpty
        return "Provider: \(provider)\nAPI key set: \(hasKey)"
    }

    private func shouldAttachScreenContext(to text: String) -> Bool {
        // Vision Mode: ALWAYS attach the captured screen context so Syntra
        // behaves like a true screen-aware assistant (Raycast/ChatGPT Desktop
        // style). The captured image is the user's workspace (captured BEFORE
        // Syntra appears), so even simple prompts like "what is this" work.
        return true
    }

    /// Called by AIAssistView when the user sends a message.
    func sendMessage(_ text: String,
                     ocrText: String? = nil,
                     selectedText: String? = nil,
                      smarterAnalysisEnabled: Bool = false,
                      contextImages: [Data]? = nil,
                      visibleUserMessage: String? = nil,
                       showUserMessage: Bool = true,
                       quietErrors: Bool = false) async throws {

        let apiKey = currentAPIKey()
        guard !apiKey.isEmpty else {
            await MainActor.run {
                self.messageStream = quietErrors
                    ? "Add your \(SettingsModel.shared.apiProvider.rawValue) API key in Settings → Advanced, then try again."
                    : "⚠️ No API key set. Open Settings → Advanced and paste your \(SettingsModel.shared.apiProvider.rawValue) API key."
                self.isReceiving = false
            }
            return
        }

        // Snapshot user attachments immediately so the UI can respond before
        // OCR/screen capture work finishes.
        let userVisibleImages = await MainActor.run { () -> [Data] in
            let imgs = self.pendingImages
            self.pendingImages = []
            return imgs
        }

        // Append user bubble + reset stream before context capture to remove
        // the delayed/laggy feeling on send.
        await MainActor.run {
            if !self.messageStream.isEmpty {
                self.lastMessages.append(MessageData(message: self.messageStream, isUser: false))
            }
            if showUserMessage {
                self.lastMessages.append(MessageData(message: visibleUserMessage ?? text, isUser: true, images: userVisibleImages))
            }
            self.messageStream = ""
            self.isReceiving = true
        }

        let attachScreenContext = contextImages != nil || shouldAttachScreenContext(to: text)

        // Add automatic screen/cursor context for the model. Only dropped/pasted
        // images are shown in chat; the live screen snapshot stays hidden context.
        let imagesForTurn: [Data]
        if let contextImages {
            imagesForTurn = contextImages
        } else {
            var merged = userVisibleImages
            if attachScreenContext, let screenImage = contextManager.imageBytes {
                merged.append(screenImage)
            }
            imagesForTurn = merged
        }
        self.currentTurnImages = imagesForTurn

        // Build composite user prompt with optional OCR / selected-text context
        var userContent = text
        if userContent.isEmpty && !imagesForTurn.isEmpty {
            userContent = "Describe \(imagesForTurn.count == 1 ? "this image" : "these images")."
        }
        let ocr = attachScreenContext ? (ocrText ?? (contextManager.ocrText.isEmpty ? nil : contextManager.ocrText)) : nil
        let sel = attachScreenContext ? (selectedText ?? (contextManager.selectedText.isEmpty ? nil : contextManager.selectedText)) : nil
        if let sel, !sel.isEmpty {
            userContent += "\n\n[Selected text from user's screen]\n\(sel)"
        }
        if let ocr, !ocr.isEmpty {
            userContent += "\n\n[Text visible on user's screen (OCR)]\n\(ocr)"
        }
        let browserURL = attachScreenContext ? contextManager.browserURL.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        if !browserURL.isEmpty {
            userContent += "\n\n[Active browser page]\n\(browserURL)"
        }
        let cursorContext = attachScreenContext ? contextManager.cursorContextDescription.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        if !cursorContext.isEmpty {
            userContent += "\n\n[Cursor / visual target context]\n\(cursorContext)"
        }

        messageHistory.append(AIMessage(role: "user", content: userContent, images: imagesForTurn))

        // ===== Vision debug =====
        let activeAppName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
        print("[SyntraVision] PROMPT:", text)
        print("[SyntraVision] HAS SCREENSHOT:", !imagesForTurn.isEmpty)
        print("[SyntraVision] SCREENSHOT COUNT:", imagesForTurn.count)
        print("[SyntraVision] SCREENSHOT BYTES:", imagesForTurn.map { $0.count })
        print("[SyntraVision] OCR LENGTH:", (ocr ?? "").count)
        print("[SyntraVision] SELECTED TEXT LENGTH:", (sel ?? "").count)
        print("[SyntraVision] BROWSER URL:", browserURL)
        print("[SyntraVision] ACTIVE APP:", activeAppName)
        print("[SyntraVision] PROVIDER:", SettingsModel.shared.apiProvider.rawValue, "MODEL:", SettingsModel.shared.currentModel())

        do {
            switch SettingsModel.shared.apiProvider {
            case .openAI, .azure:
                try await streamOpenAICompatible(apiKey: apiKey)
            case .google:
                try await streamGemini(apiKey: apiKey)
            case .anthropic:
                try await streamAnthropic(apiKey: apiKey)
            }
        } catch {
            await MainActor.run {
                let message = quietErrors
                    ? "I couldn't finish that request. Check your connection/API settings and try again."
                    : "⚠️ \(error.localizedDescription)"
                self.messageStream = self.messageStream.isEmpty ? message : self.messageStream + "\n\n" + message
                self.isReceiving = false
            }
        }
        self.currentTurnImages = []
    }

    /// Fire a one-shot non-streaming completion for short utility calls
    /// (e.g. chat title generation). Returns trimmed text or nil on failure.
    func oneShotCompletion(prompt: String, maxTokens: Int = 40) async throws -> String? {
        let apiKey = currentAPIKey()
        guard !apiKey.isEmpty else { return nil }

        switch SettingsModel.shared.apiProvider {
        case .openAI, .azure:
            let urlString: String
            var headers: [String: String] = ["Content-Type": "application/json"]
            switch SettingsModel.shared.apiProvider {
            case .openAI:
                urlString = "https://api.openai.com/v1/chat/completions"
                headers["Authorization"] = "Bearer \(apiKey)"
            case .azure:
                let base = SettingsModel.shared.customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                urlString = base.isEmpty ? "https://api.openai.com/v1/chat/completions" : base
                headers["api-key"] = apiKey
                headers["Authorization"] = "Bearer \(apiKey)"
            default: return nil
            }
            guard let url = URL(string: urlString) else { return nil }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
            let body: [String: Any] = [
                "model": SettingsModel.shared.currentModel(),
                "messages": [["role": "user", "content": prompt]],
                "max_tokens": maxTokens,
                "stream": false
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: req)
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = obj["choices"] as? [[String: Any]],
               let msg = choices.first?["message"] as? [String: Any],
               let content = msg["content"] as? String {
                return content
            }
        case .google:
            let model = SettingsModel.shared.currentModel()
            let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
            guard let url = URL(string: urlString) else { return nil }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "contents": [["role": "user", "parts": [["text": prompt]]]],
                "generationConfig": ["maxOutputTokens": maxTokens]
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: req)
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = obj["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]] {
                return parts.compactMap { $0["text"] as? String }.joined()
            }
        case .anthropic:
            guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return nil }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            let body: [String: Any] = [
                "model": SettingsModel.shared.currentModel(),
                "max_tokens": maxTokens,
                "messages": [["role": "user", "content": prompt]]
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: req)
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = obj["content"] as? [[String: Any]] {
                return content.compactMap { $0["text"] as? String }.joined()
            }
        }
        return nil
    }

    // MARK: - Provider routing helpers

    private func currentAPIKey() -> String {
        let m = SettingsModel.shared
        switch m.apiProvider {
        case .openAI:    return m.keyOpenAI.trimmingCharacters(in: .whitespacesAndNewlines)
        case .google:    return m.keyGoogle.trimmingCharacters(in: .whitespacesAndNewlines)
        case .anthropic: return m.keyAnthropic.trimmingCharacters(in: .whitespacesAndNewlines)
        case .azure:     return m.keyAzure.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func systemPrompt() -> String {
        """
        You are Syntra, a concise, helpful on-screen assistant. \
        The user may share OCR text of their screen, a text selection, or images. \
        Use them as context only when relevant. If the user asks "what is this", "what is that", how to reply, or another screen-dependent question, infer the target from selected text, the cursor-marked screenshot, and the visible page/window. Answer only the user's prompt; do not describe screen capture mechanics. Keep answers crisp and high-signal.

        Formatting rules:
        - Use Markdown.
        - When you show code, ALWAYS wrap it in fenced ``` code blocks with a language tag (e.g. ```swift, ```python).
        - Use **bold** for emphasis and `inline code` for identifiers.
        - Use bullet lists for steps or grouped items; never use a bullet for a single point.
        - Prefer short paragraphs. Don't pad with filler.
        - For math, chemistry and physics, use LaTeX inline as $...$ and display as $$...$$. Use \\ce{} for chemical equations.
        """
    }

    private func mimeType(for imageData: Data) -> String {
        if imageData.count >= 2,
           imageData[imageData.startIndex] == 0xFF,
           imageData[imageData.index(after: imageData.startIndex)] == 0xD8 {
            return "image/jpeg"
        }
        return "image/png"
    }

    private func openAIMessagesPayload() -> [[String: Any]] {
        var arr: [[String: Any]] = [["role": "system", "content": systemPrompt()]]
        for (index, m) in messageHistory.enumerated() {
            let includeImages = index == messageHistory.count - 1
            if m.role == "user" && includeImages && !m.images.isEmpty {
                var contentArr: [[String: Any]] = [["type": "text", "text": m.content]]
                for img in m.images {
                    let b64 = img.base64EncodedString()
                    contentArr.append([
                        "type": "image_url",
                        "image_url": ["url": "data:\(mimeType(for: img));base64,\(b64)"]
                    ])
                }
                arr.append(["role": m.role, "content": contentArr])
            } else {
                arr.append(["role": m.role, "content": m.content])
            }
        }
        return arr
    }

    // MARK: - OpenAI / Azure streaming

    private func streamOpenAICompatible(apiKey: String) async throws {
        let urlString: String
        var headers: [String: String] = ["Content-Type": "application/json"]
        let model: String = SettingsModel.shared.currentModel()

        switch SettingsModel.shared.apiProvider {
        case .openAI:
            urlString = "https://api.openai.com/v1/chat/completions"
            headers["Authorization"] = "Bearer \(apiKey)"
        case .azure:
            let base = SettingsModel.shared.customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            urlString = (base.isEmpty ? "https://api.openai.com/v1/chat/completions" : base)
            headers["api-key"] = apiKey
            headers["Authorization"] = "Bearer \(apiKey)"
        default:
            return
        }

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AIConnectionManager", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        req.timeoutInterval = 120

        let body: [String: Any] = [
            "model": model,
            "messages": openAIMessagesPayload(),
            "stream": true
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "AIConnectionManager", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "Provider returned HTTP \(code)"])
        }

        var assembled = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = obj["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let chunk = delta["content"] as? String else { continue }

            assembled += chunk
            let snapshot = assembled
            await MainActor.run { self.messageStream = snapshot }
        }

        messageHistory.append(AIMessage(role: "assistant", content: assembled))
        await MainActor.run {
            if !assembled.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.lastMessages.append(MessageData(message: assembled, isUser: false))
            }
            self.messageStream = ""
            self.isReceiving = false
            ChatHistoryStore.shared.save(messages: self.lastMessages)
        }
    }

    // MARK: - Anthropic streaming

    private func streamAnthropic(apiKey: String) async throws {
        let model = SettingsModel.shared.currentModel()
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 120

        var messages: [[String: Any]] = []
        for (index, m) in messageHistory.enumerated() where m.role == "user" || m.role == "assistant" {
            let includeImages = index == messageHistory.count - 1
            if m.role == "user" && includeImages && !m.images.isEmpty {
                var contentArr: [[String: Any]] = []
                for img in m.images {
                    let b64 = img.base64EncodedString()
                    contentArr.append([
                        "type": "image",
                        "source": ["type": "base64", "media_type": mimeType(for: img), "data": b64]
                    ])
                }
                contentArr.append(["type": "text", "text": m.content])
                messages.append(["role": m.role, "content": contentArr])
            } else {
                messages.append(["role": m.role, "content": m.content])
            }
        }

        let body: [String: Any] = [
            "model": model,
            "system": systemPrompt(),
            "max_tokens": 2048,
            "stream": true,
            "messages": messages
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "AIConnectionManager", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "Anthropic returned HTTP \(code)"])
        }

        var assembled = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            guard let data = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let delta = obj["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                assembled += text
                let snapshot = assembled
                await MainActor.run { self.messageStream = snapshot }
            }
        }

        messageHistory.append(AIMessage(role: "assistant", content: assembled))
        await MainActor.run {
            if !assembled.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.lastMessages.append(MessageData(message: assembled, isUser: false))
            }
            self.messageStream = ""
            self.isReceiving = false
            ChatHistoryStore.shared.save(messages: self.lastMessages)
        }
    }

    // MARK: - Google Gemini streaming

    private func streamGemini(apiKey: String) async throws {
        let model = SettingsModel.shared.currentModel()
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AIConnectionManager", code: 11,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini URL"])
        }

        var contents: [[String: Any]] = []
        for (index, m) in messageHistory.enumerated() {
            let role = (m.role == "assistant") ? "model" : "user"
            var parts: [[String: Any]] = [["text": m.content]]
            if m.role == "user" && index == messageHistory.count - 1 {
                for img in m.images {
                    parts.append([
                        "inlineData": ["mimeType": mimeType(for: img), "data": img.base64EncodedString()]
                    ])
                }
            }
            contents.append(["role": role, "parts": parts])
        }

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": systemPrompt()]]],
            "contents": contents
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "AIConnectionManager", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "Gemini returned HTTP \(code)"])
        }

        var assembled = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            guard let data = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = obj["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else { continue }

            for p in parts {
                if let t = p["text"] as? String { assembled += t }
            }
            let snapshot = assembled
            await MainActor.run { self.messageStream = snapshot }
        }

        messageHistory.append(AIMessage(role: "assistant", content: assembled))
        await MainActor.run {
            if !assembled.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.lastMessages.append(MessageData(message: assembled, isUser: false))
            }
            self.messageStream = ""
            self.isReceiving = false
            ChatHistoryStore.shared.save(messages: self.lastMessages)
        }
    }
}
