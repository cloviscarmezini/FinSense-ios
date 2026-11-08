// Sources/FinSense/Models/ChatMessage.swift
import Foundation

public enum ChatMessageRole: String, Codable, Hashable {
    case user
    case assistant
    case system
}

public struct ChatMessage: Identifiable, Codable, Hashable {
    public var id: UUID
    public var role: ChatMessageRole
    public var content: String
    public var timestamp: Date
    public var modelUsed: String?

    public init(
        id: UUID = UUID(),
        role: ChatMessageRole,
        content: String,
        timestamp: Date = Date(),
        modelUsed: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.modelUsed = modelUsed
    }
}
