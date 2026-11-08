// Sources/FinSense/Models/CloudSyncModels.swift
import Foundation

public enum SyncStatus: Equatable {
    case disabled
    case synced(lastSync: Date)
    case syncing
    case outOfSync(pendingCount: Int, reason: String)
    case authError(message: String)

    public var iconSymbol: String {
        switch self {
        case .disabled: return "icloud"
        case .synced: return "checkmark.icloud.fill"
        case .syncing: return "arrow.triangle.2.circlepath.icloud.fill"
        case .outOfSync: return "exclamationmark.icloud.fill"
        case .authError: return "xmark.icloud.fill"
        }
    }
}

public enum SyncOperation: String, Codable {
    case upsert = "UPSERT"
    case delete = "DELETE"
}

public struct LocalSyncMutation: Identifiable, Codable, Hashable {
    public var id: UUID
    public var entityName: String
    public var entityId: UUID
    public var operation: SyncOperation
    public var updatedAt: Date
    public var payloadJSON: String?

    public init(
        id: UUID = UUID(),
        entityName: String,
        entityId: UUID,
        operation: SyncOperation,
        updatedAt: Date = Date(),
        payloadJSON: String? = nil
    ) {
        self.id = id
        self.entityName = entityName
        self.entityId = entityId
        self.operation = operation
        self.updatedAt = updatedAt
        self.payloadJSON = payloadJSON
    }
}

public struct SyncPushPullRequest: Codable {
    public let clientId: String
    public let clientLastSyncRevision: Int64
    public let mutations: [SyncMutationDTO]

    public init(
        clientId: String,
        clientLastSyncRevision: Int64,
        mutations: [SyncMutationDTO]
    ) {
        self.clientId = clientId
        self.clientLastSyncRevision = clientLastSyncRevision
        self.mutations = mutations
    }

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case clientLastSyncRevision = "client_last_sync_revision"
        case mutations
    }
}

public struct SyncMutationDTO: Codable {
    public let mutationId: UUID
    public let entityName: String
    public let entityId: UUID
    public let operation: String
    public let updatedAt: String
    public let payload: [String: AnyCodableValue]?

    public init(
        mutationId: UUID,
        entityName: String,
        entityId: UUID,
        operation: String,
        updatedAt: String,
        payload: [String: AnyCodableValue]? = nil
    ) {
        self.mutationId = mutationId
        self.entityName = entityName
        self.entityId = entityId
        self.operation = operation
        self.updatedAt = updatedAt
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case mutationId = "mutation_id"
        case entityName = "entity_name"
        case entityId = "entity_id"
        case operation
        case updatedAt = "updated_at"
        case payload
    }
}

public struct SyncPushPullResponse: Codable {
    public let serverCurrentRevision: Int64
    public let acknowledgedMutationIds: [UUID]
    public let rejectedMutations: [SyncRejectedMutationDTO]
    public let deltas: SyncDeltasContainerDTO
    public let tombstones: [SyncTombstoneDTO]

    public init(
        serverCurrentRevision: Int64,
        acknowledgedMutationIds: [UUID],
        rejectedMutations: [SyncRejectedMutationDTO],
        deltas: SyncDeltasContainerDTO,
        tombstones: [SyncTombstoneDTO]
    ) {
        self.serverCurrentRevision = serverCurrentRevision
        self.acknowledgedMutationIds = acknowledgedMutationIds
        self.rejectedMutations = rejectedMutations
        self.deltas = deltas
        self.tombstones = tombstones
    }

    enum CodingKeys: String, CodingKey {
        case serverCurrentRevision = "server_current_revision"
        case acknowledgedMutationIds = "acknowledged_mutation_ids"
        case rejectedMutations = "rejected_mutations"
        case deltas
        case tombstones
    }
}

public struct SyncRejectedMutationDTO: Codable {
    public let mutationId: UUID
    public let reason: String

    public init(mutationId: UUID, reason: String) {
        self.mutationId = mutationId
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case mutationId = "mutation_id"
        case reason
    }
}

public struct SyncTombstoneDTO: Codable {
    public let entityName: String
    public let entityId: UUID
    public let deletedAt: String

    public init(entityName: String, entityId: UUID, deletedAt: String) {
        self.entityName = entityName
        self.entityId = entityId
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case entityName = "entity_name"
        case entityId = "entity_id"
        case deletedAt = "deleted_at"
    }
}

public struct SyncDeltasContainerDTO: Codable {
    public let bankAccounts: [BankAccount]?
    public let categories: [CategoryItem]?
    public let financialTransactions: [FinancialTransaction]?
    public let investmentItems: [InvestmentItem]?
    public let creditContracts: [CreditContract]?
    public let debtItems: [DebtItem]?
    public let categoryProvisions: [CategoryProvision]?
    public let categoryQuotaRules: [CategoryQuotaRule]?
    public let chatMessages: [ChatMessage]?

    public init(
        bankAccounts: [BankAccount]? = nil,
        categories: [CategoryItem]? = nil,
        financialTransactions: [FinancialTransaction]? = nil,
        investmentItems: [InvestmentItem]? = nil,
        creditContracts: [CreditContract]? = nil,
        debtItems: [DebtItem]? = nil,
        categoryProvisions: [CategoryProvision]? = nil,
        categoryQuotaRules: [CategoryQuotaRule]? = nil,
        chatMessages: [ChatMessage]? = nil
    ) {
        self.bankAccounts = bankAccounts
        self.categories = categories
        self.financialTransactions = financialTransactions
        self.investmentItems = investmentItems
        self.creditContracts = creditContracts
        self.debtItems = debtItems
        self.categoryProvisions = categoryProvisions
        self.categoryQuotaRules = categoryQuotaRules
        self.chatMessages = chatMessages
    }

    enum CodingKeys: String, CodingKey {
        case bankAccounts = "bank_accounts"
        case categories
        case financialTransactions = "financial_transactions"
        case investmentItems = "investment_items"
        case creditContracts = "credit_contracts"
        case debtItems = "debt_items"
        case categoryProvisions = "category_provisions"
        case categoryQuotaRules = "category_quota_rules"
        case chatMessages = "chat_messages"
    }
}

public enum AnyCodableValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dictionary([String: AnyCodableValue])
    case array([AnyCodableValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let b = try? container.decode(Bool.self) { self = .bool(b) }
        else if let i = try? container.decode(Int.self) { self = .int(i) }
        else if let d = try? container.decode(Double.self) { self = .double(d) }
        else if let s = try? container.decode(String.self) { self = .string(s) }
        else if let arr = try? container.decode([AnyCodableValue].self) { self = .array(arr) }
        else if let dict = try? container.decode([String: AnyCodableValue].self) { self = .dictionary(dict) }
        else { self = .null }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .dictionary(let dict): try container.encode(dict)
        case .array(let arr): try container.encode(arr)
        case .null: try container.encodeNil()
        }
    }
}
