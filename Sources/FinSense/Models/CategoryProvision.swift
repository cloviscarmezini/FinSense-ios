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
    case allOccurrences

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .onlyThisMonth:
            return "Excluir somente deste mês"
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

        if cleanEst > 0 && cleanRealized > cleanEst + 0.001 {
            self.status = .exceeded
        } else if rawPct >= 80.0 - 0.001 {
            self.status = .warning
        } else {
            self.status = .normal
        }
    }
}
