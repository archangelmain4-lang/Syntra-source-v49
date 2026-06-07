//
//  SupabaseNotesAPI.swift
//  Syntra
//
//  Saves "Quick Capture" notes directly to the user's Syntra Supabase
//  (desktop_notes table) using the user's auth JWT. No backend server
//  required — PostgREST + RLS handle authorization.
//

import Foundation

struct DesktopNote: Codable, Identifiable {
    let id: String
    let user_id: String
    let content: String
    let tags: [String]?
    let captured_text: String?
    let source_app: String?
    let created_at: String?
}

final class SupabaseNotesAPI {
    static let shared = SupabaseNotesAPI()

    // Hardcoded Syntra Supabase project config (same as the rest of the app).
    private let supabaseURL = "https://vdershnfxixsfhxegual.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZkZXJzaG5meGl4c2ZoeGVndWFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE4OTU0MzksImV4cCI6MjA2NzQ3MTQzOX0.eBjegKmT9qzhbjqOpJRScfn6yaQkgPukobzSaIB5VkM"

    enum NotesError: Error, LocalizedError {
        case notAuthenticated
        case badResponse(Int, String)
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "You need to sign in to your Syntra account first."
            case .badResponse(let code, let body): return "Server error \(code): \(body)"
            case .transport(let e): return e.localizedDescription
            }
        }
    }

    /// Create a new note. Returns the saved note id.
    func createNote(
        content: String,
        tags: [String] = [],
        capturedText: String? = nil,
        sourceApp: String? = nil
    ) async throws -> String {
        guard let token = AuthManager.shared.model.currentAuth?.authToken,
              !token.isEmpty else {
            throw NotesError.notAuthenticated
        }

        let url = URL(string: "\(supabaseURL)/rest/v1/desktop_notes")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")

        // user_id is required by RLS — derive it from the JWT subject.
        guard let userId = Self.userIdFromJWT(token) else {
            throw NotesError.notAuthenticated
        }

        var body: [String: Any] = [
            "user_id": userId,
            "content": content,
            "tags": tags
        ]
        if let capturedText, !capturedText.isEmpty { body["captured_text"] = capturedText }
        if let sourceApp, !sourceApp.isEmpty { body["source_app"] = sourceApp }

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw NotesError.badResponse(0, "No response")
            }
            guard (200..<300).contains(http.statusCode) else {
                let bodyStr = String(data: data, encoding: .utf8) ?? "<empty>"
                throw NotesError.badResponse(http.statusCode, bodyStr)
            }
            if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let first = arr.first,
               let id = first["id"] as? String {
                return id
            }
            return ""
        } catch let e as NotesError {
            throw e
        } catch {
            throw NotesError.transport(error)
        }
    }

    /// List the user's recent notes.
    func listNotes(limit: Int = 50) async throws -> [DesktopNote] {
        guard let token = AuthManager.shared.model.currentAuth?.authToken,
              !token.isEmpty else {
            throw NotesError.notAuthenticated
        }

        let url = URL(string: "\(supabaseURL)/rest/v1/desktop_notes?select=*&order=created_at.desc&limit=\(limit)")!
        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let bodyStr = String(data: data, encoding: .utf8) ?? "<empty>"
            throw NotesError.badResponse(code, bodyStr)
        }
        return (try? JSONDecoder().decode([DesktopNote].self, from: data)) ?? []
    }

    // MARK: - JWT helpers

    /// Extract the "sub" claim (Supabase user id) from a JWT without verifying signature.
    private static func userIdFromJWT(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        // base64url -> base64 padding
        payload = payload.replacingOccurrences(of: "-", with: "+")
                         .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        return sub
    }
}
