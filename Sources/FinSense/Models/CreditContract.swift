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
    public var effectiveAmortization: Double?
    public var previousBalance: Double?

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
        notes: String = "",
        effectiveAmortization: Double? = nil,
        previousBalance: Double? = nil
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
        self.effectiveAmortization = effectiveAmortization
        self.previousBalance = previousBalance
    }

    enum CodingKeys: String, CodingKey {
        case id, date, amountPaid, mode, previousInstallmentAmount, newInstallmentAmount
        case previousRemainingInstallments, newRemainingInstallments, accountId, transactionId, notes
        case effectiveAmortization, previousBalance
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        self.id = (try? c.decode(UUID.self, forKey: AnyKey("id"))) ?? UUID()
        self.date = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("date"))) ?? Date()
        self.amountPaid = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("amountPaid")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("amount_paid"))) ?? 0.0
        self.mode = (try? c.decodeIfPresent(AmortizationRecalculationMode.self, forKey: AnyKey("mode"))) ?? .reduceTerm
        self.previousInstallmentAmount = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("previousInstallmentAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("previous_installment_amount"))) ?? 0.0
        self.newInstallmentAmount = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("newInstallmentAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("new_installment_amount"))) ?? 0.0
        self.previousRemainingInstallments = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("previousRemainingInstallments")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("previous_remaining_installments"))) ?? 0
        self.newRemainingInstallments = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("newRemainingInstallments")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("new_remaining_installments"))) ?? 0

        if let acc = try? c.decode(UUID.self, forKey: AnyKey("accountId")) { self.accountId = acc }
        else if let acc = try? c.decode(UUID.self, forKey: AnyKey("account_id")) { self.accountId = acc }
        else { self.accountId = UUID() }

        self.transactionId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("transactionId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("transaction_id")))
        self.notes = (try? c.decodeIfPresent(String.self, forKey: AnyKey("notes"))) ?? ""
        self.effectiveAmortization = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("effectiveAmortization")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("effective_amortization")))
        self.previousBalance = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("previousBalance")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("previous_balance")))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(amountPaid, forKey: .amountPaid)
        try c.encode(mode, forKey: .mode)
        try c.encode(previousInstallmentAmount, forKey: .previousInstallmentAmount)
        try c.encode(newInstallmentAmount, forKey: .newInstallmentAmount)
        try c.encode(previousRemainingInstallments, forKey: .previousRemainingInstallments)
        try c.encode(newRemainingInstallments, forKey: .newRemainingInstallments)
        try c.encode(accountId, forKey: .accountId)
        try c.encodeIfPresent(transactionId, forKey: .transactionId)
        try c.encode(notes, forKey: .notes)
        try c.encodeIfPresent(effectiveAmortization, forKey: .effectiveAmortization)
        try c.encodeIfPresent(previousBalance, forKey: .previousBalance)
    }
}

/// Métricas de Acompanhamento e Conquista de Progresso do Contrato de Crédito.
/// Adota o conceito de Prazo Original Imutável como régua mestra de progresso,
/// discriminando o avanço natural no fluxo das parcelas pagas da aceleração conquistada por amortizações extraordinárias.
public struct ContractProgressMetrics: Hashable, Identifiable {
    public var id: UUID

    /// Prazo Original Contratado imutável (Base total invariável = 100% da régua do tempo)
    public let originalTotalInstallments: Int

    /// Parcelas quitadas mês a mês no fluxo regular ao longo do tempo
    public let paidInFlowCount: Int

    /// Parcelas futuras que ainda restam ser pagas no cenário atual
    public let remainingCount: Int

    /// Parcelas eliminadas antecipadamente por amortizações extraordinárias
    public let eliminatedByAmortizationCount: Int

    /// Total de meses superados (pagos no fluxo + eliminados por amortização)
    public let totalOvercomeMonths: Int

    /// Percentual de conclusão global em relação ao plano original (0.0 a 1.0)
    public let globalCompletionPercentage: Double

    /// Proporção do progresso natural (0.0 a 1.0)
    public let naturalProgressRatio: Double

    /// Proporção da aceleração por amortização (0.0 a 1.0)
    public let amortizationAccelerationRatio: Double

    /// Proporção da dívida futura restante (0.0 a 1.0)
    public let remainingRatio: Double

    /// Anos de vida financeira poupados
    public let savedYears: Int

    /// Meses residuais poupados
    public let savedRemainingMonths: Int

    /// Texto traduzido do tempo de vida financeira recuperado (anos e meses)
    public var savedTimeString: String {
        if savedYears > 0 && savedRemainingMonths > 0 {
            return "\(savedYears) ano\(savedYears > 1 ? "s" : "") e \(savedRemainingMonths) m\(savedRemainingMonths > 1 ? "eses" : "ês")"
        } else if savedYears > 0 {
            return "\(savedYears) ano\(savedYears > 1 ? "s" : "")"
        } else {
            return "\(savedRemainingMonths) m\(savedRemainingMonths > 1 ? "eses" : "ês")"
        }
    }

    /// Novo Prazo Total Recalculado (parcelas pagas no fluxo + parcelas restantes a pagar)
    public var newRecalculatedTotalInstallments: Int {
        paidInFlowCount + remainingCount
    }

    /// Percentual de andamento do plano atual no cronograma vigente (0.0 a 1.0)
    public var currentPlanCompletionPercentage: Double {
        let total = newRecalculatedTotalInstallments
        return total > 0 ? Double(paidInFlowCount) / Double(total) : 1.0
    }

    /// Formatação amigável de total de meses e anos equivalentes (ex.: "360 meses (30 anos)" ou "251 meses (~21 anos)")
    public static func formatMonthsAndYears(_ months: Int) -> String {
        guard months > 0 else { return "0 meses" }
        if months % 12 == 0 {
            let y = months / 12
            return "\(months) meses (\(y) ano\(y > 1 ? "s" : ""))"
        } else {
            let years = Double(months) / 12.0
            let roundedYears = Int(round(years))
            if roundedYears > 0 {
                return "\(months) meses (~\(roundedYears) ano\(roundedYears > 1 ? "s" : ""))"
            } else {
                return "\(months) m\(months > 1 ? "eses" : "ês")"
            }
        }
    }

    /// Prazo Original Contratado formatado em meses e anos
    public var originalMonthsFormatted: String {
        Self.formatMonthsAndYears(originalTotalInstallments)
    }

    /// Novo Prazo Recalculado formatado em meses e anos
    public var newRecalculatedMonthsFormatted: String {
        Self.formatMonthsAndYears(newRecalculatedTotalInstallments)
    }

    public init(
        id: UUID = UUID(),
        originalTotalInstallments: Int,
        paidInFlowCount: Int,
        remainingCount: Int,
        isSettled: Bool = false
    ) {
        self.id = id
        let original = max(originalTotalInstallments, 1)
        self.originalTotalInstallments = original

        if isSettled || remainingCount <= 0 {
            let paid = min(paidInFlowCount, original)
            let eliminated = max(0, original - paid)
            self.paidInFlowCount = paid
            self.remainingCount = 0
            self.eliminatedByAmortizationCount = eliminated
            self.totalOvercomeMonths = original
            self.globalCompletionPercentage = 1.0
            self.naturalProgressRatio = Double(paid) / Double(original)
            self.amortizationAccelerationRatio = Double(eliminated) / Double(original)
            self.remainingRatio = 0.0
            self.savedYears = eliminated / 12
            self.savedRemainingMonths = eliminated % 12
        } else {
            let paid = min(paidInFlowCount, original)
            let rem = min(remainingCount, max(0, original - paid))
            let eliminated = max(0, original - (paid + rem))
            let overcome = min(paid + eliminated, original)
            self.paidInFlowCount = paid
            self.remainingCount = rem
            self.eliminatedByAmortizationCount = eliminated
            self.totalOvercomeMonths = overcome
            self.globalCompletionPercentage = Double(overcome) / Double(original)
            self.naturalProgressRatio = Double(paid) / Double(original)
            self.amortizationAccelerationRatio = Double(eliminated) / Double(original)
            self.remainingRatio = Double(rem) / Double(original)
            self.savedYears = eliminated / 12
            self.savedRemainingMonths = eliminated % 12
        }
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
    public var originalTotalInstallments: Int?
    public var monthlyInterestRate: Double // e.g., 1.65 means 1.65% a.m.
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

    // Componentes de Financiamento Imobiliário (SFH/SFI - Padrão CAIXA)
    public var annualNominalInterestRate: Double?
    public var indexationRate: FinancingIndexation?
    public var adminFee: Double?
    public var insuranceFee: Double?
    public var baseInstallmentAmount: Double?
    public var financingDetails: FinancingModel?
    public var loanDetails: LoanModel?

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
        originalTotalInstallments: Int? = nil,
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
        createdAt: Date = Date(),
        annualNominalInterestRate: Double? = nil,
        indexationRate: FinancingIndexation? = nil,
        adminFee: Double? = nil,
        insuranceFee: Double? = nil,
        baseInstallmentAmount: Double? = nil,
        financingDetails: FinancingModel? = nil,
        loanDetails: LoanModel? = nil
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
        self.originalTotalInstallments = originalTotalInstallments ?? totalInstallments
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

        self.annualNominalInterestRate = annualNominalInterestRate
        self.indexationRate = indexationRate
        self.adminFee = adminFee
        self.insuranceFee = insuranceFee
        self.baseInstallmentAmount = baseInstallmentAmount
        self.financingDetails = financingDetails
        self.loanDetails = loanDetails

        if kind == .financing && self.financingDetails == nil {
            let effAnnual = annualNominalInterestRate ?? (monthlyInterestRate > 0 ? monthlyInterestRate * 12.0 : 8.51)
            let effAdmin = adminFee ?? 25.0
            let effInsurance = insuranceFee ?? 0.0
            let remaining = max(totalInstallments - pastInstallmentsElapsedAtCreation, 0)
            self.financingDetails = FinancingModel(
                id: id,
                balance: outstandingBalance ?? totalContractedAmount,
                annualNominalInterestRate: effAnnual,
                amortizationSystem: amortizationSystem,
                indexationRate: indexationRate ?? .tr,
                adminFee: effAdmin,
                insuranceFee: effInsurance,
                totalInstallments: totalInstallments,
                remainingInstallments: remaining,
                totalInstallmentAmount: installmentAmount,
                lastBillingDate: startDate
            )
        }

        if kind == .loan && self.loanDetails == nil {
            let remaining = max(totalInstallments - pastInstallmentsElapsedAtCreation, 0)
            let effBalance: Double
            if let explicit = outstandingBalance {
                effBalance = explicit
            } else if pastInstallmentsElapsedAtCreation > 0 {
                effBalance = LoanModel.calculatePresentValue(installment: installmentAmount, monthlyRate: monthlyInterestRate, remaining: remaining)
            } else {
                effBalance = totalContractedAmount
            }
            let type: LoanType = (loanSubtype == .consignado) ? .payrollDeductible : .personal
            self.loanDetails = LoanModel(
                id: id,
                balance: effBalance,
                monthlyInterestRate: monthlyInterestRate,
                installmentValue: installmentAmount,
                remainingInstallments: remaining,
                totalInstallments: totalInstallments,
                loanType: type,
                startDate: startDate,
                lastBillingDate: startDate,
                notes: notes
            )
        }
    }

    /// Taxa de Juros Nominal Anual efetiva (% a.a.)
    public var effectiveAnnualNominalRate: Double {
        if let annual = annualNominalInterestRate, annual > 0 {
            return annual
        }
        if let fin = financingDetails, fin.annualNominalInterestRate > 0 {
            return fin.annualNominalInterestRate
        }
        return monthlyInterestRate * 12.0
    }

    /// Taxa de juros mensal nominal em decimal calculada dinamicamente: annualRate / 12 / 100
    public var effectiveMonthlyNominalRateDecimal: Double {
        (effectiveAnnualNominalRate / 12.0) / 100.0
    }

    /// Taxa de administração mensal efetiva
    public var effectiveAdminFee: Double {
        adminFee ?? financingDetails?.adminFee ?? (kind == .financing ? 25.0 : 0.0)
    }

    /// Valor dos seguros mensais MIP/DFI efetivos
    public var effectiveInsuranceFee: Double {
        insuranceFee ?? financingDetails?.insuranceFee ?? 0.0
    }

    /// Parcela Base Price (Amortização + Juros)
    public var effectiveBaseInstallmentPrice: Double {
        if let base = baseInstallmentAmount, base > 0 {
            return base
        }
        if let fin = financingDetails, fin.baseInstallmentPrice > 0 {
            return fin.baseInstallmentPrice
        }
        if kind == .financing {
            return max(0.0, installmentAmount - effectiveInsuranceFee - effectiveAdminFee)
        }
        return installmentAmount
    }

    /// Retorna ou gera o modelo especializado de financiamento
    public var effectiveFinancingModel: FinancingModel? {
        if let fin = financingDetails { return fin }
        guard kind == .financing else { return nil }
        let remaining = max(totalInstallments - pastInstallmentsElapsedAtCreation, 0)
        return FinancingModel(
            id: id,
            balance: outstandingBalance ?? totalContractedAmount,
            annualNominalInterestRate: effectiveAnnualNominalRate,
            amortizationSystem: amortizationSystem,
            indexationRate: indexationRate ?? .tr,
            adminFee: effectiveAdminFee,
            insuranceFee: effectiveInsuranceFee,
            totalInstallments: totalInstallments,
            remainingInstallments: remaining,
            totalInstallmentAmount: installmentAmount,
            lastBillingDate: startDate
        )
    }

    /// Retorna ou gera o modelo especializado de empréstimo (Tabela Price pura)
    public var effectiveLoanModel: LoanModel? {
        if let loan = loanDetails { return loan }
        guard kind == .loan else { return nil }
        let remaining = max(totalInstallments - pastInstallmentsElapsedAtCreation, 0)
        let effBalance: Double
        if let explicit = outstandingBalance {
            effBalance = explicit
        } else if pastInstallmentsElapsedAtCreation > 0 {
            effBalance = LoanModel.calculatePresentValue(installment: installmentAmount, monthlyRate: monthlyInterestRate, remaining: remaining)
        } else {
            effBalance = totalContractedAmount
        }
        let type: LoanType = (loanSubtype == .consignado) ? .payrollDeductible : .personal
        return LoanModel(
            id: id,
            balance: effBalance,
            monthlyInterestRate: monthlyInterestRate,
            installmentValue: installmentAmount,
            remainingInstallments: remaining,
            totalInstallments: totalInstallments,
            loanType: type,
            startDate: startDate,
            lastBillingDate: startDate,
            notes: notes
        )
    }

    /// Prazo Original Contratado imutável
    public var effectiveOriginalTotalInstallments: Int {
        if let original = originalTotalInstallments, original > 0 {
            return max(original, totalInstallments)
        }
        if let finTotal = financingDetails?.totalInstallments, finTotal > 0 {
            return max(finTotal, totalInstallments)
        }
        if let loanTotal = loanDetails?.totalInstallments, loanTotal > 0 {
            return max(loanTotal, totalInstallments)
        }
        let eliminatedInHistory = amortizationHistory
            .filter { $0.mode == .reduceTerm }
            .reduce(0) { $0 + max(0, $1.previousRemainingInstallments - $1.newRemainingInstallments) }
        return max(totalInstallments + eliminatedInHistory, totalInstallments)
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, name, contractNumber, loanSubtype, financingSubtype, amortizationSystem
        case totalContractedAmount, outstandingBalance, installmentAmount, billingDay
        case totalInstallments, originalTotalInstallments, monthlyInterestRate, startDate, accountId, categoryId
        case pastInstallmentsElapsedAtCreation, extraAmortizedTotal, amortizationHistory
        case isSettled, settledAmount, settledDate, settledAccountId, notes, createdAt
        case annualNominalInterestRate, indexationRate, adminFee, insuranceFee
        case baseInstallmentAmount, financingDetails, loanDetails
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
        self.originalTotalInstallments = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("originalTotalInstallments")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("original_total_installments")))
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

        self.annualNominalInterestRate = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("annualNominalInterestRate")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("annual_nominal_interest_rate")))
        self.indexationRate = (try? c.decodeIfPresent(FinancingIndexation.self, forKey: AnyKey("indexationRate")))
            ?? (try? c.decodeIfPresent(FinancingIndexation.self, forKey: AnyKey("indexation_rate")))
        self.adminFee = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("adminFee")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("admin_fee")))
        self.insuranceFee = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("insuranceFee")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("insurance_fee")))
        self.baseInstallmentAmount = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("baseInstallmentAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("base_installment_amount")))
        self.financingDetails = (try? c.decodeIfPresent(FinancingModel.self, forKey: AnyKey("financingDetails")))
            ?? (try? c.decodeIfPresent(FinancingModel.self, forKey: AnyKey("financing_details")))
        self.loanDetails = (try? c.decodeIfPresent(LoanModel.self, forKey: AnyKey("loanDetails")))
            ?? (try? c.decodeIfPresent(LoanModel.self, forKey: AnyKey("loan_details")))
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
        try c.encodeIfPresent(originalTotalInstallments, forKey: .originalTotalInstallments)
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
        try c.encodeIfPresent(annualNominalInterestRate, forKey: .annualNominalInterestRate)
        try c.encodeIfPresent(indexationRate, forKey: .indexationRate)
        try c.encodeIfPresent(adminFee, forKey: .adminFee)
        try c.encodeIfPresent(insuranceFee, forKey: .insuranceFee)
        try c.encodeIfPresent(baseInstallmentAmount, forKey: .baseInstallmentAmount)
        try c.encodeIfPresent(financingDetails, forKey: .financingDetails)
        try c.encodeIfPresent(loanDetails, forKey: .loanDetails)
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
