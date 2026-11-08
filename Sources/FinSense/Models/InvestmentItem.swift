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
}
