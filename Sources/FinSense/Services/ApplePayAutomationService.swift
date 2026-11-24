// Sources/FinSense/Services/ApplePayAutomationService.swift
import Foundation
import Combine

public struct ApplePayCardAlias: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var walletCardName: String
    public var targetCreditCardId: UUID?
    public var targetAccountId: UUID?

    public init(
        id: UUID = UUID(),
        walletCardName: String,
        targetCreditCardId: UUID? = nil,
        targetAccountId: UUID? = nil
    ) {
        self.id = id
        self.walletCardName = walletCardName
        self.targetCreditCardId = targetCreditCardId
        self.targetAccountId = targetAccountId
    }
}

public struct ApplePayConfiguration: Codable, Equatable, Sendable {
    public var defaultCreditCardId: UUID?
    public var defaultAccountId: UUID?
    public var preferCreditCardFallback: Bool
    public var defaultCategoryId: UUID?
    public var aliases: [ApplePayCardAlias]

    public init(
        defaultCreditCardId: UUID? = nil,
        defaultAccountId: UUID? = nil,
        preferCreditCardFallback: Bool = true,
        defaultCategoryId: UUID? = nil,
        aliases: [ApplePayCardAlias] = []
    ) {
        self.defaultCreditCardId = defaultCreditCardId
        self.defaultAccountId = defaultAccountId
        self.preferCreditCardFallback = preferCreditCardFallback
        self.defaultCategoryId = defaultCategoryId
        self.aliases = aliases
    }
}

public struct ApplePayResolvedTarget: Sendable {
    public let accountId: UUID
    public let creditCardId: UUID?
    public let matchedDisplayName: String
    public let usedFallback: Bool
}

@MainActor
public final class ApplePayAutomationCoordinator: ObservableObject {
    public static let shared = ApplePayAutomationCoordinator()

    private let userDefaultsKey = "finsense_apple_pay_configuration_v1"

    @Published public var configuration: ApplePayConfiguration {
        didSet { saveConfiguration() }
    }

    public weak var activeStore: FinancialDataStore?
    public weak var activeSyncService: CloudSyncService?

    public init() {
        if let data = UserDefaults.standard.data(forKey: "finsense_apple_pay_configuration_v1"),
           let decoded = try? JSONDecoder().decode(ApplePayConfiguration.self, from: data) {
            self.configuration = decoded
        } else {
            self.configuration = ApplePayConfiguration()
        }
    }

    public func configure(store: FinancialDataStore, syncService: CloudSyncService) {
        self.activeStore = store
        self.activeSyncService = syncService
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    public func addOrUpdateAlias(
        walletCardName: String,
        targetCreditCardId: UUID?,
        targetAccountId: UUID?
    ) {
        let trimmed = walletCardName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = Self.normalize(trimmed)
        if let idx = configuration.aliases.firstIndex(where: { Self.normalize($0.walletCardName) == normalized }) {
            configuration.aliases[idx].walletCardName = trimmed
            configuration.aliases[idx].targetCreditCardId = targetCreditCardId
            configuration.aliases[idx].targetAccountId = targetAccountId
        } else {
            configuration.aliases.append(
                ApplePayCardAlias(
                    walletCardName: trimmed,
                    targetCreditCardId: targetCreditCardId,
                    targetAccountId: targetAccountId
                )
            )
        }
    }

    public func removeAlias(id: UUID) {
        configuration.aliases.removeAll { $0.id == id }
    }

    public static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolve o destino (Cartão de Crédito ou Conta Bancária) a partir do nome do cartão na Apple Wallet.
    public func resolveTarget(
        forWalletCardName cardName: String?,
        in store: FinancialDataStore
    ) -> ApplePayResolvedTarget {
        let normalizedInput = Self.normalize(cardName ?? "")

        if !normalizedInput.isEmpty {
            // 1. Correspondência exata ou por prefixo nos apelidos configurados pelo usuário
            if let alias = configuration.aliases.first(where: {
                let n = Self.normalize($0.walletCardName)
                return !n.isEmpty && (n == normalizedInput || normalizedInput.contains(n) || n.contains(normalizedInput))
            }) {
                if let cid = alias.targetCreditCardId, let card = store.creditCards.first(where: { $0.id == cid }) {
                    return ApplePayResolvedTarget(accountId: card.id, creditCardId: card.id, matchedDisplayName: card.name, usedFallback: false)
                }
                if let aid = alias.targetAccountId, let acc = store.accounts.first(where: { $0.id == aid }) {
                    return ApplePayResolvedTarget(accountId: acc.id, creditCardId: nil, matchedDisplayName: acc.name, usedFallback: false)
                }
            }

            // 2. Match inteligente com cartões cadastrados (nome, últimos 4 dígitos ou bandeira)
            if let matchedCard = store.creditCards.first(where: { card in
                let normName = Self.normalize(card.name)
                let normBrand = Self.normalize(card.brand.rawValue)
                let digits = card.lastFourDigits.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normName.isEmpty && (normalizedInput == normName || normalizedInput.contains(normName) || normName.contains(normalizedInput)) {
                    return true
                }
                if !digits.isEmpty && normalizedInput.contains(digits) {
                    return true
                }
                if !normBrand.isEmpty && normalizedInput.contains(normBrand) {
                    return true
                }
                return false
            }) {
                return ApplePayResolvedTarget(
                    accountId: matchedCard.id,
                    creditCardId: matchedCard.id,
                    matchedDisplayName: matchedCard.name,
                    usedFallback: false
                )
            }

            // 3. Match inteligente com contas bancárias (débito na Wallet)
            if let matchedAccount = store.accounts.first(where: { acc in
                let normAcc = Self.normalize(acc.name)
                return !normAcc.isEmpty && (normalizedInput == normAcc || normalizedInput.contains(normAcc) || normAcc.contains(normalizedInput))
            }) {
                return ApplePayResolvedTarget(
                    accountId: matchedAccount.id,
                    creditCardId: nil,
                    matchedDisplayName: matchedAccount.name,
                    usedFallback: false
                )
            }
        }

        // 4. Fallback configurável pelo usuário
        if configuration.preferCreditCardFallback,
           let defCardId = configuration.defaultCreditCardId,
           let defCard = store.creditCards.first(where: { $0.id == defCardId }) {
            return ApplePayResolvedTarget(accountId: defCard.id, creditCardId: defCard.id, matchedDisplayName: defCard.name, usedFallback: true)
        }
        if let defAccId = configuration.defaultAccountId,
           let defAcc = store.accounts.first(where: { $0.id == defAccId }) {
            return ApplePayResolvedTarget(accountId: defAcc.id, creditCardId: nil, matchedDisplayName: defAcc.name, usedFallback: true)
        }
        if let firstCard = store.creditCards.first, configuration.preferCreditCardFallback {
            return ApplePayResolvedTarget(accountId: firstCard.id, creditCardId: firstCard.id, matchedDisplayName: firstCard.name, usedFallback: true)
        }
        if let firstAcc = store.accounts.first {
            return ApplePayResolvedTarget(accountId: firstAcc.id, creditCardId: nil, matchedDisplayName: firstAcc.name, usedFallback: true)
        }
        return ApplePayResolvedTarget(accountId: UUID(), creditCardId: nil, matchedDisplayName: "Conta Padrão", usedFallback: true)
    }

    private func resolveCategoryId(forMerchant merchant: String, in store: FinancialDataStore) -> UUID {
        if let defCatId = configuration.defaultCategoryId,
           store.categories.contains(where: { $0.id == defCatId && $0.type == .expense }) {
            return defCatId
        }
        let normMerchant = Self.normalize(merchant)
        if let keywordMatch = store.categories.first(where: { cat in
            cat.type == .expense && cat.keywords.contains { kw in
                let nkw = Self.normalize(kw)
                return !nkw.isEmpty && normMerchant.contains(nkw)
            }
        }) {
            return keywordMatch.id
        }
        return store.categories.first(where: { $0.type == .expense })?.id
            ?? store.categories.first?.id
            ?? UUID()
    }

    /// Registra a compra recebida do Apple Pay / App Intents, marca `needsReview = true` e sincroniza em segundo plano.
    @discardableResult
    public func recordApplePayTransaction(
        amount: Double,
        merchant: String,
        cardName: String?,
        date: Date = Date(),
        triggerBackgroundSync: Bool = true
    ) async -> FinancialTransaction? {
        let sanitizedAmount = abs(amount)
        guard sanitizedAmount > 0 else { return nil }

        let targetStore: FinancialDataStore
        let targetSync: CloudSyncService?
        if let liveStore = activeStore {
            targetStore = liveStore
            targetSync = activeSyncService
        } else {
            let coldStore = FinancialDataStore()
            let coldAuth = AuthService()
            let coldSync = CloudSyncService(store: coldStore, authService: coldAuth)
            coldStore.cloudSyncService = coldSync
            targetStore = coldStore
            targetSync = coldSync
        }

        let target = resolveTarget(forWalletCardName: cardName, in: targetStore)
        let catId = resolveCategoryId(forMerchant: merchant, in: targetStore)
        let cleanMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Compra Apple Pay"
            : merchant.trimmingCharacters(in: .whitespacesAndNewlines)

        let walletNote = (cardName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        let details = walletNote.map { "Apple Pay • Wallet: \($0)" } ?? "Registrado automaticamente via Apple Pay"

        let tx = targetStore.createTransaction(
            name: cleanMerchant,
            details: details,
            amount: sanitizedAmount,
            date: date,
            type: .expense,
            isPaid: target.creditCardId == nil,
            categoryId: catId,
            accountId: target.accountId,
            creditCardId: target.creditCardId,
            needsReview: true,
            sourceApp: "apple_pay"
        )

        targetStore.flushPersistenceToDisk()

        if triggerBackgroundSync, let sync = targetSync, sync.canSync {
            await sync.performManualSync()
        }

        return tx
    }
}
