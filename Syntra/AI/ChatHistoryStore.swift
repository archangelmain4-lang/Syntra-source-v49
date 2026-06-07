//
//  ChatHistoryStore.swift
//  Syntra
//
//  Stores recent AI Assist conversations on disk so the "history" button in
//  the overlay can show prior chats and let users reopen them.
//

import Foundation
import Combine
import AppKit

final class ChatHistoryStore: ObservableObject {
    static let shared = ChatHistoryStore()

    struct StoredMessage: Codable, Identifiable {
        var id = UUID()
        let role: String          // "user" | "assistant"
        let content: String
        /// Base64-encoded PNG payloads attached to this message.
        var imagesBase64: [String] = []
    }

    struct Conversation: Codable, Identifiable {
        let id: UUID
        var title: String
        let createdAt: Date
        let messages: [StoredMessage]
    }

    @Published private(set) var conversations: [Conversation] = []
    private let key = "SyntraChatHistory_v2"
    private let maxConversations = 50

    private init() { load() }

    /// Saves the given messages as a new conversation at the top.
    /// Returns the id of the newly saved conversation (or nil if nothing to save).
    @discardableResult
    func save(messages: [MessageData]) -> UUID? {
        let stored: [StoredMessage] = messages
            .filter { !$0.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.images.isEmpty }
            .map { md in
                StoredMessage(
                    role: md.isUser ? "user" : "assistant",
                    content: md.message,
                    imagesBase64: md.images.map { $0.base64EncodedString() }
                )
            }
        guard !stored.isEmpty else { return nil }

        // Avoid stacking duplicate saved copies when the user switches between
        // old chats or repeatedly hides/shows the overlay.
        if conversations.first?.messages.map({ $0.role + "|" + $0.content }) == stored.map({ $0.role + "|" + $0.content }) {
            return conversations.first?.id
        }

        let firstUser = stored.first(where: { $0.role == "user" })?.content ?? "Conversation"
        let fallbackTitle = String(firstUser.prefix(50))

        let id = UUID()
        let convo = Conversation(
            id: id,
            title: fallbackTitle,
            createdAt: Date(),
            messages: stored
        )
        conversations.insert(convo, at: 0)
        if conversations.count > maxConversations {
            conversations = Array(conversations.prefix(maxConversations))
        }
        persist()

        // Kick off an async AI-generated short title.
        Task { await self.generateTitle(for: id, basedOn: stored) }
        return id
    }

    func updateTitle(_ id: UUID, title: String) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        var c = conversations[idx]
        c.title = title
        conversations[idx] = c
        persist()
    }

    func delete(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        conversations.removeAll()
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let arr = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = arr
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - AI title generation

    /// Asks the currently configured AI provider for a 2-5 word descriptive title.
    private func generateTitle(for id: UUID, basedOn messages: [StoredMessage]) async {
        let snippet = messages.prefix(4)
            .map { "\($0.role.uppercased()): \($0.content.prefix(400))" }
            .joined(separator: "\n")
        guard !snippet.isEmpty else { return }

        let prompt = """
        Write a 2-5 word descriptive title for this conversation. No quotes, no punctuation at the end. Just the title.

        \(snippet)
        """

        if let title = try? await AIConnectionManager.shared.oneShotCompletion(prompt: prompt, maxTokens: 24) {
            let cleaned = title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'.,!?"))
            if !cleaned.isEmpty {
                await MainActor.run { self.updateTitle(id, title: String(cleaned.prefix(60))) }
            }
        }
    }
}
