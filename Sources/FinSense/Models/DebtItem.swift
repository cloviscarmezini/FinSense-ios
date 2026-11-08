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

    enum CodingKeys: String, CodingKey {
        case id, name, customImagePath, bankPresetId, iconSymbol, colorHex, originalAmount, contractedDate, notes, isPaid, negotiatedAmount, paidDate, paidFromAccountId, paymentTransactionId, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        self.id = (try? c.decode(UUID.self, forKey: AnyKey("id"))) ?? UUID()
        self.name = (try? c.decodeIfPresent(String.self, forKey: AnyKey("name"))) ?? ""
        self.customImagePath = (try? c.decodeIfPresent(String.self, forKey: AnyKey("customImagePath")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("custom_image_path")))
        self.bankPresetId = (try? c.decodeIfPresent(String.self, forKey: AnyKey("bankPresetId")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("bank_preset_id")))
        self.iconSymbol = (try? c.decodeIfPresent(String.self, forKey: AnyKey("iconSymbol")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("icon_symbol"))) ?? "creditcard.trianglebadge.exclamationmark"
        self.colorHex = (try? c.decodeIfPresent(String.self, forKey: AnyKey("colorHex")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("color_hex"))) ?? "#EF4444"
        self.originalAmount = abs((try? c.decodeIfPresent(Double.self, forKey: AnyKey("originalAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("original_amount"))) ?? 0.0)
        self.contractedDate = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("contractedDate")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("contracted_date")))
        self.notes = (try? c.decodeIfPresent(String.self, forKey: AnyKey("notes"))) ?? ""
        self.isPaid = (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("isPaid")))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("is_paid"))) ?? false
        self.negotiatedAmount = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("negotiatedAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("negotiated_amount")))
        self.paidDate = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("paidDate")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("paid_date")))
        self.paidFromAccountId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("paidFromAccountId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("paid_from_account_id")))
        self.paymentTransactionId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("paymentTransactionId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("payment_transaction_id")))
        self.createdAt = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("createdAt")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("created_at"))) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(customImagePath, forKey: .customImagePath)
        try c.encodeIfPresent(bankPresetId, forKey: .bankPresetId)
        try c.encode(iconSymbol, forKey: .iconSymbol)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encode(originalAmount, forKey: .originalAmount)
        try c.encodeIfPresent(contractedDate, forKey: .contractedDate)
        try c.encode(notes, forKey: .notes)
        try c.encode(isPaid, forKey: .isPaid)
        try c.encodeIfPresent(negotiatedAmount, forKey: .negotiatedAmount)
        try c.encodeIfPresent(paidDate, forKey: .paidDate)
        try c.encodeIfPresent(paidFromAccountId, forKey: .paidFromAccountId)
        try c.encodeIfPresent(paymentTransactionId, forKey: .paymentTransactionId)
        try c.encode(createdAt, forKey: .createdAt)
    }
}
