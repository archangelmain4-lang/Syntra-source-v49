//
//  TagWebSocketManager.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#endif

// MARK: - API Models
struct GetAllTagsRequest: Codable {
    let tenant_name: String
}

struct GetAllTagsResponse: Codable {
    let results: [TagAPIData]
}

struct TagAPIData: Codable {
    let uniqueid: String
    let name: String
    let color: String
    
    // Convert to Tag model
    func toTag() -> Tag {
        return Tag(uniqueid: uniqueid, name: name, color: color)
    }
}

// MARK: - WebSocket Models
struct TagUpdate: Codable {
    let type: String
    let action: String? // "created", "updated", "deleted"
    let data: TagData?
    let timestamp: String?
    let status: String? // For connection messages
    let tenant_name: String? // For connection messages
}

struct TagData: Codable {
    let uniqueid: String
    let name: String?
    let color: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uniqueid = try container.decode(String.self, forKey: .uniqueid)
        self.name = try? container.decode(String.self, forKey: .name)
        self.color = try? container.decode(String.self, forKey: .color)
    }
    
    enum CodingKeys: String, CodingKey {
        case uniqueid, name, color
    }
    
    // Convert to Tag model
    func toTag() -> Tag? {
        guard let name = name, let color = color else { return nil }
        return Tag(uniqueid: uniqueid, name: name, color: color)
    }
}

// MARK: - Tag WebSocket Manager
class TagWebSocketManager: ObservableObject {
    // Singleton
    static let shared = TagWebSocketManager()
    
    // Publishers
    @Published var isConnected: Bool = false
    @Published var lastTagUpdate: TagUpdate?
    @Published var tags: [Tag] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // Combine publishers for specific tag events
    let tagCreatedPublisher = PassthroughSubject<TagData, Never>()
    let tagUpdatedPublisher = PassthroughSubject<TagData, Never>()
    let tagDeletedPublisher = PassthroughSubject<String, Never>() // Just the ID
    
    // HTTP client — routed through APIConfig (override in Settings)
    private var httpSession: URLSession
    private var baseHTTPURL: String { APIConfig.baseURL }

    // WebSocket and session
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var baseURL: String { APIConfig.websocketURL }
    private var tenantName: String = "" // Set this based on your user's tenant
    
    // Background connection management
    private var shouldMaintainConnection: Bool = true
    #if canImport(UIKit)
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    #endif
    private var reconnectionAttempts: Int = 0
    private let maxReconnectionAttempts: Int = 10
    private var reconnectionDelay: TimeInterval = 1.0
    
    // Tasks
    private var receiveTask: Task<Void, Error>?
    private var pingTask: Task<Void, Error>?
    private var connectionMonitorTask: Task<Void, Error>?
    
    private init() {
        // Setup HTTP session
        let httpConfig = URLSessionConfiguration.default
        httpConfig.timeoutIntervalForRequest = 30
        httpConfig.timeoutIntervalForResource = 60
        self.httpSession = URLSession(configuration: httpConfig)
        
        setupSession()
        setupBackgroundHandling()
    }
    
    // MARK: - Setup
    
    func setupSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }
    
    private func setupBackgroundHandling() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }
    
    #if canImport(UIKit)
    @objc private func appDidEnterBackground() {
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "TagWebSocketConnection") {
            self.endBackgroundTask()
        }
    }
    
    @objc private func appWillEnterForeground() {
        endBackgroundTask()
        
        if shouldMaintainConnection && !isConnected {
            Task {
                try await connect(tenantName: tenantName)
            }
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    #endif
    
    // MARK: - Public API
    
    /// Initialize with tenant name - fetches all tags and starts WebSocket connection
    func initialize(tenantName: String) async throws {
        self.tenantName = tenantName
        
        // First, fetch all existing tags
        try await fetchAllTags()
        
        // Then connect to WebSocket for real-time updates
        try await connect(tenantName: tenantName)
    }
    
    /// Fetch all tags from the API
    func fetchAllTags() async throws {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        guard !tenantName.isEmpty else {
            await MainActor.run {
                error = "Tenant name not set"
                isLoading = false
            }
            throw NSError(domain: "TagWebSocketManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Tenant name not set"])
        }
        
        guard let url = URL(string: "\(baseHTTPURL)/syntra_db/tag/get_all_tags_for_user") else {
            await MainActor.run {
                error = "Invalid URL"
                isLoading = false
            }
            throw NSError(domain: "TagWebSocketManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = GetAllTagsRequest(tenant_name: tenantName)
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await httpSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "TagWebSocketManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NSError(domain: "TagWebSocketManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
            }
            
            let apiResponse = try JSONDecoder().decode(GetAllTagsResponse.self, from: data)
            let fetchedTags = apiResponse.results.map { $0.toTag() }
            
            await MainActor.run {
                self.tags = fetchedTags
                self.isLoading = false
                print("Loaded \(fetchedTags.count) tags")
            }
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    /// Refresh tags from the API
    func refreshTags() async {
        do {
            try await fetchAllTags()
        } catch {
            print("Failed to refresh tags: \(error)")
        }
    }
    
    // MARK: - Connection
    
    func connect(tenantName: String) async throws {
        guard let session = session, webSocket == nil, shouldMaintainConnection else { return }
        
        self.tenantName = tenantName
        
        // Construct WebSocket URL with tenant name
        guard let url = APIConfig.authenticatedWebSocketURL("\(baseURL)/syntra_db/tag/ws?tenant_name=\(tenantName)") else {
            throw NSError(domain: "TagWebSocketManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        await MainActor.run {
            isConnected = true
        }
        
        reconnectionAttempts = 0
        reconnectionDelay = 1.0
        
        startPingTask()
        startReceiveTask()
        startConnectionMonitorTask()
    }
    
    private func startPingTask() {
        pingTask = Task {
            while !Task.isCancelled, webSocket != nil, shouldMaintainConnection {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000 * 30) // 30 seconds
                    try await webSocket?.send(.string("ping"))
                } catch {
                    print("Tag WebSocket ping failed: \(error)")
                    break
                }
            }
        }
    }
    
    private func startReceiveTask() {
        receiveTask = Task {
            do {
                while !Task.isCancelled, webSocket != nil, shouldMaintainConnection {
                    guard let task = webSocket else { break }
                    
                    let message = try await task.receive()
                    
                    switch message {
                    case .data(let data):
                        handleReceivedData(data)
                    case .string(let text):
                        handleReceivedText(text)
                    @unknown default:
                        break
                    }
                }
            } catch {
                if !Task.isCancelled && shouldMaintainConnection {
                    print("Tag WebSocket receive error: \(error)")
                    await handleConnectionError(error)
                }
            }
        }
    }
    
    private func startConnectionMonitorTask() {
        connectionMonitorTask = Task {
            while !Task.isCancelled, shouldMaintainConnection {
                try await Task.sleep(nanoseconds: 1_000_000_000 * 10) // 10 seconds
                
                if shouldMaintainConnection && !isConnected {
                    do {
                        try await reconnect()
                    } catch {
                        print("Tag WebSocket reconnect failed: \(error)")
                    }
                }
            }
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        do {
            let update = try JSONDecoder().decode(TagUpdate.self, from: data)
            handleTagUpdate(update)
        } catch {
            print("Error decoding tag update: \(error)")
        }
    }
    
    private func handleReceivedText(_ text: String) {
        // Handle pong responses
        if text == "pong" {
            return
        }
        
        // Try to parse as JSON
        if let data = text.data(using: .utf8) {
            handleReceivedData(data)
        }
    }
    
    private func handleTagUpdate(_ update: TagUpdate) {
        DispatchQueue.main.async {
            self.lastTagUpdate = update
            
            switch update.type {
            case "connection":
                print("Tag WebSocket connected: \(update.status ?? "")")
                
            case "tag_update":
                guard let action = update.action else { return }
                
                switch action {
                case "created":
                    if let data = update.data, let newTag = data.toTag() {
                        self.addOrUpdateTag(newTag)
                        self.tagCreatedPublisher.send(data)
                    }
                case "updated":
                    if let data = update.data, let updatedTag = data.toTag() {
                        self.addOrUpdateTag(updatedTag)
                        self.tagUpdatedPublisher.send(data)
                    }
                case "deleted":
                    if let data = update.data {
                        self.removeTag(with: data.uniqueid)
                        self.tagDeletedPublisher.send(data.uniqueid)
                    }
                default:
                    break
                }
                
            case "ping":
                // Server ping, no action needed
                break
                
            default:
                print("Unknown tag update type: \(update.type)")
            }
        }
    }
    
    // MARK: - Tag Management
    
    private func addOrUpdateTag(_ tag: Tag) {
        if let index = tags.firstIndex(where: { $0.uniqueid == tag.uniqueid }) {
            // Update existing tag
            tags[index] = tag
            print("Updated tag: \(tag.name)")
        } else {
            // Add new tag
            tags.append(tag)
            print("Added new tag: \(tag.name)")
        }
    }
    
    private func removeTag(with uniqueid: String) {
        if let index = tags.firstIndex(where: { $0.uniqueid == uniqueid }) {
            let removedTag = tags.remove(at: index)
            print("Removed tag: \(removedTag.name)")
        }
    }
    
    /// Get tag by unique ID
    func getTag(by uniqueid: String) -> Tag? {
        return tags.first { $0.uniqueid == uniqueid }
    }
    
    /// Get tags by name (case-insensitive search)
    func getTags(containing searchText: String) -> [Tag] {
        if searchText.isEmpty {
            return tags
        }
        return tags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - Connection Management
    
    private func handleConnectionError(_ error: Error) async {
        await MainActor.run {
            isConnected = false
        }
        
        if shouldMaintainConnection {
            do {
                try await reconnect()
            } catch {
                print("Tag WebSocket auto-reconnect failed: \(error)")
            }
        }
    }
    
    private func reconnect() async throws {
        guard shouldMaintainConnection else { return }
        
        await disconnect()
        
        if reconnectionAttempts < maxReconnectionAttempts {
            reconnectionAttempts += 1
            let delay = min(reconnectionDelay * pow(2.0, Double(reconnectionAttempts - 1)), 30.0)
            
            print("Tag WebSocket reconnecting in \(delay) seconds (attempt \(reconnectionAttempts)/\(maxReconnectionAttempts))")
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            try await connect(tenantName: tenantName)
        } else {
            print("Tag WebSocket max reconnection attempts reached.")
            reconnectionAttempts = 0
        }
    }
    
    func disconnect() async {
        pingTask?.cancel()
        receiveTask?.cancel()
        connectionMonitorTask?.cancel()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        
        await MainActor.run {
            isConnected = false
        }
    }
    
    func gracefulDisconnect() async {
        shouldMaintainConnection = false
        await disconnect()
        #if canImport(UIKit)
        endBackgroundTask()
        #endif
    }
    
    deinit {
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self)
        endBackgroundTask()
        #endif
        shouldMaintainConnection = false
        Task {
            await disconnect()
        }
    }
} 
