// Sources/FinSense/Models/FinancialTransaction.swift
import Foundation

public enum TransactionRecurrenceMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case single
    case installment
    case repeated
    case recurring

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .single: return "Único"
        case .installment: return "Parcelado"
        case .repeated: return "Repetido"
        case .recurring: return "Recorrente"
        }
    }

    public static func availableModes(for type: TransactionType) -> [TransactionRecurrenceMode] {
        switch type {
        case .expense:
            return [.single, .installment, .repeated, .recurring]
        case .income:
            return [.single, .repeated, .recurring]
        }
    }
}

public enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable, Hashable {
    case weekly
    case biweekly
    case monthly
    case bimonthly
    case quarterly
    case semiannual
    case annual

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .weekly: return "Semanal"
        case .biweekly: return "Quinzenal"
        case .monthly: return "Mensal (Ex: Assinaturas, Água, Luz)"
        case .bimonthly: return "Bimestral"
        case .quarterly: return "Trimestral"
        case .semiannual: return "Semestral"
        case .annual: return "Anual"
        }
    }

    public var shortTitle: String {
        switch self {
        case .weekly: return "Semanal"
        case .biweekly: return "Quinzenal"
        case .monthly: return "Mensal"
        case .bimonthly: return "Bimestral"
        case .quarterly: return "Trimestral"
        case .semiannual: return "Semestral"
        case .annual: return "Anual"
        }
    }
}

public struct FinancialTransaction: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var details: String
    public var amount: Double
    public var date: Date
    public var type: TransactionType
    public var isPaid: Bool
    public var categoryId: UUID
    public var accountId: UUID
    public var attachmentPath: String?
    public var attachmentName: String?
    public var ignoreInConsolidated: Bool
    public var recurrenceMode: TransactionRecurrenceMode
    public var recurrenceFrequency: RecurrenceFrequency?
    public var isCanceledRecurringSeries: Bool?
    public var seriesGroupId: UUID?
    public var installmentIndex: Int?
    public var installmentTotal: Int?
    public var rawStatementLine: String?
    public var statementOccurrenceIndex: Int
    public var linkedContractId: UUID?
    public var linkedInvestmentId: UUID?
    public var linkedDebtId: UUID?
    public var linkedQuotaId: UUID?
    public var linkedQuotaUnits: Int?
    public var linkedQuotaYearMonthKey: Int?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        details: String = "",
        amount: Double,
        date: Date,
        type: TransactionType,
        isPaid: Bool = true,
        categoryId: UUID,
        accountId: UUID,
        attachmentPath: String? = nil,
        attachmentName: String? = nil,
        ignoreInConsolidated: Bool = false,
        recurrenceMode: TransactionRecurrenceMode = .single,
        recurrenceFrequency: RecurrenceFrequency? = nil,
        isCanceledRecurringSeries: Bool? = nil,
        seriesGroupId: UUID? = nil,
        installmentIndex: Int? = nil,
        installmentTotal: Int? = nil,
        rawStatementLine: String? = nil,
        statementOccurrenceIndex: Int = 1,
        linkedContractId: UUID? = nil,
        linkedInvestmentId: UUID? = nil,
        linkedDebtId: UUID? = nil,
        linkedQuotaId: UUID? = nil,
        linkedQuotaUnits: Int? = nil,
        linkedQuotaYearMonthKey: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.amount = abs(amount)
        self.date = date
        self.type = type
        self.isPaid = isPaid
        self.categoryId = categoryId
        self.accountId = accountId
        self.attachmentPath = attachmentPath
        self.attachmentName = attachmentName
        self.ignoreInConsolidated = ignoreInConsolidated
        self.recurrenceMode = recurrenceMode
        self.recurrenceFrequency = recurrenceFrequency
        self.isCanceledRecurringSeries = isCanceledRecurringSeries
        self.seriesGroupId = seriesGroupId
        self.installmentIndex = installmentIndex
        self.installmentTotal = installmentTotal
        self.rawStatementLine = rawStatementLine
        self.statementOccurrenceIndex = statementOccurrenceIndex
        self.linkedContractId = linkedContractId
        self.linkedInvestmentId = linkedInvestmentId
        self.linkedDebtId = linkedDebtId
        self.linkedQuotaId = linkedQuotaId
        self.linkedQuotaUnits = linkedQuotaUnits
        self.linkedQuotaYearMonthKey = linkedQuotaYearMonthKey
        self.createdAt = createdAt
    }

    public var signedAmount: Double {
        type == .income ? amount : -amount
    }

    public var installmentBadge: String? {
        if recurrenceMode == .recurring {
            return nil
        }
        if let idx = installmentIndex, let total = installmentTotal, total > 1 {
            return "\(idx)/\(total)"
        }
        return nil
    }

    public var isPartOfSeries: Bool {
        seriesGroupId != nil || recurrenceMode != .single
    }

    enum CodingKeys: String, CodingKey {
        case id, name, details, amount, date, type, isPaid, categoryId, accountId
        case attachmentPath, attachmentName, ignoreInConsolidated, recurrenceMode, recurrenceFrequency
        case isCanceledRecurringSeries, seriesGroupId, installmentIndex, installmentTotal
        case rawStatementLine, statementOccurrenceIndex, linkedContractId, linkedInvestmentId
        case linkedDebtId, linkedQuotaId, linkedQuotaUnits, linkedQuotaYearMonthKey, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        self.id = (try? c.decode(UUID.self, forKey: AnyKey("id"))) ?? UUID()
        self.name = (try? c.decodeIfPresent(String.self, forKey: AnyKey("name"))) ?? ""
        self.details = (try? c.decodeIfPresent(String.self, forKey: AnyKey("details"))) ?? ""
        self.amount = abs((try? c.decodeIfPresent(Double.self, forKey: AnyKey("amount"))) ?? 0.0)
        self.date = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("date"))) ?? Date()
        self.type = (try? c.decodeIfPresent(TransactionType.self, forKey: AnyKey("type"))) ?? .expense
        self.isPaid = (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("isPaid")))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("is_paid"))) ?? true

        if let cat = try? c.decode(UUID.self, forKey: AnyKey("categoryId")) { self.categoryId = cat }
        else if let cat = try? c.decode(UUID.self, forKey: AnyKey("category_id")) { self.categoryId = cat }
        else { self.categoryId = UUID() }

        if let acc = try? c.decode(UUID.self, forKey: AnyKey("accountId")) { self.accountId = acc }
        else if let acc = try? c.decode(UUID.self, forKey: AnyKey("account_id")) { self.accountId = acc }
        else { self.accountId = UUID() }

        self.attachmentPath = (try? c.decodeIfPresent(String.self, forKey: AnyKey("attachmentPath")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("attachment_path")))
        self.attachmentName = (try? c.decodeIfPresent(String.self, forKey: AnyKey("attachmentName")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("attachment_name")))
        self.ignoreInConsolidated = (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("ignoreInConsolidated")))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("ignore_in_consolidated"))) ?? false
        self.recurrenceMode = (try? c.decodeIfPresent(TransactionRecurrenceMode.self, forKey: AnyKey("recurrenceMode")))
            ?? (try? c.decodeIfPresent(TransactionRecurrenceMode.self, forKey: AnyKey("recurrence_mode"))) ?? .single
        self.recurrenceFrequency = (try? c.decodeIfPresent(RecurrenceFrequency.self, forKey: AnyKey("recurrenceFrequency")))
            ?? (try? c.decodeIfPresent(RecurrenceFrequency.self, forKey: AnyKey("recurrence_frequency")))
        self.isCanceledRecurringSeries = (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("isCanceledRecurringSeries")))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("is_canceled_recurring_series")))
        self.seriesGroupId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("seriesGroupId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("series_group_id")))
        self.installmentIndex = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("installmentIndex")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("installment_index")))
        self.installmentTotal = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("installmentTotal")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("installment_total")))
        self.rawStatementLine = (try? c.decodeIfPresent(String.self, forKey: AnyKey("rawStatementLine")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("raw_statement_line")))
        self.statementOccurrenceIndex = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("statementOccurrenceIndex")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("statement_occurrence_index"))) ?? 1
        self.linkedContractId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("linkedContractId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("linked_contract_id")))
        self.linkedInvestmentId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("linkedInvestmentId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("linked_investment_id")))
        self.linkedDebtId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("linkedDebtId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("linked_debt_id")))
        self.linkedQuotaId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("linkedQuotaId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("linked_quota_id")))
        self.linkedQuotaUnits = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("linkedQuotaUnits")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("linked_quota_units")))
        self.linkedQuotaYearMonthKey = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("linkedQuotaYearMonthKey")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("linked_quota_year_month_key")))
        self.createdAt = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("createdAt")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("created_at"))) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(details, forKey: .details)
        try c.encode(amount, forKey: .amount)
        try c.encode(date, forKey: .date)
        try c.encode(type, forKey: .type)
        try c.encode(isPaid, forKey: .isPaid)
        try c.encode(categoryId, forKey: .categoryId)
        try c.encode(accountId, forKey: .accountId)
        try c.encodeIfPresent(attachmentPath, forKey: .attachmentPath)
        try c.encodeIfPresent(attachmentName, forKey: .attachmentName)
        try c.encode(ignoreInConsolidated, forKey: .ignoreInConsolidated)
        try c.encode(recurrenceMode, forKey: .recurrenceMode)
        try c.encodeIfPresent(recurrenceFrequency, forKey: .recurrenceFrequency)
        try c.encodeIfPresent(isCanceledRecurringSeries, forKey: .isCanceledRecurringSeries)
        try c.encodeIfPresent(seriesGroupId, forKey: .seriesGroupId)
        try c.encodeIfPresent(installmentIndex, forKey: .installmentIndex)
        try c.encodeIfPresent(installmentTotal, forKey: .installmentTotal)
        try c.encodeIfPresent(rawStatementLine, forKey: .rawStatementLine)
        try c.encode(statementOccurrenceIndex, forKey: .statementOccurrenceIndex)
        try c.encodeIfPresent(linkedContractId, forKey: .linkedContractId)
        try c.encodeIfPresent(linkedInvestmentId, forKey: .linkedInvestmentId)
        try c.encodeIfPresent(linkedDebtId, forKey: .linkedDebtId)
        try c.encodeIfPresent(linkedQuotaId, forKey: .linkedQuotaId)
        try c.encodeIfPresent(linkedQuotaUnits, forKey: .linkedQuotaUnits)
        try c.encodeIfPresent(linkedQuotaYearMonthKey, forKey: .linkedQuotaYearMonthKey)
        try c.encode(createdAt, forKey: .createdAt)
    }
}
