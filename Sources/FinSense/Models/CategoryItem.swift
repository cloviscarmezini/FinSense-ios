// Sources/FinSense/Models/CategoryItem.swift
import Foundation
import SwiftUI

public enum TransactionType: String, Codable, CaseIterable, Identifiable, Hashable {
    case expense
    case income

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .expense: return "Despesa"
        case .income: return "Receita"
        }
    }
}

public struct CategoryItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var type: TransactionType
    public var iconSymbol: String
    public var colorHex: String
    public var keywords: [String]
    public var isSystemDefault: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        type: TransactionType,
        iconSymbol: String,
        colorHex: String,
        keywords: [String] = [],
        isSystemDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.keywords = keywords
        self.isSystemDefault = isSystemDefault
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type, iconSymbol, colorHex, keywords, isSystemDefault
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        self.id = (try? c.decode(UUID.self, forKey: AnyKey("id"))) ?? UUID()
        self.name = (try? c.decodeIfPresent(String.self, forKey: AnyKey("name"))) ?? ""
        self.type = (try? c.decodeIfPresent(TransactionType.self, forKey: AnyKey("type"))) ?? .expense
        self.iconSymbol = (try? c.decodeIfPresent(String.self, forKey: AnyKey("iconSymbol")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("icon_symbol"))) ?? "folder.fill"
        self.colorHex = (try? c.decodeIfPresent(String.self, forKey: AnyKey("colorHex")))
            ?? (try? c.decodeIfPresent(String.self, forKey: AnyKey("color_hex"))) ?? "#64748B"
        self.keywords = (try? c.decodeIfPresent([String].self, forKey: AnyKey("keywords"))) ?? []
        self.isSystemDefault = (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("isSystemDefault")))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: AnyKey("is_system_default"))) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(type, forKey: .type)
        try c.encode(iconSymbol, forKey: .iconSymbol)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encode(keywords, forKey: .keywords)
        try c.encode(isSystemDefault, forKey: .isSystemDefault)
    }
}

public enum DefaultCategoriesCatalog {
    public static func buildInitialCategories() -> [CategoryItem] {
        [
            // DESPESAS
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                name: "Supermercado & Atacado",
                type: .expense,
                iconSymbol: "cart.fill",
                colorHex: "#F97316",
                keywords: ["DELTA", "SAMS", "ATACADAO", "ASSAI", "CARREFOUR", "PAO DE ACUCAR", "MERCADO"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                name: "Alimentação & Delivery",
                type: .expense,
                iconSymbol: "fork.knife",
                colorHex: "#EF4444",
                keywords: ["99 FOOD", "IFOOD", "KFC", "PIZZI", "DOCER", "ACAIF", "CACAU", "BACIO", "FRANG", "MACAR", "CEVAD", "SOPHI", "WANDO", "MR MI", "KCOWO", "MAJO", "CAPPT", "RESTAURANTE", "LANCHONETE", "PADARIA", "LANCHE", "LANCHES", "HAMBURGUER"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                name: "Moradia & Condomínio",
                type: .expense,
                iconSymbol: "house.fill",
                colorHex: "#6366F1",
                keywords: ["CONDOMI", "BBZ ADMINISTRACAO", "ALUGUEL", "IPTU", "CASA", "OBRAM", "REFORMA"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
                name: "Energia, Água & Gás",
                type: .expense,
                iconSymbol: "bolt.fill",
                colorHex: "#EAB308",
                keywords: ["CPFL", "COMGAS", "S.PIRACICAB", "SABESP", "ENEL", "LUZ", "AGUA", "GAS"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
                name: "Telefonia & Internet",
                type: .expense,
                iconSymbol: "wifi",
                colorHex: "#06B6D4",
                keywords: ["VIVO", "CLARO", "TELEFONICA", "TIM", "INTERNET", "CELULAR"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
                name: "Transporte & Mobilidade",
                type: .expense,
                iconSymbol: "bus.fill",
                colorHex: "#3B82F6",
                keywords: ["UBER", "99POP", "MOBIFACIL", "PEDAGIO", "PASSAGEM", "METRO", "ONIBUS"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
                name: "Combustível & Automóvel",
                type: .expense,
                iconSymbol: "fuelpump.fill",
                colorHex: "#0EA5E9",
                keywords: ["AUTO", "AUTOZ", "POSTO", "IPIRANGA", "SHELL", "ESTACIONAMENTO", "OFICINA", "IPVA", "GASOLINA", "COMBUSTIVEL", "ETANOL", "ABASTECIMENTO"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000019")!,
                name: "Lazer & Entretenimento",
                type: .expense,
                iconSymbol: "gamecontroller.fill",
                colorHex: "#A855F7",
                keywords: ["LAZER", "CINEMA", "TEATRO", "SHOW", "PASSEIO", "PARQUE", "VIAGEM", "INGRESSO", "JOGOS", "ENTRETENIMENTO"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000008")!,
                name: "Compras & E-Commerce",
                type: .expense,
                iconSymbol: "bag.fill",
                colorHex: "#EC4899",
                keywords: ["MARKETP", "AMAZON", "HAVAN", "PAGAR ME", "LOJAS", "VOLLU", "L4U", "MP R", "SHOPEE", "MERCADO LIVRE"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000009")!,
                name: "Pets & Veterinário",
                type: .expense,
                iconSymbol: "pawprint.fill",
                colorHex: "#84CC16",
                keywords: ["COBAS", "PETZ", "AGROM", "VETERINAR", "PET"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000010")!,
                name: "Educação & Cursos",
                type: .expense,
                iconSymbol: "graduationcap.fill",
                colorHex: "#8B5CF6",
                keywords: ["VSTP EDUCAC", "ESCOLA", "FACULDADE", "CURSO", "LIVRO", "EDUCAC"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000011")!,
                name: "Saúde & Farmácia",
                type: .expense,
                iconSymbol: "cross.case.fill",
                colorHex: "#14B8A6",
                keywords: ["DROGASIL", "DROGA", "RAIA", "FARMACIA", "MEDICO", "UNIMED", "HOSPITAL", "EVO V"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000018")!,
                name: "Cuidado Pessoal & Estética",
                type: .expense,
                iconSymbol: "scissors",
                colorHex: "#EC4899",
                keywords: ["CABELELEIRO", "CABELEIREIRO", "BARBEARIA", "SALAO", "ESTETICA", "CUIDADO PESSOAL", "BELEZA", "MANICURE", "COSMETICO"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000012")!,
                name: "Cartão de Crédito & Boletos",
                type: .expense,
                iconSymbol: "creditcard.fill",
                colorHex: "#F43F5E",
                keywords: ["BRADESCARD", "FATURA", "PAG BOLETO", "CARTAO"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000013")!,
                name: "Empréstimos & Financiamentos",
                type: .expense,
                iconSymbol: "banknote.fill",
                colorHex: "#FB7185",
                keywords: ["CONSIGNADO", "FINANCIAMENTO", "PARCELA EMPRESTIMO"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000014")!,
                name: "Aportes em Investimentos",
                type: .expense,
                iconSymbol: "chart.line.uptrend.xyaxis",
                colorHex: "#6366F1",
                keywords: ["APORTE", "INVESTIMENTO", "CDB", "POUPANCA", "COFRINHO"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000016")!,
                name: "Quitação de Dívidas",
                type: .expense,
                iconSymbol: "checkmark.shield.fill",
                colorHex: "#DC2626",
                keywords: ["DIVIDA", "ACORDO", "SERASA", "NEGOCIACAO"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000017")!,
                name: "Outras Despesas",
                type: .expense,
                iconSymbol: "ellipsis.circle.fill",
                colorHex: "#94A3B8",
                keywords: [],
                isSystemDefault: true
            ),

            // RECEITAS
            CategoryItem(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                name: "Salário & Remuneração",
                type: .income,
                iconSymbol: "banknote.fill",
                colorHex: "#10B981",
                keywords: ["SALARIO", "REMUNERACAO", "PRO-LABORE", "PAGTO SALARIO"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
                name: "PIX Recebido & Transferências",
                type: .income,
                iconSymbol: "arrow.down.left.circle.fill",
                colorHex: "#22C55E",
                keywords: ["PIX TRANSF", "RECEBIDO"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
                name: "Resgate de Investimentos & Cofrinhos",
                type: .income,
                iconSymbol: "arrow.uturn.backward.circle.fill",
                colorHex: "#06B6D4",
                keywords: ["RESGATE COFRINHOS", "RESGATE CDB", "RESGATE"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000004")!,
                name: "Rendimentos & Dividendos",
                type: .income,
                iconSymbol: "chart.line.uptrend.xyaxis",
                colorHex: "#14B8A6",
                keywords: ["REND PAGO", "RENDIMENTO", "DIVIDENDO", "JUROS"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000005")!,
                name: "Reembolso & Estorno",
                type: .income,
                iconSymbol: "arrow.counterclockwise.circle.fill",
                colorHex: "#3B82F6",
                keywords: ["DEV PIX", "ESTORNO", "REEMBOLSO", "DEVOLUCAO"],
                isSystemDefault: true
            ),
            CategoryItem(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000006")!,
                name: "Outras Receitas",
                type: .income,
                iconSymbol: "plus.circle.fill",
                colorHex: "#84CC16",
                keywords: [],
                isSystemDefault: true
            )
        ]
    }
}
