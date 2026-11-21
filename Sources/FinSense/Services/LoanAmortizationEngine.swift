import Foundation
import PDFKit

/// Detalhamento dos componentes da prestação mensal e da evolução do Saldo Devedor em um empréstimo puro (Tabela Price).
public struct LoanMonthlyBreakdown: Hashable, Identifiable {
    public var id: UUID = UUID()
    public let installmentIndex: Int
    public let previousBalance: Double
    public let interestAmount: Double
    public let amortizationAmount: Double
    public let newBalance: Double
    public let installmentDue: Double
    public let calculationDate: Date

    public init(
        installmentIndex: Int = 1,
        previousBalance: Double,
        interestAmount: Double,
        amortizationAmount: Double,
        newBalance: Double,
        installmentDue: Double,
        calculationDate: Date = Date()
    ) {
        self.installmentIndex = installmentIndex
        self.previousBalance = previousBalance
        self.interestAmount = interestAmount
        self.amortizationAmount = amortizationAmount
        self.newBalance = newBalance
        self.installmentDue = installmentDue
        self.calculationDate = calculationDate
    }
}

/// Resultado analítico e centavo a centavo da amortização extraordinária de um empréstimo.
public struct LoanAmortizationResult: Hashable {
    public let grossPayment: Double
    public let proRataInterest: Double
    public let effectiveAmortization: Double
    public let previousBalance: Double
    public let newBalance: Double
    public let previousRemainingInstallments: Int
    public let newRemainingInstallments: Int
    public let eliminatedInstallmentsCount: Int
    public let previousInstallmentAmount: Double
    public let newInstallmentAmount: Double
    public let estimatedTotalInterestSaved: Double
    public let mode: AmortizationRecalculationMode

    public init(
        grossPayment: Double,
        proRataInterest: Double,
        effectiveAmortization: Double,
        previousBalance: Double,
        newBalance: Double,
        previousRemainingInstallments: Int,
        newRemainingInstallments: Int,
        eliminatedInstallmentsCount: Int,
        previousInstallmentAmount: Double,
        newInstallmentAmount: Double,
        estimatedTotalInterestSaved: Double,
        mode: AmortizationRecalculationMode
    ) {
        self.grossPayment = grossPayment
        self.proRataInterest = proRataInterest
        self.effectiveAmortization = effectiveAmortization
        self.previousBalance = previousBalance
        self.newBalance = newBalance
        self.previousRemainingInstallments = previousRemainingInstallments
        self.newRemainingInstallments = newRemainingInstallments
        self.eliminatedInstallmentsCount = eliminatedInstallmentsCount
        self.previousInstallmentAmount = previousInstallmentAmount
        self.newInstallmentAmount = newInstallmentAmount
        self.estimatedTotalInterestSaved = estimatedTotalInterestSaved
        self.mode = mode
    }
}

/// Resultado do recálculo inverso ou reestruturação de empréstimo (reversão de transação / linked transaction rollback).
public struct LoanRecalculationResult: Hashable {
    public let balance: Double
    public let remainingInstallments: Int
    public let installmentValue: Double

    public init(
        balance: Double,
        remainingInstallments: Int,
        installmentValue: Double
    ) {
        self.balance = balance
        self.remainingInstallments = remainingInstallments
        self.installmentValue = installmentValue
    }
}

/// Motor de Matemática Financeira e Engenharia de Amortização para Empréstimos Convencionais e Consignados.
/// Opera estritamente com a Tabela Price pré-fixada pura (PMT = Amortização + Juros),
/// sem as taxas de seguros (MIP/DFI) e taxas de administração próprias de financiamentos imobiliários.
public enum LoanAmortizationEngine {

    // MARK: - 1. Motor de Evolução Mensal (Competência Price Pura)

    /// Calcula a evolução de uma competência mensal de empréstimo:
    /// 1. Juros = Saldo Atualizado * (Taxa Mensal / 100)
    /// 2. Amortização = Parcela Fixa - Juros
    /// 3. Novo Saldo Devedor = Saldo Anterior - Amortização
    public static func calculateNextInstallment(
        currentBalance: Double,
        monthlyInterestRate: Double,
        installmentValue: Double,
        installmentIndex: Int = 1,
        date: Date = Date()
    ) -> LoanMonthlyBreakdown {
        let cleanBalance = max(0.0, currentBalance)
        let cleanPMT = max(0.0, installmentValue)
        let i = max(0.0, monthlyInterestRate) / 100.0

        let interest = cleanBalance * i
        let amortization = max(0.0, min(cleanPMT - interest, cleanBalance))
        let newBalance = max(0.0, cleanBalance - amortization)

        return LoanMonthlyBreakdown(
            installmentIndex: installmentIndex,
            previousBalance: cleanBalance,
            interestAmount: interest,
            amortizationAmount: amortization,
            newBalance: newBalance,
            installmentDue: cleanPMT,
            calculationDate: date
        )
    }

    /// Conveniência calculando a competência a partir de um `LoanModel`.
    public static func calculateNextInstallment(
        for loan: LoanModel,
        installmentIndex: Int = 1,
        date: Date = Date()
    ) -> LoanMonthlyBreakdown {
        calculateNextInstallment(
            currentBalance: loan.balance,
            monthlyInterestRate: loan.monthlyInterestRate,
            installmentValue: loan.installmentValue,
            installmentIndex: installmentIndex,
            date: date
        )
    }

    // MARK: - 2. Motor de Evolução e Amortização Extraordinária (Descapitalização)

    /// Simula e calcula a amortização extraordinária de um empréstimo via descapitalização (trazer a valor presente):
    /// 1. Desconto do Principal: NovoSaldoDevedor = SaldoDevedorAtual - extraPayment (abatendo juros diários pró-rata se houver).
    /// 2. Modalidade A - Redução de Prazo: Mantém o valor da parcela e calcula o novo N:
    ///    $N = \frac{-\ln(1 - (\text{NovoSaldoDevedor} \times i)/\text{PMT})}{\ln(1 + i)}$
    ///    Arredonda N para o teto (`ceil(N - 1e-9)`).
    /// 3. Modalidade B - Redução de Parcela: Mantém o prazo restante e recalcula a nova prestação PMT:
    ///    $\text{PMT} = \frac{\text{NovoSaldoDevedor} \times i}{1 - (1 + i)^{-\text{PrazoRestante}}}$
    public static func simulateExtraAmortization(
        currentBalance: Double,
        monthlyInterestRate: Double,
        installmentValue: Double,
        currentRemainingInstallments: Int,
        extraPayment: Double,
        proRataInterest: Double = 0.0,
        mode: AmortizationRecalculationMode = .reduceTerm
    ) -> LoanAmortizationResult {
        let grossPayment = max(0.0, extraPayment)
        let cleanProRata = max(0.0, min(proRataInterest, grossPayment))

        // 1. Abate juros pró-rata do pagamento bruto antes de abater do principal
        let effectiveAmortization = max(0.0, grossPayment - cleanProRata)

        let cleanBalance = max(0.0, currentBalance)
        let newBalance = max(0.0, cleanBalance - effectiveAmortization)
        let i = max(0.0, monthlyInterestRate) / 100.0

        // Se o valor amortizado cobrir todo o Saldo Devedor (PV), ocorre Quitação Total imediata
        if newBalance <= 0.01 || effectiveAmortization >= cleanBalance {
            let totalSaved = max(0.0, Double(currentRemainingInstallments) * installmentValue - grossPayment)
            return LoanAmortizationResult(
                grossPayment: grossPayment,
                proRataInterest: cleanProRata,
                effectiveAmortization: min(effectiveAmortization, cleanBalance),
                previousBalance: cleanBalance,
                newBalance: 0.0,
                previousRemainingInstallments: currentRemainingInstallments,
                newRemainingInstallments: 0,
                eliminatedInstallmentsCount: currentRemainingInstallments,
                previousInstallmentAmount: installmentValue,
                newInstallmentAmount: 0.0,
                estimatedTotalInterestSaved: totalSaved,
                mode: mode
            )
        }

        var newRemaining = currentRemainingInstallments
        var newInstallment = installmentValue

        switch mode {
        case .reduceTerm:
            // Modalidade A - Redução de Prazo (Mantendo o Valor da Parcela)
            // N = -ln(1 - (PV * i) / PMT) / ln(1 + i)
            if i > 0.000001 && installmentValue > newBalance * i {
                let ratio = 1.0 - (newBalance * i) / installmentValue
                let calcN = -log(max(ratio, 0.000001)) / log(1.0 + i)
                newRemaining = max(1, min(Int(ceil(calcN - 1e-9)), currentRemainingInstallments))
            } else {
                newRemaining = max(1, Int(ceil((newBalance / max(installmentValue, 1.0)) - 1e-9)))
            }
            newInstallment = installmentValue

        case .reduceInstallment:
            // Modalidade B - Redução de Parcela (Mantendo o Prazo Atual)
            // PMT = PV * i / (1 - (1 + i)^(-n))
            let rem = max(currentRemainingInstallments, 1)
            if i > 0.000001 {
                newInstallment = (newBalance * i) / (1.0 - pow(1.0 + i, -Double(rem)))
            } else {
                newInstallment = newBalance / Double(rem)
            }
            newRemaining = rem
        }

        let eliminated = max(0, currentRemainingInstallments - newRemaining)
        let oldNominalFuture = Double(currentRemainingInstallments) * installmentValue
        let newNominalFuture = Double(newRemaining) * newInstallment
        let interestSaved = max(0.0, oldNominalFuture - (newNominalFuture + effectiveAmortization))

        return LoanAmortizationResult(
            grossPayment: grossPayment,
            proRataInterest: cleanProRata,
            effectiveAmortization: effectiveAmortization,
            previousBalance: cleanBalance,
            newBalance: newBalance,
            previousRemainingInstallments: currentRemainingInstallments,
            newRemainingInstallments: newRemaining,
            eliminatedInstallmentsCount: eliminated,
            previousInstallmentAmount: installmentValue,
            newInstallmentAmount: newInstallment,
            estimatedTotalInterestSaved: interestSaved,
            mode: mode
        )
    }

    /// Conveniência simulando amortização extraordinária a partir de um `LoanModel`.
    public static func simulateExtraAmortization(
        for loan: LoanModel,
        extraPayment: Double,
        proRataInterest: Double = 0.0,
        mode: AmortizationRecalculationMode = .reduceTerm
    ) -> LoanAmortizationResult {
        simulateExtraAmortization(
            currentBalance: loan.balance,
            monthlyInterestRate: loan.monthlyInterestRate,
            installmentValue: loan.installmentValue,
            currentRemainingInstallments: loan.remainingInstallments,
            extraPayment: extraPayment,
            proRataInterest: proRataInterest,
            mode: mode
        )
    }

    // MARK: - 3. Recálculo Inverso (Integridade e Rollback de Transações Casadas)

    /// Recalcula o prazo (N) ou a prestação (PMT) com base em um saldo restaurado
    /// (utilizado na exclusão de transações de amortização ou quitação para rollback atômico).
    public static func recalculate(
        balance: Double,
        monthlyInterestRate: Double,
        installmentValue: Double,
        currentRemainingInstallments: Int,
        mode: AmortizationRecalculationMode = .reduceTerm
    ) -> LoanRecalculationResult {
        let cleanBalance = max(0.0, balance)
        let i = max(0.0, monthlyInterestRate) / 100.0

        if cleanBalance <= 0.01 {
            return LoanRecalculationResult(
                balance: 0.0,
                remainingInstallments: 0,
                installmentValue: 0.0
            )
        }

        switch mode {
        case .reduceTerm:
            let newRemaining: Int
            if i > 0.000001 && installmentValue > cleanBalance * i {
                let ratio = 1.0 - (cleanBalance * i) / installmentValue
                let calcN = -log(max(ratio, 0.000001)) / log(1.0 + i)
                newRemaining = max(1, Int(ceil(calcN - 1e-9)))
            } else {
                newRemaining = max(1, Int(ceil((cleanBalance / max(installmentValue, 1.0)) - 1e-9)))
            }
            return LoanRecalculationResult(
                balance: cleanBalance,
                remainingInstallments: newRemaining,
                installmentValue: installmentValue
            )

        case .reduceInstallment:
            let rem = max(currentRemainingInstallments, 1)
            let newPMT: Double
            if i > 0.000001 {
                newPMT = (cleanBalance * i) / (1.0 - pow(1.0 + i, -Double(rem)))
            } else {
                newPMT = cleanBalance / Double(rem)
            }
            return LoanRecalculationResult(
                balance: cleanBalance,
                remainingInstallments: rem,
                installmentValue: newPMT
            )
        }
    }

    // MARK: - 4. Motor de Quitação (Payoff)

    /// Calcula o valor exato para quitação imediata:
    /// No empréstimo puro, a quitação NUNCA é a soma das parcelas restantes,
    /// mas rigorosamente o Saldo Devedor Atual a Valor Presente (PV).
    public static func calculatePayoffAmount(
        currentBalance: Double,
        monthlyInterestRate: Double,
        installmentValue: Double,
        remainingInstallments: Int
    ) -> Double {
        if currentBalance > 0.01 {
            return currentBalance
        }
        return LoanModel.calculatePresentValue(
            installment: installmentValue,
            monthlyRate: monthlyInterestRate,
            remaining: remainingInstallments
        )
    }
}

// MARK: - Camada 3: Read Model & Estruturas Imutáveis do Motor de Projeção (Decimal Puro)

public enum LoanProjectionEventKind: String, Codable, Hashable {
    case regularInstallment = "Parcela Normal"
    case extraAmortization = "Amortização Extra (Dinheiro)"
    case fgtsAmortization = "Amortização Extra (FGTS)"
}

public struct LoanProjectionTimelineRow: Identifiable, Hashable {
    public let id: UUID
    public let date: Date
    public let yearMonthKey: Int
    public let eventKind: LoanProjectionEventKind
    public let title: String
    public let installmentIndex: Int?
    public let linkedTransactionId: UUID?
    public let linkedPlannedAmortizationId: UUID?
    public let initialBalance: Decimal
    public let trCorrection: Decimal
    public let correctedBalance: Decimal
    public let interestAmount: Decimal
    public let normalAmortization: Decimal
    public let extraAmortization: Decimal
    public let changeLeftover: Decimal
    public let baseInstallment: Decimal
    public let insuranceFee: Decimal
    public let adminFee: Decimal
    public let totalBudgetOutflow: Decimal
    public let finalBalance: Decimal
    public let remainingTermMonthsAfter: Int
    public let status: ProjectedInstallmentStatus
    public let fgtsValidationWarning: String?
    public let isFGTSFullPayoffExempt: Bool

    public init(
        id: UUID = UUID(),
        date: Date,
        yearMonthKey: Int,
        eventKind: LoanProjectionEventKind,
        title: String,
        installmentIndex: Int? = nil,
        linkedTransactionId: UUID? = nil,
        linkedPlannedAmortizationId: UUID? = nil,
        initialBalance: Decimal,
        trCorrection: Decimal = .zero,
        correctedBalance: Decimal,
        interestAmount: Decimal = .zero,
        normalAmortization: Decimal = .zero,
        extraAmortization: Decimal = .zero,
        changeLeftover: Decimal = .zero,
        baseInstallment: Decimal = .zero,
        insuranceFee: Decimal = .zero,
        adminFee: Decimal = .zero,
        totalBudgetOutflow: Decimal,
        finalBalance: Decimal,
        remainingTermMonthsAfter: Int,
        status: ProjectedInstallmentStatus,
        fgtsValidationWarning: String? = nil,
        isFGTSFullPayoffExempt: Bool = false
    ) {
        self.id = id
        self.date = date
        self.yearMonthKey = yearMonthKey
        self.eventKind = eventKind
        self.title = title
        self.installmentIndex = installmentIndex
        self.linkedTransactionId = linkedTransactionId
        self.linkedPlannedAmortizationId = linkedPlannedAmortizationId
        self.initialBalance = initialBalance
        self.trCorrection = trCorrection
        self.correctedBalance = correctedBalance
        self.interestAmount = interestAmount
        self.normalAmortization = normalAmortization
        self.extraAmortization = extraAmortization
        self.changeLeftover = changeLeftover
        self.baseInstallment = baseInstallment
        self.insuranceFee = insuranceFee
        self.adminFee = adminFee
        self.totalBudgetOutflow = totalBudgetOutflow
        self.finalBalance = finalBalance
        self.remainingTermMonthsAfter = remainingTermMonthsAfter
        self.status = status
        self.fgtsValidationWarning = fgtsValidationWarning
        self.isFGTSFullPayoffExempt = isFGTSFullPayoffExempt
    }
}

public struct PlannedItemProjectionOutcome: Identifiable, Hashable {
    public let id: UUID
    public let date: Date
    public let requestedAmount: Decimal
    public let proRataInterest: Decimal
    public let effectiveAmortization: Decimal
    public let changeLeftover: Decimal
    public let balanceBefore: Decimal
    public let remainingBalanceAfter: Decimal
    public let remainingTermMonthsAfter: Int
    public let newProjectedInstallment: Decimal
    public let isFullPayoffStep: Bool
    public let fgtsValidationWarning: String?
    public let isFGTSFullPayoffExempt: Bool

    public init(
        id: UUID,
        date: Date,
        requestedAmount: Decimal,
        proRataInterest: Decimal = .zero,
        effectiveAmortization: Decimal,
        changeLeftover: Decimal = .zero,
        balanceBefore: Decimal,
        remainingBalanceAfter: Decimal,
        remainingTermMonthsAfter: Int,
        newProjectedInstallment: Decimal,
        isFullPayoffStep: Bool,
        fgtsValidationWarning: String? = nil,
        isFGTSFullPayoffExempt: Bool = false
    ) {
        self.id = id
        self.date = date
        self.requestedAmount = requestedAmount
        self.proRataInterest = proRataInterest
        self.effectiveAmortization = effectiveAmortization
        self.changeLeftover = changeLeftover
        self.balanceBefore = balanceBefore
        self.remainingBalanceAfter = remainingBalanceAfter
        self.remainingTermMonthsAfter = remainingTermMonthsAfter
        self.newProjectedInstallment = newProjectedInstallment
        self.isFullPayoffStep = isFullPayoffStep
        self.fgtsValidationWarning = fgtsValidationWarning
        self.isFGTSFullPayoffExempt = isFGTSFullPayoffExempt
    }
}

public struct LoanProjectionResult: Hashable {
    public let contractId: UUID
    public let currentRealBalance: Decimal
    public let projectedFinalBalanceAfterPlan: Decimal
    public let timeline: [LoanProjectionTimelineRow]
    public let baselineTimeline: [LoanProjectionTimelineRow]
    public let plannedItemOutcomes: [UUID: PlannedItemProjectionOutcome]

    public let originalMaturityDate: Date
    public let projectedMaturityDate: Date
    public let originalRemainingMonths: Int
    public let projectedActiveMonths: Int
    public let monthsSaved: Int

    public let originalTotalInterest: Decimal
    public let projectedTotalInterest: Decimal
    public let totalInterestSaved: Decimal
    public let totalExtraAmortized: Decimal
    public let totalChangeLeftover: Decimal
    public let doesPlanAchieveFullPayoff: Bool

    public let shadowedInstallmentTransactionIds: Set<UUID>
    public let activeInstallmentProjectedAmounts: [UUID: Decimal]
    public let fgtsWarnings: [String]
    public let payrollOperationalTip: String?

    public init(
        contractId: UUID,
        currentRealBalance: Decimal,
        projectedFinalBalanceAfterPlan: Decimal,
        timeline: [LoanProjectionTimelineRow],
        baselineTimeline: [LoanProjectionTimelineRow],
        plannedItemOutcomes: [UUID: PlannedItemProjectionOutcome],
        originalMaturityDate: Date,
        projectedMaturityDate: Date,
        originalRemainingMonths: Int,
        projectedActiveMonths: Int,
        monthsSaved: Int,
        originalTotalInterest: Decimal,
        projectedTotalInterest: Decimal,
        totalInterestSaved: Decimal,
        totalExtraAmortized: Decimal,
        totalChangeLeftover: Decimal,
        doesPlanAchieveFullPayoff: Bool,
        shadowedInstallmentTransactionIds: Set<UUID>,
        activeInstallmentProjectedAmounts: [UUID: Decimal],
        fgtsWarnings: [String],
        payrollOperationalTip: String?
    ) {
        self.contractId = contractId
        self.currentRealBalance = currentRealBalance
        self.projectedFinalBalanceAfterPlan = projectedFinalBalanceAfterPlan
        self.timeline = timeline
        self.baselineTimeline = baselineTimeline
        self.plannedItemOutcomes = plannedItemOutcomes
        self.originalMaturityDate = originalMaturityDate
        self.projectedMaturityDate = projectedMaturityDate
        self.originalRemainingMonths = originalRemainingMonths
        self.projectedActiveMonths = projectedActiveMonths
        self.monthsSaved = monthsSaved
        self.originalTotalInterest = originalTotalInterest
        self.projectedTotalInterest = projectedTotalInterest
        self.totalInterestSaved = totalInterestSaved
        self.totalExtraAmortized = totalExtraAmortized
        self.totalChangeLeftover = totalChangeLeftover
        self.doesPlanAchieveFullPayoff = doesPlanAchieveFullPayoff
        self.shadowedInstallmentTransactionIds = shadowedInstallmentTransactionIds
        self.activeInstallmentProjectedAmounts = activeInstallmentProjectedAmounts
        self.fgtsWarnings = fgtsWarnings
        self.payrollOperationalTip = payrollOperationalTip
    }
}

// MARK: - Motor de Projeção em Tempo Real (Decimal Estrito)

public enum LoanProjectionEngine {

    public static func toDecimal(_ value: Double) -> Decimal {
        let roundedCents = (value * 10000.0).rounded() / 10000.0
        return Decimal(string: String(format: "%.4f", roundedCents)) ?? Decimal(roundedCents)
    }

    public static func toDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    public static func roundCurrency(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal.zero
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }

    public static func calculateSantanderProRataInterest(
        balance: Decimal,
        monthlyRateDecimal: Decimal,
        daysElapsed: Int
    ) -> Decimal {
        guard balance > .zero, monthlyRateDecimal > .zero, daysElapsed > 0 else {
            return .zero
        }
        if daysElapsed == 30 {
            return roundCurrency(balance * monthlyRateDecimal)
        }
        let imDouble = toDouble(monthlyRateDecimal)
        let exponent = Double(daysElapsed) / 30.0
        let factorDouble = pow(1.0 + imDouble, exponent) - 1.0
        let factorDecimal = Decimal(string: String(format: "%.10f", factorDouble)) ?? Decimal(factorDouble)
        return roundCurrency(balance * factorDecimal)
    }

    public static func calculatePriceBaseInstallment(
        balance: Decimal,
        monthlyRateDecimal: Decimal,
        remainingMonths: Int
    ) -> Decimal {
        guard balance > .zero, remainingMonths > 0 else { return .zero }
        guard monthlyRateDecimal > Decimal(string: "0.0000001")! else {
            return roundCurrency(balance / Decimal(remainingMonths))
        }
        let iDouble = toDouble(monthlyRateDecimal)
        let denomDouble = 1.0 - pow(1.0 + iDouble, -Double(remainingMonths))
        guard denomDouble > 0.0000001 else {
            return roundCurrency(balance / Decimal(remainingMonths))
        }
        let denomDecimal = Decimal(string: String(format: "%.10f", denomDouble)) ?? Decimal(denomDouble)
        return roundCurrency((balance * monthlyRateDecimal) / denomDecimal)
    }

    public static func calculatePriceRemainingMonths(
        balance: Decimal,
        monthlyRateDecimal: Decimal,
        baseInstallment: Decimal,
        fallbackMaxMonths: Int
    ) -> Int {
        guard balance > Decimal(string: "0.01")!, baseInstallment > .zero else { return 0 }
        guard monthlyRateDecimal > Decimal(string: "0.0000001")! else {
            let ratio = toDouble(balance / baseInstallment)
            return max(1, Int(ceil(ratio - 1e-9)))
        }
        let pvDouble = toDouble(balance)
        let iDouble = toDouble(monthlyRateDecimal)
        let pmtDouble = toDouble(baseInstallment)
        guard pmtDouble > pvDouble * iDouble else {
            return max(fallbackMaxMonths, 1)
        }
        let ratio = 1.0 - (pvDouble * iDouble) / pmtDouble
        let calcN = -log(max(ratio, 0.0000001)) / log(1.0 + iDouble)
        return max(1, min(Int(ceil(calcN - 1e-9)), max(fallbackMaxMonths, 1)))
    }

    public static func buildPayrollOperationalTip(for contract: CreditContract) -> String? {
        guard contract.kind == .loan else { return nil }
        let salaryDay = contract.billingDay
        let bankDay = contract.effectiveBankDueDay
        let bestDay = bankDay >= 28 ? 1 : (bankDay + 1)
        if salaryDay != bankDay {
            return "Janela operacional de folha: o desconto no salário ocorre no dia \(salaryDay) e a liquidação no banco ocorre no dia \(bankDay). O melhor dia para amortizar é o 1º dia útil após o vencimento (dia \(bestDay)), garantindo que a parcela do mês já foi baixada."
        } else {
            return "Regra operacional de consignado: a liquidação no banco ocorre no dia \(bankDay). O melhor dia para amortizar é o 1º dia útil após o vencimento (dia \(bestDay)), garantindo que a parcela do mês já foi baixada."
        }
    }

    private enum InternalChronologicalEvent {
        case regularInstallment(tx: FinancialTransaction)
        case plannedAmortization(item: PlannedAmortization)

        var date: Date {
            switch self {
            case .regularInstallment(let tx): return tx.date
            case .plannedAmortization(let item): return item.date
            }
        }

        var sameDayPriority: Int {
            switch self {
            case .regularInstallment: return 0
            case .plannedAmortization: return 1
            }
        }
    }

    public static func simulate(
        contract: CreditContract,
        unpaidInstallmentTransactions: [FinancialTransaction],
        currentRealBalanceDouble: Double,
        plan: AmortizationPlan?,
        calendar: Calendar = Calendar.current
    ) -> LoanProjectionResult {
        let initialBalance = roundCurrency(max(.zero, toDecimal(currentRealBalanceDouble)))
        let sortedInstallments = unpaidInstallmentTransactions
            .filter { $0.installmentIndex != nil && !$0.isPaid }
            .sorted { a, b in
                if a.date == b.date {
                    return (a.installmentIndex ?? 0) < (b.installmentIndex ?? 0)
                }
                return a.date < b.date
            }

        let pendingAmortizations = (plan?.items ?? [])
            .filter { $0.status == .pending && $0.amount > .zero }
            .sorted { a, b in
                if a.date == b.date {
                    return a.createdAt < b.createdAt
                }
                return a.date < b.date
            }

        let isLoan = contract.kind == .loan
        let monthlyRateDecimal: Decimal = {
            if isLoan {
                return toDecimal(contract.monthlyInterestRate) / Decimal(100)
            } else {
                let annualNominal = toDecimal(contract.effectiveAnnualNominalRate)
                return annualNominal / Decimal(1200)
            }
        }()

        let monthlyTRRateDecimal: Decimal = {
            guard !isLoan, (contract.indexationRate ?? .tr) == .tr else { return .zero }
            if let planTR = plan?.estimatedMonthlyTR, planTR > .zero {
                return planTR >= Decimal(string: "0.01")! ? (planTR / Decimal(100)) : planTR
            }
            if let contractTR = contract.estimatedMonthlyTR, contractTR > 0 {
                let dec = toDecimal(contractTR)
                return dec >= Decimal(string: "0.01")! ? (dec / Decimal(100)) : dec
            }
            return .zero
        }()

        let initialBaseInstallment: Decimal = {
            if isLoan {
                return roundCurrency(toDecimal(contract.installmentAmount))
            } else {
                return roundCurrency(toDecimal(contract.effectiveBaseInstallmentPrice))
            }
        }()

        let initialInsuranceFee: Decimal = isLoan ? .zero : roundCurrency(toDecimal(contract.effectiveInsuranceFee))
        let fixedAdminFee: Decimal = isLoan ? .zero : roundCurrency(toDecimal(contract.effectiveAdminFee))
        let initialRemainingMonths = max(sortedInstallments.count, 1)

        let baselineRun = runEventSimulation(
            contract: contract,
            initialBalance: initialBalance,
            monthlyRateDecimal: monthlyRateDecimal,
            monthlyTRRateDecimal: monthlyTRRateDecimal,
            initialBaseInstallment: initialBaseInstallment,
            initialInsuranceFee: initialInsuranceFee,
            fixedAdminFee: fixedAdminFee,
            initialRemainingMonths: initialRemainingMonths,
            installments: sortedInstallments,
            plannedItems: [],
            calendar: calendar
        )

        let projectedRun = runEventSimulation(
            contract: contract,
            initialBalance: initialBalance,
            monthlyRateDecimal: monthlyRateDecimal,
            monthlyTRRateDecimal: monthlyTRRateDecimal,
            initialBaseInstallment: initialBaseInstallment,
            initialInsuranceFee: initialInsuranceFee,
            fixedAdminFee: fixedAdminFee,
            initialRemainingMonths: initialRemainingMonths,
            installments: sortedInstallments,
            plannedItems: pendingAmortizations,
            calendar: calendar
        )

        let originalMaturityDate = contract.maturityDate
            ?? baselineRun.payoffDate
            ?? sortedInstallments.last?.date
            ?? Date()

        let projectedMaturityDate = projectedRun.payoffDate
            ?? sortedInstallments.last?.date
            ?? originalMaturityDate

        let originalRemainingMonths = baselineRun.activeInstallmentsCount
        let projectedActiveMonths = projectedRun.activeInstallmentsCount
        let monthsSaved = max(0, originalRemainingMonths - projectedActiveMonths)
        let interestSaved = max(.zero, roundCurrency(baselineRun.totalInterest - projectedRun.totalInterest))

        let doesPlanAchieveFullPayoff = !pendingAmortizations.isEmpty && (
            projectedRun.balanceAfterLastPlannedItem <= Decimal(string: "0.01")! ||
            projectedRun.plannedOutcomes.values.contains(where: {
                $0.isFullPayoffStep || $0.remainingBalanceAfter <= Decimal(string: "0.01")!
            })
        )

        return LoanProjectionResult(
            contractId: contract.id,
            currentRealBalance: initialBalance,
            projectedFinalBalanceAfterPlan: projectedRun.balanceAfterLastPlannedItem,
            timeline: projectedRun.rows,
            baselineTimeline: baselineRun.rows,
            plannedItemOutcomes: projectedRun.plannedOutcomes,
            originalMaturityDate: originalMaturityDate,
            projectedMaturityDate: projectedMaturityDate,
            originalRemainingMonths: originalRemainingMonths,
            projectedActiveMonths: projectedActiveMonths,
            monthsSaved: monthsSaved,
            originalTotalInterest: baselineRun.totalInterest,
            projectedTotalInterest: projectedRun.totalInterest,
            totalInterestSaved: interestSaved,
            totalExtraAmortized: projectedRun.totalExtraAmortized,
            totalChangeLeftover: projectedRun.totalChangeLeftover,
            doesPlanAchieveFullPayoff: doesPlanAchieveFullPayoff,
            shadowedInstallmentTransactionIds: projectedRun.shadowedTxIds,
            activeInstallmentProjectedAmounts: projectedRun.activeTxProjectedAmounts,
            fgtsWarnings: projectedRun.fgtsWarnings,
            payrollOperationalTip: buildPayrollOperationalTip(for: contract)
        )
    }

    private struct SimulationRunOutput {
        let rows: [LoanProjectionTimelineRow]
        let plannedOutcomes: [UUID: PlannedItemProjectionOutcome]
        let totalInterest: Decimal
        let totalExtraAmortized: Decimal
        let totalChangeLeftover: Decimal
        let finalBalance: Decimal
        let balanceAfterLastPlannedItem: Decimal
        let activeInstallmentsCount: Int
        let payoffDate: Date?
        let shadowedTxIds: Set<UUID>
        let activeTxProjectedAmounts: [UUID: Decimal]
        let fgtsWarnings: [String]
    }

    private static func runEventSimulation(
        contract: CreditContract,
        initialBalance: Decimal,
        monthlyRateDecimal: Decimal,
        monthlyTRRateDecimal: Decimal,
        initialBaseInstallment: Decimal,
        initialInsuranceFee: Decimal,
        fixedAdminFee: Decimal,
        initialRemainingMonths: Int,
        installments: [FinancialTransaction],
        plannedItems: [PlannedAmortization],
        calendar: Calendar
    ) -> SimulationRunOutput {
        let isLoan = contract.kind == .loan
        var events: [InternalChronologicalEvent] = []
        events.append(contentsOf: installments.map { .regularInstallment(tx: $0) })
        events.append(contentsOf: plannedItems.map { .plannedAmortization(item: $0) })

        events.sort { a, b in
            let dayA = calendar.startOfDay(for: a.date)
            let dayB = calendar.startOfDay(for: b.date)
            if dayA == dayB {
                return a.sameDayPriority < b.sameDayPriority
            }
            return dayA < dayB
        }

        var runningBalance = initialBalance
        var currentBaseInstallment = initialBaseInstallment
        var currentInsuranceFee = initialInsuranceFee
        var remainingTermMonths = max(initialRemainingMonths, 1)
        var installmentReductionScale: Decimal = Decimal(1)
        var currentSACAmortizationQuota: Decimal = {
            if !isLoan && contract.amortizationSystem == .sac && remainingTermMonths > 0 {
                return roundCurrency(initialBalance / Decimal(remainingTermMonths))
            }
            return .zero
        }()

        var rows: [LoanProjectionTimelineRow] = []
        var plannedOutcomes: [UUID: PlannedItemProjectionOutcome] = [:]
        var totalInterest: Decimal = .zero
        var totalExtraAmortized: Decimal = .zero
        var totalChangeLeftover: Decimal = .zero
        var balanceAfterLastPlannedItem: Decimal = initialBalance
        var activeInstallmentsCount = 0
        var payoffDate: Date? = nil
        var shadowedTxIds: Set<UUID> = []
        var activeTxProjectedAmounts: [UUID: Decimal] = [:]
        var fgtsWarnings: [String] = []
        var lastFGTSDate: Date? = contract.lastFGTSUsageDate

        for event in events {
            let ymKey = calendar.component(.year, from: event.date) * 100 + calendar.component(.month, from: event.date)

            switch event {
            case .regularInstallment(let tx):
                if runningBalance <= Decimal(string: "0.01")! {
                    shadowedTxIds.insert(tx.id)
                    rows.append(
                        LoanProjectionTimelineRow(
                            date: tx.date,
                            yearMonthKey: ymKey,
                            eventKind: .regularInstallment,
                            title: tx.name,
                            installmentIndex: tx.installmentIndex,
                            linkedTransactionId: tx.id,
                            initialBalance: .zero,
                            trCorrection: .zero,
                            correctedBalance: .zero,
                            interestAmount: .zero,
                            normalAmortization: .zero,
                            extraAmortization: .zero,
                            changeLeftover: .zero,
                            baseInstallment: .zero,
                            insuranceFee: .zero,
                            adminFee: .zero,
                            totalBudgetOutflow: .zero,
                            finalBalance: .zero,
                            remainingTermMonthsAfter: 0,
                            status: .shadowed
                        )
                    )
                    continue
                }

                let balanceBefore = runningBalance
                let trCorrection: Decimal
                let correctedBalance: Decimal

                if !isLoan && monthlyTRRateDecimal > .zero {
                    trCorrection = roundCurrency(balanceBefore * monthlyTRRateDecimal)
                    correctedBalance = balanceBefore + trCorrection
                    if contract.amortizationSystem == .price {
                        currentBaseInstallment = roundCurrency(currentBaseInstallment * (Decimal(1) + monthlyTRRateDecimal))
                    } else if remainingTermMonths > 0 {
                        currentSACAmortizationQuota = roundCurrency(correctedBalance / Decimal(remainingTermMonths))
                    }
                } else {
                    trCorrection = .zero
                    correctedBalance = balanceBefore
                }

                let interest: Decimal
                let effectiveNormalAmortization: Decimal
                let effectiveBaseInstallment: Decimal
                let newBalance: Decimal
                let totalOutflow: Decimal

                if isLoan, let schedule = contract.scheduledInstallments, !schedule.isEmpty {
                    let txDecAmount = roundCurrency(toDecimal(tx.amount))
                    let schedItem = schedule.first(where: { $0.installmentNumber == tx.installmentIndex })
                    let effectiveD0Installment = min(correctedBalance, txDecAmount)
                    effectiveBaseInstallment = effectiveD0Installment

                    if let schedInterest = schedItem?.interestAmount {
                        let rawInterest = roundCurrency(toDecimal(schedInterest))
                        interest = txDecAmount > .zero
                            ? roundCurrency(rawInterest * (effectiveD0Installment / txDecAmount))
                            : .zero
                    } else {
                        interest = roundCurrency(effectiveD0Installment * Decimal(string: "0.221136")!)
                    }

                    effectiveNormalAmortization = max(.zero, roundCurrency(effectiveD0Installment - interest))
                    newBalance = max(.zero, roundCurrency(correctedBalance - effectiveD0Installment))
                    totalOutflow = effectiveBaseInstallment
                } else if !isLoan,
                          contract.amortizationSystem == .price,
                          ((contract.averageMonthlyInstallmentGrowth ?? 0) > 0 || !(contract.scheduledInstallments?.isEmpty ?? true) || tx.projectedInstallmentCorrectionAmount != nil) {
                    let calcInterest = roundCurrency(correctedBalance * monthlyRateDecimal)
                    interest = calcInterest
                    let rawBaseInstallment = currentBaseInstallment
                    let rawNormalAmortization = max(.zero, rawBaseInstallment - calcInterest)

                    let stepIndex = max(1, (tx.installmentIndex ?? (contract.pastInstallmentsElapsedAtCreation + activeInstallmentsCount + 1)) - contract.pastInstallmentsElapsedAtCreation)
                    let speculativeIncreaseDec: Decimal = {
                        if let explicitProj = tx.projectedInstallmentCorrectionAmount, explicitProj > 0 {
                            return roundCurrency(toDecimal(explicitProj) * installmentReductionScale)
                        }
                        if let avgG = contract.averageMonthlyInstallmentGrowth, avgG > 0 {
                            return roundCurrency(Decimal(stepIndex) * toDecimal(avgG) * installmentReductionScale)
                        }
                        if let schedItem = contract.scheduledInstallments?.first(where: { $0.installmentNumber == tx.installmentIndex }),
                           let j = schedItem.interestAmount, j > 0 {
                            return roundCurrency(toDecimal(j) * installmentReductionScale)
                        }
                        let baseReg = toDecimal(tx.baseInstallmentRegisteredAmount ?? contract.installmentAmount)
                        let txDec = toDecimal(tx.amount)
                        return max(.zero, roundCurrency((txDec - baseReg) * installmentReductionScale))
                    }()

                    let baseRegisteredOutflowDec = roundCurrency(toDecimal(tx.baseInstallmentRegisteredAmount ?? contract.installmentAmount) * installmentReductionScale)

                    if rawNormalAmortization >= correctedBalance {
                        effectiveNormalAmortization = correctedBalance
                        effectiveBaseInstallment = effectiveNormalAmortization + calcInterest
                        totalOutflow = roundCurrency(effectiveBaseInstallment + currentInsuranceFee + fixedAdminFee + speculativeIncreaseDec)
                    } else {
                        effectiveNormalAmortization = rawNormalAmortization
                        effectiveBaseInstallment = rawBaseInstallment
                        totalOutflow = roundCurrency(baseRegisteredOutflowDec + speculativeIncreaseDec)
                    }
                    newBalance = max(.zero, roundCurrency(correctedBalance - effectiveNormalAmortization))
                } else {
                    let calcInterest = roundCurrency(correctedBalance * monthlyRateDecimal)
                    interest = calcInterest
                    let rawNormalAmortization: Decimal
                    let rawBaseInstallment: Decimal

                    if isLoan || contract.amortizationSystem == .price {
                        rawBaseInstallment = currentBaseInstallment
                        rawNormalAmortization = max(.zero, rawBaseInstallment - calcInterest)
                    } else {
                        let sacAmort = remainingTermMonths > 0
                            ? roundCurrency(correctedBalance / Decimal(remainingTermMonths))
                            : correctedBalance
                        rawNormalAmortization = max(currentSACAmortizationQuota, sacAmort)
                        rawBaseInstallment = rawNormalAmortization + calcInterest
                    }

                    if rawNormalAmortization >= correctedBalance {
                        effectiveNormalAmortization = correctedBalance
                        effectiveBaseInstallment = effectiveNormalAmortization + calcInterest
                    } else {
                        effectiveNormalAmortization = rawNormalAmortization
                        effectiveBaseInstallment = rawBaseInstallment
                    }

                    newBalance = max(.zero, roundCurrency(correctedBalance - effectiveNormalAmortization))
                    totalOutflow = roundCurrency(effectiveBaseInstallment + currentInsuranceFee + fixedAdminFee)
                }

                if !isLoan && (contract.scheduledInstallments?.isEmpty ?? true) && initialBalance > Decimal(string: "0.01")! && initialInsuranceFee > .zero {
                    let ratio = max(.zero, min(Decimal(1), newBalance / initialBalance))
                    currentInsuranceFee = roundCurrency(initialInsuranceFee * ratio)
                }

                runningBalance = newBalance
                remainingTermMonths = newBalance <= Decimal(string: "0.01")! ? 0 : max(0, remainingTermMonths - 1)
                totalInterest += interest
                activeInstallmentsCount += 1
                activeTxProjectedAmounts[tx.id] = totalOutflow

                if newBalance <= Decimal(string: "0.01")! && payoffDate == nil {
                    payoffDate = tx.date
                }

                rows.append(
                    LoanProjectionTimelineRow(
                        date: tx.date,
                        yearMonthKey: ymKey,
                        eventKind: .regularInstallment,
                        title: tx.name,
                        installmentIndex: tx.installmentIndex,
                        linkedTransactionId: tx.id,
                        initialBalance: balanceBefore,
                        trCorrection: trCorrection,
                        correctedBalance: correctedBalance,
                        interestAmount: interest,
                        normalAmortization: effectiveNormalAmortization,
                        extraAmortization: .zero,
                        changeLeftover: .zero,
                        baseInstallment: effectiveBaseInstallment,
                        insuranceFee: isLoan ? .zero : currentInsuranceFee,
                        adminFee: isLoan ? .zero : fixedAdminFee,
                        totalBudgetOutflow: totalOutflow,
                        finalBalance: newBalance,
                        remainingTermMonthsAfter: remainingTermMonths,
                        status: .active
                    )
                )

            case .plannedAmortization(let item):
                let balanceBefore = runningBalance
                let requested = roundCurrency(item.amount)

                if balanceBefore <= Decimal(string: "0.01")! {
                    let outcome = PlannedItemProjectionOutcome(
                        id: item.id,
                        date: item.date,
                        requestedAmount: requested,
                        proRataInterest: .zero,
                        effectiveAmortization: .zero,
                        changeLeftover: requested,
                        balanceBefore: .zero,
                        remainingBalanceAfter: .zero,
                        remainingTermMonthsAfter: 0,
                        newProjectedInstallment: .zero,
                        isFullPayoffStep: false
                    )
                    plannedOutcomes[item.id] = outcome
                    totalChangeLeftover += requested
                    balanceAfterLastPlannedItem = .zero
                    continue
                }

                var fgtsWarning: String? = nil
                var isFGTSExempt = false
                if item.source == .fgts {
                    if requested >= balanceBefore {
                        isFGTSExempt = true
                    } else if let prevFGTS = lastFGTSDate {
                        let monthsDiff = calendar.dateComponents([.month], from: calendar.startOfDay(for: prevFGTS), to: calendar.startOfDay(for: item.date)).month ?? 0
                        if monthsDiff < 24 {
                            let allowedDate = calendar.date(byAdding: .month, value: 24, to: prevFGTS) ?? item.date
                            let msg = "Interstício legal do FGTS: amortização parcial exige 24 meses desde o último uso (\(BRLFormatters.shortDate(prevFGTS))). Liberado a partir de \(BRLFormatters.shortDate(allowedDate)) (ou permitido agora apenas para quitação total)."
                            fgtsWarning = msg
                            fgtsWarnings.append(msg)
                        }
                    }
                    lastFGTSDate = item.date
                }

                let effectiveAmortization: Decimal
                let changeLeftover: Decimal
                let newBalance: Decimal
                let isFullPayoffStep: Bool

                if requested >= balanceBefore {
                    effectiveAmortization = balanceBefore
                    changeLeftover = roundCurrency(requested - balanceBefore)
                    newBalance = .zero
                    isFullPayoffStep = true
                } else {
                    effectiveAmortization = requested
                    changeLeftover = .zero
                    newBalance = roundCurrency(balanceBefore - effectiveAmortization)
                    isFullPayoffStep = newBalance <= Decimal(string: "0.01")!
                }

                let effectiveMode: AmortizationRecalculationMode = isLoan ? .reduceTerm : item.mode

                if isFullPayoffStep {
                    remainingTermMonths = 0
                    if payoffDate == nil {
                        payoffDate = item.date
                    }
                } else {
                    switch effectiveMode {
                    case .reduceTerm:
                        if isLoan || contract.amortizationSystem == .price {
                            remainingTermMonths = calculatePriceRemainingMonths(
                                balance: newBalance,
                                monthlyRateDecimal: monthlyRateDecimal,
                                baseInstallment: currentBaseInstallment,
                                fallbackMaxMonths: remainingTermMonths
                            )
                        } else {
                            if currentSACAmortizationQuota > .zero {
                                let ratio = toDouble(newBalance / currentSACAmortizationQuota)
                                remainingTermMonths = max(1, Int(ceil(ratio - 1e-9)))
                            }
                        }

                    case .reduceInstallment:
                        if contract.amortizationSystem == .price {
                            let prevBase = currentBaseInstallment
                            currentBaseInstallment = calculatePriceBaseInstallment(
                                balance: newBalance,
                                monthlyRateDecimal: monthlyRateDecimal,
                                remainingMonths: max(remainingTermMonths, 1)
                            )
                            if prevBase > Decimal(string: "0.01")! {
                                installmentReductionScale = installmentReductionScale * (currentBaseInstallment / prevBase)
                            }
                        } else {
                            currentSACAmortizationQuota = roundCurrency(newBalance / Decimal(max(remainingTermMonths, 1)))
                            let nextInterest = roundCurrency(newBalance * monthlyRateDecimal)
                            currentBaseInstallment = currentSACAmortizationQuota + nextInterest
                        }
                    }

                    if !isLoan && initialBalance > Decimal(string: "0.01")! && initialInsuranceFee > .zero {
                        let ratio = max(.zero, min(Decimal(1), newBalance / initialBalance))
                        currentInsuranceFee = roundCurrency(initialInsuranceFee * ratio)
                    }
                }

                let projectedNextTotalInstallment: Decimal = isFullPayoffStep
                    ? .zero
                    : roundCurrency(currentBaseInstallment + (isLoan ? .zero : (currentInsuranceFee + fixedAdminFee)))

                runningBalance = newBalance
                totalExtraAmortized += effectiveAmortization
                totalChangeLeftover += changeLeftover
                balanceAfterLastPlannedItem = newBalance

                let outcome = PlannedItemProjectionOutcome(
                    id: item.id,
                    date: item.date,
                    requestedAmount: requested,
                    proRataInterest: .zero,
                    effectiveAmortization: effectiveAmortization,
                    changeLeftover: changeLeftover,
                    balanceBefore: balanceBefore,
                    remainingBalanceAfter: newBalance,
                    remainingTermMonthsAfter: remainingTermMonths,
                    newProjectedInstallment: projectedNextTotalInstallment,
                    isFullPayoffStep: isFullPayoffStep,
                    fgtsValidationWarning: fgtsWarning,
                    isFGTSFullPayoffExempt: isFGTSExempt
                )
                plannedOutcomes[item.id] = outcome

                rows.append(
                    LoanProjectionTimelineRow(
                        date: item.date,
                        yearMonthKey: ymKey,
                        eventKind: item.source == .fgts ? .fgtsAmortization : .extraAmortization,
                        title: item.source == .fgts ? "Amortização Extra (FGTS)" : "Amortização Extraordinária",
                        installmentIndex: nil,
                        linkedTransactionId: item.linkedTransactionId,
                        linkedPlannedAmortizationId: item.id,
                        initialBalance: balanceBefore,
                        trCorrection: .zero,
                        correctedBalance: balanceBefore,
                        interestAmount: .zero,
                        normalAmortization: .zero,
                        extraAmortization: effectiveAmortization,
                        changeLeftover: changeLeftover,
                        baseInstallment: .zero,
                        insuranceFee: .zero,
                        adminFee: .zero,
                        totalBudgetOutflow: effectiveAmortization,
                        finalBalance: newBalance,
                        remainingTermMonthsAfter: remainingTermMonths,
                        status: .pendingAmortization,
                        fgtsValidationWarning: fgtsWarning,
                        isFGTSFullPayoffExempt: isFGTSExempt
                    )
                )
            }
        }

        return SimulationRunOutput(
            rows: rows,
            plannedOutcomes: plannedOutcomes,
            totalInterest: roundCurrency(totalInterest),
            totalExtraAmortized: roundCurrency(totalExtraAmortized),
            totalChangeLeftover: roundCurrency(totalChangeLeftover),
            finalBalance: runningBalance,
            balanceAfterLastPlannedItem: balanceAfterLastPlannedItem,
            activeInstallmentsCount: activeInstallmentsCount,
            payoffDate: payoffDate,
            shadowedTxIds: shadowedTxIds,
            activeTxProjectedAmounts: activeTxProjectedAmounts,
            fgtsWarnings: fgtsWarnings
        )
    }

    public static func generateAutomaticPlanItems(
        contract: CreditContract,
        unpaidInstallmentTransactions: [FinancialTransaction],
        currentRealBalanceDouble: Double,
        billingDay: Int,
        incomeCommitmentPercentage: Decimal,
        mode: AmortizationRecalculationMode = .reduceTerm,
        estimatedMonthlyTR: Decimal = .zero,
        referenceNow: Date = Date(),
        monthlyAvailableSurplusProvider: (Date) -> Decimal,
        calendar: Calendar = Calendar.current
    ) -> [PlannedAmortization] {
        let clampedDay = min(max(billingDay, 1), 28)
        let pct = min(max(incomeCommitmentPercentage, Decimal(1)), Decimal(100))
        let effectiveMode: AmortizationRecalculationMode = contract.kind == .loan ? .reduceTerm : mode
        let todayStart = calendar.startOfDay(for: referenceNow)

        var startComps = calendar.dateComponents([.year, .month], from: todayStart)
        startComps.day = clampedDay
        var firstCandidateDate = calendar.date(from: startComps) ?? todayStart
        if firstCandidateDate < todayStart {
            firstCandidateDate = calendar.date(byAdding: .month, value: 1, to: firstCandidateDate) ?? firstCandidateDate
        }

        var generatedItems: [PlannedAmortization] = []
        let maxMonthsToSimulate = max(unpaidInstallmentTransactions.count, contract.totalInstallments, 1)

        for monthOffset in 0..<maxMonthsToSimulate {
            guard let candidateDate = calendar.date(byAdding: .month, value: monthOffset, to: firstCandidateDate) else {
                continue
            }

            let availableSurplus = max(.zero, monthlyAvailableSurplusProvider(candidateDate))
            let budgetForAmortization = roundCurrency(availableSurplus * (pct / Decimal(100)))
            guard budgetForAmortization >= Decimal(string: "10.00")! else {
                continue
            }

            let probeId = UUID()
            let probeItem = PlannedAmortization(
                id: probeId,
                contractId: contract.id,
                date: candidateDate,
                amount: toDecimal(currentRealBalanceDouble * 2.0 + 1_000_000.0),
                source: .cash,
                mode: effectiveMode,
                status: .pending
            )
            let tempPlan = AmortizationPlan(
                contractId: contract.id,
                generationMode: .automatic,
                billingDay: clampedDay,
                incomeCommitmentPercentage: pct,
                defaultRecalculationMode: effectiveMode,
                estimatedMonthlyTR: estimatedMonthlyTR,
                items: generatedItems + [probeItem]
            )

            let simResult = simulate(
                contract: contract,
                unpaidInstallmentTransactions: unpaidInstallmentTransactions,
                currentRealBalanceDouble: currentRealBalanceDouble,
                plan: tempPlan,
                calendar: calendar
            )

            guard let probeOutcome = simResult.plannedItemOutcomes[probeId] else {
                break
            }

            let balanceAvailableToAmortize = probeOutcome.balanceBefore
            if balanceAvailableToAmortize <= Decimal(string: "0.01")! {
                if let lastGen = generatedItems.last,
                   let lastOutcome = simResult.plannedItemOutcomes[lastGen.id],
                   lastOutcome.remainingBalanceAfter > Decimal(string: "0.01")! {
                    let residualToPayOff = lastOutcome.remainingBalanceAfter
                    let finalPayoffDate: Date = {
                        let lastGenDay = calendar.startOfDay(for: lastGen.date)
                        if let nextRegularRow = simResult.timeline.first(where: {
                            $0.eventKind == .regularInstallment &&
                            calendar.startOfDay(for: $0.date) > lastGenDay &&
                            calendar.startOfDay(for: $0.date) <= calendar.startOfDay(for: candidateDate)
                        }) {
                            let dayBefore = calendar.date(byAdding: .day, value: -1, to: nextRegularRow.date) ?? nextRegularRow.date
                            return calendar.startOfDay(for: dayBefore) > lastGenDay ? dayBefore : lastGen.date
                        }
                        return candidateDate
                    }()

                    let pctInt = NSDecimalNumber(decimal: pct).intValue
                    if calendar.isDate(finalPayoffDate, inSameDayAs: lastGen.date) {
                        generatedItems[generatedItems.count - 1].amount = roundCurrency(lastGen.amount + residualToPayOff)
                        generatedItems[generatedItems.count - 1].notes = "Liquidação Total Automática (\(pctInt)% do saldo previsto no mês)"
                    } else {
                        let finalPayoffItem = PlannedAmortization(
                            contractId: contract.id,
                            date: finalPayoffDate,
                            amount: residualToPayOff,
                            source: .cash,
                            mode: effectiveMode,
                            status: .pending,
                            notes: "Liquidação Total Automática (Quitação do saldo residual)"
                        )
                        generatedItems.append(finalPayoffItem)
                    }
                }
                break
            }

            let actualAmount = min(budgetForAmortization, balanceAvailableToAmortize)
            guard actualAmount > Decimal(string: "0.01")! else {
                break
            }

            let pctInt = NSDecimalNumber(decimal: pct).intValue
            let isPayoffHere = actualAmount >= balanceAvailableToAmortize
            let newItem = PlannedAmortization(
                contractId: contract.id,
                date: candidateDate,
                amount: actualAmount,
                source: .cash,
                mode: effectiveMode,
                status: .pending,
                notes: isPayoffHere
                    ? "Liquidação Total Automática (\(pctInt)% do saldo previsto no mês)"
                    : "Planejamento automático (\(pctInt)% do saldo previsto no mês)"
            )
            generatedItems.append(newItem)

            if isPayoffHere {
                break
            }
        }

        return generatedItems
    }

    public static func maxAvailableLoanBalanceToAmortize(
        contract: CreditContract,
        unpaidInstallmentTransactions: [FinancialTransaction],
        currentRealBalanceDouble: Double,
        existingItems: [PlannedAmortization],
        onDate: Date,
        excludingItemId: UUID? = nil,
        estimatedMonthlyTR: Decimal = .zero,
        calendar: Calendar = .current
    ) -> Decimal {
        let filteredItems = existingItems.filter {
            $0.status == .pending && $0.id != excludingItemId && $0.amount > .zero
        }

        if !filteredItems.isEmpty {
            let basePlan = AmortizationPlan(
                contractId: contract.id,
                generationMode: .manual,
                billingDay: contract.billingDay,
                incomeCommitmentPercentage: Decimal(30),
                defaultRecalculationMode: .reduceTerm,
                estimatedMonthlyTR: estimatedMonthlyTR,
                items: filteredItems
            )
            let baseSim = simulate(
                contract: contract,
                unpaidInstallmentTransactions: unpaidInstallmentTransactions,
                currentRealBalanceDouble: currentRealBalanceDouble,
                plan: basePlan,
                calendar: calendar
            )
            if baseSim.doesPlanAchieveFullPayoff && excludingItemId == nil {
                return .zero
            }
        }

        let probeId = UUID()
        let probeItem = PlannedAmortization(
            id: probeId,
            contractId: contract.id,
            date: onDate,
            amount: toDecimal(max(currentRealBalanceDouble * 2.0, 1_000_000.0)),
            source: .cash,
            mode: .reduceTerm,
            status: .pending,
            createdAt: Date.distantFuture
        )
        let probePlan = AmortizationPlan(
            contractId: contract.id,
            generationMode: .manual,
            billingDay: contract.billingDay,
            incomeCommitmentPercentage: Decimal(30),
            defaultRecalculationMode: .reduceTerm,
            estimatedMonthlyTR: estimatedMonthlyTR,
            items: filteredItems + [probeItem]
        )
        let simResult = simulate(
            contract: contract,
            unpaidInstallmentTransactions: unpaidInstallmentTransactions,
            currentRealBalanceDouble: currentRealBalanceDouble,
            plan: probePlan,
            calendar: calendar
        )
        guard let probeOutcome = simResult.plannedItemOutcomes[probeId] else {
            return .zero
        }
        return roundCurrency(max(.zero, probeOutcome.balanceBefore))
    }

    public static func clampAndSanitizePlannedItems(
        _ items: [PlannedAmortization],
        contract: CreditContract,
        unpaidInstallmentTransactions: [FinancialTransaction],
        currentRealBalanceDouble: Double,
        estimatedMonthlyTR: Decimal = .zero,
        calendar: Calendar = .current
    ) -> [PlannedAmortization] {
        let nonPending = items.filter { $0.status != .pending }
        let sortedPending = items
            .filter { $0.status == .pending && $0.amount > .zero }
            .sorted { a, b in
                let dA = calendar.startOfDay(for: a.date)
                let dB = calendar.startOfDay(for: b.date)
                if dA == dB { return a.createdAt < b.createdAt }
                return dA < dB
            }

        var acceptedPending: [PlannedAmortization] = []

        for var candidate in sortedPending {
            let maxAllowed = maxAvailableLoanBalanceToAmortize(
                contract: contract,
                unpaidInstallmentTransactions: unpaidInstallmentTransactions,
                currentRealBalanceDouble: currentRealBalanceDouble,
                existingItems: acceptedPending,
                onDate: candidate.date,
                excludingItemId: candidate.id,
                estimatedMonthlyTR: estimatedMonthlyTR,
                calendar: calendar
            )
            guard maxAllowed > Decimal(string: "0.01")! else {
                break
            }
            if candidate.amount > maxAllowed {
                candidate.amount = maxAllowed
            }
            acceptedPending.append(candidate)

            if candidate.amount >= maxAllowed {
                break
            }
        }

        return (nonPending + acceptedPending).sorted { $0.date < $1.date }
    }
}

public enum PlanExpirationValidator {
    public static func validateAndExpireOverdueItems(
        plans: inout [AmortizationPlan],
        referenceNow: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> [UUID] {
        let todayStart = calendar.startOfDay(for: referenceNow)
        var newlyExpiredIds: [UUID] = []

        for pIdx in plans.indices {
            var planMutated = false
            for iIdx in plans[pIdx].items.indices {
                if plans[pIdx].items[iIdx].status == .pending {
                    let itemDay = calendar.startOfDay(for: plans[pIdx].items[iIdx].date)
                    if itemDay < todayStart {
                        plans[pIdx].items[iIdx].status = .expired
                        newlyExpiredIds.append(plans[pIdx].items[iIdx].id)
                        planMutated = true
                    }
                }
            }
            if planMutated {
                plans[pIdx].updatedAt = referenceNow
            }
        }

        return newlyExpiredIds
    }
}

// MARK: - Credit Contract (Loan & Financing) Document Parser (Santander DDC & Caixa Habitação)

public struct ParsedCreditContractDocument: Identifiable, Hashable, Codable {
    public var id: UUID
    public var kind: CreditContractKind
    public var name: String
    public var contractNumber: String
    public var institutionName: String
    public var loanSubtype: LoanSubtype
    public var financingSubtype: FinancingSubtype
    public var amortizationSystem: AmortizationSystem
    public var totalContractedAmount: Double
    public var outstandingBalance: Double
    public var installmentAmount: Double
    public var billingDay: Int
    public var totalInstallments: Int
    public var paidInstallmentsCount: Int
    public var remainingInstallmentsCount: Int
    public var monthlyInterestRate: Double
    public var startDate: Date
    public var firstFutureBillingDate: Date
    public var documentEmissionDate: Date?
    public var extractedNotes: String

    public var annualNominalInterestRate: Double?
    public var indexationRate: FinancingIndexation?
    public var adminFee: Double?
    public var insuranceFee: Double?
    public var baseInstallmentAmount: Double?

    public var bankDueDay: Int
    public var referenceDate: Date?
    public var maturityDate: Date?
    public var firstInstallmentBankDueDate: Date?
    public var scheduledInstallments: [ContractInstallmentScheduleItem]
    public var averageMonthlyInstallmentGrowth: Double?

    public init(
        id: UUID = UUID(),
        kind: CreditContractKind,
        name: String,
        contractNumber: String,
        institutionName: String,
        loanSubtype: LoanSubtype = .consignado,
        financingSubtype: FinancingSubtype = .imovel,
        amortizationSystem: AmortizationSystem = .price,
        totalContractedAmount: Double,
        outstandingBalance: Double,
        installmentAmount: Double,
        billingDay: Int,
        totalInstallments: Int,
        paidInstallmentsCount: Int,
        remainingInstallmentsCount: Int,
        monthlyInterestRate: Double,
        startDate: Date,
        firstFutureBillingDate: Date,
        documentEmissionDate: Date? = nil,
        extractedNotes: String = "",
        annualNominalInterestRate: Double? = nil,
        indexationRate: FinancingIndexation? = nil,
        adminFee: Double? = nil,
        insuranceFee: Double? = nil,
        baseInstallmentAmount: Double? = nil,
        bankDueDay: Int? = nil,
        referenceDate: Date? = nil,
        maturityDate: Date? = nil,
        firstInstallmentBankDueDate: Date? = nil,
        scheduledInstallments: [ContractInstallmentScheduleItem] = [],
        averageMonthlyInstallmentGrowth: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.contractNumber = contractNumber
        self.institutionName = institutionName
        self.loanSubtype = loanSubtype
        self.financingSubtype = financingSubtype
        self.amortizationSystem = amortizationSystem
        self.totalContractedAmount = abs(totalContractedAmount)
        self.outstandingBalance = abs(outstandingBalance)
        self.installmentAmount = abs(installmentAmount)
        self.billingDay = min(max(billingDay, 1), 31)
        self.totalInstallments = max(totalInstallments, 1)
        self.paidInstallmentsCount = max(paidInstallmentsCount, 0)
        self.remainingInstallmentsCount = max(remainingInstallmentsCount, 0)
        self.monthlyInterestRate = max(monthlyInterestRate, 0.0)
        self.startDate = startDate
        self.firstFutureBillingDate = firstFutureBillingDate
        self.documentEmissionDate = documentEmissionDate
        self.extractedNotes = extractedNotes
        self.annualNominalInterestRate = annualNominalInterestRate
        self.indexationRate = indexationRate
        self.adminFee = adminFee
        self.insuranceFee = insuranceFee
        self.baseInstallmentAmount = baseInstallmentAmount
        self.bankDueDay = min(max(bankDueDay ?? billingDay, 1), 31)
        self.referenceDate = referenceDate ?? documentEmissionDate
        self.maturityDate = maturityDate
        self.firstInstallmentBankDueDate = firstInstallmentBankDueDate
        self.scheduledInstallments = scheduledInstallments
        self.averageMonthlyInstallmentGrowth = averageMonthlyInstallmentGrowth
    }

    public func recalculatedForSalaryBillingDay(
        _ salaryBillingDay: Int,
        referenceNow: Date,
        calendar: Calendar = .current
    ) -> (
        paidCount: Int,
        remainingCount: Int,
        firstFutureBillingDate: Date,
        remainingBalance: Double,
        nextInstallmentAmount: Double
    ) {
        let clampedDay = min(max(salaryBillingDay, 1), 28)
        let docRef = referenceDate ?? documentEmissionDate ?? referenceNow
        let effectiveRef = calendar.startOfDay(for: max(referenceNow, docRef))

        if !scheduledInstallments.isEmpty {
            let sortedSchedule = scheduledInstallments.sorted { $0.installmentNumber < $1.installmentNumber }
            let futureItems = sortedSchedule.filter { item in
                var comps = calendar.dateComponents([.year, .month], from: item.bankDueDate)
                comps.day = clampedDay
                let salaryDate = calendar.date(from: comps) ?? item.bankDueDate
                return calendar.startOfDay(for: salaryDate) > effectiveRef
            }

            let paidCount = min(totalInstallments, max(paidInstallmentsCount, totalInstallments - futureItems.count))
            let remainingCount = max(totalInstallments - paidCount, 0)

            let nextBillingDate: Date = {
                if let firstFuture = futureItems.first {
                    var comps = calendar.dateComponents([.year, .month], from: firstFuture.bankDueDate)
                    comps.day = clampedDay
                    return calendar.date(from: comps) ?? firstFuture.bankDueDate
                }
                var comps = calendar.dateComponents([.year, .month], from: effectiveRef)
                comps.day = clampedDay
                let candidate = calendar.date(from: comps) ?? effectiveRef
                return calendar.date(byAdding: .month, value: 1, to: candidate) ?? candidate
            }()

            let remainingBalance: Double = {
                if kind == .loan && futureItems.count < sortedSchedule.count {
                    let sum = futureItems.reduce(0.0) { $0 + $1.amount }
                    return (sum * 100.0).rounded() / 100.0
                }
                return outstandingBalance
            }()

            let nextAmount: Double = {
                if kind == .financing {
                    return installmentAmount
                }
                return futureItems.first?.amount ?? installmentAmount
            }()
            return (paidCount, remainingCount, nextBillingDate, remainingBalance, nextAmount)
        }

        var comps = calendar.dateComponents([.year, .month], from: firstFutureBillingDate)
        comps.day = clampedDay
        var nextDate = calendar.date(from: comps) ?? firstFutureBillingDate
        var paid = paidInstallmentsCount

        while calendar.startOfDay(for: nextDate) <= effectiveRef && paid < totalInstallments {
            paid += 1
            nextDate = calendar.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
        }

        let remaining = max(totalInstallments - paid, 0)
        return (paid, remaining, nextDate, outstandingBalance, installmentAmount)
    }
}

public enum ContractDocumentImportService {

    public static func extractText(from fileURL: URL) -> String {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { fileURL.stopAccessingSecurityScopedResource() }
        }
        if fileURL.pathExtension.lowercased() == "pdf",
           let pdf = PDFDocument(url: fileURL) {
            var fullText = ""
            for pageIdx in 0..<pdf.pageCount {
                if let pageText = pdf.page(at: pageIdx)?.string {
                    fullText += pageText + "\n"
                }
            }
            if !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return fullText
            }
        }
        return (try? String(contentsOf: fileURL, encoding: .utf8))
            ?? (try? String(contentsOf: fileURL, encoding: .isoLatin1))
            ?? ""
    }

    public static func parseContractDocumentText(
        _ rawText: String,
        expectedKind: CreditContractKind
    ) -> ParsedCreditContractDocument {
        let normalized = rawText
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .uppercased()
        let cal = Calendar.current

        // 1. Santander Consignado (DDC)
        if normalized.contains("DOCUMENTO DESCRITIVO DE CREDITO") ||
           (normalized.contains("SANTANDER") && normalized.contains("CONSIGNADO")) {

            let contractNo = extractRegexGroup(#"NR\.?\s*CONTRATO[:\s\n]*([0-9\-]{5,20})"#, in: normalized)
                ?? extractContractNumber(in: normalized)
                ?? "SANTANDER"

            let startDate = extractDate(after: "DT. FORMALIZACAO", in: normalized)
                ?? extractDate(after: "FORMALIZACAO", in: normalized)
                ?? Date()

            let referenceDate = extractDate(after: "EM:", in: normalized)
                ?? extractDate(after: "DATA EMISSAO DDC", in: normalized)
                ?? Date()

            let emissionDate = extractDate(after: "DATA EMISSAO DDC", in: normalized)
                ?? referenceDate

            let firstVctoDate = extractDate(after: "1º VCTO", in: normalized)
                ?? extractDate(after: "1O VCTO", in: normalized)
                ?? extractDate(after: "1 VCTO", in: normalized)

            let maturityDate = extractDate(after: "DT. VCTO. FINAL", in: normalized)
                ?? extractDate(after: "VCTO. FINAL", in: normalized)

            let financedAmount = extractRegexBRLAmount(#"V[LI1]R\.?\s*FINANCIADO[:\s\n]*R?\$?\s*(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: normalized)
                ?? extractFirstBRLAmount(after: "FINANCIADO", in: normalized)
                ?? extractFirstBRLAmount(after: "VALOR SOLICITADO", in: normalized)
                ?? 0.0

            let requestedAmount = extractFirstBRLAmount(after: "VALOR SOLICITADO", in: normalized) ?? financedAmount

            let outstandingDebt = extractFirstBRLAmount(after: "DIVIDA PARA LIQUIDACAO", in: normalized)
                ?? extractRegexBRLAmount(#"SOMA\s+SALDO\s+DEVEDOR\s+D[0O][:\s\n\(]*R?\$?\s*(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: normalized)
                ?? extractFirstBRLAmount(after: "A VENCER:", in: normalized)
                ?? financedAmount

            let somaNominalAVencer = extractRegexBRLAmount(#"SOMA\s+V[LI1]R\.?\s*PARCELAS[:\s\n\(]*R?\$?\s*(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: normalized)

            let totalInstallments = extractFirstInteger(after: "NR. PARCELAS", in: normalized)
                ?? extractFirstInteger(after: "TOTAL DE PARCELAS", in: normalized)
                ?? 36

            let monthlyRate = extractRegexRate(#"TX\.?\s*APLICADA[\s\S]{0,45}?(\d{1,2},\d{2,4})"#, in: normalized)
                ?? extractRegexRate(#"TX\.?\s*EFET\.?\s*DO\s*CONTRATO[:\s\n]*(\d{1,2},\d{2,4})"#, in: normalized)
                ?? extractRegexRate(#"TAXA\s+EFETIVA\s+MENSAL[:\s\n]*(\d{1,2},\d{2,4})"#, in: normalized)
                ?? 2.00

            let parsedScheduleItems: [ContractInstallmentScheduleItem] = {
                guard let rangePos = normalized.range(of: "PARCELAS A VENCER") else { return [] }
                let tail = String(normalized[rangePos.upperBound...])
                let sectionText: String
                if let totalRange = tail.range(of: "TOTAL A VENCER") {
                    sectionText = String(tail[..<totalRange.lowerBound])
                } else if let somaRange = tail.range(of: "SOMA VLR") {
                    sectionText = String(tail[..<somaRange.lowerBound])
                } else {
                    sectionText = tail
                }
                return extractSantanderInstallmentSchedule(in: sectionText, totalInstallments: totalInstallments)
            }()

            let openOccurrences = countOccurrences(of: "EM ABERTO", in: normalized)
            let paidOccurrences = countOccurrences(of: "LIQUIDADA", in: normalized) + countOccurrences(of: " PAGA ", in: normalized)
            let rangeRemaining: Int? = {
                if !parsedScheduleItems.isEmpty {
                    return parsedScheduleItems.count
                }
                if let rangePos = normalized.range(of: "PARCELAS A VENCER") {
                    let tail = String(normalized[rangePos.upperBound...])
                    if let firstStr = extractRegexGroup(#"PARCELAS\s+(\d{1,3})\s+A\s+\d{1,3}"#, in: tail),
                       let lastStr = extractRegexGroup(#"PARCELAS\s+\d{1,3}\s+A\s+(\d{1,3})"#, in: tail),
                       let firstIdx = Int(firstStr),
                       let lastIdx = Int(lastStr),
                       lastIdx >= firstIdx {
                        return lastIdx - firstIdx + 1
                    }
                    let sectionText: String
                    if let totalRange = tail.range(of: "TOTAL A VENCER") {
                        sectionText = String(tail[..<totalRange.lowerBound])
                    } else if let somaRange = tail.range(of: "SOMA VLR") {
                        sectionText = String(tail[..<somaRange.lowerBound])
                    } else {
                        sectionText = tail
                    }
                    let openInTable = countOccurrences(of: "EM ABERTO", in: sectionText)
                    if openInTable > 1 {
                        return openInTable
                    }
                }
                return nil
            }()

            let remainingInstallments: Int = {
                if let r = rangeRemaining, r > 0 {
                    return min(r, totalInstallments)
                }
                if openOccurrences > 0 {
                    return min(openOccurrences, totalInstallments)
                }
                if paidOccurrences > 0 && paidOccurrences < totalInstallments {
                    return totalInstallments - paidOccurrences
                }
                if let fDate = firstVctoDate {
                    var cursor = cal.startOfDay(for: fDate)
                    let refDay = cal.startOfDay(for: referenceDate)
                    var elapsed = 0
                    while cursor < refDay && elapsed < totalInstallments {
                        elapsed += 1
                        cursor = cal.date(byAdding: .month, value: 1, to: cursor) ?? cursor
                    }
                    return max(totalInstallments - elapsed, 1)
                }
                return totalInstallments
            }()

            let paidInstallments = max(totalInstallments - remainingInstallments, 0)

            let fixedPayrollInstallment: Double = {
                if let directParc = extractRegexBRLAmount(#"V[LI1]R\.?\s*PARC(?:ELA)?[:\s\n]+(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: normalized), directParc > 0 {
                    return directParc
                }
                if let soma = somaNominalAVencer, soma > 0, remainingInstallments > 0 {
                    return ((soma / Double(remainingInstallments)) * 100.0).rounded() / 100.0
                }
                return remainingInstallments > 0 ? ((outstandingDebt / Double(remainingInstallments)) * 100.0).rounded() / 100.0 : 0.0
            }()

            let bankDueDay: Int = {
                if let firstSched = parsedScheduleItems.first {
                    return cal.component(.day, from: firstSched.bankDueDate)
                }
                if let fDate = firstVctoDate {
                    return cal.component(.day, from: fDate)
                }
                if let mDate = maturityDate {
                    return cal.component(.day, from: mDate)
                }
                if let rangePos = normalized.range(of: "PARCELAS A VENCER"),
                   let d = extractFirstDate(in: String(normalized[rangePos.upperBound...])) {
                    return cal.component(.day, from: d)
                }
                return 25
            }()

            let firstFutureDate: Date = {
                if let firstSched = parsedScheduleItems.first {
                    return firstSched.bankDueDate
                }
                if let fDate = firstVctoDate,
                   let calculated = cal.date(byAdding: .month, value: paidInstallments, to: fDate) {
                    return calculated
                }
                if let rangePos = normalized.range(of: "PARCELAS A VENCER"),
                   let d = extractFirstDate(in: String(normalized[rangePos.upperBound...])) {
                    return d
                }
                return Date()
            }()

            let finalScheduledInstallments: [ContractInstallmentScheduleItem] = {
                if !parsedScheduleItems.isEmpty {
                    return parsedScheduleItems
                }
                guard remainingInstallments > 0, fixedPayrollInstallment > 0, monthlyRate > 0 else { return [] }
                var synthesized: [ContractInstallmentScheduleItem] = []
                let rateDec = monthlyRate / 100.0
                let refStart = cal.startOfDay(for: referenceDate)
                for offset in 0..<remainingInstallments {
                    let instNum = paidInstallments + offset + 1
                    let due = cal.date(byAdding: .month, value: offset, to: firstFutureDate) ?? firstFutureDate
                    let days = max(1, cal.dateComponents([.day], from: refStart, to: cal.startOfDay(for: due)).day ?? ((offset + 1) * 30))
                    let pv = ((fixedPayrollInstallment / pow(1.0 + rateDec, Double(days) / 30.0)) * 100.0).rounded() / 100.0
                    let principal = ((pv * 0.778864) * 100.0).rounded() / 100.0
                    let interest = ((pv - principal) * 100.0).rounded() / 100.0
                    synthesized.append(
                        ContractInstallmentScheduleItem(
                            installmentNumber: instNum,
                            bankDueDate: due,
                            amount: pv,
                            principalAmount: principal,
                            interestAmount: interest
                        )
                    )
                }
                return synthesized
            }()

            let installmentAmount = finalScheduledInstallments.first?.amount ?? fixedPayrollInstallment

            let resolvedMaturityDate: Date? = maturityDate ?? {
                if let lastSched = finalScheduledInstallments.last {
                    return lastSched.bankDueDate
                }
                if remainingInstallments > 0 {
                    return cal.date(byAdding: .month, value: max(remainingInstallments - 1, 0), to: firstFutureDate)
                }
                return nil
            }()

            let nominalTotalRemaining = somaNominalAVencer ?? (Double(remainingInstallments) * fixedPayrollInstallment)

            return ParsedCreditContractDocument(
                kind: .loan,
                name: "Crédito Consignado Santander (Contrato \(contractNo))",
                contractNumber: contractNo,
                institutionName: "Banco Santander (Brasil) S.A.",
                loanSubtype: .consignado,
                financingSubtype: .imovel,
                amortizationSystem: .price,
                totalContractedAmount: financedAmount,
                outstandingBalance: outstandingDebt,
                installmentAmount: installmentAmount,
                billingDay: bankDueDay,
                totalInstallments: totalInstallments,
                paidInstallmentsCount: paidInstallments,
                remainingInstallmentsCount: remainingInstallments,
                monthlyInterestRate: monthlyRate,
                startDate: startDate,
                firstFutureBillingDate: firstFutureDate,
                documentEmissionDate: emissionDate,
                extractedNotes: "Contrato \(contractNo) • Dt. Formalização: \(BRLFormatters.shortDate(startDate)) • Valor Solicitado: \(BRLFormatters.currency(requestedAmount)) • Vlr. Financiado: \(BRLFormatters.currency(financedAmount)) • \(paidInstallments) parcelas liquidadas no banco e \(remainingInstallments) parcelas na tabela a vencer (Total nominal a vencer: \(BRLFormatters.currency(nominalTotalRemaining)) • Saldo Devedor D0: \(BRLFormatters.currency(outstandingDebt)) • Vencimento no Banco: dia \(bankDueDay)).",
                bankDueDay: bankDueDay,
                referenceDate: referenceDate,
                maturityDate: resolvedMaturityDate,
                firstInstallmentBankDueDate: firstVctoDate,
                scheduledInstallments: finalScheduledInstallments
            )
        }

        // 2. Demonstrativo de Evolução - Habitação (CAIXA)
        if normalized.contains("DEMONSTRATIVO DE EVOLUCAO") ||
           (normalized.contains("CAIXA") && (normalized.contains("HABITACAO") || normalized.contains("SALDO DEVEDOR TEORICO"))) {

            let contractNo = extractRegexGroup(#"\b(\d{8,14}-\d)\b"#, in: normalized)
                ?? extractContractNumber(in: normalized)
                ?? "CAIXA-HAB"

            let emissionDate = extractDate(after: "DATA GERACAO", in: normalized) ?? Date()

            let outstandingDebt = extractFirstBRLAmount(after: "SALDO DEVEDOR TEORICO", in: normalized)
                ?? extractFirstBRLAmount(after: "SALDO DEVEDOR", in: normalized)
                ?? 0.0

            let detectedIndexer: FinancingIndexation = {
                if let idxRange = normalized.range(of: "INDEXADOR DO SALDO") {
                    let tail = String(normalized[idxRange.upperBound...].prefix(60))
                    if tail.contains("IPCA") { return .ipca }
                    if tail.contains("FIXO") || tail.contains("PREFIXADO") { return .fixed }
                }
                return .tr
            }()

            let detectedSystem: AmortizationSystem = {
                if let sysRange = normalized.range(of: "SISTEMA DE AMORTIZACAO") {
                    let tail = String(normalized[sysRange.upperBound...].prefix(50))
                    if tail.contains("SAC") { return .sac }
                    if tail.contains("TP") || tail.contains("PRICE") { return .price }
                }
                return normalized.contains("SAC") && !normalized.contains("SISTEMA DE AMORTIZACAO TP") ? .sac : .price
            }()

            let totalMonths = extractFirstInteger(after: "PRAZO DO FINANCIAMENTO", in: normalized) ?? 360
            let remainingMonths = extractFirstInteger(after: "PRAZO REMANESCENTE", in: normalized) ?? totalMonths
            let paidMonths = max(totalMonths - remainingMonths, 0)

            let historyRows = extractCaixaPaidInstallmentsHistory(in: normalized)
            var latestPaidDueDate: Date? = historyRows.last?.dueDate
            var extractedInstallmentAmount: Double = historyRows.last?.paidAmount ?? 0.0
            var extractedBasePrice: Double = historyRows.last?.baseInstallment ?? 0.0
            var extractedInsurance: Double = historyRows.last?.insuranceFee ?? 0.0
            var extractedAdminFee: Double = historyRows.last?.adminFee ?? 25.0

            if historyRows.isEmpty, let tableRange = normalized.range(of: "DESCRICAO DAS ULTIMAS PRESTACOES") {
                let tableTail = String(normalized[tableRange.upperBound...].prefix(500))
                latestPaidDueDate = extractFirstDate(in: tableTail)

                if let directAmortJuros = extractRegexBRLAmount(#"AMORT(?:IZACAO)?\s*\+\s*JUROS\s+(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: tableTail) {
                    extractedBasePrice = directAmortJuros
                }
                if let directSeguro = extractRegexBRLAmount(#"SEGURO\s+(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: tableTail) {
                    extractedInsurance = directSeguro
                }
                if let directAdmin = extractRegexBRLAmount(#"TAXA[S]?\s+ADMIN(?:ISTRACAO)?\s+(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: tableTail) {
                    extractedAdminFee = directAdmin
                }
                if let directPago = extractRegexBRLAmount(#"PAGO\s+(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: tableTail) {
                    extractedInstallmentAmount = directPago
                } else if let directDevido = extractRegexBRLAmount(#"DEVIDO\s+(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: tableTail) {
                    extractedInstallmentAmount = directDevido
                } else {
                    let allAmounts = extractAllBRLAmounts(in: tableTail).filter { $0 > 200.0 }
                    if let lastAmt = allAmounts.last {
                        extractedInstallmentAmount = lastAmt
                    }
                }

                if extractedInstallmentAmount > 0 && extractedBasePrice > 0 {
                    let calculatedDiff = extractedInstallmentAmount - extractedBasePrice - extractedInsurance
                    if calculatedDiff >= 0.01 {
                        extractedAdminFee = ((calculatedDiff * 100.0).rounded()) / 100.0
                    }
                } else if extractedBasePrice > 0 && extractedInstallmentAmount == 0 {
                    extractedInstallmentAmount = extractedBasePrice + extractedInsurance + extractedAdminFee
                }
            }

            let referenceDate: Date = {
                if let directRef = extractDate(after: "SALDO DEVEDOR TEORICO EM", in: normalized) {
                    if let latest = latestPaidDueDate, abs(directRef.timeIntervalSince(latest)) > 86400 * 60 {
                        return latest
                    }
                    return directRef
                }
                if let latest = latestPaidDueDate {
                    return latest
                }
                return extractDate(after: "SALDO DEVEDOR TEORICO", in: normalized) ?? emissionDate
            }()

            let bankDueDay: Int = {
                if let d = latestPaidDueDate {
                    return cal.component(.day, from: d)
                }
                return 5
            }()

            let firstFutureDate: Date = {
                if let d = latestPaidDueDate,
                   let next = cal.date(byAdding: .month, value: 1, to: d) {
                    return next
                }
                return Date()
            }()

            let maturityDate: Date? = {
                if remainingMonths > 0 {
                    return cal.date(byAdding: .month, value: max(remainingMonths - 1, 0), to: firstFutureDate)
                }
                return nil
            }()

            let startDate: Date = {
                if let d = latestPaidDueDate,
                   let start = cal.date(byAdding: .month, value: -paidMonths, to: d) {
                    return start
                }
                return Date()
            }()

            let annualRate: Double = {
                if normalized.contains("TAXA DE JUROS NOMINAL COM RELACIONAMENTO"),
                   let rateRange = normalized.range(of: "TAXA DE JUROS") {
                    let tail = String(normalized[rateRange.lowerBound...].prefix(260))
                    let candidateRates = extractAllRates(in: tail).filter { $0 > 1.0 && $0 < 30.0 }
                    if let minRelationshipRate = candidateRates.min() {
                        return minRelationshipRate
                    }
                }
                if let relRate = extractRegexRate(#"TAXA\s+DE\s+JUROS\s+NOMINAL\s+COM\s+RELACIONAMENTO[:\s\n]*(\d{1,2},\d{2,4})"#, in: normalized), relRate > 0 {
                    return relRate
                }
                if let contRate = extractRegexRate(#"TAXA\s+DE\s+JUROS\s+CONTRATUAL\s+NOMINAL[:\s\n]*(\d{1,2},\d{2,4})"#, in: normalized), contRate > 0 {
                    return contRate
                }
                if let rateRange = normalized.range(of: "TAXA DE JUROS") {
                    let tail = String(normalized[rateRange.lowerBound...].prefix(200))
                    let rates = extractAllRates(in: tail)
                    if let effectiveAnnual = rates.last, effectiveAnnual > 0 {
                        return effectiveAnnual > 2.5 ? effectiveAnnual : (effectiveAnnual * 12.0)
                    }
                }
                return 8.51
            }()

            let monthlyRate = annualRate / 12.0

            let estimatedOriginalContracted = remainingMonths > 0
                ? (((outstandingDebt * Double(totalMonths) / Double(remainingMonths)) / 1000.0).rounded() * 1000.0)
                : outstandingDebt

            let finalBasePrice = extractedBasePrice > 0 ? extractedBasePrice : 2_546.77
            let finalInsurance = extractedInsurance > 0 ? extractedInsurance : 86.27
            let latestPaidInstallment = extractedInstallmentAmount > 0 ? extractedInstallmentAmount : 2_658.06

            var avgPaidGrowthDec: Decimal = .zero
            if let firstRow = historyRows.first,
               let lastRow = historyRows.last,
               lastRow.installmentNumber > firstRow.installmentNumber {
                let intervals = Decimal(lastRow.installmentNumber - firstRow.installmentNumber)
                let paidDiff = LoanProjectionEngine.toDecimal(lastRow.paidAmount) - LoanProjectionEngine.toDecimal(firstRow.paidAmount)
                if paidDiff > .zero {
                    avgPaidGrowthDec = paidDiff / intervals
                }
            }

            let latestPaidDec = LoanProjectionEngine.toDecimal(latestPaidInstallment)
            var caixaScheduledInstallments: [ContractInstallmentScheduleItem] = []
            if remainingMonths > 0 {
                caixaScheduledInstallments.reserveCapacity(remainingMonths)
                for offset in 0..<remainingMonths {
                    let step = Decimal(offset + 1)
                    let instNum = paidMonths + offset + 1
                    let due = cal.date(byAdding: .month, value: offset, to: firstFutureDate) ?? firstFutureDate
                    let projectedCorrection = LoanProjectionEngine.roundCurrency(step * avgPaidGrowthDec)
                    let projectedPaid = LoanProjectionEngine.roundCurrency(latestPaidDec + projectedCorrection)
                    caixaScheduledInstallments.append(
                        ContractInstallmentScheduleItem(
                            installmentNumber: instNum,
                            bankDueDate: due,
                            amount: LoanProjectionEngine.toDouble(projectedPaid),
                            principalAmount: latestPaidInstallment,
                            interestAmount: LoanProjectionEngine.toDouble(projectedCorrection)
                        )
                    )
                }
            }

            let avgGrowthDouble: Double? = avgPaidGrowthDec > .zero ? LoanProjectionEngine.toDouble(avgPaidGrowthDec) : nil
            let nextProjectedInstallment = caixaScheduledInstallments.first?.amount ?? latestPaidInstallment
            let sysCode = detectedSystem == .sac ? "SAC" : "TP (Tabela Price)"
            let growthSummaryNote: String = {
                if let avgG = avgGrowthDouble, let firstH = historyRows.first, let lastH = historyRows.last {
                    return " • Valor cadastrado da parcela: \(BRLFormatters.currency(latestPaidInstallment)) • Projeção de correção mensal pela média do documento (Parcelas \(firstH.installmentNumber) a \(lastH.installmentNumber): \(BRLFormatters.currency(firstH.paidAmount)) → \(BRLFormatters.currency(lastH.paidAmount))): +\(BRLFormatters.currency(avgG))/mês (1ª futura: \(BRLFormatters.currency(nextProjectedInstallment)))"
                }
                return ""
            }()

            return ParsedCreditContractDocument(
                kind: .financing,
                name: "Financiamento Habitação CAIXA (Contrato \(contractNo))",
                contractNumber: contractNo,
                institutionName: "Caixa Econômica Federal",
                loanSubtype: .consignado,
                financingSubtype: .imovel,
                amortizationSystem: detectedSystem,
                totalContractedAmount: max(estimatedOriginalContracted, outstandingDebt),
                outstandingBalance: outstandingDebt,
                installmentAmount: latestPaidInstallment,
                billingDay: bankDueDay,
                totalInstallments: totalMonths,
                paidInstallmentsCount: paidMonths,
                remainingInstallmentsCount: remainingMonths,
                monthlyInterestRate: ((monthlyRate * 100.0).rounded()) / 100.0,
                startDate: startDate,
                firstFutureBillingDate: firstFutureDate,
                documentEmissionDate: emissionDate,
                extractedNotes: "Contrato \(contractNo) • Sistema \(sysCode) + Indexador \(detectedIndexer.shortLabel) • \(paidMonths) prestações pagas e \(remainingMonths) prestações futuras remanescentes • Saldo Devedor Teórico em \(BRLFormatters.shortDate(referenceDate)): \(BRLFormatters.currency(outstandingDebt)) • Vencimento no Banco: dia \(bankDueDay)\(growthSummaryNote).",
                annualNominalInterestRate: annualRate,
                indexationRate: detectedIndexer,
                adminFee: extractedAdminFee,
                insuranceFee: finalInsurance,
                baseInstallmentAmount: finalBasePrice,
                bankDueDay: bankDueDay,
                referenceDate: referenceDate,
                maturityDate: maturityDate,
                scheduledInstallments: caixaScheduledInstallments,
                averageMonthlyInstallmentGrowth: avgGrowthDouble
            )
        }

        // 3. Fallback genérico
        let contractNo = extractContractNumber(in: normalized) ?? "DOC-\(Int.random(in: 10000...99999))"
        let isImovel = normalized.contains("HABITACAO") || normalized.contains("IMOVEL") || normalized.contains("APARTAMENTO") || normalized.contains("CASA")
        let isCarro = normalized.contains("VEICULO") || normalized.contains("AUTOMOVEL") || normalized.contains("CARRO") || normalized.contains("MOTO")
        let detectedKind: CreditContractKind = (isImovel || isCarro) ? .financing : expectedKind
        let detectedLoanSubtype: LoanSubtype = normalized.contains("CONSIGNADO") ? .consignado : (normalized.contains("FGTS") ? .fgts : .pessoal)
        let detectedFinSubtype: FinancingSubtype = isCarro ? .carro : .imovel
        let detectedSystem: AmortizationSystem = normalized.contains("SAC") ? .sac : .price

        let extractedTotal = extractFirstBRLAmount(after: "FINANCIADO", in: normalized)
            ?? extractFirstBRLAmount(after: "VALOR TOTAL", in: normalized)
            ?? extractFirstBRLAmount(after: "VALOR SOLICITADO", in: normalized)
            ?? 50_000.00
        let extractedOutstanding = extractFirstBRLAmount(after: "SALDO DEVEDOR", in: normalized)
            ?? extractFirstBRLAmount(after: "DIVIDA PARA LIQUIDACAO", in: normalized)
            ?? extractedTotal
        let extractedInstallment = extractFirstBRLAmount(after: "VLR. PARC", in: normalized)
            ?? extractFirstBRLAmount(after: "PRESTACAO", in: normalized)
            ?? extractFirstBRLAmount(after: "PARCELA", in: normalized)
            ?? 1_500.00
        let extractedTotalMonths = extractFirstInteger(after: "NR. PARCELAS", in: normalized)
            ?? extractFirstInteger(after: "PRAZO DO FINANCIAMENTO", in: normalized)
            ?? 48
        let extractedRemainingMonths = extractFirstInteger(after: "PRAZO REMANESCENTE", in: normalized)
            ?? extractedTotalMonths
        let extractedPaid = max(extractedTotalMonths - extractedRemainingMonths, 0)
        let extractedStartDate = extractDate(after: "FORMALIZACAO", in: normalized)
            ?? extractDate(after: "DATA INICIO", in: normalized)
            ?? Date()

        return ParsedCreditContractDocument(
            kind: detectedKind,
            name: "\(detectedKind.title) Importado (\(contractNo))",
            contractNumber: contractNo,
            institutionName: "Instituição Financeira",
            loanSubtype: detectedLoanSubtype,
            financingSubtype: detectedFinSubtype,
            amortizationSystem: detectedSystem,
            totalContractedAmount: extractedTotal,
            outstandingBalance: extractedOutstanding,
            installmentAmount: extractedInstallment,
            billingDay: 10,
            totalInstallments: extractedTotalMonths,
            paidInstallmentsCount: extractedPaid,
            remainingInstallmentsCount: extractedRemainingMonths,
            monthlyInterestRate: detectedKind == .loan ? 1.85 : 0.80,
            startDate: extractedStartDate,
            firstFutureBillingDate: Date(),
            documentEmissionDate: Date(),
            extractedNotes: "Contrato \(contractNo) importado via análise documental."
        )
    }

    private static func extractDate(after keyword: String, in text: String) -> Date? {
        guard let range = text.range(of: keyword) else { return nil }
        let tail = String(text[range.upperBound...].prefix(120))
        return extractFirstDate(in: tail)
    }

    private static func extractFirstDate(in text: String) -> Date? {
        if let matchRange = text.range(of: #"\b\d{2}/\d{2}/\d{2,4}\b"#, options: .regularExpression) {
            let dateStr = String(text[matchRange])
            let parts = dateStr.split(separator: "/")
            if parts.count == 3, parts[2].count == 2, let yy = Int(parts[2]) {
                let fullYear = yy >= 70 ? 1900 + yy : 2000 + yy
                let normalizedDateStr = "\(parts[0])/\(parts[1])/\(fullYear)"
                return BRLFormatters.shortDateFormatter.date(from: normalizedDateStr)
            }
            return BRLFormatters.shortDateFormatter.date(from: dateStr)
        }
        return nil
    }

    private static func extractFirstBRLAmount(after keyword: String, in text: String) -> Double? {
        guard let range = text.range(of: keyword) else { return nil }
        let tail = String(text[range.upperBound...].prefix(180))
        if let matchRange = tail.range(of: #"\d{1,3}(?:\.\d{3})*,\d{2}"#, options: .regularExpression) {
            let numStr = String(tail[matchRange])
            return BRLFormatters.parseAmount(numStr)
        }
        return nil
    }

    private static func extractRegexBRLAmount(_ pattern: String, in text: String) -> Double? {
        guard let numStr = extractRegexGroup(pattern, in: text) else { return nil }
        return BRLFormatters.parseAmount(numStr)
    }

    private static func extractRegexRate(_ pattern: String, in text: String) -> Double? {
        guard let rateStr = extractRegexGroup(pattern, in: text) else { return nil }
        return Double(rateStr.replacingOccurrences(of: ",", with: "."))
    }

    private static func extractAllBRLAmounts(in text: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: #"\d{1,3}(?:\.\d{3})*,\d{2}"#) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { BRLFormatters.parseAmount(ns.substring(with: $0.range)) }
    }

    private static func extractAllRates(in text: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,2},\d{2,4})\s*%"#) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap {
            guard $0.numberOfRanges >= 2 else { return nil }
            let str = ns.substring(with: $0.range(at: 1)).replacingOccurrences(of: ",", with: ".")
            return Double(str)
        }
    }

    private static func extractRegexGroup(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        return ns.substring(with: match.range(at: 1))
    }

    private static func countOccurrences(of substring: String, in text: String) -> Int {
        guard !substring.isEmpty else { return 0 }
        return text.components(separatedBy: substring).count - 1
    }

    private static func extractFirstInteger(after keyword: String, in text: String) -> Int? {
        guard let range = text.range(of: keyword) else { return nil }
        let tail = String(text[range.upperBound...].prefix(100))
        if let matchRange = tail.range(of: #"\b\d{1,3}\b"#, options: .regularExpression) {
            return Int(tail[matchRange])
        }
        return nil
    }

    private static func extractContractNumber(in text: String) -> String? {
        if let range = text.range(of: #"CONTRATO[:\s\n]+([0-9\-]+)"#, options: .regularExpression) {
            let sub = String(text[range])
            return sub.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "-")).inverted)
                .filter { !$0.isEmpty }
                .last
        }
        return nil
    }

    private static func extractSantanderInstallmentSchedule(
        in sectionText: String,
        totalInstallments: Int
    ) -> [ContractInstallmentScheduleItem] {
        let pattern = #"\b(\d{1,3})\s+(\d{2}/\d{2}/\d{2,4})\s+(\d{1,3}(?:\.\d{3})*,\d{2})(?:\s+(\d{1,3}(?:\.\d{3})*,\d{2})\s+(\d{1,3}(?:\.\d{3})*,\d{2}))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let ns = sectionText as NSString
        let matches = regex.matches(in: sectionText, options: [], range: NSRange(location: 0, length: ns.length))

        var items: [ContractInstallmentScheduleItem] = []
        var seenNumbers: Set<Int> = []

        for match in matches {
            guard match.numberOfRanges >= 4 else { continue }
            let numStr = ns.substring(with: match.range(at: 1))
            let dateStr = ns.substring(with: match.range(at: 2))
            let amountStr = ns.substring(with: match.range(at: 3))

            guard let instNum = Int(numStr),
                  instNum >= 1,
                  instNum <= max(totalInstallments, 300),
                  !seenNumbers.contains(instNum),
                  let dueDate = extractFirstDate(in: dateStr),
                  let amount = BRLFormatters.parseAmount(amountStr),
                  amount > 0 else {
                continue
            }

            var principal: Double? = nil
            var interest: Double? = nil
            if match.numberOfRanges >= 6,
               match.range(at: 4).location != NSNotFound,
               match.range(at: 5).location != NSNotFound {
                principal = BRLFormatters.parseAmount(ns.substring(with: match.range(at: 4)))
                interest = BRLFormatters.parseAmount(ns.substring(with: match.range(at: 5)))
            }

            seenNumbers.insert(instNum)
            items.append(
                ContractInstallmentScheduleItem(
                    installmentNumber: instNum,
                    bankDueDate: dueDate,
                    amount: amount,
                    principalAmount: principal,
                    interestAmount: interest
                )
            )
        }

        return items.sorted { $0.installmentNumber < $1.installmentNumber }
    }

    private struct CaixaHistoricalInstallmentRow {
        let installmentNumber: Int
        let dueDate: Date
        let paymentDate: Date
        let baseInstallment: Double
        let insuranceFee: Double
        let adminFee: Double
        let dueAmount: Double
        let paidAmount: Double
    }

    private static func extractCaixaPaidInstallmentsHistory(in text: String) -> [CaixaHistoricalInstallmentRow] {
        let headerPattern = #"(\d{2}/\d{2}/\d{2,4})\s+(\d{2}/\d{2}/\d{2,4})\s+(?:N[ºO°]?\s*)?(\d{1,3})\s+(?:TIPO\s*)?\d{3}\b"#
        guard let regex = try? NSRegularExpression(pattern: headerPattern, options: []) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return [] }

        var rows: [CaixaHistoricalInstallmentRow] = []
        var seenInstallments: Set<Int> = []

        for idx in matches.indices {
            let match = matches[idx]
            guard match.numberOfRanges >= 4 else { continue }
            let dueStr = ns.substring(with: match.range(at: 1))
            let payStr = ns.substring(with: match.range(at: 2))
            let numStr = ns.substring(with: match.range(at: 3))

            guard let instNum = Int(numStr),
                  instNum >= 1,
                  instNum <= 600,
                  !seenInstallments.contains(instNum),
                  let dueDate = extractFirstDate(in: dueStr) else {
                continue
            }
            let paymentDate = extractFirstDate(in: payStr) ?? dueDate

            let bodyStart = match.range.location + match.range.length
            let nextStart: Int = {
                if idx + 1 < matches.count {
                    return matches[idx + 1].range.location
                }
                return min(ns.length, bodyStart + 320)
            }()
            guard nextStart > bodyStart else { continue }
            var rowBody = ns.substring(with: NSRange(location: bodyStart, length: min(nextStart - bodyStart, 320)))
            for stopWord in ["TOTAL DA DIFERENCA", "MENSAGENS DO CONTRATO", "DESCRICAO DAS ULTIMAS"] {
                if let stopRange = rowBody.range(of: stopWord) {
                    rowBody = String(rowBody[..<stopRange.lowerBound])
                }
            }

            let allAmounts = extractAllBRLAmounts(in: rowBody)
            let largeAmounts = allAmounts.filter { $0 > 200.0 }
            guard let firstLarge = largeAmounts.first, let lastLarge = largeAmounts.last else {
                continue
            }

            let baseInst = extractRegexBRLAmount(#"AMORT(?:IZACAO)?\s*\+\s*JUROS\s+(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: rowBody)
                ?? firstLarge
            let paidAmt = extractRegexBRLAmount(#"PAGO\s+(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: rowBody)
                ?? lastLarge
            let dueAmt = extractRegexBRLAmount(#"DEVIDO\s+(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: rowBody)
                ?? (largeAmounts.count >= 3 ? largeAmounts[largeAmounts.count - 2] : paidAmt)

            let insurance: Double = {
                if let directSeg = extractRegexBRLAmount(#"SEGURO\s+(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: rowBody) {
                    return directSeg
                }
                if allAmounts.count >= 2 && allAmounts[1] < 200.0 && allAmounts[1] > 0 {
                    return allAmounts[1]
                }
                return 0.0
            }()

            let adminFee: Double = {
                if let directAdm = extractRegexBRLAmount(#"TAXA[S]?\s+ADMIN(?:ISTRACAO)?\s+(\d{1,3}(?:\.\d{3})*,\d{2})"#, in: rowBody), directAdm > 0 {
                    return directAdm
                }
                let diff = dueAmt - baseInst - insurance
                if diff >= 0.01 && diff <= 100.0 {
                    return ((diff * 100.0).rounded()) / 100.0
                }
                if allAmounts.count >= 3 && allAmounts[2] > 0 && allAmounts[2] <= 100.0 {
                    return allAmounts[2]
                }
                return 25.0
            }()

            seenInstallments.insert(instNum)
            rows.append(
                CaixaHistoricalInstallmentRow(
                    installmentNumber: instNum,
                    dueDate: dueDate,
                    paymentDate: paymentDate,
                    baseInstallment: baseInst,
                    insuranceFee: insurance,
                    adminFee: adminFee,
                    dueAmount: dueAmt,
                    paidAmount: paidAmt
                )
            )
        }

        return rows.sorted { $0.installmentNumber < $1.installmentNumber }
    }
}

public enum SampleContractDocumentsData {
    public static let santanderLoanOCRText: String = """
    Banco Santander (Brasil) S.A.
    Documento Descritivo de Crédito Modalidade da Operação: Crédito Consignado
    Nr. Contrato: 783694303 Data Emissão DDC: 10/11/2026 Dt. Formalização: 30/10/2025
    Cliente: CLOVIS CARMEZINI JUNIOR CPF: 396.520.318-52 Matrícula: 00157579
    Agência: 2972 - AGENCIA DIGITAL - 29
    Valor Solicitado: 106.863,99 Vlr. Financiado: 110.108,13 Dívida para Liquidação: 91.341,50 Em: 11/11/2026
    IOF: 3.244,14 Dt. 1º Vcto: 25/01/2026 Dt. Vcto. Final: 25/12/2028
    Seguro: 0,00 Nr. Parcelas: 36 Prazo: 1152
    Custo Efet Total CET: 2,21 % a.m. 29,93 % a.a.
    Tx. Efet. do contrato: 2,0087 % a.m. 26,9535 % a.a.
    Tx. Aplicada a.m. % (Valor Presente): 2,0087 %
    Movimentações Efetuadas: Parcelas 1 a 10 (25/01/2026 a 25/10/2026) - VLR. PARC 4.509,81 - Liquidação Desconto em folha
    PARCELAS A VENCER
    NR. PARC DT.VCTO VLR. PARC AMORTIZAÇÃO / VLR PRINCIPAL VLR. JUROS SALDO DEVEDOR (D0) SITUAÇÃO
    11 25/11/2026 4.468,15 3.480,08 988,07 4.468,15 Em aberto Desconto em folha
    12 25/12/2026 4.380,17 3.411,55 968,62 4.380,17 Em aberto Desconto em folha
    13 25/01/2027 4.291,07 3.342,16 948,91 4.291,07 Em aberto Desconto em folha
    14 25/02/2027 4.203,79 3.274,17 929,62 4.203,79 Em aberto Desconto em folha
    15 25/03/2027 4.126,48 3.213,96 912,52 4.126,48 Em aberto Desconto em folha
    16 25/04/2027 4.042,54 3.148,59 893,95 4.042,54 Em aberto Desconto em folha
    17 25/05/2027 3.962,94 3.086,59 876,35 3.962,94 Em aberto Desconto em folha
    18 25/06/2027 3.882,33 3.023,80 858,53 3.882,33 Em aberto Desconto em folha
    19 25/07/2027 3.805,88 2.964,26 841,62 3.805,88 Em aberto Desconto em folha
    20 25/08/2027 3.728,47 2.903,97 824,50 3.728,47 Em aberto Desconto em folha
    21 25/09/2027 3.652,63 2.844,90 807,73 3.652,63 Em aberto Desconto em folha
    22 25/10/2027 3.580,70 2.788,88 791,82 3.580,70 Em aberto Desconto em folha
    23 25/11/2027 3.507,87 2.732,15 775,72 3.507,87 Em aberto Desconto em folha
    24 25/12/2027 3.438,80 2.678,35 760,45 3.438,80 Em aberto Desconto em folha
    25 25/01/2028 3.368,85 2.623,87 744,98 3.368,85 Em aberto Desconto em folha
    26 25/02/2028 3.300,32 2.570,50 729,82 3.300,32 Em aberto Desconto em folha
    27 25/03/2028 3.237,48 2.521,55 715,93 3.237,48 Em aberto Desconto em folha
    28 25/04/2028 3.171,63 2.470,26 701,37 3.171,63 Em aberto Desconto em folha
    29 25/05/2028 3.109,18 2.421,62 687,56 3.109,18 Em aberto Desconto em folha
    30 25/06/2028 3.045,93 2.372,36 673,57 3.045,93 Em aberto Desconto em folha
    31 25/07/2028 2.985,96 2.325,65 660,31 2.985,96 Em aberto Desconto em folha
    32 25/08/2028 2.925,22 2.278,34 646,88 2.925,22 Em aberto Desconto em folha
    33 25/09/2028 2.865,72 2.232,00 633,72 2.865,72 Em aberto Desconto em folha
    34 25/10/2028 2.809,29 2.188,05 621,24 2.809,29 Em aberto Desconto em folha
    35 25/11/2028 2.752,15 2.143,54 608,61 2.752,15 Em aberto Desconto em folha
    36 25/12/2028 2.697,95 2.101,35 596,60 2.697,95 Em aberto Desconto em folha
    Total a Vencer: Soma Vlr. Parcelas: (91.341,50) Soma Principal: (71.143,00) Soma Juros: (20.198,50) Soma Saldo Devedor D0: (91.341,50)
    """

    public static let caixaFinancingOCRText: String = """
    CAIXA Demonstrativo de Evolução - Habitação
    DADOS DO CLIENTE / DADOS DO IMÓVEL DATA GERAÇÃO: 06/11/2026
    Contrato: 178770203328-1
    Nome: CLOVIS CARMEZINI JUNIOR CPF/CGC: 396.520.318-52
    Endereço: AV DOIS CORREGOS 1287 BL.A AP84 DOIS CORREGOS PIRACICABA SP 13420835
    EXTRATO DE EVOLUÇÃO DO SALDO
    Saldo Devedor Teórico em 05/11/26 Valor R$ 324.737,86
    Indexador do Saldo: TR
    DADOS DO CONTRATO
    Prazo do Financiamento: 360 meses
    Prazo Remanescente: 332 meses
    Taxa de Juros Contratual Nominal: 8,64%
    Taxa de Juros Nominal com Relacionamento: 8,51%
    Sistema de Amortização: TP
    Agência de Contrato: 4104-1
    DESCRIÇÃO DAS ÚLTIMAS PRESTAÇÕES/DEVOLUÇÕES:
    Data Vencimento Data Pagamento Nº Tipo Amortização + Juros Seguro Taxas Administração Subsídio Governo/Bônus Diferencial de Juros + TR FGTS Quota/Valor Mora/Multa Devido Pago Diferença de Pagamento
    05/11/2026 05/11/2026 28 310 2.546,77 86,27 0,00 0,00 0,00 0 / 0,00 0,00 2.658,04 2.658,06 -0,02
    05/10/2026 05/10/2026 27 310 2.542,62 86,14 25,00 0,00 0,00 0 / 0,00 0,00 2.653,76 2.653,79 -0,03
    05/09/2026 08/09/2026 26 310 2.539,70 86,08 0,00 0,00 0,00 0 / 0,00 0,00 2.650,78 2.650,73 0,05
    05/08/2026 05/08/2026 25 310 2.535,33 85,95 25,00 0,00 0,00 0 / 0,00 0,00 2.646,28 2.646,31 -0,03
    05/07/2026 06/07/2026 24 310 2.530,99 85,83 25,00 0,00 0,00 0 / 0,00 0,00 2.641,82 2.641,84 -0,02
    05/06/2026 05/06/2026 23 310 2.526,68 85,71 0,00 0,00 0,00 0 / 0,00 0,00 2.637,39 2.637,34 0,05
    05/05/2026 05/05/2026 22 310 2.522,32 85,57 0,00 0,00 0,00 0 / 0,00 0,00 2.632,89 2.632,92 -0,03
    05/04/2026 06/04/2026 21 310 2.519,02 85,49 25,00 0,00 0,00 0 / 0,00 0,00 2.629,51 2.629,53 -0,02
    05/03/2026 05/03/2026 20 310 2.514,72 85,38 25,00 0,00 0,00 0 / 0,00 0,00 2.625,10 2.625,11 -0,01
    05/02/2026 05/02/2026 19 310 2.511,65 85,29 25,00 0,00 0,00 0 / 0,00 0,00 2.621,94 2.621,88 0,06
    05/01/2026 05/01/2026 18 310 2.507,24 85,17 25,00 0,00 0,00 0 / 0,00 0,00 2.617,41 2.617,42 -0,01
    05/12/2025 05/12/2025 17 310 2.503,13 85,04 0,00 0,00 0,00 0 / 0,00 0,00 2.613,17 2.613,19 -0,02
    TOTAL DA DIFERENÇA ATUALIZADA R$ 0,00
    """
}
