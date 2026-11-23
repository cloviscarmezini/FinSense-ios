// Sources/FinSense/Models/CreditCardModel.swift
import Foundation
import SwiftUI

public enum CreditCardBrand: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case mastercard = "Mastercard"
    case visa = "Visa"
    case elo = "Elo"
    case amex = "American Express"
    case hipercard = "Hipercard"
    case other = "Outra"

    public var id: String { rawValue }

    public var shortBadge: String {
        switch self {
        case .mastercard: return "MC"
        case .visa: return "VISA"
        case .elo: return "ELO"
        case .amex: return "AMEX"
        case .hipercard: return "HIPER"
        case .other: return "CARD"
        }
    }
}

public struct CreditCard: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var totalLimit: Double
    public var closingDay: Int
    public var bestPurchaseDay: Int
    public var dueDay: Int
    public var defaultPaymentAccountId: UUID?
    public var brand: CreditCardBrand
    public var bankPresetId: String?
    public var customImagePath: String?
    public var iconSymbol: String
    public var colorHex: String
    public var lastFourDigits: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        totalLimit: Double,
        closingDay: Int,
        bestPurchaseDay: Int? = nil,
        dueDay: Int,
        defaultPaymentAccountId: UUID? = nil,
        brand: CreditCardBrand = .mastercard,
        bankPresetId: String? = nil,
        customImagePath: String? = nil,
        iconSymbol: String = "creditcard.fill",
        colorHex: String = "#820AD1",
        lastFourDigits: String = "",
        createdAt: Date = Date()
    ) {
        let clampedClosing = min(max(closingDay, 1), 31)
        let suggestedBest = clampedClosing >= 31 ? 1 : clampedClosing + 1
        self.id = id
        self.name = name
        self.totalLimit = max(0.0, totalLimit)
        self.closingDay = clampedClosing
        self.bestPurchaseDay = min(max(bestPurchaseDay ?? suggestedBest, 1), 31)
        self.dueDay = min(max(dueDay, 1), 31)
        self.defaultPaymentAccountId = defaultPaymentAccountId
        self.brand = brand
        self.bankPresetId = bankPresetId
        self.customImagePath = customImagePath
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.lastFourDigits = lastFourDigits
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, totalLimit, closingDay, bestPurchaseDay, dueDay
        case defaultPaymentAccountId, brand, bankPresetId, customImagePath
        case iconSymbol, colorHex, lastFourDigits, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        self.id = (try? c.decode(UUID.self, forKey: AnyKey("id"))) ?? UUID()
        self.name = (try? c.decodeIfPresent(String.self, forKey: AnyKey("name"))) ?? ""
        self.totalLimit = max(0.0, (try? c.decodeIfPresent(Double.self, forKey: AnyKey("totalLimit")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("total_limit"))) ?? 0.0)
        let rawClosing = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("closingDay")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("closing_day"))) ?? 25
        self.closingDay = min(max(rawClosing, 1), 31)
        let suggestedBest = self.closingDay >= 31 ? 1 : self.closingDay + 1
        let rawBest = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("bestPurchaseDay")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("best_purchase_day"))) ?? suggestedBest
        self.bestPurchaseDay = min(max(rawBest, 1), 31)
        let rawDue = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("dueDay")))
            ?? (try? c.decodeIfPresent(Int.self, forKey: AnyKey("due_day"))) ?? 5
        self.dueDay = min(max(rawDue, 1), 31)
        self.defaultPaymentAccountId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("defaultPaymentAccountId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("default_payment_account_id")))
        self.brand = (try? c.decodeIfPresent(CreditCardBrand.self, forKey: AnyKey("brand"))) ?? .mastercard
        self.bankPresetId = (try? c.decodeIfPresent(String.self, forKey: AnyKey("bankPresetId")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("bank_preset_id")))
        self.customImagePath = (try? c.decodeIfPresent(String.self, forKey: AnyKey("customImagePath")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("custom_image_path")))
        self.iconSymbol = (try? c.decodeIfPresent(String.self, forKey: AnyKey("iconSymbol")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("icon_symbol"))) ?? "creditcard.fill"
        self.colorHex = (try? c.decodeIfPresent(String.self, forKey: AnyKey("colorHex")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("color_hex"))) ?? "#820AD1"
        self.lastFourDigits = (try? c.decodeIfPresent(String.self, forKey: AnyKey("lastFourDigits")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("last_four_digits"))) ?? ""
        self.createdAt = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("createdAt")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("created_at"))) ?? Date()
    }
}

public enum CreditCardInvoiceStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case open = "Aberta"
    case closed = "Fechada"
    case paid = "Paga"

    public var id: String { rawValue }

    public var colorHex: String {
        switch self {
        case .open: return "#3B82F6"
        case .closed: return "#F59E0B"
        case .paid: return "#10B981"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .open: return "lock.open.fill"
        case .closed: return "clock.badge.exclamationmark.fill"
        case .paid: return "checkmark.seal.fill"
        }
    }
}

public struct CreditCardInvoice: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var creditCardId: UUID
    public var year: Int
    public var month: Int
    public var closingDate: Date
    public var dueDate: Date
    public var isPaid: Bool
    public var paidAmount: Double?
    public var paidDate: Date?
    public var paidFromAccountId: UUID?
    public var paymentTransactionId: UUID?
    public var createdAt: Date

    public var yearMonthKey: Int { year * 100 + month }

    public init(
        id: UUID = UUID(),
        creditCardId: UUID,
        year: Int,
        month: Int,
        closingDate: Date,
        dueDate: Date,
        isPaid: Bool = false,
        paidAmount: Double? = nil,
        paidDate: Date? = nil,
        paidFromAccountId: UUID? = nil,
        paymentTransactionId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.creditCardId = creditCardId
        self.year = year
        self.month = month
        self.closingDate = closingDate
        self.dueDate = dueDate
        self.isPaid = isPaid
        self.paidAmount = paidAmount
        self.paidDate = paidDate
        self.paidFromAccountId = paidFromAccountId
        self.paymentTransactionId = paymentTransactionId
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, creditCardId, year, month, closingDate, dueDate
        case isPaid, paidAmount, paidDate, paidFromAccountId, paymentTransactionId, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        self.id = (try? c.decode(UUID.self, forKey: AnyKey("id"))) ?? UUID()
        self.creditCardId = (try? c.decode(UUID.self, forKey: AnyKey("creditCardId")))
            ?? (try? c.decode(UUID.self, forKey: AnyKey("credit_card_id"))) ?? UUID()
        self.year = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("year"))) ?? 2026
        self.month = (try? c.decodeIfPresent(Int.self, forKey: AnyKey("month"))) ?? 1
        self.closingDate = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("closingDate")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("closing_date"))) ?? Date()
        self.dueDate = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("dueDate")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("due_date"))) ?? Date()
        self.isPaid = (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("isPaid")))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("is_paid"))) ?? false
        self.paidAmount = (try? c.decodeIfPresent(Double.self, forKey: AnyKey("paidAmount")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: AnyKey("paid_amount")))
        self.paidDate = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("paidDate")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("paid_date")))
        self.paidFromAccountId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("paidFromAccountId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("paid_from_account_id")))
        self.paymentTransactionId = (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("paymentTransactionId")))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: AnyKey("payment_transaction_id")))
        self.createdAt = (try? c.decodeIfPresent(Date.self, forKey: AnyKey("createdAt")))
            ?? (try? c.decodeIfPresent(Date.self, forKey: AnyKey("created_at"))) ?? Date()
    }
}

public struct CreditCardInvoiceSummary: Identifiable, Hashable {
    public var id: String { "\(cardId.uuidString)_\(yearMonthKey)" }
    public let cardId: UUID
    public let invoiceId: UUID?
    public let year: Int
    public let month: Int
    public let yearMonthKey: Int
    public let monthYearLabel: String
    public let closingDate: Date
    public let dueDate: Date
    public let status: CreditCardInvoiceStatus
    public let transactions: [FinancialTransaction]
    public let totalAmount: Double
    public let paidAmount: Double?
    public let paidDate: Date?
    public let paymentAccountId: UUID?
    public let paymentTransactionId: UUID?
}
