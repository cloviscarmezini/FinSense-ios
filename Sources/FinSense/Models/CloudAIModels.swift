// Sources/FinSense/Models/CloudAIModels.swift
import Foundation

public struct AIStatementParseResponse: Codable {
    public let transactions: [ParsedTransactionDTO]
    public let rawText: String?
    public let processingTimeMs: Int

    public init(
        transactions: [ParsedTransactionDTO],
        rawText: String? = nil,
        processingTimeMs: Int
    ) {
        self.transactions = transactions
        self.rawText = rawText
        self.processingTimeMs = processingTimeMs
    }

    enum CodingKeys: String, CodingKey {
        case transactions
        case rawText = "raw_text"
        case processingTimeMs = "processing_time_ms"
    }
}

public struct ParsedTransactionDTO: Codable, Identifiable {
    public var id: UUID { UUID() }
    public let date: String
    public let description: String
    public let amount: Double
    public let type: String
    public let categorySuggestion: String?

    public init(
        date: String,
        description: String,
        amount: Double,
        type: String,
        categorySuggestion: String? = nil
    ) {
        self.date = date
        self.description = description
        self.amount = amount
        self.type = type
        self.categorySuggestion = categorySuggestion
    }

    enum CodingKeys: String, CodingKey {
        case date, description, amount, type
        case categorySuggestion = "category_suggestion"
    }
}
