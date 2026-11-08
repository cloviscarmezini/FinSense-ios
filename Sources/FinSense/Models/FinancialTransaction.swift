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
}
