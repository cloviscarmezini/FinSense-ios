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
