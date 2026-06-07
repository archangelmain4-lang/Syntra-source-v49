//
//  NotesAPI.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import Foundation
import Combine

/// API service for notes-related operations
class NotesAPI {
    static let shared = NotesAPI()
    
    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Search notes by keyword
    func searchNotes(keyword: String, limit: Int = 20) -> AnyPublisher<[Note], APIClient.APIError> {
        let parameters = [
            "keyword": keyword,
            "limit": String(limit)
        ]
        
        let queryString = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        
        return apiClient.request(
            endpoint: "/notes/search?\(queryString)",
            method: .get
        )
    }
    
    /// Get a single note by ID
    func getNote(id: String) -> AnyPublisher<Note, APIClient.APIError> {
        return apiClient.request(
            endpoint: "/notes/\(id)",
            method: .get
        )
    }
    
    /// Create a new note
    func createNote(title: String, content: String, tags: [Tag]) -> AnyPublisher<Note, APIClient.APIError> {
        let body = CreateNoteRequest(
            title: title,
            content: content,
            tagIds: tags.map { $0.uniqueid }
        )
        
        return apiClient.request(
            endpoint: "/notes",
            method: .post,
            body: body
        )
    }
    
    /// Update an existing note
    func updateNote(id: String, title: String? = nil, content: String? = nil, tags: [Tag]? = nil) -> AnyPublisher<Note, APIClient.APIError> {
        let body = UpdateNoteRequest(
            title: title,
            content: content,
            tagIds: tags?.map { $0.uniqueid }
        )
        
        return apiClient.request(
            endpoint: "/notes/\(id)",
            method: .patch,
            body: body
        )
    }
    
    /// Delete a note
    func deleteNote(id: String) -> AnyPublisher<Void, APIClient.APIError> {
        return apiClient.requestVoid(
            endpoint: "/notes/\(id)",
            method: .delete
        )
    }
    
    /// Get notes by tag
    func getNotesByTag(tagId: String, limit: Int = 50) -> AnyPublisher<[Note], APIClient.APIError> {
        return apiClient.request(
            endpoint: "/notes/tag/\(tagId)?limit=\(limit)",
            method: .get
        )
    }
    
    /// Batch create notes
    func batchCreateNotes(_ notes: [CreateNoteRequest]) -> AnyPublisher<[Note], APIClient.APIError> {
        return apiClient.request(
            endpoint: "/notes/batch",
            method: .post,
            body: notes
        )
    }
    
    /// Create a Syntra note (minimal note with just title)
    func createSyntraNote(title: String, tenantName: String) -> AnyPublisher<SyntraNoteResponse, APIClient.APIError> {
        let body = SyntraNoteRequest(
            title: title,
            tenantName: tenantName
        )
        
        return apiClient.request(
            endpoint: "/syntra/create/note",
            method: .post,
            body: body
        )
    }
}

// MARK: - Request Models

struct CreateNoteRequest: Codable {
    let title: String
    let content: String
    let tagIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case title
        case content
        case tagIds = "tag_ids"
    }
}

struct UpdateNoteRequest: Codable {
    let title: String?
    let content: String?
    let tagIds: [String]?
    
    enum CodingKeys: String, CodingKey {
        case title
        case content
        case tagIds = "tag_ids"
    }
}

struct SyntraNoteRequest: Codable {
    let title: String
    let tenantName: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case tenantName = "tenant_name"
    }
}

// MARK: - Response Models

struct SyntraNoteResponse: Codable {
    let success: Bool
    let uniqueid: String
}

// MARK: - Example View Model using NotesAPI

class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let notesAPI = NotesAPI.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Search for notes
    func searchNotes(keyword: String) {
        isLoading = true
        error = nil
        
        notesAPI.searchNotes(keyword: keyword)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] notes in
                    self?.notes = notes
                }
            )
            .store(in: &cancellables)
    }
    
    /// Create a new note
    func createNote(title: String, content: String, tags: [Tag]) {
        isLoading = true
        error = nil
        
        notesAPI.createNote(title: title, content: content, tags: tags)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] note in
                    self?.notes.append(note)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Delete a note
    func deleteNote(_ note: Note) {
        notesAPI.deleteNote(id: note.uniqueid)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.notes.removeAll { $0.uniqueid == note.uniqueid }
                }
            )
            .store(in: &cancellables)
    }
} 