// Sources/FinSense/Models/CreditContract.swift
import Foundation

public enum CreditContractKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case loan
    case financing

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .loan: return "Empréstimo"
        case .financing: return "Financiamento"
        }
    }
}

public enum LoanSubtype: String, Codable, CaseIterable, Identifiable, Hashable {
    case consignado = "Consignado"
    case pessoal = "Pessoal"
    case fgts = "Antecipação FGTS"
    case empresarial = "Empresarial"
    case refinanciamento = "Refinanciamento"
    case outros = "Outros"

    public var id: String { rawValue }

    public var discountFactorMultiplier: Double {
        switch self {
        case .consignado, .fgts:
            return 1.0
        case .pessoal, .refinanciamento:
            return 0.98
        case .empresarial, .outros:
            return 0.95
        }
    }
}

public enum FinancingSubtype: String, Codable, CaseIterable, Identifiable, Hashable {
    case imovel = "Imóvel"
    case carro = "Carro"

    public var id: String { rawValue }

    public var iconSymbol: String {
        switch self {
        case .imovel: return "house.fill"
        case .carro: return "car.fill"
        }
    }
}

public enum AmortizationSystem: String, Codable, CaseIterable, Identifiable, Hashable {
    case price = "PRICE (Parcelas Fixas)"
    case sac = "SAC (Amortização Constante)"

    public var id: String { rawValue }
}

public enum AmortizationRecalculationMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case reduceTerm = "Reduzir Prazo (Quantidade de Parcelas)"
    case reduceInstallment = "Reduzir Valor da Parcela"

    public var id: String { rawValue }
}

public struct AmortizationRecord: Identifiable, Codable, Hashable {
    public var id: UUID
    public var date: Date
    public var amountPaid: Double
    public var mode: AmortizationRecalculationMode
    public var previousInstallmentAmount: Double
    public var newInstallmentAmount: Double
    public var previousRemainingInstallments: Int
    public var newRemainingInstallments: Int
    public var accountId: UUID
    public var transactionId: UUID?
    public var notes: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        amountPaid: Double,
        mode: AmortizationRecalculationMode,
        previousInstallmentAmount: Double,
        newInstallmentAmount: Double,
        previousRemainingInstallments: Int,
        newRemainingInstallments: Int,
        accountId: UUID,
        transactionId: UUID? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.amountPaid = amountPaid
        self.mode = mode
        self.previousInstallmentAmount = previousInstallmentAmount
        self.newInstallmentAmount = newInstallmentAmount
        self.previousRemainingInstallments = previousRemainingInstallments
        self.newRemainingInstallments = newRemainingInstallments
        self.accountId = accountId
        self.transactionId = transactionId
        self.notes = notes
    }
}

public struct CreditContract: Identifiable, Codable, Hashable {
    public var id: UUID
    public var kind: CreditContractKind
    public var name: String
    public var contractNumber: String?
    public var loanSubtype: LoanSubtype?
    public var financingSubtype: FinancingSubtype?
    public var amortizationSystem: AmortizationSystem
    public var totalContractedAmount: Double
    public var outstandingBalance: Double?
    public var installmentAmount: Double
    public var billingDay: Int
    public var totalInstallments: Int
    public var monthlyInterestRate: Double // e.g. 1.65 means 1.65% a.m.
    public var startDate: Date?
    public var accountId: UUID
    public var categoryId: UUID
    public var pastInstallmentsElapsedAtCreation: Int
    public var extraAmortizedTotal: Double
    public var amortizationHistory: [AmortizationRecord]
    public var isSettled: Bool
    public var settledAmount: Double?
    public var settledDate: Date?
    public var settledAccountId: UUID?
    public var notes: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: CreditContractKind,
        name: String,
        contractNumber: String? = nil,
        loanSubtype: LoanSubtype? = .consignado,
        financingSubtype: FinancingSubtype? = nil,
        amortizationSystem: AmortizationSystem = .price,
        totalContractedAmount: Double,
        outstandingBalance: Double? = nil,
        installmentAmount: Double,
        billingDay: Int,
        totalInstallments: Int,
        monthlyInterestRate: Double,
        startDate: Date? = nil,
        accountId: UUID,
        categoryId: UUID,
        pastInstallmentsElapsedAtCreation: Int = 0,
        extraAmortizedTotal: Double = 0.0,
        amortizationHistory: [AmortizationRecord] = [],
        isSettled: Bool = false,
        settledAmount: Double? = nil,
        settledDate: Date? = nil,
        settledAccountId: UUID? = nil,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.contractNumber = contractNumber
        self.loanSubtype = loanSubtype
        self.financingSubtype = financingSubtype
        self.amortizationSystem = amortizationSystem
        self.totalContractedAmount = abs(totalContractedAmount)
        self.outstandingBalance = outstandingBalance.map { abs($0) }
        self.installmentAmount = abs(installmentAmount)
        self.billingDay = min(max(billingDay, 1), 31)
        self.totalInstallments = max(totalInstallments, 1)
        self.monthlyInterestRate = max(monthlyInterestRate, 0.0)
        self.startDate = startDate
        self.accountId = accountId
        self.categoryId = categoryId
        self.pastInstallmentsElapsedAtCreation = max(pastInstallmentsElapsedAtCreation, 0)
        self.extraAmortizedTotal = extraAmortizedTotal
        self.amortizationHistory = amortizationHistory
        self.isSettled = isSettled
        self.settledAmount = settledAmount
        self.settledDate = settledDate
        self.settledAccountId = settledAccountId
        self.notes = notes
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, name, contractNumber, loanSubtype, financingSubtype, amortizationSystem
        case totalContractedAmount, outstandingBalance, installmentAmount, billingDay
        case totalInstallments, monthlyInterestRate, startDate, accountId, categoryId
        case pastInstallmentsElapsedAtCreation, extraAmortizedTotal, amortizationHistory
        case isSettled, settledAmount, settledDate, settledAccountId, notes, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        self.id = (try? c.decode(UUID.self, forKey: AnyKey("id"))) ?? UUID()
        self.kind = (try? c.decode(CreditContractKind.self, forKey: AnyKey("kind"))) ?? .loan
        self.name = (try? c.decodeIfPresent(String.self, forKey: AnyKey("name"))) ?? ""
        self.contractNumber = (try? c.decodeIfPresent(String.self, forKey: AnyKey("contractNumber")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("contract_number")))
        self.loanSubtype = (try? c.decodeIfPresent(LoanSubtype.self, forKey: AnyKey("loanSubtype")))
            ?? (try? c.decodeIfPresent(LoanSubtype.self, forKey: AnyKey("loan_subtype")))
        self.financingSubtype = (try? c.decodeIfPresent(FinancingSubtype.self, forKey: AnyKey("financingSubtype")))
            ?? (try? c.decodeIfPresent(FinancingSubtype.self, forKey: AnyKey("financing_subtype")))
        self.amortizationSystem = (try? c.decodeIfPresent(AmortizationSystem.self, forKey: AnyKey("amortizationSystem")))
            ?? (try? c.decodeIfPresent(AmortizationSystem.self, forKey: AnyKey("amortization_system"))) ?? .price
        self.totalContractedAmount = abs((try? c.decodeIfPresent(Double.self, forKey: AnyKey("totalContractedAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("total_contracted_amount"))) ?? 0.0)
        self.outstandingBalance = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("outstandingBalance")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("outstanding_balance")))
        self.installmentAmount = abs((try? c.decodeIfPresent(Double.self, forKey: AnyKey("installmentAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("installment_amount"))) ?? 0.0)
        self.billingDay = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("billingDay")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("billing_day"))) ?? 1
        self.totalInstallments = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("totalInstallments")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("total_installments"))) ?? 1
        self.monthlyInterestRate = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("monthlyInterestRate")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("monthly_interest_rate"))) ?? 0.0
        self.startDate = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("startDate")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("start_date")))

        if let acc = try? c.decode(UUID.self, forKey: AnyKey("accountId")) { self.accountId = acc }
        else if let acc = try? c.decode(UUID.self, forKey: AnyKey("account_id")) { self.accountId = acc }
        else { self.accountId = UUID() }

        if let cat = try? c.decode(UUID.self, forKey: AnyKey("categoryId")) { self.categoryId = cat }
        else if let cat = try? c.decode(UUID.self, forKey: AnyKey("category_id")) { self.categoryId = cat }
        else { self.categoryId = UUID() }

        self.pastInstallmentsElapsedAtCreation = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("pastInstallmentsElapsedAtCreation")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("past_installments_elapsed_at_creation"))) ?? 0
        self.extraAmortizedTotal = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("extraAmortizedTotal")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("extra_amortized_total"))) ?? 0.0
        self.amortizationHistory = (try? c.decodeIfPresent([AmortizationRecord].self, forKey: AnyKey("amortizationHistory")))
            ?? (try? c.decodeIfPresent([AmortizationRecord].self, forKey: AnyKey("amortization_history"))) ?? []
        self.isSettled = (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("isSettled")))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("is_settled"))) ?? false
        self.settledAmount = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("settledAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("settled_amount")))
        self.settledDate = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("settledDate")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("settled_date")))
        self.settledAccountId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("settledAccountId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("settled_account_id")))
        self.notes = (try? c.decodeIfPresent(String.self, forKey: AnyKey("notes"))) ?? ""
        self.createdAt = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("createdAt")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("created_at"))) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(contractNumber, forKey: .contractNumber)
        try c.encodeIfPresent(loanSubtype, forKey: .loanSubtype)
        try c.encodeIfPresent(financingSubtype, forKey: .financingSubtype)
        try c.encode(amortizationSystem, forKey: .amortizationSystem)
        try c.encode(totalContractedAmount, forKey: .totalContractedAmount)
        try c.encodeIfPresent(outstandingBalance, forKey: .outstandingBalance)
        try c.encode(installmentAmount, forKey: .installmentAmount)
        try c.encode(billingDay, forKey: .billingDay)
        try c.encode(totalInstallments, forKey: .totalInstallments)
        try c.encode(monthlyInterestRate, forKey: .monthlyInterestRate)
        try c.encodeIfPresent(startDate, forKey: .startDate)
        try c.encode(accountId, forKey: .accountId)
        try c.encode(categoryId, forKey: .categoryId)
        try c.encode(pastInstallmentsElapsedAtCreation, forKey: .pastInstallmentsElapsedAtCreation)
        try c.encode(extraAmortizedTotal, forKey: .extraAmortizedTotal)
        try c.encode(amortizationHistory, forKey: .amortizationHistory)
        try c.encode(isSettled, forKey: .isSettled)
        try c.encodeIfPresent(settledAmount, forKey: .settledAmount)
        try c.encodeIfPresent(settledDate, forKey: .settledDate)
        try c.encodeIfPresent(settledAccountId, forKey: .settledAccountId)
        try c.encode(notes, forKey: .notes)
        try c.encode(createdAt, forKey: .createdAt)
    }

    public var subtypeDisplayName: String {
        switch kind {
        case .loan:
            return loanSubtype?.rawValue ?? "Consignado"
        case .financing:
            return financingSubtype?.rawValue ?? "Imóvel"
        }
    }

    public var iconSymbol: String {
        switch kind {
        case .loan:
            switch loanSubtype ?? .consignado {
            case .consignado: return "person.badge.shield.checkmark.fill"
            case .pessoal: return "banknote.fill"
            case .fgts: return "building.2.crop.circle.fill"
            case .empresarial: return "briefcase.fill"
            case .refinanciamento: return "arrow.triangle.2.circlepath.circle.fill"
            case .outros: return "doc.text.fill"
            }
        case .financing:
            return (financingSubtype ?? .imovel).iconSymbol
        }
    }
}
