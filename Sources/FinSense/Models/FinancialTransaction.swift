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

    public var defaultInitialHorizonCount: Int {
        switch self {
        case .weekly: return 104
        case .biweekly: return 78
        case .monthly: return 60
        case .bimonthly: return 36
        case .quarterly: return 28
        case .semiannual: return 20
        case .annual: return 15
        }
    }

    public func nextDate(from baseDate: Date, occurrenceIndex: Int, calendar: Calendar = .current) -> Date {
        guard occurrenceIndex > 0 else { return baseDate }
        switch self {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7 * occurrenceIndex, to: baseDate) ?? baseDate
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14 * occurrenceIndex, to: baseDate) ?? baseDate
        case .monthly:
            return calendar.date(byAdding: .month, value: occurrenceIndex, to: baseDate) ?? baseDate
        case .bimonthly:
            return calendar.date(byAdding: .month, value: 2 * occurrenceIndex, to: baseDate) ?? baseDate
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3 * occurrenceIndex, to: baseDate) ?? baseDate
        case .semiannual:
            return calendar.date(byAdding: .month, value: 6 * occurrenceIndex, to: baseDate) ?? baseDate
        case .annual:
            return calendar.date(byAdding: .year, value: occurrenceIndex, to: baseDate) ?? baseDate
        }
    }
}

/// Identifica a origem relacional e de domínio de uma transação financeira para permitir rollback e reversão de estado.
public enum TransactionOrigin: String, Codable, CaseIterable, Identifiable, Hashable {
    case standard
    case financingAmortization
    case loanAmortization
    case loanPayoff
    case contractSettlement
    case plannedAmortization
    case investmentDeposit
    case investmentRedemption
    case debtPayment
    case quotaAllocation
    case internalTransfer
    case creditCardInvoicePayment
    case reimbursementReceipt

    public var id: String { rawValue }
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
    public var transactionOrigin: TransactionOrigin?
    public var linkedEntityID: UUID?
    public var baseInstallmentRegisteredAmount: Double?
    public var projectedInstallmentCorrectionAmount: Double?
    public var confirmedRealInterestCorrectionAmount: Double?
    public var creditCardId: UUID?
    public var creditCardInvoiceYearMonthKey: Int?
    public var creditCardInvoiceId: UUID?
    public var needsReview: Bool?
    public var sourceApp: String?
    public var isReimbursable: Bool?
    public var reimbursableDebtor: String?
    public var reimbursableAmount: Double?
    public var reimbursementExpectedDate: Date?
    public var reimbursementReceivedAmount: Double?
    public var isReimbursementSettled: Bool?
    public var linkedReimbursementTransactionId: UUID?
    public var currencyCode: String?
    public var exchangeRateToBRL: Double?
    public var createdAt: Date

    public var isCreditCardInvoicePayment: Bool {
        transactionOrigin == .creditCardInvoicePayment
    }

    public var isCreditCardExpense: Bool {
        creditCardId != nil && !isCreditCardInvoicePayment
    }

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
        transactionOrigin: TransactionOrigin? = nil,
        linkedEntityID: UUID? = nil,
        baseInstallmentRegisteredAmount: Double? = nil,
        projectedInstallmentCorrectionAmount: Double? = nil,
        confirmedRealInterestCorrectionAmount: Double? = nil,
        creditCardId: UUID? = nil,
        creditCardInvoiceYearMonthKey: Int? = nil,
        creditCardInvoiceId: UUID? = nil,
        needsReview: Bool? = nil,
        sourceApp: String? = nil,
        isReimbursable: Bool? = nil,
        reimbursableDebtor: String? = nil,
        reimbursableAmount: Double? = nil,
        reimbursementExpectedDate: Date? = nil,
        reimbursementReceivedAmount: Double? = nil,
        isReimbursementSettled: Bool? = nil,
        linkedReimbursementTransactionId: UUID? = nil,
        currencyCode: String? = nil,
        exchangeRateToBRL: Double? = nil,
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
        self.transactionOrigin = transactionOrigin
        self.linkedEntityID = linkedEntityID ?? linkedContractId ?? linkedInvestmentId ?? linkedDebtId ?? linkedQuotaId ?? creditCardInvoiceId
        self.baseInstallmentRegisteredAmount = baseInstallmentRegisteredAmount.map { abs($0) }
        self.projectedInstallmentCorrectionAmount = projectedInstallmentCorrectionAmount
        self.confirmedRealInterestCorrectionAmount = confirmedRealInterestCorrectionAmount
        self.creditCardId = creditCardId
        self.creditCardInvoiceYearMonthKey = creditCardInvoiceYearMonthKey
        self.creditCardInvoiceId = creditCardInvoiceId
        self.needsReview = needsReview
        self.sourceApp = sourceApp
        self.isReimbursable = isReimbursable
        self.reimbursableDebtor = reimbursableDebtor
        self.reimbursableAmount = reimbursableAmount
        self.reimbursementExpectedDate = reimbursementExpectedDate
        self.reimbursementReceivedAmount = reimbursementReceivedAmount
        self.isReimbursementSettled = isReimbursementSettled
        self.linkedReimbursementTransactionId = linkedReimbursementTransactionId
        self.currencyCode = currencyCode
        self.exchangeRateToBRL = exchangeRateToBRL
        self.createdAt = createdAt
    }

    /// Origem relacional efetiva da transação (explícita ou inferida dos vínculos de domínio)
    public var effectiveOrigin: TransactionOrigin {
        if let explicit = transactionOrigin { return explicit }
        if linkedDebtId != nil { return .debtPayment }
        if linkedInvestmentId != nil {
            return type == .income ? .investmentRedemption : .investmentDeposit
        }
        if linkedContractId != nil {
            if installmentIndex == nil {
                if name.localizedCaseInsensitiveContains("quitação") || name.localizedCaseInsensitiveContains("quitacao") {
                    return .contractSettlement
                }
                return .financingAmortization
            }
        }
        if linkedQuotaId != nil { return .quotaAllocation }
        return .standard
    }

    /// ID da entidade financeira vinculada (Contrato, Investimento ou Dívida)
    public var effectiveLinkedEntityID: UUID? {
        linkedEntityID ?? linkedContractId ?? linkedInvestmentId ?? linkedDebtId ?? linkedQuotaId
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
        case attachmentPath, attachmentName, ignoreInConsolidated, recurrenceMode
        case recurrenceFrequency, isCanceledRecurringSeries, seriesGroupId
        case installmentIndex, installmentTotal, rawStatementLine, statementOccurrenceIndex
        case linkedContractId, linkedInvestmentId, linkedDebtId, linkedQuotaId
        case linkedQuotaUnits, linkedQuotaYearMonthKey, transactionOrigin, linkedEntityID
        case baseInstallmentRegisteredAmount, projectedInstallmentCorrectionAmount, confirmedRealInterestCorrectionAmount
        case creditCardId, creditCardInvoiceYearMonthKey, creditCardInvoiceId
        case needsReview, sourceApp, isReimbursable, reimbursableDebtor, reimbursableAmount
        case reimbursementExpectedDate, reimbursementReceivedAmount, isReimbursementSettled
        case linkedReimbursementTransactionId, currencyCode, exchangeRateToBRL
        case createdAt
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
        self.transactionOrigin = (try? c.decodeIfPresent(TransactionOrigin.self, forKey: AnyKey("transactionOrigin")))
            ?? (try? c.decodeIfPresent(TransactionOrigin.self, forKey: AnyKey("transaction_origin")))
        self.linkedEntityID = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("linkedEntityID")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("linked_entity_id")))
            ?? linkedContractId ?? linkedInvestmentId ?? linkedDebtId ?? linkedQuotaId
        self.baseInstallmentRegisteredAmount = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("baseInstallmentRegisteredAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("base_installment_registered_amount")))
        self.projectedInstallmentCorrectionAmount = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("projectedInstallmentCorrectionAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("projected_installment_correction_amount")))
        self.confirmedRealInterestCorrectionAmount = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("confirmedRealInterestCorrectionAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("confirmed_real_interest_correction_amount")))
        self.creditCardId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("creditCardId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("credit_card_id")))
        self.creditCardInvoiceYearMonthKey = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("creditCardInvoiceYearMonthKey")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("credit_card_invoice_year_month_key")))
        self.creditCardInvoiceId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("creditCardInvoiceId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("credit_card_invoice_id")))
        self.needsReview = (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("needsReview")))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("needs_review")))
        self.sourceApp = (try? c.decodeIfPresent(String.self, forKey: AnyKey("sourceApp")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("source_app")))
        self.isReimbursable = (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("isReimbursable")))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("is_reimbursable")))
        self.reimbursableDebtor = (try? c.decodeIfPresent(String.self, forKey: AnyKey("reimbursableDebtor")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("reimbursable_debtor")))
        self.reimbursableAmount = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("reimbursableAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("reimbursable_amount")))
        self.reimbursementExpectedDate = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("reimbursementExpectedDate")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("reimbursement_expected_date")))
        self.reimbursementReceivedAmount = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("reimbursementReceivedAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("reimbursement_received_amount")))
        self.isReimbursementSettled = (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("isReimbursementSettled")))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("is_reimbursement_settled")))
        self.linkedReimbursementTransactionId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("linkedReimbursementTransactionId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("linked_reimbursement_transaction_id")))
        self.currencyCode = (try? c.decodeIfPresent(String.self, forKey: AnyKey("currencyCode")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("currency_code")))
        self.exchangeRateToBRL = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("exchangeRateToBRL")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("exchange_rate_to_brl")))
        self.createdAt = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("createdAt")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("created_at"))) ?? Date()
    }

    /// Identifica se a receita possui natureza extraordinária (ex: 13º salário, bônus, PLR, restituição de IR, rescisão).
    public var isExtraordinaryIncome: Bool {
        guard type == .income else { return false }
        let text = "\(name) \(details) \(rawStatementLine ?? "")"
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let keywords = [
            "13", "decimo terceiro", "bonus", "plr",
            "participacao nos lucros", "restituicao", "rescisao",
            "extraordinari", "heranca", "premio", "premiacao"
        ]
        return keywords.contains { text.contains($0) }
    }

    /// Identifica se a despesa é de natureza fixa / recorrente (assinaturas, financiamento, aluguel, condomínio, etc.)
    public var isFixedExpense: Bool {
        guard type == .expense else { return false }
        if recurrenceMode == .recurring { return true }
        if linkedContractId != nil { return true }
        let text = "\(name) \(details)"
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let keywords = ["fixa", "fixo", "recorrente", "assinatura", "aluguel", "condominio", "plano", "mensalidade", "prestacao", "parcela"]
        return keywords.contains { text.contains($0) }
    }

    /// Despesas de consumo variável / avulsas
    public var isVariableExpense: Bool {
        guard type == .expense else { return false }
        return !isFixedExpense
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
        try c.encodeIfPresent(transactionOrigin, forKey: .transactionOrigin)
        try c.encodeIfPresent(linkedEntityID, forKey: .linkedEntityID)
        try c.encodeIfPresent(baseInstallmentRegisteredAmount, forKey: .baseInstallmentRegisteredAmount)
        try c.encodeIfPresent(projectedInstallmentCorrectionAmount, forKey: .projectedInstallmentCorrectionAmount)
        try c.encodeIfPresent(confirmedRealInterestCorrectionAmount, forKey: .confirmedRealInterestCorrectionAmount)
        try c.encodeIfPresent(creditCardId, forKey: .creditCardId)
        try c.encodeIfPresent(creditCardInvoiceYearMonthKey, forKey: .creditCardInvoiceYearMonthKey)
        try c.encodeIfPresent(creditCardInvoiceId, forKey: .creditCardInvoiceId)
        try c.encodeIfPresent(needsReview, forKey: .needsReview)
        try c.encodeIfPresent(sourceApp, forKey: .sourceApp)
        try c.encodeIfPresent(isReimbursable, forKey: .isReimbursable)
        try c.encodeIfPresent(reimbursableDebtor, forKey: .reimbursableDebtor)
        try c.encodeIfPresent(reimbursableAmount, forKey: .reimbursableAmount)
        try c.encodeIfPresent(reimbursementExpectedDate, forKey: .reimbursementExpectedDate)
        try c.encodeIfPresent(reimbursementReceivedAmount, forKey: .reimbursementReceivedAmount)
        try c.encodeIfPresent(isReimbursementSettled, forKey: .isReimbursementSettled)
        try c.encodeIfPresent(linkedReimbursementTransactionId, forKey: .linkedReimbursementTransactionId)
        try c.encodeIfPresent(currencyCode, forKey: .currencyCode)
        try c.encodeIfPresent(exchangeRateToBRL, forKey: .exchangeRateToBRL)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Análise Cronológica Intramês (Vale de Caixa)

public struct DailyCashFlowPoint: Identifiable, Hashable, Sendable {
    public var id: Int { day }
    public let day: Int
    public let date: Date
    public let openingBalance: Double
    public let dayIncome: Double
    public let dayExpense: Double
    public let closingBalance: Double

    public var isNegative: Bool {
        closingBalance < -0.005
    }

    public init(
        day: Int,
        date: Date,
        openingBalance: Double,
        dayIncome: Double,
        dayExpense: Double,
        closingBalance: Double
    ) {
        self.day = day
        self.date = date
        self.openingBalance = openingBalance
        self.dayIncome = dayIncome
        self.dayExpense = dayExpense
        self.closingBalance = closingBalance
    }
}

public enum IntraMonthAlertLevel: String, Codable, Hashable, Sendable {
    case none
    case possibleRisk
    case confirmedDeficit
}

public struct IntraMonthDeficitOccasion: Identifiable, Hashable, Sendable {
    public var id: UUID { transactionId }
    public let transactionId: UUID
    public let date: Date
    public let day: Int
    public let month: Int
    public let deficitAmount: Double
    public let resultingBalance: Double
    public let isRecoveredLater: Bool
    public let recoveredDate: Date?
    public let isResolvedByToday: Bool

    public var dayMonthLabel: String {
        String(format: "%02d/%02d", day, month)
    }

    public init(
        transactionId: UUID,
        date: Date,
        day: Int,
        month: Int,
        deficitAmount: Double,
        resultingBalance: Double,
        isRecoveredLater: Bool,
        recoveredDate: Date?,
        isResolvedByToday: Bool
    ) {
        self.transactionId = transactionId
        self.date = date
        self.day = day
        self.month = month
        self.deficitAmount = deficitAmount
        self.resultingBalance = resultingBalance
        self.isRecoveredLater = isRecoveredLater
        self.recoveredDate = recoveredDate
        self.isResolvedByToday = isResolvedByToday
    }
}

public struct IntraMonthCashFlowAnalysis: Hashable, Sendable {
    public let monthStart: Date
    public let monthEnd: Date
    public let openingBalance: Double
    public let closingBalance: Double
    public let currentMonthProvisionsTotal: Double
    public let closingBalanceWithProvisions: Double
    public let minimumBalance: Double
    public let minimumBalanceDate: Date?
    public let minimumBalanceDay: Int?
    public let alertLevel: IntraMonthAlertLevel
    public let hasIntraMonthDeficit: Bool
    public let isTemporaryTrough: Bool
    public let riskStartDay: Int?
    public let riskEndDay: Int?
    public let cutoffTransactionId: UUID?
    public let recoveryTransactionId: UUID?
    public let cutoffTransactionIds: Set<UUID>
    public let deepeningDeficitTransactionIds: Set<UUID>
    public let recoveryTransactionIds: Set<UUID>
    public let deficitZoneTransactionIds: Set<UUID>
    public let deficitOccasions: [IntraMonthDeficitOccasion]
    public let alertableOccasions: [IntraMonthDeficitOccasion]
    public let runningBalanceByTransactionId: [UUID: Double]
    public let dailyPoints: [DailyCashFlowPoint]

    public var shortfallAmount: Double {
        if !alertableOccasions.isEmpty {
            return max(0.0, alertableOccasions.reduce(0.0) { $0 + $1.deficitAmount })
        }
        if alertLevel == .possibleRisk {
            return max(0.0, -closingBalanceWithProvisions)
        }
        return max(0.0, -minimumBalance)
    }

    public var alertSummaryText: String? {
        switch alertLevel {
        case .none:
            return nil
        case .possibleRisk:
            let missingStr = AppFormatters.currency(max(0.0, -closingBalanceWithProvisions))
            return "Possibilidade de caixa negativo (até \(missingStr) c/ previsões)"
        case .confirmedDeficit:
            if alertableOccasions.isEmpty {
                let missingStr = AppFormatters.currency(max(0.0, -minimumBalance))
                if let start = riskStartDay, let end = riskEndDay {
                    return start == end
                        ? "Faltarão \(missingStr) no dia \(start)"
                        : "Faltarão \(missingStr) entre os dias \(start) e \(end)"
                }
                return "Faltarão \(missingStr) durante o mês"
            }
            let parts = alertableOccasions.map { occ in
                "\(AppFormatters.currency(occ.deficitAmount)) no dia \(occ.dayMonthLabel)"
            }
            if parts.count == 1 {
                return "Faltarão \(parts[0])"
            } else if parts.count == 2 {
                return "Faltarão \(parts[0]) e \(parts[1])"
            } else {
                let head = parts.dropLast().joined(separator: ", ")
                return "Faltarão \(head) e \(parts.last!)"
            }
        }
    }

    public init(
        monthStart: Date,
        monthEnd: Date,
        openingBalance: Double,
        closingBalance: Double,
        currentMonthProvisionsTotal: Double = 0.0,
        closingBalanceWithProvisions: Double? = nil,
        minimumBalance: Double,
        minimumBalanceDate: Date?,
        minimumBalanceDay: Int?,
        alertLevel: IntraMonthAlertLevel? = nil,
        hasIntraMonthDeficit: Bool,
        isTemporaryTrough: Bool,
        riskStartDay: Int?,
        riskEndDay: Int?,
        cutoffTransactionId: UUID?,
        recoveryTransactionId: UUID?,
        cutoffTransactionIds: Set<UUID> = [],
        deepeningDeficitTransactionIds: Set<UUID> = [],
        recoveryTransactionIds: Set<UUID> = [],
        deficitZoneTransactionIds: Set<UUID>,
        deficitOccasions: [IntraMonthDeficitOccasion] = [],
        alertableOccasions: [IntraMonthDeficitOccasion] = [],
        runningBalanceByTransactionId: [UUID: Double],
        dailyPoints: [DailyCashFlowPoint]
    ) {
        self.monthStart = monthStart
        self.monthEnd = monthEnd
        self.openingBalance = openingBalance
        self.closingBalance = closingBalance
        self.currentMonthProvisionsTotal = currentMonthProvisionsTotal
        self.closingBalanceWithProvisions = closingBalanceWithProvisions ?? (closingBalance - currentMonthProvisionsTotal)
        self.minimumBalance = minimumBalance
        self.minimumBalanceDate = minimumBalanceDate
        self.minimumBalanceDay = minimumBalanceDay
        self.alertLevel = alertLevel ?? (hasIntraMonthDeficit ? .confirmedDeficit : .none)
        self.hasIntraMonthDeficit = hasIntraMonthDeficit
        self.isTemporaryTrough = isTemporaryTrough
        self.riskStartDay = riskStartDay
        self.riskEndDay = riskEndDay
        self.cutoffTransactionId = cutoffTransactionId
        self.recoveryTransactionId = recoveryTransactionId
        self.cutoffTransactionIds = cutoffTransactionIds
        self.deepeningDeficitTransactionIds = deepeningDeficitTransactionIds
        self.recoveryTransactionIds = recoveryTransactionIds
        self.deficitZoneTransactionIds = deficitZoneTransactionIds
        self.deficitOccasions = deficitOccasions
        self.alertableOccasions = alertableOccasions
        self.runningBalanceByTransactionId = runningBalanceByTransactionId
        self.dailyPoints = dailyPoints
    }
}
