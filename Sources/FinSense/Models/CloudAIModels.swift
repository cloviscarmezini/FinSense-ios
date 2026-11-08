// Sources/FinSense/Models/CloudAIModels.swift
import Foundation

public struct BackendAIModelInfo: Identifiable, Codable, Hashable {
    public let id: String
    public let displayName: String
    public let repoId: String
    public let fileName: String
    public let sizeBytes: Int64
    public let quantization: String
    public let isActive: Bool

    public init(
        id: String,
        displayName: String,
        repoId: String,
        fileName: String,
        sizeBytes: Int64,
        quantization: String,
        isActive: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.repoId = repoId
        self.fileName = fileName
        self.sizeBytes = sizeBytes
        self.quantization = quantization
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case repoId = "repo_id"
        case fileName = "file_name"
        case sizeBytes = "size_bytes"
        case quantization
        case isActive = "is_active"
    }
}

public struct SuggestedBackendModel: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let sizeEstimate: String
    public let isDownloaded: Bool

    public init(
        id: String,
        name: String,
        description: String,
        sizeEstimate: String,
        isDownloaded: Bool
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.sizeEstimate = sizeEstimate
        self.isDownloaded = isDownloaded
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case sizeEstimate = "size_estimate"
        case isDownloaded = "is_downloaded"
    }
}

public struct AIModelsCatalogResponse: Codable {
    public let selectedModelId: String?
    public let installedModels: [BackendAIModelInfo]
    public let suggestedModels: [SuggestedBackendModel]

    public init(
        selectedModelId: String?,
        installedModels: [BackendAIModelInfo],
        suggestedModels: [SuggestedBackendModel]
    ) {
        self.selectedModelId = selectedModelId
        self.installedModels = installedModels
        self.suggestedModels = suggestedModels
    }

    enum CodingKeys: String, CodingKey {
        case selectedModelId = "selected_model_id"
        case installedModels = "installed_models"
        case suggestedModels = "suggested_models"
    }
}

public struct AIDownloadTaskStatusResponse: Codable {
    public let taskId: UUID
    public let repoId: String
    public let fileName: String
    public let status: String // "PENDING", "DOWNLOADING", "VERIFYING", "READY", "FAILED", "CANCELED"
    public let progressPercentage: Double
    public let downloadedBytes: Int64
    public let totalBytes: Int64
    public let speedBytesSec: Int64
    public let errorMessage: String?

    public init(
        taskId: UUID,
        repoId: String,
        fileName: String,
        status: String,
        progressPercentage: Double,
        downloadedBytes: Int64,
        totalBytes: Int64,
        speedBytesSec: Int64,
        errorMessage: String? = nil
    ) {
        self.taskId = taskId
        self.repoId = repoId
        self.fileName = fileName
        self.status = status
        self.progressPercentage = progressPercentage
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.speedBytesSec = speedBytesSec
        self.errorMessage = errorMessage
    }

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case repoId = "repo_id"
        case fileName = "file_name"
        case status
        case progressPercentage = "progress_percentage"
        case downloadedBytes = "downloaded_bytes"
        case totalBytes = "total_bytes"
        case speedBytesSec = "speed_bytes_sec"
        case errorMessage = "error_message"
    }
}

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
