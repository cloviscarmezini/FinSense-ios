// Sources/FinSense/Models/CategoryQuotaRule.swift
import Foundation

public struct CategoryQuotaMonthlyOverride: Codable, Hashable {
    public var name: String?
    public var plannedQuantity: Int
    public var estimatedUnitPrice: Double

    public init(
        name: String? = nil,
        plannedQuantity: Int,
        estimatedUnitPrice: Double
    ) {
        self.name = name
        self.plannedQuantity = max(0, plannedQuantity)
        self.estimatedUnitPrice = max(0, estimatedUnitPrice)
    }
}

public struct CategoryQuotaRule: Identifiable, Codable, Hashable {
    public var id: UUID
    public var seriesId: UUID
    public var categoryId: UUID
    public var name: String
    public var iconSymbol: String
    public var year: Int
    public var month: Int
    public var plannedQuantity: Int
    public var estimatedUnitPrice: Double
    public var repeatForFutureMonths: Bool
    public var monthlyOverrides: [Int: CategoryQuotaMonthlyOverride]?
    public var excludedYearMonthKeys: Set<Int>?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        seriesId: UUID? = nil,
        categoryId: UUID,
        name: String,
        iconSymbol: String = "shippingbox.fill",
        year: Int,
        month: Int,
        plannedQuantity: Int,
        estimatedUnitPrice: Double,
        repeatForFutureMonths: Bool = true,
        monthlyOverrides: [Int: CategoryQuotaMonthlyOverride]? = nil,
        excludedYearMonthKeys: Set<Int>? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.seriesId = seriesId ?? id
        self.categoryId = categoryId
        self.name = name
        self.iconSymbol = iconSymbol
        self.year = year
        self.month = min(max(month, 1), 12)
        self.plannedQuantity = max(0, plannedQuantity)
        self.estimatedUnitPrice = max(0, estimatedUnitPrice)
        self.repeatForFutureMonths = repeatForFutureMonths
        self.monthlyOverrides = monthlyOverrides
        self.excludedYearMonthKeys = excludedYearMonthKeys
        self.createdAt = createdAt
    }

    public var yearMonthKey: Int {
        year * 100 + month
    }
}

public struct CategoryQuotaEnvelope: Identifiable, Hashable {
    public var id: UUID { rule.seriesId }
    public let rule: CategoryQuotaRule
    public var seriesId: UUID { rule.seriesId }
    public var categoryId: UUID { rule.categoryId }
    public let name: String
    public let iconSymbol: String
    public let plannedQuantity: Int
    public let consumedUnits: Int
    public let pendingUnits: Int
    public let estimatedUnitPrice: Double
    public let totalEstimatedAmount: Double
    public let remainingProvision: Double
    public let realizedExpense: Double
    public let repeatForFutureMonths: Bool
    public let isInheritedFromPreviousMonth: Bool
    public let isLocalMonthOverride: Bool

    public var progressRatio: Double {
        guard plannedQuantity > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(consumedUnits) / Double(plannedQuantity)))
    }

    public var status: ProvisionStatusLevel {
        if consumedUnits > plannedQuantity {
            return .exceeded
        } else if plannedQuantity > 0 && Double(consumedUnits) / Double(plannedQuantity) >= 0.8 - 0.001 {
            return .warning
        } else {
            return .normal
        }
    }

    public init(
        rule: CategoryQuotaRule,
        name: String,
        iconSymbol: String,
        plannedQuantity: Int,
        consumedUnits: Int,
        estimatedUnitPrice: Double,
        realizedExpense: Double,
        repeatForFutureMonths: Bool,
        isInheritedFromPreviousMonth: Bool,
        isLocalMonthOverride: Bool = false
    ) {
        self.rule = rule
        self.name = name
        self.iconSymbol = iconSymbol
        let cleanPlanned = max(0, plannedQuantity)
        let cleanConsumed = max(0, consumedUnits)
        let cleanUnit = max(0.0, estimatedUnitPrice)
        self.plannedQuantity = cleanPlanned
        self.consumedUnits = cleanConsumed
        self.pendingUnits = max(0, cleanPlanned - cleanConsumed)
        self.estimatedUnitPrice = cleanUnit
        self.totalEstimatedAmount = Double(cleanPlanned) * cleanUnit
        self.remainingProvision = Double(max(0, cleanPlanned - cleanConsumed)) * cleanUnit
        self.realizedExpense = max(0.0, realizedExpense)
        self.repeatForFutureMonths = repeatForFutureMonths
        self.isInheritedFromPreviousMonth = isInheritedFromPreviousMonth
        self.isLocalMonthOverride = isLocalMonthOverride
    }
}
