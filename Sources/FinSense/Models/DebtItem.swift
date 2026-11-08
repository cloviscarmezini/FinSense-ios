// Sources/FinSense/Models/DebtItem.swift
import Foundation

public struct DebtItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var customImagePath: String?
    public var bankPresetId: String?
    public var iconSymbol: String
    public var colorHex: String
    public var originalAmount: Double
    public var contractedDate: Date?
    public var notes: String
    public var isPaid: Bool
    public var negotiatedAmount: Double?
    public var paidDate: Date?
    public var paidFromAccountId: UUID?
    public var paymentTransactionId: UUID?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        customImagePath: String? = nil,
        bankPresetId: String? = nil,
        iconSymbol: String = "creditcard.trianglebadge.exclamationmark",
        colorHex: String = "#EF4444",
        originalAmount: Double,
        contractedDate: Date? = nil,
        notes: String = "",
        isPaid: Bool = false,
        negotiatedAmount: Double? = nil,
        paidDate: Date? = nil,
        paidFromAccountId: UUID? = nil,
        paymentTransactionId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.customImagePath = customImagePath
        self.bankPresetId = bankPresetId
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.originalAmount = abs(originalAmount)
        self.contractedDate = contractedDate
        self.notes = notes
        self.isPaid = isPaid
        self.negotiatedAmount = negotiatedAmount
        self.paidDate = paidDate
        self.paidFromAccountId = paidFromAccountId
        self.paymentTransactionId = paymentTransactionId
        self.createdAt = createdAt
    }
}
