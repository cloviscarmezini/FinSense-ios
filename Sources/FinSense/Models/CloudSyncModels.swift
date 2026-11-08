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

public struct AnyKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?
    public init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    public init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    public init(_ string: String) { self.stringValue = string; self.intValue = nil }
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
    public let sinceRevision: Int64
    public let clientLastSyncRevision: Int64
    public let mutations: [SyncMutationDTO]

    public init(
        clientId: String,
        sinceRevision: Int64? = nil,
        clientLastSyncRevision: Int64,
        mutations: [SyncMutationDTO]
    ) {
        self.clientId = clientId
        self.sinceRevision = sinceRevision ?? clientLastSyncRevision
        self.clientLastSyncRevision = clientLastSyncRevision
        self.mutations = mutations
    }

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case sinceRevision = "since_revision"
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
    public let data: [String: AnyCodableValue]?
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
        self.data = payload
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case mutationId = "mutation_id"
        case entityName = "entity_name"
        case entityId = "entity_id"
        case operation
        case updatedAt = "updated_at"
        case data
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mutationId = try container.decode(UUID.self, forKey: .mutationId)
        self.entityName = try container.decode(String.self, forKey: .entityName)
        self.entityId = try container.decode(UUID.self, forKey: .entityId)
        self.operation = try container.decode(String.self, forKey: .operation)
        self.updatedAt = (try? container.decode(String.self, forKey: .updatedAt)) ?? ""
        let d = try? container.decodeIfPresent([String: AnyCodableValue].self, forKey: .data)
        let p = try? container.decodeIfPresent([String: AnyCodableValue].self, forKey: .payload)
        self.data = d ?? p
        self.payload = p ?? d
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mutationId, forKey: .mutationId)
        try container.encode(entityName, forKey: .entityName)
        try container.encode(entityId, forKey: .entityId)
        try container.encode(operation, forKey: .operation)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(payload, forKey: .payload)
    }
}

public struct SyncPushPullResponse: Codable {
    public let serverCurrentRevision: Int64
    public let latestRevision: Int64
    public let acknowledgedMutationIds: [UUID]
    public let appliedMutationIds: [UUID]
    public let rejectedMutations: [SyncRejectedMutationDTO]
    public let serverChanges: [SyncMutationDTO]?
    public let deltas: SyncDeltasContainerDTO?
    public let tombstones: [SyncTombstoneDTO]?

    public init(
        serverCurrentRevision: Int64,
        latestRevision: Int64 = 0,
        acknowledgedMutationIds: [UUID],
        appliedMutationIds: [UUID] = [],
        rejectedMutations: [SyncRejectedMutationDTO] = [],
        serverChanges: [SyncMutationDTO]? = nil,
        deltas: SyncDeltasContainerDTO? = nil,
        tombstones: [SyncTombstoneDTO]? = nil
    ) {
        self.serverCurrentRevision = serverCurrentRevision
        self.latestRevision = latestRevision == 0 ? serverCurrentRevision : latestRevision
        self.acknowledgedMutationIds = acknowledgedMutationIds
        self.appliedMutationIds = appliedMutationIds.isEmpty ? acknowledgedMutationIds : appliedMutationIds
        self.rejectedMutations = rejectedMutations
        self.serverChanges = serverChanges
        self.deltas = deltas
        self.tombstones = tombstones
    }

    enum CodingKeys: String, CodingKey {
        case serverCurrentRevision = "server_current_revision"
        case latestRevision = "latest_revision"
        case acknowledgedMutationIds = "acknowledged_mutation_ids"
        case appliedMutationIds = "applied_mutation_ids"
        case rejectedMutations = "rejected_mutations"
        case serverChanges = "server_changes"
        case deltas
        case tombstones
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let rev = try? container.decode(Int64.self, forKey: .serverCurrentRevision) {
            self.serverCurrentRevision = rev
            self.latestRevision = (try? container.decode(Int64.self, forKey: .latestRevision)) ?? rev
        } else if let rev = try? container.decode(Int64.self, forKey: .latestRevision) {
            self.serverCurrentRevision = rev
            self.latestRevision = rev
        } else {
            self.serverCurrentRevision = 0
            self.latestRevision = 0
        }

        if let acks = try? container.decode([UUID].self, forKey: .acknowledgedMutationIds) {
            self.acknowledgedMutationIds = acks
            self.appliedMutationIds = (try? container.decode([UUID].self, forKey: .appliedMutationIds)) ?? acks
        } else if let apps = try? container.decode([UUID].self, forKey: .appliedMutationIds) {
            self.acknowledgedMutationIds = apps
            self.appliedMutationIds = apps
        } else {
            self.acknowledgedMutationIds = []
            self.appliedMutationIds = []
        }

        self.rejectedMutations = (try? container.decodeIfPresent([SyncRejectedMutationDTO].self, forKey: .rejectedMutations)) ?? []
        self.serverChanges = try? container.decodeIfPresent([SyncMutationDTO].self, forKey: .serverChanges)
        self.deltas = try? container.decodeIfPresent(SyncDeltasContainerDTO.self, forKey: .deltas)
        self.tombstones = try? container.decodeIfPresent([SyncTombstoneDTO].self, forKey: .tombstones)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serverCurrentRevision, forKey: .serverCurrentRevision)
        try container.encode(latestRevision, forKey: .latestRevision)
        try container.encode(acknowledgedMutationIds, forKey: .acknowledgedMutationIds)
        try container.encode(appliedMutationIds, forKey: .appliedMutationIds)
        try container.encode(rejectedMutations, forKey: .rejectedMutations)
        try container.encodeIfPresent(serverChanges, forKey: .serverChanges)
        try container.encodeIfPresent(deltas, forKey: .deltas)
        try container.encodeIfPresent(tombstones, forKey: .tombstones)
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
        case bankAccountsAlt = "bankAccounts"
        case categories
        case financialTransactions = "financial_transactions"
        case financialTransactionsAlt = "financialTransactions"
        case investmentItems = "investment_items"
        case investmentItemsAlt = "investmentItems"
        case creditContracts = "credit_contracts"
        case creditContractsAlt = "creditContracts"
        case debtItems = "debt_items"
        case debtItemsAlt = "debtItems"
        case categoryProvisions = "category_provisions"
        case categoryProvisionsAlt = "categoryProvisions"
        case categoryQuotaRules = "category_quota_rules"
        case categoryQuotaRulesAlt = "categoryQuotaRules"
        case chatMessages = "chat_messages"
        case chatMessagesAlt = "chatMessages"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bankAccounts = (try? container.decodeIfPresent([BankAccount].self, forKey: .bankAccounts))
            ?? (try? container.decodeIfPresent([BankAccount].self, forKey: .bankAccountsAlt))
        self.categories = try? container.decodeIfPresent([CategoryItem].self, forKey: .categories)
        self.financialTransactions = (try? container.decodeIfPresent([FinancialTransaction].self, forKey: .financialTransactions))
            ?? (try? container.decodeIfPresent([FinancialTransaction].self, forKey: .financialTransactionsAlt))
        self.investmentItems = (try? container.decodeIfPresent([InvestmentItem].self, forKey: .investmentItems))
            ?? (try? container.decodeIfPresent([InvestmentItem].self, forKey: .investmentItemsAlt))
        self.creditContracts = (try? container.decodeIfPresent([CreditContract].self, forKey: .creditContracts))
            ?? (try? container.decodeIfPresent([CreditContract].self, forKey: .creditContractsAlt))
        self.debtItems = (try? container.decodeIfPresent([DebtItem].self, forKey: .debtItems))
            ?? (try? container.decodeIfPresent([DebtItem].self, forKey: .debtItemsAlt))
        self.categoryProvisions = (try? container.decodeIfPresent([CategoryProvision].self, forKey: .categoryProvisions))
            ?? (try? container.decodeIfPresent([CategoryProvision].self, forKey: .categoryProvisionsAlt))
        self.categoryQuotaRules = (try? container.decodeIfPresent([CategoryQuotaRule].self, forKey: .categoryQuotaRules))
            ?? (try? container.decodeIfPresent([CategoryQuotaRule].self, forKey: .categoryQuotaRulesAlt))
        self.chatMessages = (try? container.decodeIfPresent([ChatMessage].self, forKey: .chatMessages))
            ?? (try? container.decodeIfPresent([ChatMessage].self, forKey: .chatMessagesAlt))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(bankAccounts, forKey: .bankAccounts)
        try container.encodeIfPresent(categories, forKey: .categories)
        try container.encodeIfPresent(financialTransactions, forKey: .financialTransactions)
        try container.encodeIfPresent(investmentItems, forKey: .investmentItems)
        try container.encodeIfPresent(creditContracts, forKey: .creditContracts)
        try container.encodeIfPresent(debtItems, forKey: .debtItems)
        try container.encodeIfPresent(categoryProvisions, forKey: .categoryProvisions)
        try container.encodeIfPresent(categoryQuotaRules, forKey: .categoryQuotaRules)
        try container.encodeIfPresent(chatMessages, forKey: .chatMessages)
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
