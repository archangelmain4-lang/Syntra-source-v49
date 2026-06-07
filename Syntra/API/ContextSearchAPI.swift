//
//  ContextSearchAPI.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import Foundation
import Combine

/// Request model for context search
struct ContextSearchRequest: Codable {
    let screenOcr: String
    let tenantName: String
    
    enum CodingKeys: String, CodingKey {
        case screenOcr = "screen_ocr"
        case tenantName = "tenant_name"
    }
}

/// API service for context search functionality
class ContextSearchAPI: WebSocketManager {
    static let shared = ContextSearchAPI()
    
    @Published var searchResults: ContextSearchResponse?
    @Published var isSearching = false
    
    private let endpoint = "/v1/context/context-search-ws-sentence-chunks"
    private var currentEndpoint: String?
    
    /// Search method type
    enum SearchMethod {
        case topicExtraction
        case sentenceChunks
        
        var endpoint: String {
            switch self {
            case .topicExtraction:
                return "/v1/context/context-search-ws-topic-extraction"
            case .sentenceChunks:
                return "/v1/context/context-search-ws-sentence-chunks"
            }
        }
    }
    
    /// Connect to context search WebSocket with specified method
    func connectForSearch(method: SearchMethod = .sentenceChunks) {
        currentEndpoint = method.endpoint
        connect(to: method.endpoint)
    }
    
    /// Search for context based on screen OCR
    func searchContext(screenOCR: String, tenantName: String = "EJIy9EyNGpYRZdRx0vqb9SiBQZx1") {
        guard isConnected else {
            print("WebSocket not connected. Attempting to connect...")
            connectForSearch()
            
            // Retry after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.searchContext(screenOCR: screenOCR, tenantName: tenantName)
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isSearching = true
        }
        
        print("Sending request")
        
        let request = ContextSearchRequest(screenOcr: screenOCR, tenantName: tenantName)
        
        send(request) { [weak self] error in
            if let error = error {
                print("Error sending context search request: \(error)")
                DispatchQueue.main.async {
                    self?.isSearching = false
                    self?.connectionError = error
                }
            }
        }
    }
    
    /// Handle received data from WebSocket
    override func handleData(_ data: Data) {
        do {
            // Try to decode as ContextSearchResponse
            let response = try JSONDecoder().decode(ContextSearchResponse.self, from: data)
            
            DispatchQueue.main.async {
                self.searchResults = response
                self.isSearching = false
                print("Received \(response.totalResults) search results")
            }
        } catch {
            // Try to decode as error response
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorDict["error"] as? String {
                print("Context search error: \(errorMessage)")
                DispatchQueue.main.async {
                    self.connectionError = NSError(domain: "ContextSearchAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    self.isSearching = false
                }
            } else {
                print("Failed to decode context search response: \(error)")
                DispatchQueue.main.async {
                    self.connectionError = error
                    self.isSearching = false
                }
            }
        }
    }
    
    /// Override reconnect to use current endpoint
    override func reconnect() {
        guard let endpoint = currentEndpoint else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            self.connect(to: endpoint)
        }
    }
}

/// Manager for integrating context search with AutoContextOverlay
class AutoContextManager: ObservableObject {
    @Published var contextNotes: [Note] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let contextSearchAPI = ContextSearchAPI.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind search results
        contextSearchAPI.$searchResults
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                self?.contextNotes = response.results
            }
            .store(in: &cancellables)
        
        // Bind loading state
        contextSearchAPI.$isSearching
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        // Bind error state
        contextSearchAPI.$connectionError
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)
    }
    
    /// Connect to the WebSocket service
    func connect(method: ContextSearchAPI.SearchMethod = .sentenceChunks) {
        contextSearchAPI.connectForSearch(method: method)
    }
    
    /// Search for context notes based on screen OCR
    func searchContext(screenOCR: String) {
        contextSearchAPI.searchContext(screenOCR: screenOCR)
    }
    
    /// Disconnect from the WebSocket service
    func disconnect() {
        contextSearchAPI.disconnect()
    }
} 
