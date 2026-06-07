//
//  WebSocketManager.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import Foundation
import Combine

/// Manages WebSocket connections for real-time API communication
class WebSocketManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectionError: Error?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private let reconnectDelay: TimeInterval = 3.0
    private var shouldReconnect = true
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    
    /// Connect to a WebSocket endpoint
    func connect(to endpoint: String) {
        guard let url = APIConfig.authenticatedWebSocketURL("\(APIConfig.websocketURL)\(endpoint)") else {
            connectionError = URLError(.badURL)
            return
        }
        
        disconnect()
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Send init message
        sendInit()
        
        // Start receiving messages
        receiveMessage()
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionError = nil
        }
    }
    
    /// Send initialization message
    private func sendInit() {
        let initMessage = ["init": true]
        guard let data = try? JSONSerialization.data(withJSONObject: initMessage),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        
        webSocketTask?.send(.string(jsonString)) { [weak self] error in
            if let error = error {
                self?.handleError(error)
            }
        }
    }
    
    /// Send JSON data through the WebSocket
    func send<T: Encodable>(_ data: T, completion: @escaping (Error?) -> Void) {
        guard let webSocketTask = webSocketTask else {
            completion(URLError(.notConnectedToInternet))
            return
        }
        
        do {
            let jsonData = try JSONEncoder().encode(data)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                completion(URLError(.cannotDecodeContentData))
                return
            }
            print("Sending json string")
            print(jsonString)
            webSocketTask.send(.string(jsonString)) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }
    
    /// Receive messages from the WebSocket
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self?.handleData(data)
                case .string(let text):
                    self?.handleText(text)
                @unknown default:
                    break
                }
                
                // Continue receiving messages
                self?.receiveMessage()
                
            case .failure(let error):
                self?.handleError(error)
            }
        }
    }
    
    /// Handle received data - can be overridden by subclasses
    open func handleData(_ data: Data) {
        // Override in subclasses to handle specific data types
    }
    
    /// Handle received text
    private func handleText(_ text: String) {
        // Handle init confirmation
        if text == "|INIT|" {
            print("WebSocket initialized successfully")
            return
        }
        
        // Try to parse as JSON
        if let data = text.data(using: .utf8) {
            handleData(data)
        }
    }
    
    /// Handle WebSocket errors
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.connectionError = error
            self.isConnected = false
        }
        
        if shouldReconnect {
            reconnect()
        }
    }
    
    /// Reconnect after a delay - can be overridden by subclasses
    open func reconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self = self, self.shouldReconnect else { return }
            // Subclasses should override to reconnect to specific endpoint
        }
    }
    
    /// Disconnect from the WebSocket
    func disconnect() {
        shouldReconnect = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    deinit {
        disconnect()
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionError = nil
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
        
        if shouldReconnect {
            reconnect()
        }
    }
} 
