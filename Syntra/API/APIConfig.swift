//
//  APIConfig.swift
//  Syntra
//

import Foundation

/// Configuration for API endpoints. Honors a user-supplied override stored
/// in UserDefaults under "CustomAPIBaseURL" (set from Settings → Account & API).
struct APIConfig {
    /// Default Syntra backend (placeholder; users can override in Settings).
    static let defaultBaseURL = "https://api.syntra.cc"

    /// Live base URL — uses the custom override if set, else the default.
    static var baseURL: String {
        let override = UserDefaults.standard.string(forKey: "CustomAPIBaseURL") ?? ""
        let trimmed = override.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultBaseURL : trimmed
    }

    /// User-supplied API key (optional). Sent as `Authorization: Bearer <key>`
    /// when present.
    static var apiKey: String {
        UserDefaults.standard.string(forKey: "CustomAPIKey") ?? ""
    }

    /// WebSocket URL derived from `baseURL`.
    static var websocketURL: String {
        let base = baseURL
        let wsProtocol = base.hasPrefix("https") ? "wss" : "ws"
        let cleanURL = base
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        return "\(wsProtocol)://\(cleanURL)"
    }

    static func authenticatedWebSocketURL(_ rawURL: String) -> URL? {
        guard var components = URLComponents(string: rawURL) else { return nil }
        let key = apiKey
        if !key.isEmpty {
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "api_key", value: key))
            components.queryItems = items
        }
        return components.url
    }

    struct Timeouts {
        static let standard: TimeInterval = 30.0
        static let extended: TimeInterval = 60.0
        static let websocket: TimeInterval = 120.0
    }

    static var defaultHeaders: [String: String] {
        var h: [String: String] = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        let key = apiKey
        if !key.isEmpty {
            h["Authorization"] = "Bearer \(key)"
        }
        return h
    }
}
