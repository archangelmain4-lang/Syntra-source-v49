//
//  Auth.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import Foundation

/// Authentication data model for user login information
struct Auth: Identifiable, Codable, Equatable {
    let id = UUID()
    let tenantName: String
    let email: String
    let authToken: String?
    let isAuthenticated: Bool
    let expiresAt: Date?
    
    // Convenience initializer for creating auth data
    init(
        tenantName: String,
        email: String,
        authToken: String? = nil,
        isAuthenticated: Bool = false,
        expiresAt: Date? = nil
    ) {
        self.tenantName = tenantName
        self.email = email
        self.authToken = authToken
        self.isAuthenticated = isAuthenticated
        self.expiresAt = expiresAt
    }
    
    // Check if the auth token is expired
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    // Check if user is authenticated and token is not expired
    var isValidAuthentication: Bool {
        return isAuthenticated && !isExpired
    }
}

/// Authentication response model for handling auth callbacks
struct AuthResponse: Codable {
    let tenantName: String
    let email: String
    let authToken: String?
    let expiresIn: Int? // seconds until expiration
    
    enum CodingKeys: String, CodingKey {
        case tenantName = "tenant_name"
        case email
        case authToken = "auth_token"
        case expiresIn = "expires_in"
    }
    
    // Convert to Auth model
    func toAuth() -> Auth {
        let expirationDate = expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
        return Auth(
            tenantName: tenantName,
            email: email,
            authToken: authToken,
            isAuthenticated: authToken != nil,
            expiresAt: expirationDate
        )
    }
} 