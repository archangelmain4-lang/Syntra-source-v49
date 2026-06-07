//
//  Note.swift
//  Syntra
//
//  Created by AI Assistant on 5/15/25.
//

import Foundation

/// Note model matching the backend WeaviateNote structure
struct Note: Identifiable, Codable, Equatable {
    let id = UUID()
    let uniqueid: String
    let title: String
    let content: String
    let filePath: String
    let tags: [Tag]
    let created: Int
    let lastModified: Int
    let lastUpdateDevice: String
    let lastUpdateDeviceId: String
    let incomingConnections: [String]
    let outgoingConnections: [String]
    let tagIds: [String]
    let fileData: String?
    let fileType: String?
    let fileText: String?
    let noteType: String?
    
    // Custom coding keys to handle backend response format
    enum CodingKeys: String, CodingKey {
        case uniqueid
        case properties
        // Also include direct properties for flat responses
        case title
        case content
        case filePath
        case tags
        case created
        case lastModified
        case lastUpdateDevice
        case lastUpdateDeviceId
        case incomingConnections
        case outgoingConnections
        case tagIds
        case fileData
        case fileType
        case fileText
        case noteType
    }
    
    enum PropertiesKeys: String, CodingKey {
        case title
        case content
        case filePath
        case tags
        case created
        case lastModified
        case lastUpdateDevice
        case lastUpdateDeviceId
        case incomingConnections
        case outgoingConnections
        case tagIds
        case fileData
        case fileType
        case fileText
        case noteType
    }
    
    // Custom decoder to handle nested properties structure from backend
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uniqueid = try container.decode(String.self, forKey: .uniqueid)
        
        // Try to decode from nested properties first
        if container.contains(.properties) {
            let propertiesContainer = try container.nestedContainer(keyedBy: PropertiesKeys.self, forKey: .properties)
            self.title = try propertiesContainer.decode(String.self, forKey: .title)
            self.content = try propertiesContainer.decode(String.self, forKey: .content)
            self.filePath = try propertiesContainer.decodeIfPresent(String.self, forKey: .filePath) ?? ""
            self.tags = try propertiesContainer.decode([Tag].self, forKey: .tags)
            self.created = try propertiesContainer.decode(Int.self, forKey: .created)
            self.lastModified = try propertiesContainer.decode(Int.self, forKey: .lastModified)
            self.lastUpdateDevice = try propertiesContainer.decodeIfPresent(String.self, forKey: .lastUpdateDevice) ?? ""
            self.lastUpdateDeviceId = try propertiesContainer.decodeIfPresent(String.self, forKey: .lastUpdateDeviceId) ?? ""
            // incomingConnections
            if let ids = try? propertiesContainer.decode([String].self, forKey: .incomingConnections) {
                self.incomingConnections = ids
            } else if let dicts = try? propertiesContainer.decode([[String: String]].self, forKey: .incomingConnections) {
                self.incomingConnections = dicts.compactMap { $0["uniqueid"] ?? $0["id"] ?? $0["target"] }
            } else {
                self.incomingConnections = []
            }
            // outgoingConnections
            if let ids = try? propertiesContainer.decode([String].self, forKey: .outgoingConnections) {
                self.outgoingConnections = ids
            } else if let dicts = try? propertiesContainer.decode([[String: String]].self, forKey: .outgoingConnections) {
                self.outgoingConnections = dicts.compactMap { $0["uniqueid"] ?? $0["id"] ?? $0["target"] }
            } else {
                self.outgoingConnections = []
            }
            self.tagIds = try propertiesContainer.decode([String].self, forKey: .tagIds)
            self.fileData = try propertiesContainer.decodeIfPresent(String.self, forKey: .fileData)
            self.fileType = try propertiesContainer.decodeIfPresent(String.self, forKey: .fileType)
            self.fileText = try propertiesContainer.decodeIfPresent(String.self, forKey: .fileText)
            self.noteType = try propertiesContainer.decodeIfPresent(String.self, forKey: .noteType)
        } else {
            // Fall back to flat structure
            self.title = try container.decode(String.self, forKey: .title)
            self.content = try container.decode(String.self, forKey: .content)
            self.filePath = try container.decodeIfPresent(String.self, forKey: .filePath) ?? ""
            self.tags = try container.decode([Tag].self, forKey: .tags)
            self.created = try container.decode(Int.self, forKey: .created)
            self.lastModified = try container.decode(Int.self, forKey: .lastModified)
            self.lastUpdateDevice = try container.decodeIfPresent(String.self, forKey: .lastUpdateDevice) ?? ""
            self.lastUpdateDeviceId = try container.decodeIfPresent(String.self, forKey: .lastUpdateDeviceId) ?? ""
            // incomingConnections
            if let ids = try? container.decode([String].self, forKey: .incomingConnections) {
                self.incomingConnections = ids
            } else if let dicts = try? container.decode([[String: String]].self, forKey: .incomingConnections) {
                self.incomingConnections = dicts.compactMap { $0["uniqueid"] ?? $0["id"] ?? $0["target"] }
            } else {
                self.incomingConnections = []
            }
            // outgoingConnections
            if let ids = try? container.decode([String].self, forKey: .outgoingConnections) {
                self.outgoingConnections = ids
            } else if let dicts = try? container.decode([[String: String]].self, forKey: .outgoingConnections) {
                self.outgoingConnections = dicts.compactMap { $0["uniqueid"] ?? $0["id"] ?? $0["target"] }
            } else {
                self.outgoingConnections = []
            }
            self.tagIds = try container.decode([String].self, forKey: .tagIds)
            self.fileData = try container.decodeIfPresent(String.self, forKey: .fileData)
            self.fileType = try container.decodeIfPresent(String.self, forKey: .fileType)
            self.fileText = try container.decodeIfPresent(String.self, forKey: .fileText)
            self.noteType = try container.decodeIfPresent(String.self, forKey: .noteType)
        }
    }
    
    // Custom encoder to match backend format
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uniqueid, forKey: .uniqueid)
        
        var propertiesContainer = container.nestedContainer(keyedBy: PropertiesKeys.self, forKey: .properties)
        try propertiesContainer.encode(title, forKey: .title)
        try propertiesContainer.encode(content, forKey: .content)
        try propertiesContainer.encode(filePath, forKey: .filePath)
        try propertiesContainer.encode(tags, forKey: .tags)
        try propertiesContainer.encode(created, forKey: .created)
        try propertiesContainer.encode(lastModified, forKey: .lastModified)
        try propertiesContainer.encode(lastUpdateDevice, forKey: .lastUpdateDevice)
        try propertiesContainer.encode(lastUpdateDeviceId, forKey: .lastUpdateDeviceId)
        try propertiesContainer.encode(incomingConnections, forKey: .incomingConnections)
        try propertiesContainer.encode(outgoingConnections, forKey: .outgoingConnections)
        try propertiesContainer.encode(tagIds, forKey: .tagIds)
        try propertiesContainer.encodeIfPresent(fileData, forKey: .fileData)
        try propertiesContainer.encodeIfPresent(fileType, forKey: .fileType)
        try propertiesContainer.encodeIfPresent(fileText, forKey: .fileText)
        try propertiesContainer.encodeIfPresent(noteType, forKey: .noteType)
    }
    
    // Convenience initializer for creating notes locally
    init(
        uniqueid: String,
        title: String,
        content: String,
        filePath: String = "",
        tags: [Tag] = [],
        created: Int = Int(Date().timeIntervalSince1970 * 1000),
        lastModified: Int = Int(Date().timeIntervalSince1970 * 1000),
        lastUpdateDevice: String = "",
        lastUpdateDeviceId: String = "",
        incomingConnections: [String] = [],
        outgoingConnections: [String] = [],
        tagIds: [String] = [],
        fileData: String? = nil,
        fileType: String? = nil,
        fileText: String? = nil,
        noteType: String? = nil
    ) {
        self.uniqueid = uniqueid
        self.title = title
        self.content = content
        self.filePath = filePath
        self.tags = tags
        self.created = created
        self.lastModified = lastModified
        self.lastUpdateDevice = lastUpdateDevice
        self.lastUpdateDeviceId = lastUpdateDeviceId
        self.incomingConnections = incomingConnections
        self.outgoingConnections = outgoingConnections
        self.tagIds = tagIds.isEmpty && !tags.isEmpty ? tags.map { $0.uniqueid } : tagIds
        self.fileData = fileData
        self.fileType = fileType
        self.fileText = fileText
        self.noteType = noteType
    }
}

// MARK: - Equatable
extension Note {
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.uniqueid == rhs.uniqueid
    }
}

// Response model for context search results
struct ContextSearchResponse: Codable {
    let results: [Note]
    let searchQueriesUsed: [String]?
    let sentenceChunksUsed: [String]?
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case results
        case searchQueriesUsed = "search_queries_used"
        case sentenceChunksUsed = "sentence_chunks_used"
        case totalResults = "total_results"
    }
} 