// Sources/FinSense/Models/BankAccount.swift
import Foundation
import SwiftUI

public struct BankPreset: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var shortCode: String
    public var monogram: String
    public var primaryHex: String
    public var secondaryHex: String
    public var symbolName: String

    public init(
        id: String,
        name: String,
        shortCode: String,
        monogram: String,
        primaryHex: String,
        secondaryHex: String,
        symbolName: String
    ) {
        self.id = id
        self.name = name
        self.shortCode = shortCode
        self.monogram = monogram
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
        self.symbolName = symbolName
    }
}

public struct BankAccount: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var bankPresetId: String?
    public var customImagePath: String?
    public var iconSymbol: String
    public var colorHex: String
    public var initialBalance: Double
    public var agency: String
    public var accountNumber: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        bankPresetId: String? = nil,
        customImagePath: String? = nil,
        iconSymbol: String = "building.columns.fill",
        colorHex: String = "#EC7000",
        initialBalance: Double = 0.0,
        agency: String = "",
        accountNumber: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.bankPresetId = bankPresetId
        self.customImagePath = customImagePath
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.initialBalance = initialBalance
        self.agency = agency
        self.accountNumber = accountNumber
        self.createdAt = createdAt
    }
}

public enum BrazilianBanksCatalog {
    public static let presets: [BankPreset] = [
        BankPreset(
            id: "itau",
            name: "Itaú Unibanco",
            shortCode: "341",
            monogram: "itaú",
            primaryHex: "#EC7000",
            secondaryHex: "#003399",
            symbolName: "building.columns.fill"
        ),
        BankPreset(
            id: "nubank",
            name: "Nubank",
            shortCode: "260",
            monogram: "nu",
            primaryHex: "#820AD1",
            secondaryHex: "#4B0082",
            symbolName: "creditcard.fill"
        ),
        BankPreset(
            id: "santander",
            name: "Santander",
            shortCode: "033",
            monogram: "SAN",
            primaryHex: "#EC0000",
            secondaryHex: "#990000",
            symbolName: "flame.fill"
        ),
        BankPreset(
            id: "bradesco",
            name: "Bradesco",
            shortCode: "237",
            monogram: "BRA",
            primaryHex: "#CC092F",
            secondaryHex: "#8A0620",
            symbolName: "building.2.fill"
        ),
        BankPreset(
            id: "bb",
            name: "Banco do Brasil",
            shortCode: "001",
            monogram: "BB",
            primaryHex: "#F8D117",
            secondaryHex: "#0038A8",
            symbolName: "banknote.fill"
        ),
        BankPreset(
            id: "caixa",
            name: "Caixa Econômica",
            shortCode: "104",
            monogram: "CEF",
            primaryHex: "#005CA9",
            secondaryHex: "#F39200",
            symbolName: "xmark.square.fill"
        ),
        BankPreset(
            id: "inter",
            name: "Banco Inter",
            shortCode: "077",
            monogram: "inter",
            primaryHex: "#FF7A00",
            secondaryHex: "#CC6200",
            symbolName: "globe.americas.fill"
        ),
        BankPreset(
            id: "c6",
            name: "C6 Bank",
            shortCode: "336",
            monogram: "C6",
            primaryHex: "#242424",
            secondaryHex: "#555555",
            symbolName: "circle.hexagongrid.fill"
        ),
        BankPreset(
            id: "btg",
            name: "BTG Pactual",
            shortCode: "208",
            monogram: "BTG",
            primaryHex: "#001E62",
            secondaryHex: "#0047BB",
            symbolName: "chart.bar.xaxis"
        ),
        BankPreset(
            id: "mercadopago",
            name: "Mercado Pago",
            shortCode: "323",
            monogram: "MP",
            primaryHex: "#009EE3",
            secondaryHex: "#005E8A",
            symbolName: "hands.sparkles.fill"
        ),
        BankPreset(
            id: "picpay",
            name: "PicPay",
            shortCode: "380",
            monogram: "Pic",
            primaryHex: "#11C76F",
            secondaryHex: "#0B8449",
            symbolName: "qrcode.viewfinder"
        ),
        BankPreset(
            id: "xp",
            name: "XP Investimentos",
            shortCode: "348",
            monogram: "XP",
            primaryHex: "#1C1C1E",
            secondaryHex: "#EAB308",
            symbolName: "chart.line.uptrend.xyaxis"
        ),
        BankPreset(
            id: "sicredi",
            name: "Sicredi",
            shortCode: "748",
            monogram: "SIC",
            primaryHex: "#3FA110",
            secondaryHex: "#266309",
            symbolName: "leaf.fill"
        ),
        BankPreset(
            id: "sicoob",
            name: "Sicoob",
            shortCode: "756",
            monogram: "SCB",
            primaryHex: "#003641",
            secondaryHex: "#00AE9D",
            symbolName: "triangle.fill"
        ),
        BankPreset(
            id: "safra",
            name: "Banco Safra",
            shortCode: "422",
            monogram: "SAF",
            primaryHex: "#1B2432",
            secondaryHex: "#C5A059",
            symbolName: "shield.fill"
        ),
        BankPreset(
            id: "neon",
            name: "Neon",
            shortCode: "735",
            monogram: "NEON",
            primaryHex: "#00E5FF",
            secondaryHex: "#0077FF",
            symbolName: "sparkles"
        ),
        BankPreset(
            id: "carteira",
            name: "Carteira Física / Espécie",
            shortCode: "000",
            monogram: "R$",
            primaryHex: "#10B981",
            secondaryHex: "#047857",
            symbolName: "wallet.pass.fill"
        )
    ]

    public static func preset(for id: String?) -> BankPreset? {
        guard let id else { return nil }
        return presets.first { $0.id == id }
    }
}
