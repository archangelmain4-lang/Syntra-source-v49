//
//  AuthManagerExample.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import SwiftUI

// MARK: - Example of how to use AuthManager in any SwiftUI View

struct ExampleView: View {
    // Observe auth state changes
    @ObservedObject private var authModel = AuthManager.shared.model
    
    var body: some View {
        VStack {
            if authModel.isAuthenticated {
                VStack {
                    Text("✅ Authenticated")
                        .foregroundColor(.green)
                    Text("Email: \(authModel.email ?? "Unknown")")
                    Text("Tenant: \(authModel.tenantName ?? "Unknown")")
                    
                    Button("Logout") {
                        AuthManager.shared.logout()
                    }
                }
            } else {
                VStack {
                    Text("❌ Not Authenticated")
                        .foregroundColor(.red)
                    
                    Button("Connect Account") {
                        AuthManager.shared.startAuthFlow()
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStatusChanged)) { notification in
            // Handle auth status changes
            if let auth = notification.object as? Auth {
                print("Auth status changed: \(auth.email)")
            } else {
                print("User logged out")
            }
        }
    }
}

// MARK: - Example of how to use AuthManager in any class/manager

class ExampleManager {
    
    init() {
        // Listen for auth changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(authStatusChanged),
            name: .authStatusChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func authStatusChanged() {
        let authManager = AuthManager.shared
        
        if authManager.model.isAuthenticated {
            print("User authenticated: \(authManager.model.email ?? "Unknown")")
            // Initialize authenticated features
            setupAuthenticatedFeatures()
        } else {
            print("User logged out")
            // Clean up authenticated features
            cleanupAuthenticatedFeatures()
        }
    }
    
    private func setupAuthenticatedFeatures() {
        // Setup features that require authentication
    }
    
    private func cleanupAuthenticatedFeatures() {
        // Clean up authenticated features
    }
    
    func performAuthenticatedAction() {
        let authManager = AuthManager.shared
        
        guard authManager.model.isAuthenticated else {
            print("User not authenticated, starting auth flow...")
            authManager.startAuthFlow()
            return
        }
        
        // Perform action that requires authentication
        print("Performing authenticated action for: \(authManager.model.email ?? "Unknown")")
    }
}

// MARK: - Example of how to check auth status anywhere

extension AuthManager {
    /// Convenience computed properties for quick access
    var isAuthenticated: Bool {
        return model.isAuthenticated
    }
    
    var userEmail: String? {
        return model.email
    }
    
    var tenantName: String? {
        return model.tenantName
    }
}

// MARK: - Global functions for easy access

/// Check if user is authenticated
func isUserAuthenticated() -> Bool {
    return AuthManager.shared.isAuthenticated
}

/// Get current user email
func getCurrentUserEmail() -> String? {
    return AuthManager.shared.userEmail
}

/// Start auth flow if not authenticated
func ensureAuthenticated() {
    if !AuthManager.shared.isAuthenticated {
        AuthManager.shared.startAuthFlow()
    }
} 