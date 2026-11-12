// Sources/FinSense/Models/CategoryProvision.swift
import Foundation

public enum ProvisionEditScope: String, Codable, CaseIterable, Identifiable, Hashable {
    case onlyThisMonth
    case thisAndFutureMonths

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .onlyThisMonth:
            return "Aplicar somente a este mês"
        case .thisAndFutureMonths:
            return "Aplicar a este e a todos os meses futuros"
        }
    }
}

public enum ProvisionDeleteScope: String, Codable, CaseIterable, Identifiable, Hashable {
    case onlyThisMonth
    case fromThisMonthOnward
    case allOccurrences

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .onlyThisMonth:
            return "Excluir somente deste mês"
        case .fromThisMonthOnward:
            return "Excluir deste mês em diante"
        case .allOccurrences:
            return "Excluir todas as ocorrências"
        }
    }
}

public enum ProvisionStatusLevel: String, Codable, CaseIterable, Hashable {
    case normal = "Normal"      // Abaixo de 80%
    case warning = "Alerta"     // Entre 80% e 100%
    case exceeded = "Estourado" // Acima de 100%

    public var title: String { rawValue }

    public var colorHex: String {
        switch self {
        case .normal: return "#10B981"   // Verde
        case .warning: return "#F59E0B"  // Amarelo
        case .exceeded: return "#EF4444" // Vermelho
        }
    }

    public var iconSymbol: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .exceeded: return "xmark.octagon.fill"
        }
    }
}

public struct CategoryProvision: Identifiable, Codable, Hashable {
    public var id: UUID
    public var categoryId: UUID
    public var year: Int
    public var month: Int
    public var estimatedAmount: Double
    public var repeatForFutureMonths: Bool
    public var monthlyOverrides: [Int: Double]?
    public var excludedYearMonthKeys: Set<Int>?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        categoryId: UUID,
        year: Int,
        month: Int,
        estimatedAmount: Double,
        repeatForFutureMonths: Bool = true,
        monthlyOverrides: [Int: Double]? = nil,
        excludedYearMonthKeys: Set<Int>? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.categoryId = categoryId
        self.year = year
        self.month = min(max(month, 1), 12)
        self.estimatedAmount = max(0, estimatedAmount)
        self.repeatForFutureMonths = repeatForFutureMonths
        self.monthlyOverrides = monthlyOverrides
        self.excludedYearMonthKeys = excludedYearMonthKeys
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, categoryId, year, month, estimatedAmount, repeatForFutureMonths, monthlyOverrides, excludedYearMonthKeys, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        self.id = (try? c.decode(UUID.self, forKey: AnyKey("id"))) ?? UUID()
        if let cat = try? c.decode(UUID.self, forKey: AnyKey("categoryId")) { self.categoryId = cat }
        else if let cat = try? c.decode(UUID.self, forKey: AnyKey("category_id")) { self.categoryId = cat }
        else { self.categoryId = UUID() }

        self.year = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("year"))) ?? 2026
        self.month = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("month"))) ?? 1
        self.estimatedAmount = abs((try? c.decodeIfPresent(Double.self, forKey: AnyKey("estimatedAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("estimated_amount"))) ?? 0.0)
        self.repeatForFutureMonths = (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("repeatForFutureMonths")))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("repeat_for_future_months"))) ?? true
        self.monthlyOverrides = (try? c.decodeIfPresent([Int: Double].self, forKey: AnyKey("monthlyOverrides")))
            ?? (try? c.decodeIfPresent([Int: Double].self, forKey: AnyKey("monthly_overrides")))
        self.excludedYearMonthKeys = (try? c.decodeIfPresent(Set<Int>.self, forKey: AnyKey("excludedYearMonthKeys")))
            ?? (try? c.decodeIfPresent(Set<Int>.self, forKey: AnyKey("excluded_year_month_keys")))
        self.createdAt = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("createdAt")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("created_at"))) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(categoryId, forKey: .categoryId)
        try c.encode(year, forKey: .year)
        try c.encode(month, forKey: .month)
        try c.encode(estimatedAmount, forKey: .estimatedAmount)
        try c.encode(repeatForFutureMonths, forKey: .repeatForFutureMonths)
        try c.encodeIfPresent(monthlyOverrides, forKey: .monthlyOverrides)
        try c.encodeIfPresent(excludedYearMonthKeys, forKey: .excludedYearMonthKeys)
        try c.encode(createdAt, forKey: .createdAt)
    }

    public var yearMonthKey: Int {
        year * 100 + month
    }
}

public struct CategoryProvisionEnvelope: Identifiable, Hashable {
    public var id: UUID { category.id }
    public let category: CategoryItem
    public let provision: CategoryProvision
    public var provisionId: UUID { provision.id }

    public let estimatedAmount: Double
    public let realizedExpense: Double
    public let remainingProvision: Double
    public let exceededAmount: Double
    public let rawProgressPercentage: Double
    public let clampedProgressPercentage: Double
    public let status: ProvisionStatusLevel
    public let isFreeBudgetLocalOverride: Bool
    public var repeatForFutureMonths: Bool {
        provision.repeatForFutureMonths
    }
    public let isInheritedFromPreviousMonth: Bool

    public var freeBudgetEstimated: Double { estimatedAmount }
    public var freeBudgetRealizedExpense: Double { realizedExpense }
    public var freeBudgetRemaining: Double { remainingProvision }

    public var isInvestmentCategory: Bool {
        category.name.localizedCaseInsensitiveContains("aporte") || category.name.localizedCaseInsensitiveContains("investimento")
    }

    public var statusTitle: String {
        if isInvestmentCategory {
            guard estimatedAmount > 0 else { return "Pendente" }
            if realizedExpense > estimatedAmount + 0.001 {
                return "Superado"
            } else if rawProgressPercentage >= 99.9 {
                return "Meta Atingida"
            } else if rawProgressPercentage >= 80.0 {
                return "Quase lá"
            } else if realizedExpense > 0 {
                return "Em andamento"
            } else {
                return "Pendente"
            }
        }
        return status.title
    }

    public var statusColorHex: String {
        if isInvestmentCategory {
            guard estimatedAmount > 0 else { return "#94A3B8" }
            if rawProgressPercentage >= 99.9 {
                return "#10B981"
            } else if rawProgressPercentage >= 80.0 {
                return "#0284C7"
            } else if realizedExpense > 0 {
                return "#0284C7"
            } else {
                return "#94A3B8"
            }
        }
        return status.colorHex
    }

    public var statusIconSymbol: String {
        if isInvestmentCategory {
            guard estimatedAmount > 0 else { return "circle" }
            if realizedExpense > estimatedAmount + 0.001 {
                return "star.fill"
            } else if rawProgressPercentage >= 99.9 {
                return "checkmark.circle.fill"
            } else if rawProgressPercentage >= 80.0 {
                return "chart.line.uptrend.xyaxis"
            } else if realizedExpense > 0 {
                return "arrow.triangle.2.circlepath"
            } else {
                return "circle"
            }
        }
        return status.iconSymbol
    }

    public init(
        category: CategoryItem,
        provision: CategoryProvision,
        isInheritedFromPreviousMonth: Bool,
        estimatedAmount: Double,
        realizedExpense: Double,
        isFreeBudgetLocalOverride: Bool = false
    ) {
        self.category = category
        self.provision = provision
        self.isInheritedFromPreviousMonth = isInheritedFromPreviousMonth
        self.isFreeBudgetLocalOverride = isFreeBudgetLocalOverride

        let cleanEst = max(0.0, estimatedAmount)
        let cleanRealized = max(0.0, realizedExpense)
        let cleanRem = max(0.0, cleanEst - cleanRealized)

        self.estimatedAmount = cleanEst
        self.realizedExpense = cleanRealized
        self.remainingProvision = cleanRem
        self.exceededAmount = cleanEst > 0 ? max(0.0, cleanRealized - cleanEst) : 0.0

        let rawPct = cleanEst > 0.0001 ? ((cleanRealized / cleanEst) * 100.0) : 0.0
        self.rawProgressPercentage = rawPct
        self.clampedProgressPercentage = min(100.0, max(0.0, rawPct))

        let isInv = category.name.localizedCaseInsensitiveContains("aporte") || category.name.localizedCaseInsensitiveContains("investimento")
        if isInv {
            self.status = .normal
        } else if cleanEst > 0 && cleanRealized > cleanEst + 0.001 {
            self.status = .exceeded
        } else if rawPct >= 80.0 - 0.001 {
            self.status = .warning
        } else {
            self.status = .normal
        }
    }
}

// MARK: - Unified Financial KPI Architecture

/// Os seis contextos temporais padronizados da aplicação (mensais e anuais).
public enum FinancialTemporalContext: String, Codable, CaseIterable, Identifiable, Hashable {
    case pastMonth       // 1. Mês passado: mês fechado
    case currentMonth    // 2. Mês atual: mês em andamento
    case futureMonth     // 3. Mês futuro: mês projetado
    case pastYear        // 4. Ano passado: ano fechado
    case currentYear     // 5. Ano atual: ano em andamento
    case futureYear      // 6. Ano futuro: ano projetado

    public var id: String { rawValue }

    public var isClosed: Bool {
        self == .pastMonth || self == .pastYear
    }

    public var isCurrent: Bool {
        self == .currentMonth || self == .currentYear
    }

    public var isFuture: Bool {
        self == .futureMonth || self == .futureYear
    }

    public var isAnnual: Bool {
        self == .pastYear || self == .currentYear || self == .futureYear
    }

    public var title: String {
        switch self {
        case .pastMonth: return "Mês Passado (Fechado)"
        case .currentMonth: return "Mês Atual (Em Andamento)"
        case .futureMonth: return "Mês Futuro (Projetado)"
        case .pastYear: return "Ano Passado (Fechado)"
        case .currentYear: return "Ano Atual (Em Andamento)"
        case .futureYear: return "Ano Futuro (Projetado)"
        }
    }
}

/// Modelo canônico e centralizado contendo todos os indicadores de resumo (KPIs)
/// calculados estritamente pelo FinancialDataStore para as telas da aplicação:
/// Dashboard, Transações, Despesas e Receitas.
public struct UnifiedFinancialKPISummary: Hashable {
    public let referenceDate: Date
    public let referenceNow: Date
    public let isAnnual: Bool
    public let temporalContext: FinancialTemporalContext

    // 1. Receitas
    public let receivedIncome: Double             // Receitas efetivamente recebidas (isPaid == true)
    public let pendingIncome: Double              // Receitas pendentes cadastradas (isPaid == false)
    public let pendingIncomeOverdue: Double       // Receitas pendentes em atraso (date < today)
    public let pendingIncomeOnTime: Double        // Receitas pendentes no prazo (date >= today)
    public let unrecordedExpectedIncome: Double   // Receitas previstas sem lançamento cadastrado (R$ 0,00 documentado)
    public let projectedIncome: Double            // receivedIncome + pendingIncome + unrecordedExpectedIncome
    public let habitualIncome: Double             // Receitas habituais
    public let extraordinaryIncome: Double         // Receitas extraordinárias (13º salário, bônus, PLR, etc.)
    public let topIncomeSourceName: String?       // Categoria/fonte principal
    public let topIncomeSourceAmount: Double      // Valor da principal fonte
    public let topIncomeSourcePercentage: Double  // % da principal fonte

    // 2. Despesas
    public let paidExpense: Double                // Despesas pagas (isPaid == true)
    public let pendingExpense: Double             // Despesas pendentes cadastradas (isPaid == false)
    public let recordedExpense: Double            // Despesas lançadas = paidExpense + pendingExpense
    public let overdueExpenses: Double            // Despesas vencidas (isPaid == false && date < today)
    public let onTimePendingExpenses: Double      // Despesas pendentes no prazo (isPaid == false && date >= today)
    public let fixedExpenses: Double              // Despesas fixas / recorrentes
    public let fixedExpensesPercentage: Double    // % de despesas fixas
    public let variableExpenses: Double           // Despesas variáveis / avulsas
    public let variableExpensesPercentage: Double // % de despesas variáveis

    // 3. Orçamentos e Cotas
    public let categoryCeilingsRemaining: Double  // Tetos restantes por categoria
    public let specificQuotasRemaining: Double    // Cotas específicas restantes
    public let remainingBudgetsAndQuotas: Double  // categoryCeilingsRemaining + specificQuotasRemaining
    public let totalBudgetsOverrun: Double        // Excedente de orçamento (estouro de teto)
    public let hasBudgetOverrun: Bool             // totalBudgetsOverrun > 0.001

    // 4. Gastos Planejados e Sobra
    public let totalPlannedExpenses: Double       // recordedExpense + remainingBudgetsAndQuotas
    public let surplusAfterPlanning: Double       // projectedIncome - totalPlannedExpenses
    public let operationalNetBalance: Double      // projectedIncome - recordedExpense

    // 5. Saldo Bancário e Caixa
    public let currentAccountBalanceNow: Double   // Saldo atual consolidado das contas hoje
    public let projectedAccountBalance: Double    // Saldo inicial + movimentações futuras registradas
    public let balanceIfAllBudgetsConsumed: Double // projectedAccountBalance - remainingBudgetsAndQuotas
    public let projectedAccountBalanceTitle: String

    // 6. Estatísticas Operacionais (Transações)
    public let consolidatedEntries: Double        // Entradas consolidadas (ignora transferências internas e canceladas)
    public let consolidatedExits: Double          // Saídas consolidadas (ignora transferências internas e canceladas)
    public let transactionsNetBalance: Double     // consolidatedEntries - consolidatedExits
    public let totalPendingVolume: Double         // pendingIncome + pendingExpense
    public let paidTransactionsCount: Int         // Quantidade de transações efetivadas
    public let pendingTransactionsCount: Int      // Quantidade de transações pendentes
    public let validTransactionsCount: Int        // Quantidade total de transações válidas

    public var isPast: Bool { temporalContext.isClosed }

    public init(
        referenceDate: Date,
        referenceNow: Date,
        isAnnual: Bool,
        temporalContext: FinancialTemporalContext,
        receivedIncome: Double,
        pendingIncome: Double,
        pendingIncomeOverdue: Double,
        pendingIncomeOnTime: Double,
        unrecordedExpectedIncome: Double,
        projectedIncome: Double,
        habitualIncome: Double,
        extraordinaryIncome: Double,
        topIncomeSourceName: String?,
        topIncomeSourceAmount: Double,
        topIncomeSourcePercentage: Double,
        paidExpense: Double,
        pendingExpense: Double,
        recordedExpense: Double,
        overdueExpenses: Double,
        onTimePendingExpenses: Double,
        fixedExpenses: Double,
        fixedExpensesPercentage: Double,
        variableExpenses: Double,
        variableExpensesPercentage: Double,
        categoryCeilingsRemaining: Double,
        specificQuotasRemaining: Double,
        remainingBudgetsAndQuotas: Double,
        totalBudgetsOverrun: Double,
        hasBudgetOverrun: Bool,
        totalPlannedExpenses: Double,
        surplusAfterPlanning: Double,
        operationalNetBalance: Double,
        currentAccountBalanceNow: Double,
        projectedAccountBalance: Double,
        balanceIfAllBudgetsConsumed: Double,
        projectedAccountBalanceTitle: String,
        consolidatedEntries: Double,
        consolidatedExits: Double,
        transactionsNetBalance: Double,
        totalPendingVolume: Double,
        paidTransactionsCount: Int,
        pendingTransactionsCount: Int,
        validTransactionsCount: Int
    ) {
        self.referenceDate = referenceDate
        self.referenceNow = referenceNow
        self.isAnnual = isAnnual
        self.temporalContext = temporalContext
        self.receivedIncome = receivedIncome
        self.pendingIncome = pendingIncome
        self.pendingIncomeOverdue = pendingIncomeOverdue
        self.pendingIncomeOnTime = pendingIncomeOnTime
        self.unrecordedExpectedIncome = unrecordedExpectedIncome
        self.projectedIncome = projectedIncome
        self.habitualIncome = habitualIncome
        self.extraordinaryIncome = extraordinaryIncome
        self.topIncomeSourceName = topIncomeSourceName
        self.topIncomeSourceAmount = topIncomeSourceAmount
        self.topIncomeSourcePercentage = topIncomeSourcePercentage
        self.paidExpense = paidExpense
        self.pendingExpense = pendingExpense
        self.recordedExpense = recordedExpense
        self.overdueExpenses = overdueExpenses
        self.onTimePendingExpenses = onTimePendingExpenses
        self.fixedExpenses = fixedExpenses
        self.fixedExpensesPercentage = fixedExpensesPercentage
        self.variableExpenses = variableExpenses
        self.variableExpensesPercentage = variableExpensesPercentage
        self.categoryCeilingsRemaining = categoryCeilingsRemaining
        self.specificQuotasRemaining = specificQuotasRemaining
        self.remainingBudgetsAndQuotas = remainingBudgetsAndQuotas
        self.totalBudgetsOverrun = totalBudgetsOverrun
        self.hasBudgetOverrun = hasBudgetOverrun
        self.totalPlannedExpenses = totalPlannedExpenses
        self.surplusAfterPlanning = surplusAfterPlanning
        self.operationalNetBalance = operationalNetBalance
        self.currentAccountBalanceNow = currentAccountBalanceNow
        self.projectedAccountBalance = projectedAccountBalance
        self.balanceIfAllBudgetsConsumed = balanceIfAllBudgetsConsumed
        self.projectedAccountBalanceTitle = projectedAccountBalanceTitle
        self.consolidatedEntries = consolidatedEntries
        self.consolidatedExits = consolidatedExits
        self.transactionsNetBalance = transactionsNetBalance
        self.totalPendingVolume = totalPendingVolume
        self.paidTransactionsCount = paidTransactionsCount
        self.pendingTransactionsCount = pendingTransactionsCount
        self.validTransactionsCount = validTransactionsCount
    }
}
