// Sources/FinSense/Models/InvestmentItem.swift
import Foundation

public enum InvestmentMovementType: String, Codable, CaseIterable, Identifiable, Hashable {
    case deposit
    case withdrawal

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .deposit: return "Aporte"
        case .withdrawal: return "Resgate"
        }
    }
}

public struct InvestmentMovement: Identifiable, Codable, Hashable {
    public var id: UUID
    public var type: InvestmentMovementType
    public var amount: Double
    public var date: Date
    public var sourceAccountId: UUID
    public var investmentAccountId: UUID
    public var notes: String
    public var generatedTransactionId: UUID?

    public init(
        id: UUID = UUID(),
        type: InvestmentMovementType = .deposit,
        amount: Double,
        date: Date = Date(),
        sourceAccountId: UUID,
        investmentAccountId: UUID,
        notes: String = "",
        generatedTransactionId: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.amount = abs(amount)
        self.date = date
        self.sourceAccountId = sourceAccountId
        self.investmentAccountId = investmentAccountId
        self.notes = notes
        self.generatedTransactionId = generatedTransactionId
    }
}

public struct InvestmentItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var groupName: String
    public var investmentAccountId: UUID
    public var balance: Double
    public var showInConsolidated: Bool
    public var iconSymbol: String
    public var colorHex: String
    public var notes: String
    public var movements: [InvestmentMovement]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        groupName: String,
        investmentAccountId: UUID,
        balance: Double = 0.0,
        showInConsolidated: Bool = true,
        iconSymbol: String = "chart.line.uptrend.xyaxis",
        colorHex: String = "#10B981",
        notes: String = "",
        movements: [InvestmentMovement] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.groupName = groupName
        self.investmentAccountId = investmentAccountId
        self.balance = balance
        self.showInConsolidated = showInConsolidated
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.notes = notes
        self.movements = movements
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, groupName, investmentAccountId, balance, showInConsolidated, iconSymbol, colorHex, notes, movements, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        self.id = (try? c.decode(UUID.self, forKey: AnyKey("id"))) ?? UUID()
        self.name = (try? c.decodeIfPresent(String.self, forKey: AnyKey("name"))) ?? ""
        self.groupName = (try? c.decodeIfPresent(String.self, forKey: AnyKey("groupName")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("group_name"))) ?? ""

        if let acc = try? c.decode(UUID.self, forKey: AnyKey("investmentAccountId")) { self.investmentAccountId = acc }
        else if let acc = try? c.decode(UUID.self, forKey: AnyKey("investment_account_id")) { self.investmentAccountId = acc }
        else { self.investmentAccountId = UUID() }

        self.balance = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("balance"))) ?? 0.0
        self.showInConsolidated = (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("showInConsolidated")))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("show_in_consolidated"))) ?? true
        self.iconSymbol = (try? c.decodeIfPresent(String.self, forKey: AnyKey("iconSymbol")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("icon_symbol"))) ?? "chart.line.uptrend.xyaxis"
        self.colorHex = (try? c.decodeIfPresent(String.self, forKey: AnyKey("colorHex")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("color_hex"))) ?? "#10B981"
        self.notes = (try? c.decodeIfPresent(String.self, forKey: AnyKey("notes"))) ?? ""
        self.movements = (try? c.decodeIfPresent([InvestmentMovement].self, forKey: AnyKey("movements"))) ?? []
        self.createdAt = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("createdAt")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("created_at"))) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(groupName, forKey: .groupName)
        try c.encode(investmentAccountId, forKey: .investmentAccountId)
        try c.encode(balance, forKey: .balance)
        try c.encode(showInConsolidated, forKey: .showInConsolidated)
        try c.encode(iconSymbol, forKey: .iconSymbol)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encode(notes, forKey: .notes)
        try c.encode(movements, forKey: .movements)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

public enum InvestmentPeriodFilter: String, CaseIterable, Identifiable {
    case threeMonths = "3 meses"
    case sixMonths = "6 meses"
    case oneYear = "1 ano"

    public var id: String { rawValue }
    public var title: String { rawValue }
}

public struct InvestmentMonthlyMovementPoint: Identifiable, Hashable {
    public var id: String { yearMonthKey }
    public let yearMonthKey: String // "2026-11"
    public let year: Int
    public let month: Int
    public let label: String        // "Nov/26"
    public let shortLabel: String   // "Nov"
    public let date: Date
    public let isPast: Bool
    public let isCurrent: Bool
    public let isFuture: Bool
    public let deposits: Double     // Entradas / Aportes efetuados no mês
    public let withdrawals: Double  // Saídas / Resgates efetuados no mês
    public let projectedDeposits: Double // Projeção de aportes com base nas cotas planejadas
    public let netMovement: Double
    public let baseAccumulated: Double   // Base acumulada antes dos aportes deste mês
    public let endBalance: Double        // Saldo acumulado final ao fim do mês

    public init(
        yearMonthKey: String,
        year: Int,
        month: Int,
        label: String,
        shortLabel: String,
        date: Date,
        isPast: Bool,
        isCurrent: Bool,
        isFuture: Bool,
        deposits: Double,
        withdrawals: Double,
        projectedDeposits: Double,
        baseAccumulated: Double = 0.0,
        endBalance: Double = 0.0
    ) {
        self.yearMonthKey = yearMonthKey
        self.year = year
        self.month = month
        self.label = label
        self.shortLabel = shortLabel
        self.date = date
        self.isPast = isPast
        self.isCurrent = isCurrent
        self.isFuture = isFuture
        self.deposits = deposits
        self.withdrawals = withdrawals
        self.projectedDeposits = projectedDeposits
        self.netMovement = deposits - withdrawals + (isFuture ? projectedDeposits : 0.0)
        self.baseAccumulated = max(0.0, baseAccumulated)
        let resolvedEnd = endBalance > 0 ? endBalance : (baseAccumulated + deposits + (isFuture || isCurrent ? projectedDeposits : 0.0))
        self.endBalance = max(0.0, resolvedEnd)
    }
}
