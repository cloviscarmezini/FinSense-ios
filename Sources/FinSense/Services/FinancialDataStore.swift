// Sources/FinSense/Services/FinancialDataStore.swift
import Foundation
import SwiftUI
import Combine

public enum DashboardPeriodMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case monthly
    case annual

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .monthly: return "Mensal"
        case .annual: return "Anual"
        }
    }
}

public struct CategorySpendSummary: Identifiable, Hashable {
    public var id: UUID { category.id }
    public let category: CategoryItem
    public let total: Double
    public let percentage: Double
    public let count: Int
}

public struct MonthlyCashFlowPoint: Identifiable, Hashable {
    public var id: String { label }
    public let monthDate: Date
    public let label: String
    public let income: Double
    public let expense: Double
    public let net: Double
    public let accumulatedBalance: Double
    public let remainingProvisions: Double
    public let isPastMonth: Bool

    public var totalBudgetedExpense: Double {
        expense + remainingProvisions
    }

    public init(
        monthDate: Date,
        label: String,
        income: Double,
        expense: Double,
        net: Double,
        accumulatedBalance: Double,
        remainingProvisions: Double = 0.0,
        isPastMonth: Bool = false
    ) {
        self.monthDate = monthDate
        self.label = label
        self.income = income
        self.expense = expense
        self.net = net
        self.accumulatedBalance = accumulatedBalance
        self.remainingProvisions = remainingProvisions
        self.isPastMonth = isPastMonth
    }
}

public struct DebtLineItem: Identifiable, Hashable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let section: String
    public let nominalAmount: Double
    public let projectedPayoffAmount: Double
    public let iconSymbol: String
    public let colorHex: String
}

public struct ComprehensiveDebtSummary: Hashable {
    public let currentMonthUnpaidTransactions: [FinancialTransaction]
    public let futureUnpaidRegularTransactions: [FinancialTransaction]
    public let activeDebts: [DebtItem]
    public let activeLoans: [CreditContract]
    public let activeFinancings: [CreditContract]

    public let currentMonthUnpaidTotal: Double
    public let futureRegularExpensesTotal: Double
    public let unpaidDebtsTotal: Double
    public let loansRemainingNominalTotal: Double
    public let loansProjectedPayoffTotal: Double
    public let loansAmortizedInPeriodTotal: Double
    public let financingsRemainingNominalTotal: Double
    public let financingsProjectedPayoffTotal: Double
    public let financingsAmortizedInPeriodTotal: Double

    public let loansPaidInPeriodTotal: Double
    public let loansRealAmortizationInPeriodTotal: Double
    public let financingsPaidInPeriodTotal: Double
    public let financingsRealAmortizationInPeriodTotal: Double

    public let grandTotalNominal: Double
    public let grandTotalWithPayoffProjection: Double
    public let itemizedLines: [DebtLineItem]

    public init(
        currentMonthUnpaidTransactions: [FinancialTransaction],
        futureUnpaidRegularTransactions: [FinancialTransaction],
        activeDebts: [DebtItem],
        activeLoans: [CreditContract],
        activeFinancings: [CreditContract],
        currentMonthUnpaidTotal: Double,
        futureRegularExpensesTotal: Double,
        unpaidDebtsTotal: Double,
        loansRemainingNominalTotal: Double,
        loansProjectedPayoffTotal: Double,
        loansAmortizedInPeriodTotal: Double = 0.0,
        financingsRemainingNominalTotal: Double,
        financingsProjectedPayoffTotal: Double,
        financingsAmortizedInPeriodTotal: Double = 0.0,
        loansPaidInPeriodTotal: Double? = nil,
        loansRealAmortizationInPeriodTotal: Double = 0.0,
        financingsPaidInPeriodTotal: Double? = nil,
        financingsRealAmortizationInPeriodTotal: Double = 0.0,
        grandTotalNominal: Double,
        grandTotalWithPayoffProjection: Double,
        itemizedLines: [DebtLineItem] = []
    ) {
        self.currentMonthUnpaidTransactions = currentMonthUnpaidTransactions
        self.futureUnpaidRegularTransactions = futureUnpaidRegularTransactions
        self.activeDebts = activeDebts
        self.activeLoans = activeLoans
        self.activeFinancings = activeFinancings
        self.currentMonthUnpaidTotal = currentMonthUnpaidTotal
        self.futureRegularExpensesTotal = futureRegularExpensesTotal
        self.unpaidDebtsTotal = unpaidDebtsTotal
        self.loansRemainingNominalTotal = loansRemainingNominalTotal
        self.loansProjectedPayoffTotal = loansProjectedPayoffTotal
        self.loansAmortizedInPeriodTotal = loansAmortizedInPeriodTotal
        self.financingsRemainingNominalTotal = financingsRemainingNominalTotal
        self.financingsProjectedPayoffTotal = financingsProjectedPayoffTotal
        self.financingsAmortizedInPeriodTotal = financingsAmortizedInPeriodTotal
        self.loansPaidInPeriodTotal = loansPaidInPeriodTotal ?? loansAmortizedInPeriodTotal
        self.loansRealAmortizationInPeriodTotal = loansRealAmortizationInPeriodTotal
        self.financingsPaidInPeriodTotal = financingsPaidInPeriodTotal ?? financingsAmortizedInPeriodTotal
        self.financingsRealAmortizationInPeriodTotal = financingsRealAmortizationInPeriodTotal
        self.grandTotalNominal = grandTotalNominal
        self.grandTotalWithPayoffProjection = grandTotalWithPayoffProjection
        self.itemizedLines = itemizedLines
    }
}

public struct FinancialDatabaseSnapshot: Codable {
    public var schemaVersion: Int?
    public var accounts: [BankAccount]
    public var creditCards: [CreditCard]?
    public var creditCardInvoices: [CreditCardInvoice]?
    public var categories: [CategoryItem]
    public var transactions: [FinancialTransaction]
    public var investments: [InvestmentItem]
    public var debts: [DebtItem]
    public var contracts: [CreditContract]
    public var amortizationPlans: [AmortizationPlan]?
    public var budgetProjectionScenario: BudgetProjectionScenario?
    public var provisions: [CategoryProvision]?
    public var categoryQuotas: [CategoryQuotaRule]?

    public init(
        schemaVersion: Int? = 3,
        accounts: [BankAccount] = [],
        creditCards: [CreditCard]? = [],
        creditCardInvoices: [CreditCardInvoice]? = [],
        categories: [CategoryItem] = [],
        transactions: [FinancialTransaction] = [],
        investments: [InvestmentItem] = [],
        debts: [DebtItem] = [],
        contracts: [CreditContract] = [],
        amortizationPlans: [AmortizationPlan]? = [],
        budgetProjectionScenario: BudgetProjectionScenario? = nil,
        provisions: [CategoryProvision]? = [],
        categoryQuotas: [CategoryQuotaRule]? = []
    ) {
        self.schemaVersion = schemaVersion
        self.accounts = accounts
        self.creditCards = creditCards
        self.creditCardInvoices = creditCardInvoices
        self.categories = categories
        self.transactions = transactions
        self.investments = investments
        self.debts = debts
        self.contracts = contracts
        self.amortizationPlans = amortizationPlans
        self.budgetProjectionScenario = budgetProjectionScenario
        self.provisions = provisions
        self.categoryQuotas = categoryQuotas
    }
}

@MainActor
public final class FinancialDataStore: ObservableObject {
    @Published public var accounts: [BankAccount] = [] {
        didSet { invalidateDerivedCaches() }
    }
    @Published public var creditCards: [CreditCard] = [] {
        didSet { invalidateDerivedCaches() }
    }
    @Published public var creditCardInvoices: [CreditCardInvoice] = [] {
        didSet { invalidateDerivedCaches() }
    }
    @Published public var categories: [CategoryItem] = [] {
        didSet { invalidateDerivedCaches() }
    }
    @Published public var transactions: [FinancialTransaction] = [] {
        didSet { invalidateDerivedCaches() }
    }
    @Published public var investments: [InvestmentItem] = [] {
        didSet { invalidateDerivedCaches() }
    }
    @Published public var debts: [DebtItem] = [] {
        didSet { invalidateDerivedCaches() }
    }
    @Published public var contracts: [CreditContract] = [] {
        didSet { invalidateDerivedCaches() }
    }
    @Published public var amortizationPlans: [AmortizationPlan] = [] {
        didSet { invalidateDerivedCaches() }
    }
    @Published public var budgetProjectionScenario: BudgetProjectionScenario = .withPlanning {
        didSet { invalidateDerivedCaches() }
    }
    @Published public var provisions: [CategoryProvision] = [] {
        didSet { invalidateDerivedCaches() }
    }
    @Published public var categoryQuotas: [CategoryQuotaRule] = [] {
        didSet { invalidateDerivedCaches() }
    }

    @Published public var selectedMonth: Date = Date() {
        didSet {
            ensureRecurringTransactionsMaterialized(upTo: endOfYear(for: selectedMonth))
        }
    }
    @Published public var dashboardPeriodMode: DashboardPeriodMode = .monthly
    @Published public var isHideBalancesEnabled: Bool = false
    @Published public private(set) var dataRevision: UInt64 = 0

    @Published public var simulatedCurrentDate: Date? = nil {
        didSet {
            invalidateDerivedCaches()
            validateExpiredAmortizationPlans()
        }
    }

    private var isBatchLoading: Bool = false
    private var cachedTransactionsByYM: [Int: [FinancialTransaction]]? = nil
    private var cachedTransactionsByYear: [Int: [FinancialTransaction]]? = nil
    private var cachedAccountsById: [UUID: BankAccount]? = nil
    private var cachedCreditCardsById: [UUID: CreditCard]? = nil
    private var cachedCategoriesById: [UUID: CategoryItem]? = nil
    private var cachedLoanProjections: [UUID: LoanProjectionResult] = [:]
    private var cachedActiveProjectionSnapshot: (shadowedTxIds: Set<UUID>, projectedInstallmentAmounts: [UUID: Double], payoffTxIds: Set<UUID>)? = nil
    private var cachedKPISummaryByKey: [Int: UnifiedFinancialKPISummary] = [:]
    private var cachedIntraMonthAnalysisByYM: [Int: IntraMonthCashFlowAnalysis] = [:]
    private var maxMaterializedRecurringDate: Date? = nil
    private let diskPersistenceQueue = DispatchQueue(label: "br.com.finsense.ios.databasePersistence", qos: .utility)
    private static let snapshotEncoder = JSONEncoder()

    public func invalidateDerivedCaches() {
        cachedTransactionsByYM = nil
        cachedTransactionsByYear = nil
        cachedAccountsById = nil
        cachedCreditCardsById = nil
        cachedCategoriesById = nil
        cachedLoanProjections.removeAll(keepingCapacity: true)
        cachedActiveProjectionSnapshot = nil
        cachedKPISummaryByKey.removeAll(keepingCapacity: true)
        cachedIntraMonthAnalysisByYM.removeAll(keepingCapacity: true)
        maxMaterializedRecurringDate = nil
        if !isBatchLoading {
            dataRevision &+= 1
        }
    }

    private func ensureTransactionIndexesBuilt() {
        guard cachedTransactionsByYM == nil || cachedTransactionsByYear == nil else { return }
        var byYM: [Int: [FinancialTransaction]] = [:]
        var byYear: [Int: [FinancialTransaction]] = [:]
        byYM.reserveCapacity(24)
        byYear.reserveCapacity(4)

        for tx in transactions {
            let comps = calendar.dateComponents([.year, .month], from: tx.date)
            if let y = comps.year, let m = comps.month {
                let ymKey = y * 100 + m
                byYM[ymKey, default: []].append(tx)
                byYear[y, default: []].append(tx)
            }
        }
        cachedTransactionsByYM = byYM
        cachedTransactionsByYear = byYear
    }

    public weak var cloudSyncService: CloudSyncService?

    public let databaseFileURL: URL
    public let attachmentsDirectoryURL: URL

    public var effectiveCurrentDate: Date { simulatedCurrentDate ?? Date() }

    public let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "pt_BR")
        return cal
    }()

    public init(customFileURL: URL? = nil) {
        if let customFileURL {
            self.databaseFileURL = customFileURL
            self.attachmentsDirectoryURL = customFileURL.deletingLastPathComponent().appendingPathComponent("Attachments", isDirectory: true)
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.databaseFileURL = docs.appendingPathComponent("financial_database.json")
            self.attachmentsDirectoryURL = docs.appendingPathComponent("Attachments", isDirectory: true)
        }

        try? FileManager.default.createDirectory(at: attachmentsDirectoryURL, withIntermediateDirectories: true)
        loadFromDisk()
    }

    // MARK: - Persistence (Snapshot JSON)

    public func loadFromDisk() {
        let fm = FileManager.default
        if fm.fileExists(atPath: databaseFileURL.path),
           let data = try? Data(contentsOf: databaseFileURL),
           let decoded = try? JSONDecoder().decode(FinancialDatabaseSnapshot.self, from: data) {
            self.accounts = decoded.accounts
            self.creditCards = decoded.creditCards ?? []
            self.creditCardInvoices = decoded.creditCardInvoices ?? []
            self.categories = decoded.categories.isEmpty ? DefaultCategoriesCatalog.buildInitialCategories() : decoded.categories
            self.transactions = decoded.transactions
            self.investments = decoded.investments
            self.debts = decoded.debts
            self.contracts = decoded.contracts
            self.amortizationPlans = decoded.amortizationPlans ?? []
            if let savedScenario = decoded.budgetProjectionScenario {
                self.budgetProjectionScenario = savedScenario
            }
            self.provisions = decoded.provisions ?? []
            self.categoryQuotas = decoded.categoryQuotas ?? []
            ensureRecurringTransactionsMaterialized(upTo: endOfYear(for: selectedMonth))

            // Migrar e garantir categoria "Aportes e investimentos" para depósitos e cotas de investimento
            let aporteCatId = self.investmentDepositCategoryId()
            var mutatedData = false
            for i in 0..<self.transactions.count {
                if self.transactions[i].transactionOrigin == .investmentDeposit && self.transactions[i].categoryId != aporteCatId {
                    self.transactions[i].categoryId = aporteCatId
                    mutatedData = true
                }
            }
            for i in 0..<self.categoryQuotas.count {
                if self.categoryQuotas[i].quotaType == .investment && self.categoryQuotas[i].categoryId != aporteCatId {
                    self.categoryQuotas[i].categoryId = aporteCatId
                    mutatedData = true
                }
            }
            if migrateExistingSantanderContractsIfNeeded() {
                mutatedData = true
            }
            if migrateExistingCaixaContractsIfNeeded() {
                mutatedData = true
            }
            for plan in self.amortizationPlans {
                syncPlannedAmortizationTransactions(for: plan.contractId, saveAfter: false)
            }
            if !self.creditCards.isEmpty {
                syncAllCreditCardInvoices(saveAfter: false)
            }
            if mutatedData || !self.amortizationPlans.isEmpty {
                saveToDisk()
            }
            validateExpiredAmortizationPlans()
        } else {
            self.categories = DefaultCategoriesCatalog.buildInitialCategories()
            self.accounts = []
            self.creditCards = []
            self.creditCardInvoices = []
            self.transactions = []
            self.investments = []
            self.debts = []
            self.contracts = []
            self.amortizationPlans = []
            self.provisions = []
            self.categoryQuotas = []
            saveToDisk()
        }
    }

    public func saveToDisk() {
        let snapshot = FinancialDatabaseSnapshot(
            schemaVersion: 3,
            accounts: accounts,
            creditCards: creditCards,
            creditCardInvoices: creditCardInvoices,
            categories: categories,
            transactions: transactions,
            investments: investments,
            debts: debts,
            contracts: contracts,
            amortizationPlans: amortizationPlans,
            budgetProjectionScenario: budgetProjectionScenario,
            provisions: provisions,
            categoryQuotas: categoryQuotas
        )
        let targetURL = databaseFileURL
        diskPersistenceQueue.async {
            if let data = try? Self.snapshotEncoder.encode(snapshot) {
                try? data.write(to: targetURL, options: .atomic)
            }
        }
    }

    public func save() {
        saveToDisk()
    }

    // MARK: - Helpers de Categoria e Conta

    public func account(for id: UUID?) -> BankAccount? {
        guard let id else { return nil }
        if cachedAccountsById == nil {
            cachedAccountsById = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        }
        return cachedAccountsById?[id]
    }

    public func category(for id: UUID?) -> CategoryItem? {
        guard let id else { return nil }
        if cachedCategoriesById == nil {
            cachedCategoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        }
        return cachedCategoriesById?[id]
    }

    public func fallbackCategoryId(for type: TransactionType, matchingSubstring: String = "") -> UUID {
        if !matchingSubstring.isEmpty,
           let match = categories.first(where: { $0.type == type && $0.name.localizedCaseInsensitiveContains(matchingSubstring) }) {
            return match.id
        }
        return categories.first(where: { $0.type == type })?.id ?? categories.first?.id ?? UUID()
    }

    /// Retorna a categoria padronizada "Aportes e investimentos", migrando registros legados
    /// ou criando-a sob demanda caso ainda não exista no catálogo de categorias do usuário.
    public func investmentDepositCategoryId() -> UUID {
        // 1. Categoria exata de despesa "Aportes e investimentos"
        if let exact = categories.first(where: { $0.type == .expense && $0.name.compare("Aportes e investimentos", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return exact.id
        }
        // 2. Se houver legado "Aportes em Investimentos", atualizar nome
        if let legacyIdx = categories.firstIndex(where: { $0.type == .expense && $0.name.compare("Aportes em Investimentos", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            categories[legacyIdx].name = "Aportes e investimentos"
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "categories", entityId: categories[legacyIdx].id, operation: .upsert, entity: categories[legacyIdx])
            return categories[legacyIdx].id
        }
        // 3. Qualquer categoria que contenha "aporte"
        if let aporteIdx = categories.firstIndex(where: { $0.type == .expense && $0.name.localizedCaseInsensitiveContains("aporte") }) {
            categories[aporteIdx].name = "Aportes e investimentos"
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "categories", entityId: categories[aporteIdx].id, operation: .upsert, entity: categories[aporteIdx])
            return categories[aporteIdx].id
        }
        // 4. Se não existir, criar a categoria "Aportes e investimentos"
        let newCat = CategoryItem(
            name: "Aportes e investimentos",
            type: .expense,
            iconSymbol: "chart.line.uptrend.xyaxis",
            colorHex: "#6366F1",
            keywords: ["APORTE", "INVESTIMENTO", "CDB", "POUPANCA", "COFRINHO"],
            isSystemDefault: true
        )
        categories.append(newCat)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "categories", entityId: newCat.id, operation: .upsert, entity: newCat)
        return newCat.id
    }

    // MARK: - CRUD: Contas Bancárias

    public func createAccount(
        name: String,
        bankPresetId: String? = nil,
        customImagePath: String? = nil,
        iconSymbol: String = "building.columns.fill",
        colorHex: String = "#EC7000",
        initialBalance: Double = 0.0,
        agency: String = "",
        accountNumber: String = ""
    ) {
        let acc = BankAccount(
            name: name,
            bankPresetId: bankPresetId,
            customImagePath: customImagePath,
            iconSymbol: iconSymbol,
            colorHex: colorHex,
            initialBalance: initialBalance,
            agency: agency,
            accountNumber: accountNumber
        )
        accounts.append(acc)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "bank_accounts", entityId: acc.id, operation: .upsert, entity: acc)
    }

    public func updateAccount(_ account: BankAccount) {
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = account
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "bank_accounts", entityId: account.id, operation: .upsert, entity: account)
        }
    }

    public func deleteAccount(_ accountId: UUID) {
        accounts.removeAll { $0.id == accountId }
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "bank_accounts", entityId: accountId, operation: .delete)
    }

    public func accountBalance(for accountId: UUID) -> Double {
        currentBalance(forAccount: accountId)
    }

    public var totalCurrentBalance: Double {
        totalCheckingBalanceNow
    }

    // MARK: - Cartões de Crédito, Faturas e Competência vs. Caixa

    public func creditCard(for id: UUID?) -> CreditCard? {
        guard let id else { return nil }
        if cachedCreditCardsById == nil {
            cachedCreditCardsById = Dictionary(uniqueKeysWithValues: creditCards.map { ($0.id, $0) })
        }
        return cachedCreditCardsById?[id]
    }

    @discardableResult
    public func addCreditCard(
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
        lastFourDigits: String = ""
    ) -> CreditCard {
        let card = CreditCard(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            totalLimit: totalLimit,
            closingDay: closingDay,
            bestPurchaseDay: bestPurchaseDay,
            dueDay: dueDay,
            defaultPaymentAccountId: defaultPaymentAccountId,
            brand: brand,
            bankPresetId: bankPresetId,
            customImagePath: customImagePath,
            iconSymbol: iconSymbol,
            colorHex: colorHex,
            lastFourDigits: lastFourDigits
        )
        creditCards.append(card)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "credit_cards", entityId: card.id, operation: .upsert, entity: card)
        return card
    }

    public func updateCreditCard(_ card: CreditCard) {
        guard let idx = creditCards.firstIndex(where: { $0.id == card.id }) else { return }
        creditCards[idx] = card
        let invoiceKeys = Set(creditCardInvoices.filter { $0.creditCardId == card.id }.map(\.yearMonthKey))
            .union(Set(transactions.filter { $0.creditCardId == card.id && !$0.isCreditCardInvoicePayment }.compactMap(\.creditCardInvoiceYearMonthKey)))
        for ymKey in invoiceKeys {
            syncCreditCardInvoice(cardId: card.id, yearMonthKey: ymKey, saveAfter: false)
        }
        sortTransactions()
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "credit_cards", entityId: card.id, operation: .upsert, entity: card)
    }

    public func deleteCreditCard(_ cardId: UUID) {
        let deletedTxIds = transactions
            .filter { $0.creditCardId == cardId && $0.isCreditCardInvoicePayment && !$0.isPaid }
            .map(\.id)
        let deletedInvIds = creditCardInvoices.filter { $0.creditCardId == cardId }.map(\.id)

        transactions.removeAll { $0.creditCardId == cardId && $0.isCreditCardInvoicePayment && !$0.isPaid }
        for idx in transactions.indices where transactions[idx].creditCardId == cardId {
            transactions[idx].creditCardId = nil
            transactions[idx].creditCardInvoiceYearMonthKey = nil
            transactions[idx].creditCardInvoiceId = nil
            if let fallbackBank = accounts.first?.id, !accounts.contains(where: { $0.id == transactions[idx].accountId }) {
                transactions[idx].accountId = fallbackBank
            }
            cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: transactions[idx].id, operation: .upsert, entity: transactions[idx])
        }
        creditCardInvoices.removeAll { $0.creditCardId == cardId }
        creditCards.removeAll { $0.id == cardId }
        sortTransactions()
        saveToDisk()
        for id in deletedTxIds {
            cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: id, operation: .delete)
        }
        for id in deletedInvIds {
            cloudSyncService?.recordLocalMutation(entityName: "credit_card_invoices", entityId: id, operation: .delete)
        }
        cloudSyncService?.recordLocalMutation(entityName: "credit_cards", entityId: cardId, operation: .delete)
    }

    public func creditCardPaymentCategoryId() -> UUID {
        if let existing = categories.first(where: {
            $0.type == .expense && (
                $0.name.localizedCaseInsensitiveContains("cart") ||
                $0.name.localizedCaseInsensitiveContains("fatura")
            )
        }) {
            return existing.id
        }
        return fallbackCategoryId(for: .expense)
    }

    public func usedLimit(for cardId: UUID) -> Double {
        let paidKeys = Set(creditCardInvoices.filter { $0.creditCardId == cardId && $0.isPaid }.map(\.yearMonthKey))
        let unpaidCardExpenses = transactions.filter { tx in
            guard tx.creditCardId == cardId,
                  !tx.isCreditCardInvoicePayment,
                  !tx.ignoreInConsolidated else { return false }
            if let ymKey = tx.creditCardInvoiceYearMonthKey, paidKeys.contains(ymKey) {
                return false
            }
            return true
        }
        return CreditCardEngine.exactSum(unpaidCardExpenses.map(\.amount))
    }

    public func availableLimit(for cardId: UUID) -> Double {
        guard let card = creditCard(for: cardId) else { return 0.0 }
        return max(0.0, card.totalLimit - usedLimit(for: cardId))
    }

    public func invoiceSummary(for cardId: UUID, year: Int, month: Int) -> CreditCardInvoiceSummary? {
        guard let card = creditCard(for: cardId) else { return nil }
        let ymKey = year * 100 + month
        let existingInv = creditCardInvoices.first { $0.creditCardId == cardId && $0.yearMonthKey == ymKey }
        let dates = CreditCardEngine.closingAndDueDates(forInvoiceYear: year, month: month, card: card, calendar: calendar)
        let cycleTransactions = transactions
            .filter {
                $0.creditCardId == cardId &&
                !$0.isCreditCardInvoicePayment &&
                !$0.ignoreInConsolidated &&
                $0.creditCardInvoiceYearMonthKey == ymKey
            }
            .sorted { a, b in
                if a.date == b.date { return a.createdAt < b.createdAt }
                return a.date < b.date
            }
        let total = CreditCardEngine.exactSum(cycleTransactions.map(\.amount))
        let isPaid = existingInv?.isPaid ?? false
        let status = CreditCardEngine.invoiceStatus(
            isPaid: isPaid,
            invoiceYear: year,
            invoiceMonth: month,
            card: card,
            referenceNow: effectiveCurrentDate,
            calendar: calendar
        )
        return CreditCardInvoiceSummary(
            cardId: cardId,
            invoiceId: existingInv?.id,
            year: year,
            month: month,
            yearMonthKey: ymKey,
            monthYearLabel: CreditCardEngine.fullInvoiceLabel(year: year, month: month, calendar: calendar),
            closingDate: existingInv?.closingDate ?? dates.closingDate,
            dueDate: existingInv?.dueDate ?? dates.dueDate,
            status: status,
            transactions: cycleTransactions,
            totalAmount: (isPaid && total <= 0.001) ? (existingInv?.paidAmount ?? 0.0) : total,
            paidAmount: existingInv?.paidAmount,
            paidDate: existingInv?.paidDate,
            paymentAccountId: existingInv?.paidFromAccountId ?? card.defaultPaymentAccountId ?? accounts.first?.id,
            paymentTransactionId: existingInv?.paymentTransactionId
        )
    }

    public func allRelevantInvoiceMonths(for cardId: UUID, around referenceDate: Date? = nil) -> [(year: Int, month: Int, key: Int)] {
        let ref = referenceDate ?? effectiveCurrentDate
        var keys = Set<Int>()
        let curYM = calendar.dateComponents([.year, .month], from: ref)
        let curY = curYM.year ?? 2026
        let curM = curYM.month ?? 1
        for offset in -2...2 {
            keys.insert(CreditCardEngine.addMonths(offset, toYear: curY, month: curM).yearMonthKey)
        }
        if let card = creditCard(for: cardId) {
            keys.insert(CreditCardEngine.allocateInvoice(forPurchaseDate: ref, card: card, calendar: calendar).yearMonthKey)
        }
        for inv in creditCardInvoices where inv.creditCardId == cardId {
            keys.insert(inv.yearMonthKey)
        }
        for tx in transactions where tx.creditCardId == cardId && !tx.isCreditCardInvoicePayment {
            if let k = tx.creditCardInvoiceYearMonthKey { keys.insert(k) }
        }
        return keys.sorted().map { key in
            let c = CreditCardEngine.yearMonthComponents(fromKey: key)
            return (c.year, c.month, key)
        }
    }

    public func syncAllCreditCardInvoices(saveAfter: Bool = false) {
        var pairs = Set<String>()
        var list: [(UUID, Int)] = []
        for inv in creditCardInvoices {
            let k = "\(inv.creditCardId.uuidString)|\(inv.yearMonthKey)"
            if pairs.insert(k).inserted { list.append((inv.creditCardId, inv.yearMonthKey)) }
        }
        for tx in transactions where tx.creditCardId != nil && !tx.isCreditCardInvoicePayment {
            if let cid = tx.creditCardId, let ym = tx.creditCardInvoiceYearMonthKey {
                let k = "\(cid.uuidString)|\(ym)"
                if pairs.insert(k).inserted { list.append((cid, ym)) }
            }
        }
        for (cid, ym) in list {
            syncCreditCardInvoice(cardId: cid, yearMonthKey: ym, saveAfter: false)
        }
        if saveAfter {
            sortTransactions()
            saveToDisk()
        }
    }

    public func syncCreditCardInvoice(cardId: UUID, yearMonthKey: Int, saveAfter: Bool = true) {
        guard let card = creditCard(for: cardId) else {
            transactions.removeAll {
                $0.creditCardId == cardId &&
                $0.creditCardInvoiceYearMonthKey == yearMonthKey &&
                $0.isCreditCardInvoicePayment &&
                !$0.isPaid
            }
            if saveAfter { sortTransactions(); saveToDisk() }
            return
        }

        let ymComps = CreditCardEngine.yearMonthComponents(fromKey: yearMonthKey)
        let dates = CreditCardEngine.closingAndDueDates(forInvoiceYear: ymComps.year, month: ymComps.month, card: card, calendar: calendar)
        let cycleExpenseIndices = transactions.indices.filter { idx in
            let tx = transactions[idx]
            return tx.creditCardId == cardId && !tx.isCreditCardInvoicePayment && !tx.ignoreInConsolidated && tx.creditCardInvoiceYearMonthKey == yearMonthKey
        }
        let cycleTotal = CreditCardEngine.exactSum(cycleExpenseIndices.map { transactions[$0].amount })
        let existingInvIdx = creditCardInvoices.firstIndex { $0.creditCardId == cardId && $0.yearMonthKey == yearMonthKey }

        if let invIdx = existingInvIdx, creditCardInvoices[invIdx].isPaid {
            creditCardInvoices[invIdx].closingDate = dates.closingDate
            creditCardInvoices[invIdx].dueDate = dates.dueDate
            let invId = creditCardInvoices[invIdx].id
            for tIdx in cycleExpenseIndices {
                transactions[tIdx].creditCardInvoiceId = invId
            }
            if saveAfter { sortTransactions(); saveToDisk() }
            return
        }

        if cycleTotal > 0.001 {
            let invIdx: Int
            if let existing = existingInvIdx {
                creditCardInvoices[existing].closingDate = dates.closingDate
                creditCardInvoices[existing].dueDate = dates.dueDate
                invIdx = existing
            } else {
                let newInv = CreditCardInvoice(
                    creditCardId: cardId,
                    year: ymComps.year,
                    month: ymComps.month,
                    closingDate: dates.closingDate,
                    dueDate: dates.dueDate,
                    isPaid: false
                )
                creditCardInvoices.append(newInv)
                invIdx = creditCardInvoices.count - 1
            }

            let invoice = creditCardInvoices[invIdx]
            for tIdx in cycleExpenseIndices {
                transactions[tIdx].creditCardInvoiceId = invoice.id
            }

            let targetAccountId = invoice.paidFromAccountId ?? card.defaultPaymentAccountId ?? accounts.first?.id
            let shortLabel = CreditCardEngine.shortInvoiceLabel(year: ymComps.year, month: ymComps.month, calendar: calendar)
            let fullLabel = CreditCardEngine.fullInvoiceLabel(year: ymComps.year, month: ymComps.month, calendar: calendar)
            let txTitle = "Pagamento Fatura: \(card.name) (\(shortLabel))"
            let count = cycleExpenseIndices.count
            let txDetails = "Pagamento de fatura \(fullLabel) • Venc. \(AppFormatters.shortDate(dates.dueDate)) (\(count) lançamento\(count == 1 ? "" : "s"))"

            if let existingPayTxIdx = transactions.firstIndex(where: {
                ($0.id == invoice.paymentTransactionId) ||
                ($0.isCreditCardInvoicePayment && $0.creditCardId == cardId && $0.creditCardInvoiceYearMonthKey == yearMonthKey)
            }) {
                if !transactions[existingPayTxIdx].isPaid {
                    transactions[existingPayTxIdx].name = txTitle
                    transactions[existingPayTxIdx].details = txDetails
                    transactions[existingPayTxIdx].amount = cycleTotal
                    transactions[existingPayTxIdx].date = dates.dueDate
                    if let accId = targetAccountId {
                        transactions[existingPayTxIdx].accountId = accId
                    }
                    transactions[existingPayTxIdx].ignoreInConsolidated = false
                    transactions[existingPayTxIdx].creditCardId = cardId
                    transactions[existingPayTxIdx].creditCardInvoiceId = invoice.id
                    transactions[existingPayTxIdx].creditCardInvoiceYearMonthKey = yearMonthKey
                    transactions[existingPayTxIdx].linkedEntityID = invoice.id
                    creditCardInvoices[invIdx].paymentTransactionId = transactions[existingPayTxIdx].id
                    cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: transactions[existingPayTxIdx].id, operation: .upsert, entity: transactions[existingPayTxIdx])
                }
            } else if let accId = targetAccountId {
                let payTxId = invoice.paymentTransactionId ?? UUID()
                let payTx = FinancialTransaction(
                    id: payTxId,
                    name: txTitle,
                    details: txDetails,
                    amount: cycleTotal,
                    date: dates.dueDate,
                    type: .expense,
                    isPaid: false,
                    categoryId: creditCardPaymentCategoryId(),
                    accountId: accId,
                    ignoreInConsolidated: false,
                    recurrenceMode: .single,
                    transactionOrigin: .creditCardInvoicePayment,
                    linkedEntityID: invoice.id,
                    creditCardId: cardId,
                    creditCardInvoiceYearMonthKey: yearMonthKey,
                    creditCardInvoiceId: invoice.id
                )
                transactions.append(payTx)
                creditCardInvoices[invIdx].paymentTransactionId = payTx.id
                cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: payTx.id, operation: .upsert, entity: payTx)
            }
            cloudSyncService?.recordLocalMutation(entityName: "credit_card_invoices", entityId: creditCardInvoices[invIdx].id, operation: .upsert, entity: creditCardInvoices[invIdx])
        } else {
            var removedTxIds: [UUID] = []
            transactions.removeAll { tx in
                let matches = (tx.isCreditCardInvoicePayment && tx.creditCardId == cardId && tx.creditCardInvoiceYearMonthKey == yearMonthKey && !tx.isPaid)
                if matches { removedTxIds.append(tx.id) }
                return matches
            }
            if let existing = existingInvIdx {
                let invId = creditCardInvoices[existing].id
                creditCardInvoices.remove(at: existing)
                cloudSyncService?.recordLocalMutation(entityName: "credit_card_invoices", entityId: invId, operation: .delete)
            }
            for txId in removedTxIds {
                cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: txId, operation: .delete)
            }
        }

        if saveAfter {
            sortTransactions()
            invalidateDerivedCaches()
            saveToDisk()
        }
    }

    @discardableResult
    public func payCreditCardInvoice(
        cardId: UUID,
        year: Int,
        month: Int,
        fromAccountId accountId: UUID,
        amount: Double? = nil,
        paymentDate: Date? = nil
    ) -> Bool {
        guard let card = creditCard(for: cardId),
              account(for: accountId) != nil else {
            return false
        }
        let ymKey = year * 100 + month
        syncCreditCardInvoice(cardId: cardId, yearMonthKey: ymKey, saveAfter: false)

        guard let summary = invoiceSummary(for: cardId, year: year, month: month) else {
            return false
        }
        let resolvedAmount = max(0.01, ((amount ?? summary.totalAmount) * 100.0).rounded() / 100.0)
        let resolvedDate = paymentDate ?? effectiveCurrentDate

        let invIdx: Int
        if let idx = creditCardInvoices.firstIndex(where: { $0.creditCardId == cardId && $0.yearMonthKey == ymKey }) {
            invIdx = idx
        } else {
            let dates = CreditCardEngine.closingAndDueDates(forInvoiceYear: year, month: month, card: card, calendar: calendar)
            let newInv = CreditCardInvoice(creditCardId: cardId, year: year, month: month, closingDate: dates.closingDate, dueDate: dates.dueDate, isPaid: false)
            creditCardInvoices.append(newInv)
            invIdx = creditCardInvoices.count - 1
        }

        creditCardInvoices[invIdx].isPaid = true
        creditCardInvoices[invIdx].paidAmount = resolvedAmount
        creditCardInvoices[invIdx].paidDate = resolvedDate
        creditCardInvoices[invIdx].paidFromAccountId = accountId

        let invoice = creditCardInvoices[invIdx]
        for idx in transactions.indices where transactions[idx].creditCardId == cardId && !transactions[idx].isCreditCardInvoicePayment && transactions[idx].creditCardInvoiceYearMonthKey == ymKey {
            transactions[idx].creditCardInvoiceId = invoice.id
        }

        let shortLabel = CreditCardEngine.shortInvoiceLabel(year: year, month: month, calendar: calendar)
        let fullLabel = CreditCardEngine.fullInvoiceLabel(year: year, month: month, calendar: calendar)
        let txTitle = "Pagamento Fatura: \(card.name) (\(shortLabel))"
        let txDetails = "Fatura \(fullLabel) paga em \(AppFormatters.shortDate(resolvedDate))"

        if let payIdx = transactions.firstIndex(where: {
            ($0.id == invoice.paymentTransactionId) ||
            ($0.isCreditCardInvoicePayment && $0.creditCardId == cardId && $0.creditCardInvoiceYearMonthKey == ymKey)
        }) {
            transactions[payIdx].name = txTitle
            transactions[payIdx].details = txDetails
            transactions[payIdx].amount = resolvedAmount
            transactions[payIdx].date = resolvedDate
            transactions[payIdx].isPaid = true
            transactions[payIdx].accountId = accountId
            transactions[payIdx].ignoreInConsolidated = false
            transactions[payIdx].creditCardId = cardId
            transactions[payIdx].creditCardInvoiceId = invoice.id
            transactions[payIdx].creditCardInvoiceYearMonthKey = ymKey
            transactions[payIdx].linkedEntityID = invoice.id
            creditCardInvoices[invIdx].paymentTransactionId = transactions[payIdx].id
            cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: transactions[payIdx].id, operation: .upsert, entity: transactions[payIdx])
        } else {
            let payTx = FinancialTransaction(
                name: txTitle,
                details: txDetails,
                amount: resolvedAmount,
                date: resolvedDate,
                type: .expense,
                isPaid: true,
                categoryId: creditCardPaymentCategoryId(),
                accountId: accountId,
                ignoreInConsolidated: false,
                recurrenceMode: .single,
                transactionOrigin: .creditCardInvoicePayment,
                linkedEntityID: invoice.id,
                creditCardId: cardId,
                creditCardInvoiceYearMonthKey: ymKey,
                creditCardInvoiceId: invoice.id
            )
            transactions.append(payTx)
            creditCardInvoices[invIdx].paymentTransactionId = payTx.id
            cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: payTx.id, operation: .upsert, entity: payTx)
        }

        cloudSyncService?.recordLocalMutation(entityName: "credit_card_invoices", entityId: creditCardInvoices[invIdx].id, operation: .upsert, entity: creditCardInvoices[invIdx])
        sortTransactions()
        invalidateDerivedCaches()
        saveToDisk()
        return true
    }

    @discardableResult
    public func createCreditCardInstallments(
        name: String,
        details: String = "",
        totalAmount: Double,
        purchaseDate: Date,
        categoryId: UUID,
        cardId: UUID,
        installmentsCount: Int
    ) -> [FinancialTransaction] {
        guard let card = creditCard(for: cardId) else { return [] }
        let safeCount = max(1, installmentsCount)
        let parts = CreditCardEngine.splitInstallmentsExactCents(totalAmount: totalAmount, count: safeCount)
        let baseCycle = CreditCardEngine.allocateInvoice(forPurchaseDate: purchaseDate, card: card, calendar: calendar)
        let seriesId = safeCount > 1 ? UUID() : nil
        let effectiveCategoryId = categories.contains(where: { $0.id == categoryId })
            ? categoryId
            : (categories.first(where: { $0.type == .expense })?.id ?? categoryId)

        var created: [FinancialTransaction] = []
        var touchedKeys: Set<Int> = []
        for idx in 0..<safeCount {
            let installmentNumber = idx + 1
            let targetYM = CreditCardEngine.addMonths(idx, toYear: baseCycle.year, month: baseCycle.month)
            let txDate = calendar.date(byAdding: .month, value: idx, to: purchaseDate) ?? purchaseDate
            let title = safeCount > 1 ? "\(name) (\(installmentNumber)/\(safeCount))" : name
            let tx = FinancialTransaction(
                name: title,
                details: details,
                amount: parts[idx],
                date: txDate,
                type: .expense,
                isPaid: false,
                categoryId: effectiveCategoryId,
                accountId: card.id,
                recurrenceMode: safeCount > 1 ? .installment : .single,
                seriesGroupId: seriesId,
                installmentIndex: safeCount > 1 ? installmentNumber : nil,
                installmentTotal: safeCount > 1 ? safeCount : nil,
                creditCardId: card.id,
                creditCardInvoiceYearMonthKey: targetYM.yearMonthKey
            )
            transactions.append(tx)
            created.append(tx)
            touchedKeys.insert(targetYM.yearMonthKey)
            cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: tx.id, operation: .upsert, entity: tx)
        }
        for ymKey in touchedKeys.sorted() {
            syncCreditCardInvoice(cardId: card.id, yearMonthKey: ymKey, saveAfter: false)
        }
        sortTransactions()
        invalidateDerivedCaches()
        saveToDisk()
        return created
    }

    // MARK: - CRUD: Categorias

    public func createCategory(
        name: String,
        type: TransactionType,
        iconSymbol: String = "tag.fill",
        colorHex: String = "#64748B",
        keywords: [String] = []
    ) {
        let cat = CategoryItem(
            name: name,
            type: type,
            iconSymbol: iconSymbol,
            colorHex: colorHex,
            keywords: keywords,
            isSystemDefault: false
        )
        categories.append(cat)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "categories", entityId: cat.id, operation: .upsert, entity: cat)
    }

    public func updateCategory(_ category: CategoryItem) {
        if let idx = categories.firstIndex(where: { $0.id == category.id }) {
            categories[idx] = category
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "categories", entityId: category.id, operation: .upsert, entity: category)
        }
    }

    public func deleteCategory(_ categoryId: UUID) {
        categories.removeAll { $0.id == categoryId }
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "categories", entityId: categoryId, operation: .delete)
    }

    // MARK: - CRUD: Transações Financeiras

    @discardableResult
    public func createTransaction(
        name: String,
        details: String = "",
        amount: Double,
        date: Date,
        type: TransactionType,
        isPaid: Bool = true,
        categoryId: UUID,
        accountId: UUID,
        recurrenceMode: TransactionRecurrenceMode = .single,
        ignoreInConsolidated: Bool = false,
        installmentIndex: Int? = nil,
        installmentTotal: Int? = nil,
        seriesGroupId: UUID? = nil,
        linkedContractId: UUID? = nil,
        linkedInvestmentId: UUID? = nil,
        linkedDebtId: UUID? = nil,
        linkedQuotaId: UUID? = nil,
        linkedQuotaUnits: Int? = nil,
        linkedQuotaYearMonthKey: Int? = nil,
        transactionOrigin: TransactionOrigin? = nil,
        linkedEntityID: UUID? = nil,
        baseInstallmentRegisteredAmount: Double? = nil,
        projectedInstallmentCorrectionAmount: Double? = nil,
        confirmedRealInterestCorrectionAmount: Double? = nil,
        creditCardId: UUID? = nil
    ) -> FinancialTransaction {
        let effectiveCreditCardId: UUID? = (type == .expense && transactionOrigin != .creditCardInvoicePayment)
            ? (creditCardId ?? (creditCard(for: accountId)?.id))
            : creditCardId

        let effectiveAccountId: UUID = {
            if let cid = effectiveCreditCardId, transactionOrigin != .creditCardInvoicePayment {
                return cid
            }
            return accounts.contains(where: { $0.id == accountId })
                ? accountId
                : (accounts.first?.id ?? accountId)
        }()

        let effectiveCategoryId: UUID = categories.contains(where: { $0.id == categoryId })
            ? categoryId
            : (categories.first(where: { $0.type == type })?.id ?? categories.first?.id ?? categoryId)

        let allocatedCardYM: Int? = {
            guard let cid = effectiveCreditCardId,
                  transactionOrigin != .creditCardInvoicePayment,
                  let card = creditCard(for: cid) else {
                return nil
            }
            return CreditCardEngine.allocateInvoice(forPurchaseDate: date, card: card, calendar: calendar).yearMonthKey
        }()
        let effectiveIsPaid = (effectiveCreditCardId != nil && transactionOrigin != .creditCardInvoicePayment) ? false : isPaid

        let tx = FinancialTransaction(
            name: name,
            details: details,
            amount: amount,
            date: date,
            type: type,
            isPaid: effectiveIsPaid,
            categoryId: effectiveCategoryId,
            accountId: effectiveAccountId,
            ignoreInConsolidated: ignoreInConsolidated,
            recurrenceMode: recurrenceMode,
            seriesGroupId: seriesGroupId,
            installmentIndex: installmentIndex,
            installmentTotal: installmentTotal,
            linkedContractId: linkedContractId,
            linkedInvestmentId: linkedInvestmentId,
            linkedDebtId: linkedDebtId,
            linkedQuotaId: linkedQuotaId,
            linkedQuotaUnits: linkedQuotaUnits,
            linkedQuotaYearMonthKey: linkedQuotaYearMonthKey,
            transactionOrigin: transactionOrigin,
            linkedEntityID: linkedEntityID,
            baseInstallmentRegisteredAmount: baseInstallmentRegisteredAmount,
            projectedInstallmentCorrectionAmount: projectedInstallmentCorrectionAmount,
            confirmedRealInterestCorrectionAmount: confirmedRealInterestCorrectionAmount,
            creditCardId: effectiveCreditCardId,
            creditCardInvoiceYearMonthKey: allocatedCardYM
        )
        transactions.append(tx)
        if let cid = effectiveCreditCardId, let ymKey = allocatedCardYM {
            syncCreditCardInvoice(cardId: cid, yearMonthKey: ymKey, saveAfter: false)
        }
        sortTransactions()
        invalidateDerivedCaches()
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: tx.id, operation: .upsert, entity: tx)
        return tx
    }

    public func isDateInFuture(_ date: Date, referenceNow: Date? = nil) -> Bool {
        let now = referenceNow ?? effectiveCurrentDate
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: now)
    }

    public func updateTransaction(_ tx: FinancialTransaction, referenceNow: Date? = nil) {
        let now = referenceNow ?? effectiveCurrentDate
        var validated = tx
        let isCardExp = (validated.creditCardId != nil && validated.transactionOrigin != .creditCardInvoicePayment)
        if isCardExp, let cid = validated.creditCardId {
            validated.accountId = cid
            validated.isPaid = false
            if let card = creditCard(for: cid) {
                validated.creditCardInvoiceYearMonthKey = CreditCardEngine.allocateInvoice(
                    forPurchaseDate: validated.date,
                    card: card,
                    calendar: calendar
                ).yearMonthKey
            }
        } else {
            if !accounts.contains(where: { $0.id == validated.accountId }), let fallbackAcc = accounts.first {
                validated.accountId = fallbackAcc.id
            }
        }
        if !categories.contains(where: { $0.id == validated.categoryId }), let fallbackCat = categories.first(where: { $0.type == validated.type }) ?? categories.first {
            validated.categoryId = fallbackCat.id
        }

        if let idx = transactions.firstIndex(where: { $0.id == validated.id }) {
            let originalBeforeEdit = transactions[idx]
            let didUserChangeDate = !calendar.isDate(validated.date, inSameDayAs: originalBeforeEdit.date)
            if !isCardExp {
                if didUserChangeDate {
                    if isDateInFuture(validated.date, referenceNow: now) && originalBeforeEdit.isPaid == validated.isPaid {
                        validated.isPaid = false
                    }
                } else if validated.isPaid && !originalBeforeEdit.isPaid && isDateInFuture(validated.date, referenceNow: now) {
                    validated.date = now
                }
            }
            transactions[idx] = validated
            if let oldCid = originalBeforeEdit.creditCardId,
               let oldYM = originalBeforeEdit.creditCardInvoiceYearMonthKey,
               !originalBeforeEdit.isCreditCardInvoicePayment {
                syncCreditCardInvoice(cardId: oldCid, yearMonthKey: oldYM, saveAfter: false)
            }
            if let newCid = validated.creditCardId,
               let newYM = validated.creditCardInvoiceYearMonthKey,
               !validated.isCreditCardInvoicePayment {
                syncCreditCardInvoice(cardId: newCid, yearMonthKey: newYM, saveAfter: false)
            }
            sortTransactions()
            invalidateDerivedCaches()
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: validated.id, operation: .upsert, entity: validated)
        }
    }

    @discardableResult
    public func toggleTransactionPaid(transactionId: UUID, referenceNow: Date? = nil) -> Bool {
        let now = referenceNow ?? effectiveCurrentDate
        guard let idx = transactions.firstIndex(where: { $0.id == transactionId }) else { return false }
        if transactions[idx].isCreditCardExpense {
            return false
        }
        if transactions[idx].transactionOrigin == .plannedAmortization && !transactions[idx].isPaid {
            let payDate = isDateInFuture(transactions[idx].date, referenceNow: now)
                ? now
                : transactions[idx].date
            return confirmPlannedAmortizationByTransactionId(transactionId, paymentDate: payDate)
        }
        if !transactions[idx].isPaid {
            if isDateInFuture(transactions[idx].date, referenceNow: now) {
                transactions[idx].date = now
            }
            if let baseReg = transactions[idx].baseInstallmentRegisteredAmount,
               transactions[idx].confirmedRealInterestCorrectionAmount == nil {
                transactions[idx].confirmedRealInterestCorrectionAmount = ((transactions[idx].amount - baseReg) * 100.0).rounded() / 100.0
            }
            transactions[idx].isPaid = true
        } else {
            transactions[idx].isPaid = false
            transactions[idx].confirmedRealInterestCorrectionAmount = nil
            if let baseReg = transactions[idx].baseInstallmentRegisteredAmount {
                let projCorr = transactions[idx].projectedInstallmentCorrectionAmount ?? 0.0
                transactions[idx].amount = ((baseReg + projCorr) * 100.0).rounded() / 100.0
            }
        }
        let updated = transactions[idx]
        sortTransactions()
        invalidateDerivedCaches()
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: updated.id, operation: .upsert, entity: updated)
        return true
    }

    /// Marca múltiplas transações pendentes como pagas/recebidas em massa,
    /// ignorando automaticamente transações já pagas ou suprimidas.
    @discardableResult
    public func markTransactionsPaid(_ transactionIds: [UUID], referenceNow: Date? = nil) -> (processedCount: Int, ignoredAlreadyPaidCount: Int) {
        let now = referenceNow ?? effectiveCurrentDate
        let uniqueIds = Set(transactionIds)
        var processedIds: [UUID] = []
        var ignoredAlreadyPaidCount = 0

        for txId in uniqueIds {
            guard let idx = transactions.firstIndex(where: { $0.id == txId }) else { continue }
            if transactions[idx].isPaid {
                ignoredAlreadyPaidCount += 1
                continue
            }
            if transactions[idx].isCreditCardExpense || transactionProjectionStatus(for: transactions[idx]) == .shadowed {
                continue
            }
            if transactions[idx].transactionOrigin == .plannedAmortization {
                let payDate = isDateInFuture(transactions[idx].date, referenceNow: now)
                    ? now
                    : transactions[idx].date
                if confirmPlannedAmortizationByTransactionId(txId, paymentDate: payDate) {
                    processedIds.append(txId)
                }
                continue
            }
            if isDateInFuture(transactions[idx].date, referenceNow: now) {
                transactions[idx].date = now
            }
            if let baseReg = transactions[idx].baseInstallmentRegisteredAmount,
               transactions[idx].confirmedRealInterestCorrectionAmount == nil {
                transactions[idx].confirmedRealInterestCorrectionAmount = ((transactions[idx].amount - baseReg) * 100.0).rounded() / 100.0
            }
            transactions[idx].isPaid = true
            processedIds.append(txId)
        }

        if !processedIds.isEmpty {
            sortTransactions()
            invalidateDerivedCaches()
            saveToDisk()
            for txId in processedIds {
                if let updated = transactions.first(where: { $0.id == txId }) {
                    cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: updated.id, operation: .upsert, entity: updated)
                }
            }
        }

        return (processedIds.count, ignoredAlreadyPaidCount)
    }

    @discardableResult
    public func confirmContractInstallmentPayment(
        transactionId: UUID,
        realPaidAmount: Double,
        paymentDate: Date? = nil,
        referenceNow: Date? = nil
    ) -> Bool {
        let now = referenceNow ?? effectiveCurrentDate
        guard let idx = transactions.firstIndex(where: { $0.id == transactionId }) else { return false }
        let cleanPaid = abs(realPaidAmount)
        guard cleanPaid > 0 else { return false }

        let contract = transactions[idx].linkedContractId.flatMap { cid in
            contracts.first(where: { $0.id == cid })
        }
        let baseReg = transactions[idx].baseInstallmentRegisteredAmount
            ?? contract?.installmentAmount
            ?? transactions[idx].amount
        let projCorr = transactions[idx].projectedInstallmentCorrectionAmount ?? max(0.0, transactions[idx].amount - baseReg)
        let realCorrection = ((cleanPaid - baseReg) * 100.0).rounded() / 100.0

        let effectivePayDate: Date = {
            if let explicitDate = paymentDate {
                return explicitDate
            }
            return isDateInFuture(transactions[idx].date, referenceNow: now) ? now : transactions[idx].date
        }()

        transactions[idx].baseInstallmentRegisteredAmount = baseReg
        transactions[idx].projectedInstallmentCorrectionAmount = projCorr
        transactions[idx].confirmedRealInterestCorrectionAmount = realCorrection
        transactions[idx].amount = cleanPaid
        transactions[idx].date = effectivePayDate
        transactions[idx].isPaid = true

        let corrSign = realCorrection >= 0 ? "+" : ""
        if let contract {
            transactions[idx].details = "\(contract.kind.title) (\(contract.subtypeDisplayName)) • Valor cadastrado: \(AppFormatters.currency(baseReg)) • Juros/Correção efetivada no pagamento: \(corrSign)\(AppFormatters.currency(realCorrection)) (Projeção era +\(AppFormatters.currency(projCorr)))"
        }

        sortTransactions()
        invalidateDerivedCaches()
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: transactionId, operation: .upsert, entity: transactions[idx])
        return true
    }

    public func installmentCorrectionBreakdown(for tx: FinancialTransaction) -> InstallmentCorrectionBreakdown? {
        guard let contractId = tx.linkedContractId,
              tx.installmentIndex != nil,
              let contract = contracts.first(where: { $0.id == contractId }),
              contract.kind == .financing else {
            return nil
        }

        let avgGrowth = contract.averageMonthlyInstallmentGrowth ?? {
            if contract.contractNumber == "178770203328-1" || contract.name.localizedCaseInsensitiveContains("CAIXA") {
                return (2658.06 - 2613.19) / 11.0
            }
            return 0.0
        }()
        guard avgGrowth > 0.0001 || tx.projectedInstallmentCorrectionAmount != nil || tx.baseInstallmentRegisteredAmount != nil else {
            return nil
        }

        let step = max(1, (tx.installmentIndex ?? (contract.pastInstallmentsElapsedAtCreation + 1)) - contract.pastInstallmentsElapsedAtCreation)
        let baseReg = tx.baseInstallmentRegisteredAmount ?? contract.installmentAmount
        let projectedCorr: Double = {
            if let explicitProj = tx.projectedInstallmentCorrectionAmount, explicitProj > 0 {
                return explicitProj
            }
            if avgGrowth > 0.0001 {
                let dec = LoanProjectionEngine.roundCurrency(Decimal(step) * LoanProjectionEngine.toDecimal(avgGrowth))
                return LoanProjectionEngine.toDouble(dec)
            }
            return max(0.0, tx.amount - baseReg)
        }()

        let confirmedReal: Double? = tx.isPaid
            ? (tx.confirmedRealInterestCorrectionAmount ?? (((tx.amount - baseReg) * 100.0).rounded() / 100.0))
            : nil

        let effectiveTotal = tx.isPaid ? tx.amount : effectiveTransactionAmount(for: tx)

        return InstallmentCorrectionBreakdown(
            baseRegisteredAmount: baseReg,
            projectedCorrectionAmount: projectedCorr,
            confirmedRealCorrectionAmount: confirmedReal,
            effectiveTotalAmount: effectiveTotal,
            averageMonthlyGrowth: avgGrowth,
            futureMonthStep: step
        )
    }

    public func deleteTransaction(_ transactionId: UUID) {
        guard let targetTx = transactions.first(where: { $0.id == transactionId }) else { return }
        revertLinkedEntities(for: targetTx)
        transactions.removeAll { $0.id == transactionId }
        if targetTx.isCreditCardExpense,
           let cid = targetTx.creditCardId,
           let ymKey = targetTx.creditCardInvoiceYearMonthKey {
            syncCreditCardInvoice(cardId: cid, yearMonthKey: ymKey, saveAfter: false)
        }
        sortTransactions()
        invalidateDerivedCaches()
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: transactionId, operation: .delete)
    }

    // MARK: - Reversão de Vínculos Relacionais (Rollback ao Deletar Transação Casada)

    private func revertLinkedEntities(for tx: FinancialTransaction) {
        let origin = tx.effectiveOrigin
        let entityId = tx.effectiveLinkedEntityID

        switch origin {
        case .investmentDeposit:
            if let invId = entityId ?? tx.linkedInvestmentId,
               let idx = investments.firstIndex(where: { $0.id == invId }) {
                if tx.isPaid {
                    investments[idx].balance = max(0.0, investments[idx].balance - tx.amount)
                }
                investments[idx].movements.removeAll { $0.generatedTransactionId == tx.id }
                cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: invId, operation: .upsert, entity: investments[idx])
            }

        case .investmentRedemption:
            if let invId = entityId ?? tx.linkedInvestmentId,
               let idx = investments.firstIndex(where: { $0.id == invId }) {
                if tx.isPaid {
                    investments[idx].balance += tx.amount
                }
                investments[idx].movements.removeAll { $0.generatedTransactionId == tx.id }
                cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: invId, operation: .upsert, entity: investments[idx])
            }

        case .debtPayment:
            if let dId = entityId ?? tx.linkedDebtId,
               let idx = debts.firstIndex(where: { $0.id == dId }) {
                debts[idx].isPaid = false
                debts[idx].negotiatedAmount = nil
                debts[idx].paidDate = nil
                debts[idx].paidFromAccountId = nil
                debts[idx].paymentTransactionId = nil
                cloudSyncService?.recordLocalMutation(entityName: "debt_items", entityId: dId, operation: .upsert, entity: debts[idx])
            }

        case .financingAmortization, .contractSettlement, .loanAmortization, .loanPayoff:
            if let cId = entityId ?? tx.linkedContractId,
               let idx = contracts.firstIndex(where: { $0.id == cId }) {
                revertContractAmortizationOrSettlement(contractIndex: idx, tx: tx)
            }

        case .plannedAmortization:
            for pIdx in amortizationPlans.indices {
                let beforeCount = amortizationPlans[pIdx].items.count
                amortizationPlans[pIdx].items.removeAll { item in
                    item.linkedTransactionId == tx.id || item.id == tx.linkedEntityID
                }
                if amortizationPlans[pIdx].items.count != beforeCount {
                    amortizationPlans[pIdx].updatedAt = effectiveCurrentDate
                    let updatedPlan = amortizationPlans[pIdx]
                    cloudSyncService?.recordLocalMutation(entityName: "amortization_plans", entityId: updatedPlan.id, operation: .upsert, entity: updatedPlan)
                }
            }

        case .creditCardInvoicePayment:
            if let invIdx = creditCardInvoices.firstIndex(where: {
                $0.paymentTransactionId == tx.id ||
                $0.id == (tx.creditCardInvoiceId ?? entityId) ||
                (tx.creditCardId != nil && $0.creditCardId == tx.creditCardId && $0.yearMonthKey == tx.creditCardInvoiceYearMonthKey)
            }) {
                creditCardInvoices[invIdx].isPaid = false
                creditCardInvoices[invIdx].paidAmount = nil
                creditCardInvoices[invIdx].paidDate = nil
                creditCardInvoices[invIdx].paidFromAccountId = nil
                creditCardInvoices[invIdx].paymentTransactionId = nil
                cloudSyncService?.recordLocalMutation(entityName: "credit_card_invoices", entityId: creditCardInvoices[invIdx].id, operation: .upsert, entity: creditCardInvoices[invIdx])
            }

        case .standard, .quotaAllocation, .internalTransfer:
            break
        }
    }

    private func revertContractAmortizationOrSettlement(contractIndex: Int, tx: FinancialTransaction) {
        var contract = contracts[contractIndex]

        let recordIdx = contract.amortizationHistory.firstIndex(where: { $0.transactionId == tx.id })
        let record = recordIdx.map { contract.amortizationHistory.remove(at: $0) }

        if contract.isSettled {
            contract.isSettled = false
            contract.settledAmount = nil
            contract.settledDate = nil
            contract.settledAccountId = nil
        }

        let effectiveAmort = record?.effectiveAmortization ?? tx.amount
        let restoredBalance: Double
        if let prevBal = record?.previousBalance, prevBal > 0.01 {
            restoredBalance = prevBal
        } else {
            let currentBal = contract.outstandingBalance ?? (contract.kind == .loan ? (contract.loanDetails?.balance ?? 0.0) : (contract.financingDetails?.balance ?? 0.0))
            restoredBalance = currentBal + effectiveAmort
        }

        contract.outstandingBalance = restoredBalance
        if contract.kind == .financing && contract.financingDetails != nil {
            contract.financingDetails?.balance = restoredBalance
        }
        if contract.kind == .loan && contract.loanDetails != nil {
            contract.loanDetails?.balance = restoredBalance
        }
        contract.extraAmortizedTotal = max(0.0, contract.extraAmortizedTotal - effectiveAmort)

        let mode = record?.mode ?? .reduceTerm
        let currentRem = record?.previousRemainingInstallments ?? remainingInstallmentsCount(for: contract)
        let currentInst = record?.previousInstallmentAmount ?? contract.installmentAmount

        let targetRemaining: Int
        let targetInstallment: Double

        if contract.kind == .loan {
            let recalc = LoanAmortizationEngine.recalculate(
                balance: restoredBalance,
                monthlyInterestRate: contract.monthlyInterestRate,
                installmentValue: currentInst,
                currentRemainingInstallments: currentRem,
                mode: mode
            )
            targetRemaining = record?.previousRemainingInstallments ?? recalc.remainingInstallments
            targetInstallment = record?.previousInstallmentAmount ?? recalc.installmentValue

            if contract.loanDetails != nil {
                contract.loanDetails?.balance = restoredBalance
                contract.loanDetails?.remainingInstallments = targetRemaining
                contract.loanDetails?.installmentValue = targetInstallment
                contract.loanDetails?.totalInstallments = max(contract.totalInstallments, contract.pastInstallmentsElapsedAtCreation + targetRemaining)
            }
        } else {
            let recalc = AmortizationEngine.recalculate(
                balance: restoredBalance,
                annualNominalRate: contract.effectiveAnnualNominalRate,
                basePriceInstallment: contract.effectiveBaseInstallmentPrice,
                totalInstallmentAmount: currentInst,
                currentRemainingInstallments: currentRem,
                mode: mode,
                amortizationSystem: contract.amortizationSystem,
                adminFee: contract.effectiveAdminFee,
                insuranceFee: contract.effectiveInsuranceFee
            )
            targetRemaining = record?.previousRemainingInstallments ?? recalc.remainingInstallments
            targetInstallment = record?.previousInstallmentAmount ?? recalc.installmentAmount

            if contract.financingDetails != nil {
                contract.financingDetails?.balance = restoredBalance
                contract.financingDetails?.remainingInstallments = targetRemaining
                contract.financingDetails?.totalInstallmentAmount = targetInstallment
                contract.financingDetails?.totalInstallments = max(contract.totalInstallments, contract.pastInstallmentsElapsedAtCreation + targetRemaining)
            }
        }

        let paidInApp = transactions.filter { $0.linkedContractId == contract.id && $0.isPaid && $0.installmentIndex != nil }.count
        let minRequiredTotal = contract.pastInstallmentsElapsedAtCreation + paidInApp + targetRemaining
        if contract.totalInstallments < minRequiredTotal {
            contract.totalInstallments = minRequiredTotal
        }

        contract.installmentAmount = targetInstallment
        contract.originalTotalInstallments = contract.effectiveOriginalTotalInstallments

        restoreMissingFutureContractTransactions(
            contract: contract,
            targetRemaining: targetRemaining,
            targetInstallment: targetInstallment
        )

        contracts[contractIndex] = contract
        cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contract.id, operation: .upsert, entity: contract)
    }

    private func restoreMissingFutureContractTransactions(
        contract: CreditContract,
        targetRemaining: Int,
        targetInstallment: Double
    ) {
        let existingUnpaid = transactions
            .filter { $0.linkedContractId == contract.id && !$0.isPaid && $0.installmentIndex != nil }
            .sorted { ($0.installmentIndex ?? 0) < ($1.installmentIndex ?? 0) }

        let existingIds = Set(existingUnpaid.map(\.id))
        for idx in transactions.indices {
            if existingIds.contains(transactions[idx].id) {
                transactions[idx].amount = targetInstallment
                transactions[idx].installmentTotal = contract.totalInstallments
                if let instIdx = transactions[idx].installmentIndex {
                    transactions[idx].name = "\(contract.name) - Parcela \(instIdx)/\(contract.totalInstallments)"
                }
            }
        }

        let missingCount = targetRemaining - existingUnpaid.count
        guard missingCount > 0 else { return }

        let paidInApp = transactions.filter { $0.linkedContractId == contract.id && $0.isPaid && $0.installmentIndex != nil }.count
        let creditCategoryId = contract.categoryId

        let startInstallmentNumber: Int
        let baseDate: Date

        if let lastTx = existingUnpaid.last {
            startInstallmentNumber = (lastTx.installmentIndex ?? (contract.pastInstallmentsElapsedAtCreation + paidInApp + existingUnpaid.count)) + 1
            baseDate = lastTx.date
        } else {
            startInstallmentNumber = contract.pastInstallmentsElapsedAtCreation + paidInApp + 1
            let computed = computePastInstallmentsAndFirstFutureDate(
                startDate: contract.startDate,
                billingDay: contract.billingDay,
                totalInstallments: contract.totalInstallments,
                referenceDate: Date()
            )
            baseDate = computed.firstFutureBillingDate
        }

        for offset in 0..<missingCount {
            let installmentNumber = startInstallmentNumber + offset
            let dueDate: Date
            if existingUnpaid.isEmpty {
                dueDate = calendar.date(byAdding: .month, value: offset, to: baseDate) ?? baseDate
            } else {
                dueDate = calendar.date(byAdding: .month, value: offset + 1, to: baseDate) ?? baseDate
            }

            let newTx = FinancialTransaction(
                name: "\(contract.name) - Parcela \(installmentNumber)/\(contract.totalInstallments)",
                details: "\(contract.kind.title) (\(contract.subtypeDisplayName)) • Juros \(String(format: "%.2f", contract.monthlyInterestRate))% a.m.",
                amount: targetInstallment,
                date: dueDate,
                type: .expense,
                isPaid: false,
                categoryId: creditCategoryId,
                accountId: contract.accountId,
                ignoreInConsolidated: false,
                recurrenceMode: .installment,
                seriesGroupId: contract.id,
                installmentIndex: installmentNumber,
                installmentTotal: contract.totalInstallments,
                linkedContractId: contract.id,
                transactionOrigin: .standard,
                linkedEntityID: contract.id
            )
            transactions.append(newTx)
        }
    }

    private func sortTransactions() {
        transactions.sort { a, b in
            if a.date == b.date {
                return a.createdAt > b.createdAt
            }
            return a.date > b.date
        }
    }

    // MARK: - CRUD: Investimentos

    public func createInvestment(
        name: String,
        groupName: String,
        investmentAccountId: UUID,
        balance: Double = 0.0,
        colorHex: String = "#10B981"
    ) {
        let inv = InvestmentItem(
            name: name,
            groupName: groupName,
            investmentAccountId: investmentAccountId,
            balance: balance,
            colorHex: colorHex
        )
        investments.append(inv)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: inv.id, operation: .upsert, entity: inv)
    }

    public func updateInvestment(_ investment: InvestmentItem) {
        if let idx = investments.firstIndex(where: { $0.id == investment.id }) {
            investments[idx] = investment
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: investment.id, operation: .upsert, entity: investment)
        }
    }

    public func deleteInvestment(_ investmentId: UUID) {
        investments.removeAll { $0.id == investmentId }
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: investmentId, operation: .delete)
    }

    public func toggleInvestmentConsolidated(_ investmentId: UUID) {
        guard let idx = investments.firstIndex(where: { $0.id == investmentId }) else { return }
        investments[idx].showInConsolidated.toggle()
        let isConsolidated = investments[idx].showInConsolidated
        let today = calendar.startOfDay(for: Date())

        // Sincroniza a regra de transações previstas de resgate futuro:
        // Se o investimento agora está no consolidado, marcação (ignoreInConsolidated = true) para evitar duplicidade.
        // Se agora não está no consolidado, passa a ser exibido nos dashboards e transações (ignoreInConsolidated = false).
        for txIdx in transactions.indices {
            if transactions[txIdx].linkedInvestmentId == investmentId,
               transactions[txIdx].transactionOrigin == .investmentRedemption,
               calendar.startOfDay(for: transactions[txIdx].date) > today {
                transactions[txIdx].ignoreInConsolidated = isConsolidated
                cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: transactions[txIdx].id, operation: .upsert, entity: transactions[txIdx])
            }
        }

        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: investmentId, operation: .upsert, entity: investments[idx])
    }

    public func recordInvestmentMovement(
        investmentId: UUID,
        type: InvestmentMovementType,
        amount: Double,
        sourceAccountId: UUID,
        date: Date = Date(),
        notes: String = ""
    ) {
        contributeToInvestment(
            investmentId: investmentId,
            amount: amount,
            sourceAccountId: sourceAccountId,
            date: date,
            movementType: type,
            notes: notes
        )
    }

    public func contributeToInvestment(
        investmentId: UUID,
        amount: Double,
        sourceAccountId: UUID,
        date: Date = Date(),
        movementType: InvestmentMovementType = .deposit,
        notes: String = ""
    ) {
        guard let idx = investments.firstIndex(where: { $0.id == investmentId }) else { return }
        let cleanAmount = abs(amount)
        guard cleanAmount > 0 else { return }

        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: date)
        let isFuture = targetDay > today

        let catId: UUID = {
            if movementType == .deposit {
                return investmentDepositCategoryId()
            } else {
                return fallbackCategoryId(for: .income, matchingSubstring: "Resgate")
            }
        }()

        let txTitle: String = {
            if movementType == .deposit {
                return isFuture ? "Aporte Previsto: \(investments[idx].name)" : "Aporte: \(investments[idx].name)"
            } else {
                return isFuture ? "Resgate Previsto: \(investments[idx].name)" : "Resgate: \(investments[idx].name)"
            }
        }()

        // Regra de transações para resgate futuro:
        // Se o card não estiver marcado para exibir no consolidado (!showInConsolidated),
        // o valor previsto de saque passa a ser exibido nos dashboards e transações na data marcada (ignoreInConsolidated = false).
        // Se estiver marcado no consolidado (showInConsolidated == true), aparece apenas a transação como marcação
        // (ignoreInConsolidated = true) para evitar duplicidade com o saldo do investimento.
        let ignoreInConsolidated: Bool = {
            if movementType == .withdrawal && isFuture {
                return investments[idx].showInConsolidated
            }
            return false
        }()

        let tx = createTransaction(
            name: txTitle,
            details: notes,
            amount: cleanAmount,
            date: date,
            type: movementType == .deposit ? .expense : .income,
            isPaid: !isFuture,
            categoryId: catId,
            accountId: sourceAccountId,
            ignoreInConsolidated: ignoreInConsolidated,
            linkedInvestmentId: investmentId,
            transactionOrigin: movementType == .deposit ? .investmentDeposit : .investmentRedemption,
            linkedEntityID: investmentId
        )

        let mov = InvestmentMovement(
            type: movementType,
            amount: cleanAmount,
            date: date,
            sourceAccountId: sourceAccountId,
            investmentAccountId: investments[idx].investmentAccountId,
            notes: notes,
            generatedTransactionId: tx.id
        )

        investments[idx].movements.insert(mov, at: 0)

        // Saldo do card principal segue o mesmo saldo acumulado se for previsão/futuro
        if !isFuture {
            if movementType == .deposit {
                investments[idx].balance += cleanAmount
            } else {
                investments[idx].balance = max(0, investments[idx].balance - cleanAmount)
            }
        }

        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: investments[idx].id, operation: .upsert, entity: investments[idx])
    }

    public var totalInvestedAmount: Double {
        totalInvestmentsBalance
    }

    public func investmentMovements(for investmentId: UUID) -> [InvestmentMovement] {
        guard let inv = investments.first(where: { $0.id == investmentId }) else { return [] }
        var result = inv.movements
        let knownTxIds = Set(result.compactMap(\.generatedTransactionId))

        let orphanTxs = transactions.filter { tx in
            (tx.linkedInvestmentId == investmentId || tx.linkedEntityID == investmentId) &&
            !knownTxIds.contains(tx.id)
        }
        for tx in orphanTxs {
            let isDeposit = tx.transactionOrigin == .investmentDeposit || tx.type == .expense
            let mov = InvestmentMovement(
                id: tx.id,
                type: isDeposit ? .deposit : .withdrawal,
                amount: tx.amount,
                date: tx.date,
                sourceAccountId: tx.accountId,
                investmentAccountId: inv.investmentAccountId,
                notes: tx.details.isEmpty ? tx.name : tx.details,
                generatedTransactionId: tx.id
            )
            result.append(mov)
        }
        return result.sorted(by: { $0.date > $1.date })
    }

    public func deleteInvestmentMovement(investmentId: UUID, movementId: UUID) {
        guard let invIdx = investments.firstIndex(where: { $0.id == investmentId }) else { return }
        let movement = investments[invIdx].movements.first(where: { $0.id == movementId })

        if let txId = movement?.generatedTransactionId ?? transactions.first(where: { $0.id == movementId })?.id,
           transactions.contains(where: { $0.id == txId }) {
            deleteTransaction(txId)
            if let currentIdx = investments.firstIndex(where: { $0.id == investmentId }) {
                investments[currentIdx].movements.removeAll(where: { $0.id == movementId || $0.generatedTransactionId == txId })
            }
        } else if let mov = movement {
            let today = calendar.startOfDay(for: Date())
            let isPastOrToday = calendar.startOfDay(for: mov.date) <= today
            if isPastOrToday {
                if mov.type == .deposit {
                    investments[invIdx].balance = max(0.0, investments[invIdx].balance - mov.amount)
                } else {
                    investments[invIdx].balance += mov.amount
                }
            }
            investments[invIdx].movements.removeAll(where: { $0.id == movementId })
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: investmentId, operation: .upsert, entity: investments[invIdx])
        }
    }

    public func investmentTimeline(
        for investmentId: UUID,
        year: Int,
        period: InvestmentPeriodFilter = .oneYear
    ) -> [InvestmentMonthlyMovementPoint] {
        guard let inv = investments.first(where: { $0.id == investmentId }) else { return [] }
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return []
        }

        let allMovs = investmentMovements(for: investmentId)

        let shortMonthDf = DateFormatter()
        shortMonthDf.locale = Locale(identifier: "pt_BR")
        shortMonthDf.dateFormat = "MMM"

        let ymDf = DateFormatter()
        ymDf.locale = Locale(identifier: "pt_BR")
        ymDf.dateFormat = "MMM/yy"

        // 1. Data em que o investimento foi iniciado/incluído
        let startRefDate = ([inv.createdAt] + allMovs.map(\.date)).min() ?? inv.createdAt
        let startYear = calendar.component(.year, from: startRefDate)
        let startMonth = calendar.component(.month, from: startRefDate)

        // 2. Saldo inicial do investimento na sua criação:
        // Estorna do saldo atual todos os aportes e resgates já realizados (data <= hoje)
        let pastRealizedDeposits = allMovs
            .filter { $0.type == .deposit && calendar.startOfDay(for: $0.date) <= today }
            .reduce(0.0) { $0 + $1.amount }
        let pastRealizedWithdrawals = allMovs
            .filter { $0.type == .withdrawal && calendar.startOfDay(for: $0.date) <= today }
            .reduce(0.0) { $0 + $1.amount }
        let initialBalanceAtStart = max(0.0, inv.balance - pastRealizedDeposits + pastRealizedWithdrawals)

        // 3. Simulação cronológica mês a mês a partir do início do investimento
        // Para qualquer mês antes de (startYear, startMonth), o saldo e movimentações são ZERO (gráfico vazio).
        var monthlyState: [String: (base: Double, dep: Double, with: Double, projDep: Double, projWith: Double, end: Double)] = [:]
        var runningBalance = initialBalanceAtStart

        let maxSimYear = max(year, currentYear)
        if startYear <= maxSimYear {
            for y in startYear...maxSimYear {
                for m in 1...12 {
                    let ymKey = String(format: "%04d-%02d", y, m)
                    guard let monthStart = calendar.date(from: DateComponents(year: y, month: m, day: 1)) else { continue }

                    // Se o mês for anterior à inclusão do investimento, tudo é 0
                    if y < startYear || (y == startYear && m < startMonth) {
                        monthlyState[ymKey] = (base: 0.0, dep: 0.0, with: 0.0, projDep: 0.0, projWith: 0.0, end: 0.0)
                        continue
                    }

                    let isPast = (y < currentYear) || (y == currentYear && m < currentMonth)
                    let isCurrent = (y == currentYear && m == currentMonth)

                    var monthDeposits: Double = 0.0
                    var monthWithdrawals: Double = 0.0
                    var monthProjDeposits: Double = 0.0
                    var monthProjWithdrawals: Double = 0.0

                    if isPast {
                        for mov in allMovs where isInMonth(mov.date, monthReference: monthStart) {
                            if mov.type == .deposit {
                                monthDeposits += mov.amount
                            } else {
                                monthWithdrawals += mov.amount
                            }
                        }
                        let base = runningBalance
                        let end = max(0.0, base + monthDeposits - monthWithdrawals)
                        runningBalance = end
                        monthlyState[ymKey] = (base: base, dep: monthDeposits, with: monthWithdrawals, projDep: 0.0, projWith: 0.0, end: end)
                    } else if isCurrent {
                        for mov in allMovs where isInMonth(mov.date, monthReference: monthStart) {
                            if calendar.startOfDay(for: mov.date) <= today {
                                if mov.type == .deposit {
                                    monthDeposits += mov.amount
                                } else {
                                    monthWithdrawals += mov.amount
                                }
                            } else {
                                // Movimentação futura dentro do mês atual
                                if mov.type == .deposit {
                                    monthProjDeposits += mov.amount
                                } else {
                                    monthProjWithdrawals += mov.amount
                                }
                            }
                        }
                        let envelopes = categoryQuotaEnvelopes(for: monthStart).filter {
                            $0.rule.quotaType == .investment && $0.rule.linkedInvestmentId == investmentId
                        }
                        monthProjDeposits += envelopes.reduce(0.0) { $0 + max(0.0, $1.remainingProvision) }

                        let base = runningBalance
                        let realizedEnd = max(0.0, base + monthDeposits - monthWithdrawals)
                        let end = max(0.0, realizedEnd + monthProjDeposits - monthProjWithdrawals)
                        runningBalance = end
                        monthlyState[ymKey] = (base: base, dep: monthDeposits, with: monthWithdrawals, projDep: monthProjDeposits, projWith: monthProjWithdrawals, end: end)
                    } else {
                        // Futuro
                        for mov in allMovs where isInMonth(mov.date, monthReference: monthStart) {
                            if mov.type == .deposit {
                                monthProjDeposits += mov.amount
                            } else {
                                monthProjWithdrawals += mov.amount
                            }
                        }
                        let envelopes = categoryQuotaEnvelopes(for: monthStart).filter {
                            $0.rule.quotaType == .investment && $0.rule.linkedInvestmentId == investmentId
                        }
                        monthProjDeposits += envelopes.reduce(0.0) { $0 + $1.totalEstimatedAmount }

                        let base = runningBalance
                        let end = max(0.0, base + monthProjDeposits - monthProjWithdrawals)
                        runningBalance = end
                        monthlyState[ymKey] = (base: base, dep: 0.0, with: 0.0, projDep: monthProjDeposits, projWith: monthProjWithdrawals, end: end)
                    }
                }
            }
        }

        var allPoints: [InvestmentMonthlyMovementPoint] = []
        for m in 1...12 {
            guard let monthStart = calendar.date(from: DateComponents(year: year, month: m, day: 1)) else { continue }
            let ymKey = String(format: "%04d-%02d", year, m)
            let shortLabel = shortMonthDf.string(from: monthStart).capitalized.replacingOccurrences(of: ".", with: "")
            let label = ymDf.string(from: monthStart).capitalized.replacingOccurrences(of: ".", with: "")

            let state = monthlyState[ymKey] ?? (base: 0.0, dep: 0.0, with: 0.0, projDep: 0.0, projWith: 0.0, end: 0.0)

            let isPast = monthStart < currentMonthStart
            let isCurrent = calendar.isDate(monthStart, equalTo: currentMonthStart, toGranularity: .month)
            let isFuture = monthStart > currentMonthStart

            allPoints.append(
                InvestmentMonthlyMovementPoint(
                    yearMonthKey: ymKey,
                    year: year,
                    month: m,
                    label: label,
                    shortLabel: shortLabel,
                    date: monthStart,
                    isPast: isPast,
                    isCurrent: isCurrent,
                    isFuture: isFuture,
                    deposits: state.dep,
                    withdrawals: state.with,
                    projectedDeposits: state.projDep,
                    projectedWithdrawals: state.projWith,
                    baseAccumulated: state.base,
                    endBalance: state.end
                )
            )
        }

        switch period {
        case .oneYear:
            return allPoints
        case .sixMonths:
            if year <= currentYear {
                return Array(allPoints.suffix(6))
            } else {
                return Array(allPoints.prefix(6))
            }
        case .threeMonths:
            if year <= currentYear {
                return Array(allPoints.suffix(3))
            } else {
                return Array(allPoints.prefix(3))
            }
        }
    }

    public func investmentMovementTimeline(
        for investmentId: UUID,
        referenceDate: Date? = nil,
        monthsBack: Int = 5,
        monthsForward: Int = 6
    ) -> [InvestmentMonthlyMovementPoint] {
        let ref = referenceDate ?? Date()
        let now = Date()
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return []
        }

        let allMovs = investmentMovements(for: investmentId)

        var points: [InvestmentMonthlyMovementPoint] = []

        let shortMonthDf = DateFormatter()
        shortMonthDf.locale = Locale(identifier: "pt_BR")
        shortMonthDf.dateFormat = "MMM"

        let ymDf = DateFormatter()
        ymDf.locale = Locale(identifier: "pt_BR")
        ymDf.dateFormat = "MMM/yy"

        for offset in (-monthsBack)...monthsForward {
            guard let targetDate = calendar.date(byAdding: .month, value: offset, to: ref),
                  let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: targetDate)) else {
                continue
            }

            let year = calendar.component(.year, from: monthStart)
            let month = calendar.component(.month, from: monthStart)
            let ymKey = String(format: "%04d-%02d", year, month)
            let shortLabel = shortMonthDf.string(from: monthStart).capitalized.replacingOccurrences(of: ".", with: "")
            let label = ymDf.string(from: monthStart).capitalized.replacingOccurrences(of: ".", with: "")

            let isPast = monthStart < currentMonthStart
            let isCurrent = monthStart == currentMonthStart
            let isFuture = monthStart > currentMonthStart

            var deposits: Double = 0.0
            var withdrawals: Double = 0.0
            var projectedDeposits: Double = 0.0

            if isPast || isCurrent {
                for m in allMovs where isInMonth(m.date, monthReference: monthStart) {
                    if m.type == .deposit {
                        deposits += m.amount
                    } else {
                        withdrawals += m.amount
                    }
                }
            }

            let envelopes = categoryQuotaEnvelopes(for: monthStart).filter { env in
                env.rule.quotaType == .investment && env.rule.linkedInvestmentId == investmentId
            }

            if isFuture {
                projectedDeposits = envelopes.reduce(0.0) { $0 + $1.totalEstimatedAmount }
            } else if isCurrent {
                projectedDeposits = envelopes.reduce(0.0) { $0 + max(0.0, $1.remainingProvision) }
            } else {
                projectedDeposits = 0.0
            }

            points.append(
                InvestmentMonthlyMovementPoint(
                    yearMonthKey: ymKey,
                    year: year,
                    month: month,
                    label: label,
                    shortLabel: shortLabel,
                    date: monthStart,
                    isPast: isPast,
                    isCurrent: isCurrent,
                    isFuture: isFuture,
                    deposits: deposits,
                    withdrawals: withdrawals,
                    projectedDeposits: projectedDeposits
                )
            )
        }

        return points
    }

    // MARK: - CRUD: Dívidas

    public var activeDebts: [DebtItem] {
        debts.filter { !$0.isPaid }
    }

    public var paidDebts: [DebtItem] {
        debts.filter { $0.isPaid }
    }

    public func createDebt(
        name: String,
        originalAmount: Double,
        bankPresetId: String? = nil,
        colorHex: String = "#EF4444",
        notes: String = ""
    ) {
        let debt = DebtItem(
            name: name,
            bankPresetId: bankPresetId,
            colorHex: colorHex,
            originalAmount: originalAmount,
            contractedDate: Date(),
            notes: notes
        )
        debts.append(debt)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "debt_items", entityId: debt.id, operation: .upsert, entity: debt)
    }

    public func updateDebt(_ debt: DebtItem) {
        if let idx = debts.firstIndex(where: { $0.id == debt.id }) {
            debts[idx] = debt
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "debt_items", entityId: debt.id, operation: .upsert, entity: debt)
        }
    }

    public func deleteDebt(_ debtId: UUID) {
        debts.removeAll { $0.id == debtId }
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "debt_items", entityId: debtId, operation: .delete)
    }

    public func markDebtPaid(
        debtId: UUID,
        negotiatedAmount: Double,
        paidFromAccountId: UUID,
        paymentDate: Date = Date()
    ) {
        guard let idx = debts.firstIndex(where: { $0.id == debtId }) else { return }
        let debt = debts[idx]
        let cleanNegotiated = abs(negotiatedAmount)
        let discount = debt.originalAmount - cleanNegotiated
        let debtCategoryId = fallbackCategoryId(for: .expense, matchingSubstring: "Dívidas")

        let discountText = discount > 0.01
            ? " (Desconto de \(AppFormatters.currency(discount)) sobre \(AppFormatters.currency(debt.originalAmount)))"
            : " (Valor original: \(AppFormatters.currency(debt.originalAmount)))"

        let tx = createTransaction(
            name: "Quitação de Dívida: \(debt.name)",
            details: "Acordo liquidado\(discountText)",
            amount: cleanNegotiated,
            date: paymentDate,
            type: .expense,
            isPaid: true,
            categoryId: debtCategoryId,
            accountId: paidFromAccountId,
            linkedDebtId: debt.id,
            transactionOrigin: .debtPayment,
            linkedEntityID: debt.id
        )

        debts[idx].isPaid = true
        debts[idx].negotiatedAmount = cleanNegotiated
        debts[idx].paidDate = paymentDate
        debts[idx].paidFromAccountId = paidFromAccountId
        debts[idx].paymentTransactionId = tx.id

        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "debt_items", entityId: debts[idx].id, operation: .upsert, entity: debts[idx])
    }

    public var totalDebtAmount: Double {
        debts.filter { !$0.isPaid }.reduce(0.0) { $0 + $1.originalAmount }
    }

    // MARK: - CRUD: Financiamentos e Empréstimos

    public func activeContracts(for kind: CreditContractKind) -> [CreditContract] {
        contracts.filter { $0.kind == kind && !$0.isSettled }
    }

    public func settledContracts(for kind: CreditContractKind) -> [CreditContract] {
        contracts.filter { $0.kind == kind && $0.isSettled }
    }

    public func computePastInstallmentsAndFirstFutureDate(
        startDate: Date?,
        billingDay: Int,
        totalInstallments: Int,
        referenceDate: Date = Date()
    ) -> (pastInstallmentsCount: Int, firstFutureBillingDate: Date) {
        let clampedDay = min(max(billingDay, 1), 28)
        let todayStart = calendar.startOfDay(for: referenceDate)

        var currentComps = calendar.dateComponents([.year, .month, .day], from: todayStart)
        currentComps.day = clampedDay
        var nextBillingDate = calendar.date(from: currentComps) ?? todayStart
        if nextBillingDate < todayStart {
            nextBillingDate = calendar.date(byAdding: .month, value: 1, to: nextBillingDate) ?? nextBillingDate
        }

        guard let startDate else {
            return (0, nextBillingDate)
        }

        let startDay = calendar.startOfDay(for: startDate)
        if startDay >= todayStart {
            var startComps = calendar.dateComponents([.year, .month], from: startDay)
            startComps.day = clampedDay
            var firstDate = calendar.date(from: startComps) ?? startDay
            if firstDate < startDay {
                firstDate = calendar.date(byAdding: .month, value: 1, to: firstDate) ?? firstDate
            }
            return (0, firstDate)
        }

        var firstInstallmentComps = calendar.dateComponents([.year, .month], from: startDay)
        firstInstallmentComps.day = clampedDay
        var cursorDate = calendar.date(from: firstInstallmentComps) ?? startDay
        if cursorDate < startDay {
            cursorDate = calendar.date(byAdding: .month, value: 1, to: cursorDate) ?? cursorDate
        }

        var elapsed = 0
        while cursorDate <= todayStart && elapsed < totalInstallments {
            elapsed += 1
            cursorDate = calendar.date(byAdding: .month, value: 1, to: cursorDate) ?? cursorDate
        }

        return (min(elapsed, totalInstallments), cursorDate)
    }

    private func migrateExistingSantanderContractsIfNeeded() -> Bool {
        var didMutate = false
        let sampleDoc = ContractDocumentImportService.parseContractDocumentText(
            SampleContractDocumentsData.santanderLoanOCRText,
            expectedKind: .loan
        )
        let todayStart = calendar.startOfDay(for: effectiveCurrentDate)

        for cIdx in contracts.indices {
            var contract = contracts[cIdx]
            guard contract.kind == .loan,
                  !contract.isSettled,
                  (contract.contractNumber == "783694303" || contract.name.localizedCaseInsensitiveContains("Santander")) else {
                continue
            }

            if contract.scheduledInstallments == nil || contract.scheduledInstallments?.isEmpty == true {
                contract.scheduledInstallments = sampleDoc.scheduledInstallments
                didMutate = true
            }

            guard let schedule = contract.scheduledInstallments, !schedule.isEmpty else { continue }
            let scheduleByNumber = Dictionary(uniqueKeysWithValues: schedule.map { ($0.installmentNumber, $0) })

            let clampedBillingDay = min(max(contract.billingDay, 1), 28)
            var newlyElapsedFromSalary = 0
            var txIdsToRemoveAsAlreadyDeducted: Set<UUID> = []

            for tIdx in transactions.indices {
                guard transactions[tIdx].linkedContractId == contract.id,
                      let instNum = transactions[tIdx].installmentIndex else {
                    continue
                }
                if let schedItem = scheduleByNumber[instNum],
                   abs(transactions[tIdx].amount - schedItem.amount) > 0.005 {
                    transactions[tIdx].amount = schedItem.amount
                    didMutate = true
                }

                if !transactions[tIdx].isPaid {
                    var comps = calendar.dateComponents([.year, .month], from: transactions[tIdx].date)
                    comps.day = clampedBillingDay
                    let salaryDeductionDate = calendar.date(from: comps) ?? transactions[tIdx].date
                    if calendar.startOfDay(for: salaryDeductionDate) <= todayStart && contract.amortizationHistory.isEmpty {
                        txIdsToRemoveAsAlreadyDeducted.insert(transactions[tIdx].id)
                        newlyElapsedFromSalary = max(newlyElapsedFromSalary, instNum)
                    }
                }
            }

            if !txIdsToRemoveAsAlreadyDeducted.isEmpty {
                transactions.removeAll { txIdsToRemoveAsAlreadyDeducted.contains($0.id) }
                if newlyElapsedFromSalary > contract.pastInstallmentsElapsedAtCreation {
                    contract.pastInstallmentsElapsedAtCreation = newlyElapsedFromSalary
                }
                didMutate = true
            }

            if contract.amortizationHistory.isEmpty {
                let remainingUnpaid = transactions
                    .filter { $0.linkedContractId == contract.id && $0.installmentIndex != nil && !$0.isPaid }
                    .sorted { ($0.installmentIndex ?? 0) < ($1.installmentIndex ?? 0) }
                if !remainingUnpaid.isEmpty {
                    let remainingSum = (remainingUnpaid.reduce(0.0) { $0 + $1.amount } * 100.0).rounded() / 100.0
                    if abs((contract.outstandingBalance ?? 0.0) - remainingSum) > 0.005 {
                        contract.outstandingBalance = remainingSum
                        contract.loanDetails?.balance = remainingSum
                        didMutate = true
                    }
                    if let firstNextAmt = remainingUnpaid.first?.amount,
                       abs(contract.installmentAmount - firstNextAmt) > 0.005 {
                        contract.installmentAmount = firstNextAmt
                        contract.loanDetails?.installmentValue = firstNextAmt
                        didMutate = true
                    }
                }
            }

            contracts[cIdx] = contract
        }

        if didMutate {
            sortTransactions()
        }
        return didMutate
    }

    private func migrateExistingCaixaContractsIfNeeded() -> Bool {
        var didMutate = false
        let sampleCaixaDoc = ContractDocumentImportService.parseContractDocumentText(
            SampleContractDocumentsData.caixaFinancingOCRText,
            expectedKind: .financing
        )
        let baseRegisteredAmount = sampleCaixaDoc.installmentAmount
        let avgGrowthDouble = sampleCaixaDoc.averageMonthlyInstallmentGrowth ?? ((2658.06 - 2613.19) / 11.0)
        let avgGrowthDec = LoanProjectionEngine.toDecimal(avgGrowthDouble)
        let baseRegisteredDec = LoanProjectionEngine.toDecimal(baseRegisteredAmount)

        for cIdx in contracts.indices {
            var contract = contracts[cIdx]
            guard contract.kind == .financing,
                  !contract.isSettled,
                  (contract.contractNumber == "178770203328-1" || contract.name.localizedCaseInsensitiveContains("CAIXA")) else {
                continue
            }

            if contract.scheduledInstallments == nil || contract.scheduledInstallments?.isEmpty == true {
                contract.scheduledInstallments = sampleCaixaDoc.scheduledInstallments
                didMutate = true
            }
            if contract.averageMonthlyInstallmentGrowth == nil || abs((contract.averageMonthlyInstallmentGrowth ?? 0) - avgGrowthDouble) > 0.0001 {
                contract.averageMonthlyInstallmentGrowth = avgGrowthDouble
                didMutate = true
            }
            if contract.amortizationHistory.isEmpty && abs(contract.installmentAmount - baseRegisteredAmount) > 0.005 {
                contract.installmentAmount = baseRegisteredAmount
                contract.financingDetails?.totalInstallmentAmount = baseRegisteredAmount
                didMutate = true
            }

            let unpaidIndices = transactions.indices
                .filter { idx in
                    transactions[idx].linkedContractId == contract.id &&
                    transactions[idx].installmentIndex != nil &&
                    !transactions[idx].isPaid
                }
                .sorted { a, b in
                    let instA = transactions[a].installmentIndex ?? 0
                    let instB = transactions[b].installmentIndex ?? 0
                    if instA != instB { return instA < instB }
                    return transactions[a].date < transactions[b].date
                }

            for (offset, tIdx) in unpaidIndices.enumerated() {
                let step = offset + 1
                let projCorrectionDec = LoanProjectionEngine.roundCurrency(Decimal(step) * avgGrowthDec)
                let projTotalDec = LoanProjectionEngine.roundCurrency(baseRegisteredDec + projCorrectionDec)
                let projCorrectionDouble = LoanProjectionEngine.toDouble(projCorrectionDec)
                let projTotalDouble = LoanProjectionEngine.toDouble(projTotalDec)

                if abs(transactions[tIdx].amount - projTotalDouble) > 0.005 ||
                   transactions[tIdx].baseInstallmentRegisteredAmount == nil ||
                   transactions[tIdx].projectedInstallmentCorrectionAmount == nil {
                    transactions[tIdx].baseInstallmentRegisteredAmount = baseRegisteredAmount
                    transactions[tIdx].projectedInstallmentCorrectionAmount = projCorrectionDouble
                    transactions[tIdx].amount = projTotalDouble
                    transactions[tIdx].details = "\(contract.kind.title) (\(contract.subtypeDisplayName)) • Valor cadastrado: \(AppFormatters.currency(baseRegisteredAmount)) • Projeção de correção (+\(step)m): +\(AppFormatters.currency(projCorrectionDouble)) (Média doc: +\(AppFormatters.currency(avgGrowthDouble))/mês)"
                    didMutate = true
                }
            }

            contracts[cIdx] = contract
        }

        if didMutate {
            sortTransactions()
        }
        return didMutate
    }

    @discardableResult
    public func createCreditContract(
        kind: CreditContractKind,
        name: String,
        contractNumber: String? = nil,
        loanSubtype: LoanSubtype? = .consignado,
        financingSubtype: FinancingSubtype? = .imovel,
        amortizationSystem: AmortizationSystem = .price,
        totalContractedAmount: Double,
        outstandingBalance: Double? = nil,
        installmentAmount: Double,
        billingDay: Int,
        totalInstallments: Int,
        originalTotalInstallments: Int? = nil,
        monthlyInterestRate: Double,
        startDate: Date? = nil,
        accountId: UUID,
        categoryId: UUID? = nil,
        notes: String = "",
        referenceDate: Date = Date(),
        overridePastInstallmentsCount: Int? = nil,
        overrideFirstFutureBillingDate: Date? = nil,
        annualNominalInterestRate: Double? = nil,
        indexationRate: FinancingIndexation? = nil,
        adminFee: Double? = nil,
        insuranceFee: Double? = nil,
        baseInstallmentAmount: Double? = nil,
        bankDueDay: Int? = nil,
        documentReferenceDate: Date? = nil,
        maturityDate: Date? = nil,
        estimatedMonthlyTR: Double? = nil,
        lastFGTSUsageDate: Date? = nil,
        scheduledInstallments: [ContractInstallmentScheduleItem]? = nil,
        averageMonthlyInstallmentGrowth: Double? = nil
    ) -> CreditContract {
        let creditCategoryId = categoryId ?? fallbackCategoryId(for: .expense, matchingSubstring: "Empréstimos")

        let computedSchedule = computePastInstallmentsAndFirstFutureDate(
            startDate: startDate,
            billingDay: billingDay,
            totalInstallments: totalInstallments,
            referenceDate: referenceDate
        )
        let clampedBillingDay = min(max(billingDay, 1), 28)
        let effectiveCutoff = calendar.startOfDay(for: max(referenceDate, documentReferenceDate ?? referenceDate))

        var pastCount = min(max(overridePastInstallmentsCount ?? computedSchedule.pastInstallmentsCount, 0), totalInstallments)
        let rawFirstFutureDate = overrideFirstFutureBillingDate ?? computedSchedule.firstFutureBillingDate
        var firstComps = calendar.dateComponents([.year, .month], from: rawFirstFutureDate)
        firstComps.day = clampedBillingDay
        var firstFutureDate = calendar.date(from: firstComps) ?? rawFirstFutureDate

        if let schedule = scheduledInstallments, !schedule.isEmpty {
            let sortedSchedule = schedule.sorted { $0.installmentNumber < $1.installmentNumber }
            let futureSchedule = sortedSchedule.filter { item in
                guard item.installmentNumber > pastCount else { return false }
                var comps = calendar.dateComponents([.year, .month], from: item.bankDueDate)
                comps.day = clampedBillingDay
                let salaryDate = calendar.date(from: comps) ?? item.bankDueDate
                return calendar.startOfDay(for: salaryDate) > effectiveCutoff
            }
            let adjustedPastCount = min(totalInstallments, max(pastCount, totalInstallments - futureSchedule.count))
            pastCount = adjustedPastCount
            if let firstFutureItem = futureSchedule.first {
                var comps = calendar.dateComponents([.year, .month], from: firstFutureItem.bankDueDate)
                comps.day = clampedBillingDay
                firstFutureDate = calendar.date(from: comps) ?? firstFutureDate
            } else {
                while calendar.startOfDay(for: firstFutureDate) <= effectiveCutoff {
                    firstFutureDate = calendar.date(byAdding: .month, value: 1, to: firstFutureDate) ?? firstFutureDate
                }
            }
        } else if (startDate != nil && calendar.startOfDay(for: startDate!) < effectiveCutoff) || overrideFirstFutureBillingDate != nil {
            while calendar.startOfDay(for: firstFutureDate) <= effectiveCutoff && pastCount < totalInstallments {
                pastCount += 1
                firstFutureDate = calendar.date(byAdding: .month, value: 1, to: firstFutureDate) ?? firstFutureDate
            }
        }

        let futureScheduledItems: [ContractInstallmentScheduleItem] = (scheduledInstallments ?? [])
            .filter { $0.installmentNumber > pastCount }
            .sorted { $0.installmentNumber < $1.installmentNumber }

        let initialLoanBalance: Double? = {
            if kind == .loan,
               !futureScheduledItems.isEmpty,
               let schedule = scheduledInstallments,
               futureScheduledItems.count < schedule.count {
                let remainingD0 = (futureScheduledItems.reduce(0.0) { $0 + $1.amount } * 100.0).rounded() / 100.0
                if let explicit = outstandingBalance {
                    return min(explicit, remainingD0)
                }
                return remainingD0
            }
            if let explicit = outstandingBalance { return explicit }
            guard kind == .loan else { return nil }
            if pastCount > 0 {
                let remaining = max(totalInstallments - pastCount, 0)
                return LoanModel.calculatePresentValue(installment: installmentAmount, monthlyRate: monthlyInterestRate, remaining: remaining)
            }
            return totalContractedAmount
        }()

        let effectiveNextInstallmentAmount = (kind == .loan)
            ? (futureScheduledItems.first?.amount ?? installmentAmount)
            : installmentAmount

        let resolvedAvgGrowth: Double? = {
            if let explicitGrowth = averageMonthlyInstallmentGrowth, explicitGrowth > 0 {
                return explicitGrowth
            }
            if kind == .financing, futureScheduledItems.count >= 2 {
                let firstAmt = futureScheduledItems[0].amount
                let lastAmt = futureScheduledItems[futureScheduledItems.count - 1].amount
                let steps = Double(futureScheduledItems.count - 1)
                if lastAmt > firstAmt && steps > 0 {
                    return (lastAmt - firstAmt) / steps
                }
            }
            return nil
        }()

        let contract = CreditContract(
            kind: kind,
            name: name,
            contractNumber: contractNumber,
            loanSubtype: kind == .loan ? (loanSubtype ?? .consignado) : nil,
            financingSubtype: kind == .financing ? (financingSubtype ?? .imovel) : nil,
            amortizationSystem: amortizationSystem,
            totalContractedAmount: totalContractedAmount,
            outstandingBalance: initialLoanBalance,
            installmentAmount: effectiveNextInstallmentAmount,
            billingDay: billingDay,
            totalInstallments: totalInstallments,
            originalTotalInstallments: originalTotalInstallments ?? totalInstallments,
            monthlyInterestRate: monthlyInterestRate,
            startDate: startDate,
            accountId: accountId,
            categoryId: creditCategoryId,
            pastInstallmentsElapsedAtCreation: pastCount,
            notes: notes,
            annualNominalInterestRate: annualNominalInterestRate,
            indexationRate: indexationRate,
            adminFee: adminFee,
            insuranceFee: insuranceFee,
            baseInstallmentAmount: baseInstallmentAmount,
            bankDueDay: bankDueDay ?? billingDay,
            referenceDate: documentReferenceDate ?? referenceDate,
            maturityDate: maturityDate,
            estimatedMonthlyTR: estimatedMonthlyTR,
            lastFGTSUsageDate: lastFGTSUsageDate,
            scheduledInstallments: scheduledInstallments,
            averageMonthlyInstallmentGrowth: resolvedAvgGrowth
        )
        contracts.append(contract)

        let scheduleByNumber: [Int: ContractInstallmentScheduleItem] = Dictionary(
            uniqueKeysWithValues: (scheduledInstallments ?? []).map { ($0.installmentNumber, $0) }
        )
        let avgGrowthDec = LoanProjectionEngine.toDecimal(resolvedAvgGrowth ?? 0.0)
        let baseRegisteredDec = LoanProjectionEngine.toDecimal(installmentAmount)

        let remainingToCreate = max(totalInstallments - pastCount, 0)
        var createdTransactions: [FinancialTransaction] = []
        for offset in 0..<remainingToCreate {
            let step = offset + 1
            let installmentNumber = pastCount + step
            let dueDate = calendar.date(byAdding: .month, value: offset, to: firstFutureDate) ?? firstFutureDate
            let schedItem = scheduleByNumber[installmentNumber]

            let individualInstallmentAmount: Double
            let txBaseRegisteredAmount: Double?
            let txProjectedCorrectionAmount: Double?
            let extraBreakdownNote: String

            if kind == .financing && avgGrowthDec > .zero {
                let projCorrDec = LoanProjectionEngine.roundCurrency(Decimal(step) * avgGrowthDec)
                let projTotalDec = LoanProjectionEngine.roundCurrency(baseRegisteredDec + projCorrDec)
                let projCorrDouble = LoanProjectionEngine.toDouble(projCorrDec)
                let projTotalDouble = LoanProjectionEngine.toDouble(projTotalDec)

                individualInstallmentAmount = projTotalDouble
                txBaseRegisteredAmount = installmentAmount
                txProjectedCorrectionAmount = projCorrDouble
                extraBreakdownNote = " • Valor cadastrado: \(AppFormatters.currency(installmentAmount)) • Projeção de correção (+\(step)m): +\(AppFormatters.currency(projCorrDouble)) (Média doc: +\(AppFormatters.currency(resolvedAvgGrowth ?? 0.0))/mês)"
            } else {
                individualInstallmentAmount = schedItem?.amount ?? installmentAmount
                txBaseRegisteredAmount = nil
                txProjectedCorrectionAmount = nil
                if let p = schedItem?.principalAmount, let j = schedItem?.interestAmount {
                    extraBreakdownNote = " • Amortização: \(AppFormatters.currency(p)) • Juros: \(AppFormatters.currency(j))"
                } else {
                    extraBreakdownNote = ""
                }
            }

            let tx = FinancialTransaction(
                name: "\(name) - Parcela \(installmentNumber)/\(totalInstallments)",
                details: "\(contract.kind.title) (\(contract.subtypeDisplayName)) • Juros \(String(format: "%.2f", monthlyInterestRate))% a.m.\(extraBreakdownNote)",
                amount: individualInstallmentAmount,
                date: dueDate,
                type: .expense,
                isPaid: false,
                categoryId: creditCategoryId,
                accountId: accountId,
                ignoreInConsolidated: false,
                recurrenceMode: .installment,
                seriesGroupId: contract.id,
                installmentIndex: installmentNumber,
                installmentTotal: totalInstallments,
                linkedContractId: contract.id,
                transactionOrigin: .standard,
                linkedEntityID: contract.id,
                baseInstallmentRegisteredAmount: txBaseRegisteredAmount,
                projectedInstallmentCorrectionAmount: txProjectedCorrectionAmount
            )
            transactions.append(tx)
            createdTransactions.append(tx)
        }

        sortTransactions()
        invalidateDerivedCaches()
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contract.id, operation: .upsert, entity: contract)
        for tx in createdTransactions {
            cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: tx.id, operation: .upsert, entity: tx)
        }
        return contract
    }

    public func createContract(
        kind: CreditContractKind,
        name: String,
        loanSubtype: LoanSubtype? = .consignado,
        financingSubtype: FinancingSubtype? = nil,
        amortizationSystem: AmortizationSystem = .price,
        totalContractedAmount: Double,
        installmentAmount: Double,
        billingDay: Int,
        totalInstallments: Int,
        monthlyInterestRate: Double,
        accountId: UUID,
        categoryId: UUID
    ) {
        createCreditContract(
            kind: kind,
            name: name,
            loanSubtype: loanSubtype,
            financingSubtype: financingSubtype,
            amortizationSystem: amortizationSystem,
            totalContractedAmount: totalContractedAmount,
            installmentAmount: installmentAmount,
            billingDay: billingDay,
            totalInstallments: totalInstallments,
            monthlyInterestRate: monthlyInterestRate,
            startDate: Date(),
            accountId: accountId,
            categoryId: categoryId
        )
    }

    public func updateContract(_ contract: CreditContract) {
        if let idx = contracts.firstIndex(where: { $0.id == contract.id }) {
            contracts[idx] = contract
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contract.id, operation: .upsert, entity: contract)
        }
    }

    public func deleteContract(_ contractId: UUID) {
        let deletedTxs = transactions.filter { $0.linkedContractId == contractId || $0.seriesGroupId == contractId }
        let deletedPlans = amortizationPlans.filter { $0.contractId == contractId }
        transactions.removeAll { $0.linkedContractId == contractId || $0.seriesGroupId == contractId }
        amortizationPlans.removeAll { $0.contractId == contractId }
        contracts.removeAll { $0.id == contractId }
        invalidateDerivedCaches()
        saveToDisk()
        for plan in deletedPlans {
            cloudSyncService?.recordLocalMutation(entityName: "amortization_plans", entityId: plan.id, operation: .delete)
        }
        for tx in deletedTxs {
            cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: tx.id, operation: .delete)
        }
        cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contractId, operation: .delete)
    }

    public func unpaidTransactions(forContract contractId: UUID, after asOfCutoff: Date? = nil) -> [FinancialTransaction] {
        if let asOfCutoff {
            return transactions
                .filter { $0.linkedContractId == contractId && $0.date > asOfCutoff }
                .sorted { $0.date < $1.date }
        } else {
            return transactions
                .filter { $0.linkedContractId == contractId && !$0.isPaid }
                .sorted { $0.date < $1.date }
        }
    }

    public func paidTransactionsCount(forContract contract: CreditContract) -> Int {
        let paidInApp = transactions.filter { $0.linkedContractId == contract.id && $0.isPaid && $0.installmentIndex != nil }.count
        return min(contract.pastInstallmentsElapsedAtCreation + paidInApp, contract.effectiveOriginalTotalInstallments)
    }

    public func progressMetrics(for contract: CreditContract) -> ContractProgressMetrics {
        let original = contract.effectiveOriginalTotalInstallments
        let paidInFlow = paidTransactionsCount(forContract: contract)
        let remaining = contract.isSettled ? 0 : remainingInstallmentsCount(for: contract)
        return ContractProgressMetrics(
            id: contract.id,
            originalTotalInstallments: original,
            paidInFlowCount: paidInFlow,
            remainingCount: remaining,
            isSettled: contract.isSettled
        )
    }

    public func eliminatedInstallmentsCount(for contract: CreditContract) -> Int {
        progressMetrics(for: contract).eliminatedByAmortizationCount
    }

    public func totalOvercomeMonths(for contract: CreditContract) -> Int {
        progressMetrics(for: contract).totalOvercomeMonths
    }

    public func globalCompletionPercentage(for contract: CreditContract) -> Double {
        progressMetrics(for: contract).globalCompletionPercentage
    }

    public func remainingInstallmentsCount(for contract: CreditContract, asOf asOfCutoff: Date? = nil) -> Int {
        guard !contract.isSettled else { return 0 }
        if let asOfCutoff {
            let remainingAfter = unpaidTransactions(forContract: contract.id, after: asOfCutoff)
            if !remainingAfter.isEmpty {
                return remainingAfter.count
            }
            let elapsed = transactions.filter { $0.linkedContractId == contract.id && $0.date <= asOfCutoff }.count
            return max(contract.totalInstallments - contract.pastInstallmentsElapsedAtCreation - elapsed, 0)
        }
        let unpaid = unpaidTransactions(forContract: contract.id).count
        if unpaid > 0 { return unpaid }
        return max(contract.totalInstallments - paidTransactionsCount(forContract: contract), 0)
    }

    public func remainingNominalAmount(for contract: CreditContract, asOf asOfCutoff: Date? = nil) -> Double {
        guard !contract.isSettled else { return 0 }
        if let asOfCutoff {
            let remainingTxs = unpaidTransactions(forContract: contract.id, after: asOfCutoff)
            if !remainingTxs.isEmpty {
                return remainingTxs.reduce(0.0) { $0 + $1.amount }
            }
            return Double(remainingInstallmentsCount(for: contract, asOf: asOfCutoff)) * contract.installmentAmount
        }
        let unpaidTxs = unpaidTransactions(forContract: contract.id)
        if !unpaidTxs.isEmpty {
            return unpaidTxs.reduce(0.0) { $0 + $1.amount }
        }
        return Double(remainingInstallmentsCount(for: contract)) * contract.installmentAmount
    }

    public func currentOutstandingBalance(for contract: CreditContract, asOf asOfCutoff: Date? = nil) -> Double {
        guard !contract.isSettled else { return 0.0 }
        let lastAmortDate = contract.amortizationHistory.first?.date

        if contract.kind == .financing, let explicitBalance = contract.outstandingBalance, explicitBalance > 0 {
            let basePrice = contract.effectiveBaseInstallmentPrice
            let annualRate = contract.effectiveAnnualNominalRate
            let admin = contract.effectiveAdminFee
            let insurance = contract.effectiveInsuranceFee

            let elapsedInApp: Int
            if let asOfCutoff {
                elapsedInApp = transactions.filter { tx in
                    tx.linkedContractId == contract.id &&
                    tx.installmentIndex != nil &&
                    (lastAmortDate == nil || tx.date > lastAmortDate!) &&
                    (tx.isPaid || tx.date <= asOfCutoff)
                }.count
            } else {
                elapsedInApp = transactions.filter { tx in
                    tx.linkedContractId == contract.id &&
                    tx.installmentIndex != nil &&
                    (lastAmortDate == nil || tx.date > lastAmortDate!) &&
                    tx.isPaid
                }.count
            }

            var runningBalance = explicitBalance
            if elapsedInApp > 0 {
                for idx in 1...elapsedInApp {
                    guard runningBalance > 0.01 else { break }
                    let step = AmortizationEngine.calculateNextInstallment(
                        currentBalance: runningBalance,
                        annualNominalRate: annualRate,
                        basePriceInstallment: basePrice,
                        adminFee: admin,
                        insuranceFee: insurance,
                        monthlyTR: 0.0,
                        installmentIndex: idx
                    )
                    runningBalance = step.newBalance
                }
            }
            return max(0.0, runningBalance)
        }

        if contract.kind == .loan {
            let initialBalance = contract.loanDetails?.balance ?? contract.outstandingBalance ?? contract.totalContractedAmount
            guard initialBalance > 0 else { return 0.0 }

            let elapsedTransactions: [FinancialTransaction]
            if let asOfCutoff {
                elapsedTransactions = transactions.filter { tx in
                    tx.linkedContractId == contract.id &&
                    tx.installmentIndex != nil &&
                    (lastAmortDate == nil || tx.date > lastAmortDate!) &&
                    (tx.isPaid || tx.date <= asOfCutoff)
                }
            } else {
                elapsedTransactions = transactions.filter { tx in
                    tx.linkedContractId == contract.id &&
                    tx.installmentIndex != nil &&
                    (lastAmortDate == nil || tx.date > lastAmortDate!) &&
                    tx.isPaid
                }
            }

            if let schedule = contract.scheduledInstallments, !schedule.isEmpty {
                let paidD0Sum = elapsedTransactions.reduce(0.0) { $0 + $1.amount }
                return max(0.0, ((initialBalance - paidD0Sum) * 100.0).rounded() / 100.0)
            }

            let monthlyRate = contract.monthlyInterestRate
            let pmt = contract.installmentAmount
            let elapsedInApp = elapsedTransactions.count

            var runningBalance = initialBalance
            if elapsedInApp > 0 {
                for idx in 1...elapsedInApp {
                    guard runningBalance > 0.01 else { break }
                    let step = LoanAmortizationEngine.calculateNextInstallment(
                        currentBalance: runningBalance,
                        monthlyInterestRate: monthlyRate,
                        installmentValue: pmt,
                        installmentIndex: idx
                    )
                    runningBalance = step.newBalance
                }
            }
            return max(0.0, runningBalance)
        }

        if let explicitBalance = contract.outstandingBalance, explicitBalance > 0 {
            let totalToAmortize = max(contract.totalInstallments - contract.pastInstallmentsElapsedAtCreation, 1)
            let estimatedPrincipalPerInstallment = explicitBalance / Double(totalToAmortize)
            let elapsedInApp: Int
            if let asOfCutoff {
                elapsedInApp = transactions.filter { tx in
                    tx.linkedContractId == contract.id &&
                    tx.installmentIndex != nil &&
                    (lastAmortDate == nil || tx.date > lastAmortDate!) &&
                    (tx.isPaid || tx.date <= asOfCutoff)
                }.count
            } else {
                elapsedInApp = transactions.filter { tx in
                    tx.linkedContractId == contract.id &&
                    tx.installmentIndex != nil &&
                    (lastAmortDate == nil || tx.date > lastAmortDate!) &&
                    tx.isPaid
                }.count
            }
            let reducedByInstallments = Double(elapsedInApp) * estimatedPrincipalPerInstallment
            return max(explicitBalance - reducedByInstallments, 0.0)
        }
        return projectedPayoffAmount(for: contract, asOf: asOfCutoff)
    }

    public func projectedPayoffAmount(for contract: CreditContract, asOf asOfCutoff: Date? = nil) -> Double {
        guard !contract.isSettled else { return 0.0 }
        let n = remainingInstallmentsCount(for: contract, asOf: asOfCutoff)
        guard n > 0 else { return 0.0 }

        if contract.kind == .loan {
            let currentBal = currentOutstandingBalance(for: contract, asOf: asOfCutoff)
            if currentBal > 0.01 {
                return currentBal
            }
            return LoanAmortizationEngine.calculatePayoffAmount(
                currentBalance: currentBal,
                monthlyInterestRate: contract.monthlyInterestRate,
                installmentValue: contract.installmentAmount,
                remainingInstallments: n
            )
        }

        let nominalRemaining = remainingNominalAmount(for: contract, asOf: asOfCutoff)
        let pmt = nominalRemaining / Double(max(n, 1))
        let i = contract.monthlyInterestRate / 100.0

        if let explicitBalance = contract.outstandingBalance, explicitBalance > 0 {
            let currentBal = currentOutstandingBalance(for: contract, asOf: asOfCutoff)
            if currentBal < nominalRemaining - 0.01 {
                return max(currentBal, 0.0)
            }
        }

        guard i > 0.0001 else {
            if let explicitBalance = contract.outstandingBalance, explicitBalance > 0 {
                return max(min(currentOutstandingBalance(for: contract, asOf: asOfCutoff), nominalRemaining), 0.0)
            }
            return max(nominalRemaining, 0)
        }

        let pvPrice = pmt * (1.0 - pow(1.0 + i, -Double(n))) / i
        let calculatedPayoff: Double
        switch contract.amortizationSystem {
        case .price:
            if contract.kind == .loan, let subtype = contract.loanSubtype {
                let discount = max(nominalRemaining - pvPrice, 0) * subtype.discountFactorMultiplier
                calculatedPayoff = max(nominalRemaining - discount, 0)
            } else {
                calculatedPayoff = min(pvPrice, nominalRemaining)
            }
        case .sac:
            let proportionalPrincipal = contract.totalContractedAmount * (Double(n) / Double(max(contract.totalInstallments, 1)))
            let estimatedPrincipal = min(max(proportionalPrincipal - contract.extraAmortizedTotal, pvPrice * 0.92), nominalRemaining)
            calculatedPayoff = max(estimatedPrincipal, 0)
        }

        if let explicitBalance = contract.outstandingBalance, explicitBalance > 0 {
            return max(min(calculatedPayoff, currentOutstandingBalance(for: contract, asOf: asOfCutoff)), 0.0)
        }
        return calculatedPayoff
    }

    public func amortizedAmountInPeriod(for contract: CreditContract, referenceDate: Date, isAnnual: Bool) -> Double {
        transactions
            .filter { tx in
                tx.linkedContractId == contract.id &&
                tx.isPaid &&
                (isAnnual ? isInYear(tx.date, yearReference: referenceDate) : isInMonth(tx.date, monthReference: referenceDate))
            }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func realAmortizationAmountInPeriod(for contract: CreditContract, referenceDate: Date, isAnnual: Bool) -> Double {
        let periodTransactions = transactions.filter { tx in
            tx.linkedContractId == contract.id &&
            tx.isPaid &&
            (isAnnual ? isInYear(tx.date, yearReference: referenceDate) : isInMonth(tx.date, monthReference: referenceDate))
        }

        if contract.kind == .financing {
            let finModel = contract.effectiveFinancingModel
            let monthlyAmort = finModel?.currentMonthlyAmortization ?? 0.0
            var sum = 0.0
            for tx in periodTransactions {
                if tx.installmentIndex != nil {
                    sum += monthlyAmort
                } else {
                    sum += tx.amount
                }
            }
            return sum
        } else if contract.kind == .loan {
            let loanModel = contract.effectiveLoanModel
            let monthlyAmort = loanModel?.currentMonthlyAmortization ?? 0.0
            var sum = 0.0
            for tx in periodTransactions {
                if tx.installmentIndex != nil {
                    sum += monthlyAmort
                } else {
                    sum += tx.amount
                }
            }
            return sum
        } else {
            return periodTransactions.reduce(0.0) { $0 + $1.amount }
        }
    }

    public func recordAmortization(
        contractId: UUID,
        amount: Double,
        mode: AmortizationRecalculationMode,
        paidFromAccountId: UUID,
        notes: String = ""
    ) {
        amortizeContract(
            contractId: contractId,
            amountPaid: amount,
            accountId: paidFromAccountId,
            date: Date(),
            mode: mode,
            notes: notes
        )
    }

    public func amortizeContract(
        contractId: UUID,
        amountPaid: Double,
        accountId: UUID,
        date: Date = Date(),
        mode: AmortizationRecalculationMode,
        proRataInterest: Double = 0.0,
        customNewInstallmentAmount: Double? = nil,
        customNewRemainingInstallments: Int? = nil,
        notes: String = ""
    ) {
        guard let idx = contracts.firstIndex(where: { $0.id == contractId }) else { return }
        var contract = contracts[idx]
        let isLoan = contract.kind == .loan
        let cleanPaid = abs(amountPaid)
        guard cleanPaid > 0 else { return }

        let prevRemaining = remainingInstallmentsCount(for: contract)
        let prevInstallment = contract.installmentAmount
        let currentPV = currentOutstandingBalance(for: contract)

        let isFullPayoff: Bool
        let newInstallment: Double
        let newRemaining: Int
        let effectiveAmortization: Double
        let proRataApplied: Double
        let newBalanceSimulated: Double

        if isLoan {
            let sim = LoanAmortizationEngine.simulateExtraAmortization(
                currentBalance: currentPV,
                monthlyInterestRate: contract.monthlyInterestRate,
                installmentValue: contract.installmentAmount,
                currentRemainingInstallments: prevRemaining,
                extraPayment: cleanPaid,
                proRataInterest: proRataInterest,
                mode: mode
            )
            isFullPayoff = cleanPaid >= (currentPV - 0.01) || sim.newBalance <= 0.01
            effectiveAmortization = sim.effectiveAmortization
            proRataApplied = sim.proRataInterest
            newBalanceSimulated = sim.newBalance
            if isFullPayoff {
                newInstallment = 0.0
                newRemaining = 0
            } else {
                newInstallment = customNewInstallmentAmount ?? sim.newInstallmentAmount
                newRemaining = customNewRemainingInstallments ?? sim.newRemainingInstallments
            }
        } else {
            let sim = AmortizationEngine.simulateExtraAmortization(
                currentBalance: currentPV,
                annualNominalRate: contract.effectiveAnnualNominalRate,
                basePriceInstallment: contract.effectiveBaseInstallmentPrice,
                totalInstallmentAmount: contract.installmentAmount,
                currentRemainingInstallments: prevRemaining,
                extraPayment: cleanPaid,
                proRataInterest: proRataInterest,
                mode: mode,
                adminFee: contract.effectiveAdminFee,
                insuranceFee: contract.effectiveInsuranceFee
            )
            isFullPayoff = cleanPaid >= (currentPV - 0.01) || sim.newBalance <= 0.01
            effectiveAmortization = sim.effectiveAmortization
            proRataApplied = sim.proRataInterest
            newBalanceSimulated = sim.newBalance
            if isFullPayoff {
                newInstallment = 0.0
                newRemaining = 0
            } else {
                newInstallment = customNewInstallmentAmount ?? sim.newInstallmentAmount
                newRemaining = customNewRemainingInstallments ?? sim.newRemainingInstallments
            }
        }

        let proRataNote = proRataApplied > 0 ? " • Juros Pró-rata: \(AppFormatters.currency(proRataApplied))" : ""
        let payoffNote = isFullPayoff ? " • Quitação Total" : ""
        let txOrigin: TransactionOrigin
        if isLoan {
            txOrigin = isFullPayoff ? .loanPayoff : .loanAmortization
        } else {
            txOrigin = isFullPayoff ? .contractSettlement : .financingAmortization
        }

        let amortTx = FinancialTransaction(
            name: isFullPayoff ? "Quitação: \(contract.name)" : "Amortização: \(contract.name)",
            details: "Amortização extraordinária (\(mode.rawValue)). Amortização Efetiva no Saldo: \(AppFormatters.currency(effectiveAmortization))\(proRataNote)\(payoffNote). \(notes)".trimmingCharacters(in: .whitespaces),
            amount: cleanPaid,
            date: date,
            type: .expense,
            isPaid: true,
            categoryId: contract.categoryId,
            accountId: accountId,
            ignoreInConsolidated: false,
            recurrenceMode: .single,
            linkedContractId: contract.id,
            transactionOrigin: txOrigin,
            linkedEntityID: contract.id
        )
        transactions.append(amortTx)

        let unpaidList = unpaidTransactions(forContract: contract.id)
        if isFullPayoff || newRemaining == 0 {
            let idsToRemove = Set(unpaidList.map(\.id))
            transactions.removeAll { idsToRemove.contains($0.id) }
            contract.isSettled = true
            contract.settledAmount = cleanPaid
            contract.settledDate = date
            contract.settledAccountId = accountId
            contract.outstandingBalance = 0.0
            if contract.financingDetails != nil {
                contract.financingDetails?.balance = 0.0
                contract.financingDetails?.remainingInstallments = 0
                contract.financingDetails?.totalInstallmentAmount = 0.0
            }
            if contract.loanDetails != nil {
                contract.loanDetails?.balance = 0.0
                contract.loanDetails?.remainingInstallments = 0
                contract.loanDetails?.installmentValue = 0.0
            }
        } else {
            if newRemaining < unpaidList.count {
                let toRemove = unpaidList.suffix(unpaidList.count - newRemaining)
                let removeIds = Set(toRemove.map(\.id))
                transactions.removeAll { removeIds.contains($0.id) }
            }
            let remainingUnpaidIds = Set(unpaidTransactions(forContract: contract.id).map(\.id))
            let newTotalInstallments = contract.totalInstallments - max(0, prevRemaining - newRemaining)
            contract.totalInstallments = max(newTotalInstallments, 1)
            contract.installmentAmount = newInstallment

            for tIdx in transactions.indices {
                if remainingUnpaidIds.contains(transactions[tIdx].id) {
                    transactions[tIdx].amount = newInstallment
                    transactions[tIdx].installmentTotal = contract.totalInstallments
                    if let instIdx = transactions[tIdx].installmentIndex {
                        transactions[tIdx].name = "\(contract.name) - Parcela \(instIdx)/\(contract.totalInstallments)"
                    }
                }
            }

            contract.outstandingBalance = newBalanceSimulated
            if contract.financingDetails != nil {
                contract.financingDetails?.balance = newBalanceSimulated
                contract.financingDetails?.remainingInstallments = newRemaining
                contract.financingDetails?.totalInstallmentAmount = newInstallment
            }
            if contract.loanDetails != nil {
                contract.loanDetails?.balance = newBalanceSimulated
                contract.loanDetails?.remainingInstallments = newRemaining
                contract.loanDetails?.installmentValue = newInstallment
            }
        }

        contract.extraAmortizedTotal += effectiveAmortization
        contract.originalTotalInstallments = contract.effectiveOriginalTotalInstallments
        let record = AmortizationRecord(
            date: date,
            amountPaid: cleanPaid,
            mode: mode,
            previousInstallmentAmount: prevInstallment,
            newInstallmentAmount: newInstallment,
            previousRemainingInstallments: prevRemaining,
            newRemainingInstallments: newRemaining,
            accountId: accountId,
            transactionId: amortTx.id,
            notes: notes,
            effectiveAmortization: effectiveAmortization,
            previousBalance: currentPV
        )
        contract.amortizationHistory.insert(record, at: 0)
        contracts[idx] = contract

        sortTransactions()
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contract.id, operation: .upsert, entity: contract)
        cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: amortTx.id, operation: .upsert, entity: amortTx)
    }

    public func settleContract(
        contractId: UUID,
        finalPayoffAmount: Double,
        accountId: UUID,
        date: Date = Date()
    ) {
        guard let idx = contracts.firstIndex(where: { $0.id == contractId }) else { return }
        var contract = contracts[idx]
        let isLoan = contract.kind == .loan
        let cleanFinal = abs(finalPayoffAmount)
        let nominalRemaining = remainingNominalAmount(for: contract)
        let prevRemaining = remainingInstallmentsCount(for: contract)
        let prevInstallment = contract.installmentAmount
        let currentPV = currentOutstandingBalance(for: contract)

        let unpaidIds = Set(unpaidTransactions(forContract: contract.id).map(\.id))
        transactions.removeAll { unpaidIds.contains($0.id) }

        let settleTx = FinancialTransaction(
            name: "Quitação: \(contract.name)",
            details: "Quitação integral de \(contract.kind.title.lowercased()) (Saldo nominal: \(AppFormatters.currency(nominalRemaining)), Saldo Devedor PV: \(AppFormatters.currency(currentPV)))",
            amount: cleanFinal,
            date: date,
            type: .expense,
            isPaid: true,
            categoryId: contract.categoryId,
            accountId: accountId,
            ignoreInConsolidated: false,
            recurrenceMode: .single,
            linkedContractId: contract.id,
            transactionOrigin: isLoan ? .loanPayoff : .contractSettlement,
            linkedEntityID: contract.id
        )
        transactions.append(settleTx)

        let record = AmortizationRecord(
            date: date,
            amountPaid: cleanFinal,
            mode: .reduceTerm,
            previousInstallmentAmount: prevInstallment,
            newInstallmentAmount: 0.0,
            previousRemainingInstallments: prevRemaining,
            newRemainingInstallments: 0,
            accountId: accountId,
            transactionId: settleTx.id,
            notes: "Quitação integral",
            effectiveAmortization: currentPV,
            previousBalance: currentPV
        )
        contract.amortizationHistory.insert(record, at: 0)

        contract.isSettled = true
        contract.settledAmount = cleanFinal
        contract.settledDate = date
        contract.settledAccountId = accountId
        contract.outstandingBalance = 0.0
        if contract.financingDetails != nil {
            contract.financingDetails?.balance = 0.0
            contract.financingDetails?.remainingInstallments = 0
            contract.financingDetails?.totalInstallmentAmount = 0.0
        }
        if contract.loanDetails != nil {
            contract.loanDetails?.balance = 0.0
            contract.loanDetails?.remainingInstallments = 0
            contract.loanDetails?.installmentValue = 0.0
        }
        contract.originalTotalInstallments = contract.effectiveOriginalTotalInstallments
        contracts[idx] = contract

        sortTransactions()
        invalidateDerivedCaches()
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contract.id, operation: .upsert, entity: contract)
        cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: settleTx.id, operation: .upsert, entity: settleTx)
    }

    // MARK: - Planejamento Dinâmico de Amortização (Camada 2 — Intenção & Camada 3 — Projeção em Memória)

    public func amortizationPlan(for contractId: UUID) -> AmortizationPlan? {
        amortizationPlans.first { $0.contractId == contractId }
    }

    public func expiredPlannedAmortizations(for contractId: UUID) -> [PlannedAmortization] {
        guard let plan = amortizationPlan(for: contractId) else { return [] }
        return plan.items
            .filter { $0.status == .expired }
            .sorted { $0.date < $1.date }
    }

    public var allExpiredPlannedAmortizations: [(contract: CreditContract, item: PlannedAmortization)] {
        var result: [(contract: CreditContract, item: PlannedAmortization)] = []
        for contract in contracts where !contract.isSettled {
            for item in expiredPlannedAmortizations(for: contract.id) {
                result.append((contract: contract, item: item))
            }
        }
        return result
    }

    public var hasAnyAmortizationPlan: Bool {
        amortizationPlans.contains { plan in
            plan.items.contains { $0.status == .pending || $0.status == .expired }
        }
    }

    public func validateExpiredAmortizationPlans(referenceNow: Date? = nil) {
        let now = referenceNow ?? effectiveCurrentDate
        let newlyExpired = PlanExpirationValidator.validateAndExpireOverdueItems(
            plans: &amortizationPlans,
            referenceNow: now,
            calendar: calendar
        )
        if !newlyExpired.isEmpty {
            for contract in contracts {
                syncPlannedAmortizationTransactions(for: contract.id, saveAfter: false)
            }
            saveToDisk()
        }
    }

    public func hasSavedAmortizationPlan(for contractId: UUID) -> Bool {
        guard let plan = amortizationPlan(for: contractId) else { return false }
        return plan.items.contains { $0.status == .pending || $0.status == .expired }
    }

    public func loanProjection(for contractId: UUID) -> LoanProjectionResult? {
        if let cached = cachedLoanProjections[contractId] {
            return cached
        }
        guard let contract = contracts.first(where: { $0.id == contractId }), !contract.isSettled else {
            return nil
        }
        let unpaidInstallments = transactions.filter {
            $0.linkedContractId == contractId &&
            $0.installmentIndex != nil &&
            !$0.isPaid
        }
        let currentRealBal = currentOutstandingBalance(for: contract)
        let plan = amortizationPlan(for: contractId)
        let result = LoanProjectionEngine.simulate(
            contract: contract,
            unpaidInstallmentTransactions: unpaidInstallments,
            currentRealBalanceDouble: currentRealBal,
            plan: plan,
            calendar: calendar
        )
        cachedLoanProjections[contractId] = result
        return result
    }

    public func simulateAmortizationPlanPreview(
        for contractId: UUID,
        draftPlan: AmortizationPlan?
    ) -> LoanProjectionResult? {
        guard let contract = contracts.first(where: { $0.id == contractId }), !contract.isSettled else {
            return nil
        }
        let unpaidInstallments = transactions.filter {
            $0.linkedContractId == contractId &&
            $0.installmentIndex != nil &&
            !$0.isPaid
        }
        let currentRealBal = currentOutstandingBalance(for: contract)
        return LoanProjectionEngine.simulate(
            contract: contract,
            unpaidInstallmentTransactions: unpaidInstallments,
            currentRealBalanceDouble: currentRealBal,
            plan: draftPlan,
            calendar: calendar
        )
    }

    public func maxAvailableLoanBalanceToAmortize(
        for contractId: UUID,
        draftItems: [PlannedAmortization],
        onDate: Date,
        excludingItemId: UUID? = nil,
        estimatedMonthlyTR: Decimal = .zero
    ) -> Double {
        guard let contract = contracts.first(where: { $0.id == contractId }), !contract.isSettled else {
            return 0.0
        }
        let unpaidInstallments = transactions.filter {
            $0.linkedContractId == contractId &&
            $0.installmentIndex != nil &&
            !$0.isPaid
        }
        let currentRealBal = currentOutstandingBalance(for: contract)
        let maxDec = LoanProjectionEngine.maxAvailableLoanBalanceToAmortize(
            contract: contract,
            unpaidInstallmentTransactions: unpaidInstallments,
            currentRealBalanceDouble: currentRealBal,
            existingItems: draftItems,
            onDate: onDate,
            excludingItemId: excludingItemId,
            estimatedMonthlyTR: estimatedMonthlyTR,
            calendar: calendar
        )
        return LoanProjectionEngine.toDouble(maxDec)
    }

    public func expectedMonthEndCashBalance(
        for monthDate: Date,
        contractId: UUID,
        draftPlan: AmortizationPlan?,
        draftProjection: LoanProjectionResult?,
        additionalTypingOutflow: Double = 0.0
    ) -> Double {
        let cutoff = endOfMonth(for: monthDate)
        let isClosed = isMonthPriorToCurrent(monthDate)
        let initialAccountsSum = accounts.reduce(0.0) { $0 + $1.initialBalance }
        let consolidatedInvestmentsSum = investments
            .filter(\.showInConsolidated)
            .reduce(0.0) { $0 + $1.balance }

        let shadowedByDraft = draftProjection?.shadowedInstallmentTransactionIds ?? []
        let projectedAmountsByDraft = draftProjection?.activeInstallmentProjectedAmounts ?? [:]

        var transactionsDelta = 0.0
        for tx in transactions {
            guard !tx.ignoreInConsolidated else { continue }
            guard !tx.isCreditCardExpense else { continue }
            guard tx.date <= cutoff else { continue }
            if isClosed && !tx.isPaid { continue }

            if tx.linkedContractId == contractId && tx.transactionOrigin == .plannedAmortization {
                continue
            }

            if tx.linkedContractId == contractId && tx.installmentIndex != nil && !tx.isPaid {
                if shadowedByDraft.contains(tx.id) {
                    continue
                }
                if let draftAmtDec = projectedAmountsByDraft[tx.id] {
                    let amt = LoanProjectionEngine.toDouble(draftAmtDec)
                    transactionsDelta += (tx.type == .income ? amt : -amt)
                    continue
                }
            }

            transactionsDelta += effectiveSignedTransactionAmount(for: tx)
        }

        var draftAmortizationsOutflow = 0.0
        if let draftPlan {
            for item in draftPlan.items where item.status == .pending && item.date <= cutoff {
                let effectiveDec = draftProjection?.plannedItemOutcomes[item.id]?.effectiveAmortization ?? item.amount
                draftAmortizationsOutflow += LoanProjectionEngine.toDouble(effectiveDec)
            }
        }

        let remainingProvisions = isClosed ? 0.0 : accumulatedRemainingProvisions(throughMonth: monthDate)
        return initialAccountsSum + transactionsDelta + consolidatedInvestmentsSum - remainingProvisions - draftAmortizationsOutflow - max(0.0, additionalTypingOutflow)
    }

    @discardableResult
    public func saveAmortizationPlan(
        contractId: UUID,
        generationMode: AmortizationPlanGenerationMode,
        billingDay: Int,
        incomeCommitmentPercentage: Decimal,
        defaultRecalculationMode: AmortizationRecalculationMode,
        estimatedMonthlyTR: Decimal,
        draftItems: [PlannedAmortization]
    ) -> AmortizationPlan? {
        guard let contractIdx = contracts.firstIndex(where: { $0.id == contractId }),
              !contracts[contractIdx].isSettled else {
            return nil
        }
        contracts[contractIdx].estimatedMonthlyTR = LoanProjectionEngine.toDouble(estimatedMonthlyTR)
        let contract = contracts[contractIdx]
        let effectiveMode: AmortizationRecalculationMode = contract.kind == .loan ? .reduceTerm : defaultRecalculationMode

        let unpaidInstallments = transactions.filter {
            $0.linkedContractId == contractId &&
            $0.installmentIndex != nil &&
            !$0.isPaid
        }
        let currentRealBal = currentOutstandingBalance(for: contract)

        let sanitizedItems = LoanProjectionEngine.clampAndSanitizePlannedItems(
            draftItems,
            contract: contract,
            unpaidInstallmentTransactions: unpaidInstallments,
            currentRealBalanceDouble: currentRealBal,
            estimatedMonthlyTR: estimatedMonthlyTR,
            calendar: calendar
        )

        let existingPlan = amortizationPlan(for: contractId)
        let executedItems = existingPlan?.items.filter { $0.status == .executed } ?? []
        let pendingOrExpired = sanitizedItems.filter { $0.status != .executed }
        let mergedItems = (executedItems + pendingOrExpired).sorted { $0.date < $1.date }

        let savedPlan = AmortizationPlan(
            id: existingPlan?.id ?? UUID(),
            contractId: contractId,
            generationMode: generationMode,
            billingDay: min(max(billingDay, 1), 31),
            incomeCommitmentPercentage: min(max(incomeCommitmentPercentage, Decimal(1)), Decimal(100)),
            defaultRecalculationMode: effectiveMode,
            estimatedMonthlyTR: max(.zero, estimatedMonthlyTR),
            items: mergedItems,
            updatedAt: effectiveCurrentDate,
            createdAt: existingPlan?.createdAt ?? effectiveCurrentDate
        )

        if let pIdx = amortizationPlans.firstIndex(where: { $0.contractId == contractId }) {
            amortizationPlans[pIdx] = savedPlan
        } else {
            amortizationPlans.append(savedPlan)
        }

        syncPlannedAmortizationTransactions(for: contractId)
        cloudSyncService?.recordLocalMutation(entityName: "amortization_plans", entityId: savedPlan.id, operation: .upsert, entity: savedPlan)
        cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contract.id, operation: .upsert, entity: contract)
        return savedPlan
    }

    public func activeProjectionSnapshot() -> (shadowedTxIds: Set<UUID>, projectedInstallmentAmounts: [UUID: Double]) {
        guard budgetProjectionScenario == .withPlanning else {
            return ([], [:])
        }
        if let cached = cachedActiveProjectionSnapshot {
            return (cached.shadowedTxIds, cached.projectedInstallmentAmounts)
        }
        var shadowed: Set<UUID> = []
        var projectedAmounts: [UUID: Double] = [:]
        var payoffTxs: Set<UUID> = []

        for contract in contracts where !contract.isSettled {
            guard let plan = amortizationPlan(for: contract.id),
                  plan.items.contains(where: { $0.status == .pending }) else {
                continue
            }
            if let proj = loanProjection(for: contract.id) {
                shadowed.formUnion(proj.shadowedInstallmentTransactionIds)
                for (txId, decAmt) in proj.activeInstallmentProjectedAmounts {
                    projectedAmounts[txId] = LoanProjectionEngine.toDouble(decAmt)
                }
                for item in plan.items where item.status == .pending {
                    if let outcome = proj.plannedItemOutcomes[item.id],
                       outcome.isFullPayoffStep || outcome.remainingBalanceAfter <= Decimal(string: "0.01")!,
                       let linkedTxId = item.linkedTransactionId {
                        payoffTxs.insert(linkedTxId)
                    }
                }
            }
        }
        cachedActiveProjectionSnapshot = (shadowed, projectedAmounts, payoffTxs)
        return (shadowed, projectedAmounts)
    }

    public func isPlannedAmortizationFullPayoff(_ tx: FinancialTransaction) -> Bool {
        if tx.transactionOrigin == .plannedAmortization {
            _ = activeProjectionSnapshot()
            if let cached = cachedActiveProjectionSnapshot, cached.payoffTxIds.contains(tx.id) {
                return true
            }
            if let contractId = tx.linkedContractId,
               let proj = loanProjection(for: contractId),
               let itemId = tx.linkedEntityID,
               let outcome = proj.plannedItemOutcomes[itemId] {
                return outcome.isFullPayoffStep || outcome.remainingBalanceAfter <= Decimal(string: "0.01")!
            }
            return tx.name.localizedCaseInsensitiveContains("Liquidação") ||
                   tx.details.localizedCaseInsensitiveContains("Liquidação Total")
        }

        if budgetProjectionScenario == .withPlanning,
           let contractId = tx.linkedContractId,
           tx.installmentIndex != nil,
           !tx.isPaid,
           hasSavedAmortizationPlan(for: contractId),
           let proj = loanProjection(for: contractId),
           proj.monthsSaved > 0 {
            if let row = proj.timeline.first(where: { $0.linkedTransactionId == tx.id }),
               row.status == .active,
               row.finalBalance <= Decimal(string: "0.01")! {
                return true
            }
        }

        return false
    }

    public func transactionProjectionStatus(for tx: FinancialTransaction) -> ProjectedInstallmentStatus {
        if tx.transactionOrigin == .plannedAmortization {
            return .pendingAmortization
        }
        guard budgetProjectionScenario == .withPlanning,
              tx.linkedContractId != nil,
              tx.installmentIndex != nil,
              !tx.isPaid else {
            return .active
        }
        let snap = activeProjectionSnapshot()
        return snap.shadowedTxIds.contains(tx.id) ? .shadowed : .active
    }

    public func isTransactionVisibleInCurrentScenario(_ tx: FinancialTransaction) -> Bool {
        if tx.transactionOrigin == .plannedAmortization {
            guard budgetProjectionScenario == .withPlanning else { return false }
            for plan in amortizationPlans {
                if let item = plan.items.first(where: { $0.id == tx.linkedEntityID || $0.linkedTransactionId == tx.id }) {
                    return item.status == .pending
                }
            }
            return false
        }
        return true
    }

    public func effectiveTransactionAmount(for tx: FinancialTransaction) -> Double {
        if tx.transactionOrigin == .plannedAmortization {
            guard budgetProjectionScenario == .withPlanning else { return 0.0 }
            for plan in amortizationPlans {
                if let item = plan.items.first(where: { $0.id == tx.linkedEntityID || $0.linkedTransactionId == tx.id }) {
                    guard item.status == .pending else { return 0.0 }
                    if let proj = loanProjection(for: plan.contractId),
                       let outcome = proj.plannedItemOutcomes[item.id] {
                        return LoanProjectionEngine.toDouble(outcome.effectiveAmortization)
                    }
                    return item.amountDouble
                }
            }
            return 0.0
        }

        if budgetProjectionScenario == .withPlanning,
           tx.linkedContractId != nil,
           tx.installmentIndex != nil,
           !tx.isPaid {
            let snap = activeProjectionSnapshot()
            if snap.shadowedTxIds.contains(tx.id) {
                return 0.0
            }
            if let projAmt = snap.projectedInstallmentAmounts[tx.id] {
                return projAmt
            }
        }

        return tx.amount
    }

    public func effectiveSignedTransactionAmount(for tx: FinancialTransaction) -> Double {
        let amt = effectiveTransactionAmount(for: tx)
        return tx.type == .income ? amt : -amt
    }

    public func syncPlannedAmortizationTransactions(for contractId: UUID, saveAfter: Bool = true) {
        guard let contract = contracts.first(where: { $0.id == contractId }) else {
            transactions.removeAll { $0.linkedContractId == contractId && $0.transactionOrigin == .plannedAmortization }
            if saveAfter { saveToDisk() }
            return
        }

        guard let pIdx = amortizationPlans.firstIndex(where: { $0.contractId == contractId }) else {
            transactions.removeAll { $0.linkedContractId == contractId && $0.transactionOrigin == .plannedAmortization }
            if saveAfter {
                sortTransactions()
                invalidateDerivedCaches()
                saveToDisk()
            }
            return
        }

        let proj = loanProjection(for: contractId)
        var validPlannedTxIds: Set<UUID> = []

        for iIdx in amortizationPlans[pIdx].items.indices {
            let item = amortizationPlans[pIdx].items[iIdx]
            guard item.status == .pending else {
                continue
            }

            let outcome = proj?.plannedItemOutcomes[item.id]
            let effectiveAmtDecimal = outcome?.effectiveAmortization ?? item.amount
            let effectiveAmtDouble = LoanProjectionEngine.toDouble(effectiveAmtDecimal)
            guard effectiveAmtDouble > 0.001 else {
                continue
            }

            let remainingBalDouble = LoanProjectionEngine.toDouble(outcome?.remainingBalanceAfter ?? .zero)
            let isFullPayoffStep = (outcome?.isFullPayoffStep == true) || (outcome?.remainingBalanceAfter ?? Decimal(1)) <= Decimal(string: "0.01")!
            let txId = item.linkedTransactionId ?? UUID()
            amortizationPlans[pIdx].items[iIdx].linkedTransactionId = txId
            validPlannedTxIds.insert(txId)

            let txTitle: String
            let txDetails: String
            if isFullPayoffStep {
                txTitle = "Amortização Planejada — Liquidação Total (\(item.source.shortTitle)): \(contract.name)"
                txDetails = "Liquidação Total Planejada (Quitação do contrato) • Saldo devedor zerado: R$ 0,00 • \(item.mode.rawValue) \(item.notes)".trimmingCharacters(in: .whitespaces)
            } else {
                txTitle = "Amortização Planejada (\(item.source.shortTitle)): \(contract.name)"
                txDetails = "Planejamento de amortização • Saldo restante projetado: \(AppFormatters.currency(remainingBalDouble)) • \(item.mode.rawValue) \(item.notes)".trimmingCharacters(in: .whitespaces)
            }

            if let existingTxIdx = transactions.firstIndex(where: { $0.id == txId }) {
                transactions[existingTxIdx].name = txTitle
                transactions[existingTxIdx].details = txDetails
                transactions[existingTxIdx].amount = effectiveAmtDouble
                transactions[existingTxIdx].date = item.date
                transactions[existingTxIdx].categoryId = contract.categoryId
                transactions[existingTxIdx].accountId = contract.accountId
                transactions[existingTxIdx].ignoreInConsolidated = false
            } else {
                let newTx = FinancialTransaction(
                    id: txId,
                    name: txTitle,
                    details: txDetails,
                    amount: effectiveAmtDouble,
                    date: item.date,
                    type: .expense,
                    isPaid: false,
                    categoryId: contract.categoryId,
                    accountId: contract.accountId,
                    ignoreInConsolidated: false,
                    recurrenceMode: .single,
                    linkedContractId: contract.id,
                    transactionOrigin: .plannedAmortization,
                    linkedEntityID: item.id
                )
                transactions.append(newTx)
            }
        }

        transactions.removeAll { tx in
            tx.linkedContractId == contractId &&
            tx.transactionOrigin == .plannedAmortization &&
            !validPlannedTxIds.contains(tx.id)
        }

        if saveAfter {
            sortTransactions()
            invalidateDerivedCaches()
            saveToDisk()
        }
    }

    @discardableResult
    public func addPlannedAmortization(
        contractId: UUID,
        date: Date,
        amount: Decimal,
        source: AmortizationFundingSource = .cash,
        mode: AmortizationRecalculationMode = .reduceTerm,
        notes: String = ""
    ) -> PlannedAmortization? {
        guard let contract = contracts.first(where: { $0.id == contractId }), !contract.isSettled else { return nil }
        guard amount > .zero else { return nil }

        let effectiveMode: AmortizationRecalculationMode = contract.kind == .loan ? .reduceTerm : mode
        let todayStart = calendar.startOfDay(for: effectiveCurrentDate)
        let itemDay = calendar.startOfDay(for: date)
        let initialStatus: PlannedAmortizationStatus = itemDay < todayStart ? .expired : .pending

        let newItem = PlannedAmortization(
            contractId: contractId,
            date: date,
            amount: amount,
            source: source,
            mode: effectiveMode,
            status: initialStatus,
            notes: notes
        )

        if let pIdx = amortizationPlans.firstIndex(where: { $0.contractId == contractId }) {
            amortizationPlans[pIdx].items.append(newItem)
            amortizationPlans[pIdx].items.sort { $0.date < $1.date }
            amortizationPlans[pIdx].updatedAt = effectiveCurrentDate
        } else {
            let bestDay = contract.effectiveBankDueDay >= 28 ? 1 : (contract.effectiveBankDueDay + 1)
            let plan = AmortizationPlan(
                contractId: contractId,
                generationMode: .manual,
                billingDay: contract.kind == .loan ? bestDay : contract.billingDay,
                incomeCommitmentPercentage: Decimal(30),
                defaultRecalculationMode: effectiveMode,
                estimatedMonthlyTR: LoanProjectionEngine.toDecimal(contract.estimatedMonthlyTR ?? 0.0),
                items: [newItem],
                updatedAt: effectiveCurrentDate,
                createdAt: effectiveCurrentDate
            )
            amortizationPlans.append(plan)
        }

        syncPlannedAmortizationTransactions(for: contractId)
        if let plan = amortizationPlan(for: contractId) {
            cloudSyncService?.recordLocalMutation(entityName: "amortization_plans", entityId: plan.id, operation: .upsert, entity: plan)
        }
        return newItem
    }

    public func updatePlannedAmortization(
        contractId: UUID,
        itemId: UUID,
        date: Date,
        amount: Decimal,
        source: AmortizationFundingSource,
        mode: AmortizationRecalculationMode,
        notes: String = ""
    ) {
        guard let pIdx = amortizationPlans.firstIndex(where: { $0.contractId == contractId }),
              let iIdx = amortizationPlans[pIdx].items.firstIndex(where: { $0.id == itemId }) else {
            return
        }
        let isLoan = contracts.first(where: { $0.id == contractId })?.kind == .loan
        let todayStart = calendar.startOfDay(for: effectiveCurrentDate)
        let itemDay = calendar.startOfDay(for: date)

        amortizationPlans[pIdx].items[iIdx].date = date
        amortizationPlans[pIdx].items[iIdx].amount = max(.zero, amount)
        amortizationPlans[pIdx].items[iIdx].source = source
        amortizationPlans[pIdx].items[iIdx].mode = isLoan ? .reduceTerm : mode
        if !notes.isEmpty {
            amortizationPlans[pIdx].items[iIdx].notes = notes
        }
        if amortizationPlans[pIdx].items[iIdx].status == .expired && itemDay >= todayStart {
            amortizationPlans[pIdx].items[iIdx].status = .pending
        } else if amortizationPlans[pIdx].items[iIdx].status == .pending && itemDay < todayStart {
            amortizationPlans[pIdx].items[iIdx].status = .expired
        }
        amortizationPlans[pIdx].items.sort { $0.date < $1.date }
        amortizationPlans[pIdx].updatedAt = effectiveCurrentDate

        syncPlannedAmortizationTransactions(for: contractId)
        cloudSyncService?.recordLocalMutation(entityName: "amortization_plans", entityId: amortizationPlans[pIdx].id, operation: .upsert, entity: amortizationPlans[pIdx])
    }

    public func removePlannedAmortization(contractId: UUID, itemId: UUID) {
        guard let pIdx = amortizationPlans.firstIndex(where: { $0.contractId == contractId }) else { return }
        amortizationPlans[pIdx].items.removeAll { $0.id == itemId }
        amortizationPlans[pIdx].updatedAt = effectiveCurrentDate
        syncPlannedAmortizationTransactions(for: contractId)
        cloudSyncService?.recordLocalMutation(entityName: "amortization_plans", entityId: amortizationPlans[pIdx].id, operation: .upsert, entity: amortizationPlans[pIdx])
    }

    public func deleteAmortizationPlan(for contractId: UUID) {
        let deletedPlans = amortizationPlans.filter { $0.contractId == contractId }
        let deletedTxs = transactions.filter { $0.linkedContractId == contractId && $0.transactionOrigin == .plannedAmortization }
        amortizationPlans.removeAll { $0.contractId == contractId }
        transactions.removeAll { $0.linkedContractId == contractId && $0.transactionOrigin == .plannedAmortization }
        sortTransactions()
        invalidateDerivedCaches()
        saveToDisk()
        for plan in deletedPlans {
            cloudSyncService?.recordLocalMutation(entityName: "amortization_plans", entityId: plan.id, operation: .delete)
        }
        for tx in deletedTxs {
            cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: tx.id, operation: .delete)
        }
    }

    public func projectedAvailableMonthlySurplusForAmortization(
        in monthReference: Date,
        excludingContractId: UUID
    ) -> Decimal {
        let monthTxs = transactionsForMonth(monthReference).filter { tx in
            !tx.ignoreInConsolidated &&
            tx.transactionOrigin != .internalTransfer &&
            tx.isCanceledRecurringSeries != true &&
            !(tx.transactionOrigin == .plannedAmortization && tx.linkedContractId == excludingContractId)
        }

        var incomeSum = monthTxs.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
        let expenseSum = monthTxs.filter { $0.type == .expense && !$0.isCreditCardInvoicePayment }.reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
        let provisionsRemaining = isMonthPriorToCurrent(monthReference) ? 0.0 : totalRemainingProvision(for: monthReference)

        if incomeSum <= 0.01 {
            let fallbackIncome = max(
                monthlyIncome(for: selectedMonth),
                monthlyIncome(for: effectiveCurrentDate)
            )
            incomeSum = fallbackIncome
        }

        let netMonthlySurplus = incomeSum - (expenseSum + provisionsRemaining)
        if netMonthlySurplus > 0.01 {
            return LoanProjectionEngine.roundCurrency(LoanProjectionEngine.toDecimal(netMonthlySurplus))
        }

        let currentKpi = buildUnifiedFinancialKPISummary(referenceDate: selectedMonth, isAnnual: false)
        if currentKpi.surplusAfterPlanning > 0.01 {
            return LoanProjectionEngine.roundCurrency(LoanProjectionEngine.toDecimal(currentKpi.surplusAfterPlanning))
        }
        if currentKpi.operationalNetBalance > 0.01 {
            return LoanProjectionEngine.roundCurrency(LoanProjectionEngine.toDecimal(currentKpi.operationalNetBalance))
        }

        return .zero
    }

    @discardableResult
    public func generateAutomaticAmortizationPlan(
        contractId: UUID,
        billingDay: Int,
        incomeCommitmentPercentage: Decimal,
        mode: AmortizationRecalculationMode = .reduceTerm,
        estimatedMonthlyTR: Decimal? = nil,
        fallbackMonthlyBaseSurplus: Decimal? = nil
    ) -> AmortizationPlan? {
        guard let contract = contracts.first(where: { $0.id == contractId }), !contract.isSettled else {
            return nil
        }

        let unpaidInstallments = transactions.filter {
            $0.linkedContractId == contractId &&
            $0.installmentIndex != nil &&
            !$0.isPaid
        }
        let currentRealBal = currentOutstandingBalance(for: contract)
        let effectiveTR = estimatedMonthlyTR ?? amortizationPlan(for: contractId)?.estimatedMonthlyTR ?? LoanProjectionEngine.toDecimal(contract.estimatedMonthlyTR ?? 0.0)
        let effectiveMode: AmortizationRecalculationMode = contract.kind == .loan ? .reduceTerm : mode

        let generatedItems = LoanProjectionEngine.generateAutomaticPlanItems(
            contract: contract,
            unpaidInstallmentTransactions: unpaidInstallments,
            currentRealBalanceDouble: currentRealBal,
            billingDay: billingDay,
            incomeCommitmentPercentage: incomeCommitmentPercentage,
            mode: effectiveMode,
            estimatedMonthlyTR: effectiveTR,
            referenceNow: effectiveCurrentDate,
            monthlyAvailableSurplusProvider: { [weak self] targetMonth in
                guard let self else { return fallbackMonthlyBaseSurplus ?? .zero }
                let computed = self.projectedAvailableMonthlySurplusForAmortization(in: targetMonth, excludingContractId: contractId)
                if computed > .zero {
                    return computed
                }
                return fallbackMonthlyBaseSurplus ?? .zero
            },
            calendar: calendar
        )

        let executedItems = amortizationPlan(for: contractId)?.items.filter { $0.status == .executed } ?? []
        let allItems = (executedItems + generatedItems).sorted { $0.date < $1.date }

        let updatedPlan = AmortizationPlan(
            id: amortizationPlan(for: contractId)?.id ?? UUID(),
            contractId: contractId,
            generationMode: .automatic,
            billingDay: billingDay,
            incomeCommitmentPercentage: incomeCommitmentPercentage,
            defaultRecalculationMode: effectiveMode,
            estimatedMonthlyTR: effectiveTR,
            items: allItems,
            updatedAt: effectiveCurrentDate,
            createdAt: amortizationPlan(for: contractId)?.createdAt ?? effectiveCurrentDate
        )

        if let pIdx = amortizationPlans.firstIndex(where: { $0.contractId == contractId }) {
            amortizationPlans[pIdx] = updatedPlan
        } else {
            amortizationPlans.append(updatedPlan)
        }

        syncPlannedAmortizationTransactions(for: contractId)
        cloudSyncService?.recordLocalMutation(entityName: "amortization_plans", entityId: updatedPlan.id, operation: .upsert, entity: updatedPlan)
        return updatedPlan
    }

    @discardableResult
    public func confirmPlannedAmortizationPayment(
        contractId: UUID,
        itemId: UUID,
        accountId: UUID? = nil,
        paymentDate: Date? = nil
    ) -> Bool {
        guard let contractIdx = contracts.firstIndex(where: { $0.id == contractId }),
              let pIdx = amortizationPlans.firstIndex(where: { $0.contractId == contractId }),
              let iIdx = amortizationPlans[pIdx].items.firstIndex(where: { $0.id == itemId }) else {
            return false
        }

        let item = amortizationPlans[pIdx].items[iIdx]
        guard item.status == .pending || item.status == .expired else { return false }

        let contract = contracts[contractIdx]
        let proj = loanProjection(for: contractId)
        let effectiveAmountDec = proj?.plannedItemOutcomes[item.id]?.effectiveAmortization ?? item.amount
        let amountToPay = max(0.01, LoanProjectionEngine.toDouble(effectiveAmountDec > .zero ? effectiveAmountDec : item.amount))
        let targetAccountId = accountId ?? contract.accountId
        let effectiveDate = paymentDate ?? item.date

        amortizationPlans[pIdx].items[iIdx].status = .executed
        amortizationPlans[pIdx].items[iIdx].date = effectiveDate
        amortizationPlans[pIdx].updatedAt = effectiveCurrentDate

        if item.source == .fgts {
            contracts[contractIdx].lastFGTSUsageDate = effectiveDate
        }

        if let provisionalTxId = item.linkedTransactionId {
            transactions.removeAll { $0.id == provisionalTxId }
        }
        transactions.removeAll {
            $0.transactionOrigin == .plannedAmortization && $0.linkedEntityID == item.id
        }

        let sourceTag = item.source == .fgts ? " [FGTS]" : ""
        amortizeContract(
            contractId: contractId,
            amountPaid: amountToPay,
            accountId: targetAccountId,
            date: effectiveDate,
            mode: contract.kind == .loan ? .reduceTerm : item.mode,
            proRataInterest: 0.0,
            notes: ("Amortização planejada confirmada\(sourceTag). " + item.notes).trimmingCharacters(in: .whitespaces)
        )

        if contracts[contractIdx].isSettled {
            for idx in amortizationPlans[pIdx].items.indices where amortizationPlans[pIdx].items[idx].status == .pending {
                amortizationPlans[pIdx].items[idx].status = .skipped
            }
        }

        syncPlannedAmortizationTransactions(for: contractId)
        cloudSyncService?.recordLocalMutation(entityName: "amortization_plans", entityId: amortizationPlans[pIdx].id, operation: .upsert, entity: amortizationPlans[pIdx])
        return true
    }

    @discardableResult
    public func confirmPlannedAmortizationByTransactionId(_ transactionId: UUID, paymentDate: Date? = nil) -> Bool {
        for plan in amortizationPlans {
            if let item = plan.items.first(where: { $0.linkedTransactionId == transactionId }) {
                return confirmPlannedAmortizationPayment(
                    contractId: plan.contractId,
                    itemId: item.id,
                    paymentDate: paymentDate
                )
            }
        }
        if let tx = transactions.first(where: { $0.id == transactionId && $0.transactionOrigin == .plannedAmortization }),
           let contractId = tx.linkedContractId,
           let itemId = tx.linkedEntityID {
            return confirmPlannedAmortizationPayment(
                contractId: contractId,
                itemId: itemId,
                paymentDate: paymentDate
            )
        }
        return false
    }

    public func rescheduleExpiredAmortization(contractId: UUID, itemId: UUID, newDate: Date) {
        guard let pIdx = amortizationPlans.firstIndex(where: { $0.contractId == contractId }),
              let iIdx = amortizationPlans[pIdx].items.firstIndex(where: { $0.id == itemId }) else {
            return
        }
        let todayStart = calendar.startOfDay(for: effectiveCurrentDate)
        let targetDate = calendar.startOfDay(for: newDate) < todayStart ? effectiveCurrentDate : newDate
        amortizationPlans[pIdx].items[iIdx].date = targetDate
        amortizationPlans[pIdx].items[iIdx].status = .pending
        amortizationPlans[pIdx].items.sort { $0.date < $1.date }
        amortizationPlans[pIdx].updatedAt = effectiveCurrentDate
        syncPlannedAmortizationTransactions(for: contractId)
        cloudSyncService?.recordLocalMutation(entityName: "amortization_plans", entityId: amortizationPlans[pIdx].id, operation: .upsert, entity: amortizationPlans[pIdx])
    }

    public func skipExpiredAmortization(contractId: UUID, itemId: UUID) {
        guard let pIdx = amortizationPlans.firstIndex(where: { $0.contractId == contractId }),
              let iIdx = amortizationPlans[pIdx].items.firstIndex(where: { $0.id == itemId }) else {
            return
        }
        amortizationPlans[pIdx].items[iIdx].status = .skipped
        amortizationPlans[pIdx].updatedAt = effectiveCurrentDate
        syncPlannedAmortizationTransactions(for: contractId)
        cloudSyncService?.recordLocalMutation(entityName: "amortization_plans", entityId: amortizationPlans[pIdx].id, operation: .upsert, entity: amortizationPlans[pIdx])
    }

    // MARK: - CRUD: Provisões e Cotas de Categorias

    public func createProvision(
        categoryId: UUID,
        year: Int,
        month: Int,
        estimatedAmount: Double,
        repeatForFutureMonths: Bool = true
    ) {
        let prov = CategoryProvision(
            categoryId: categoryId,
            year: year,
            month: month,
            estimatedAmount: estimatedAmount,
            repeatForFutureMonths: repeatForFutureMonths
        )
        provisions.append(prov)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: prov.id, operation: .upsert, entity: prov)
    }

    public func updateProvision(_ provision: CategoryProvision) {
        if let idx = provisions.firstIndex(where: { $0.id == provision.id }) {
            provisions[idx] = provision
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: provision.id, operation: .upsert, entity: provision)
        }
    }

    public func deleteProvision(_ provisionId: UUID) {
        provisions.removeAll { $0.id == provisionId }
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: provisionId, operation: .delete)
    }

    public func provisionEnvelopes(for monthReference: Date) -> [CategoryProvisionEnvelope] {
        let year = calendar.component(.year, from: monthReference)
        let month = calendar.component(.month, from: monthReference)
        let ymKey = year * 100 + month

        // Group provisions by categoryId to guarantee exactly one active envelope per category
        let grouped = Dictionary(grouping: provisions, by: { $0.categoryId })
        var result: [CategoryProvisionEnvelope] = []

        for (catId, catProvs) in grouped {
            guard let cat = category(for: catId) else { continue }

            var activeProvision: CategoryProvision? = nil
            var isInherited = false

            // 1. Exact match for this specific month
            if let exact = catProvs.first(where: { $0.yearMonthKey == ymKey }) {
                if !(exact.excludedYearMonthKeys?.contains(ymKey) ?? false) {
                    activeProvision = exact
                    isInherited = false
                }
            } else {
                // 2. Most recent provision from an earlier month that repeats for future months
                let applicable = catProvs
                    .filter { prov in
                        prov.yearMonthKey < ymKey &&
                        prov.repeatForFutureMonths &&
                        !(prov.excludedYearMonthKeys?.contains(ymKey) ?? false)
                    }
                    .max(by: { $0.yearMonthKey < $1.yearMonthKey })

                if let prov = applicable {
                    activeProvision = prov
                    isInherited = true
                }
            }

            guard let prov = activeProvision else { continue }

            let overrideAmount = prov.monthlyOverrides?[ymKey]
            let estimated = overrideAmount ?? prov.estimatedAmount
            guard estimated > 0 else { continue }
            let realized = transactionsForMonth(monthReference)
                .filter { $0.categoryId == catId && $0.type == .expense && $0.linkedQuotaId == nil && !$0.isCreditCardInvoicePayment }
                .reduce(0.0) { $0 + $1.amount }

            let env = CategoryProvisionEnvelope(
                category: cat,
                provision: prov,
                isInheritedFromPreviousMonth: isInherited,
                estimatedAmount: estimated,
                realizedExpense: realized,
                isFreeBudgetLocalOverride: overrideAmount != nil
            )
            result.append(env)
        }
        return result.sorted { $0.category.name < $1.category.name }
    }

    public func totalCategoryProvisionsRemaining(for monthReference: Date, referenceNow: Date? = nil) -> Double {
        if isMonthPriorToCurrent(monthReference, referenceNow: referenceNow) {
            return 0.0
        }
        return provisionEnvelopes(for: monthReference).reduce(0.0) { $0 + $1.remainingProvision }
    }

    /// Exclui a Verba Livre de uma categoria respeitando o escopo temporal:
    /// - `.onlyThisMonth`: remove apenas do mês corrente (a regra recorrente continua nos meses anteriores e reaparece nos futuros).
    /// - `.fromThisMonthOnward`: remove do mês informado em diante, mantendo o histórico dos meses passados.
    /// - `.allOccurrences`: remove o registro e interrompe a recorrência definitivamente para frente e para trás.
    public func deleteCategoryProvision(
        categoryId: UUID,
        for monthReference: Date,
        scope: ProvisionDeleteScope = .allOccurrences
    ) {
        let year = calendar.component(.year, from: monthReference)
        let month = calendar.component(.month, from: monthReference)
        let targetKey = year * 100 + month

        switch scope {
        case .allOccurrences:
            let toDelete = provisions.filter { $0.categoryId == categoryId }
            provisions.removeAll { $0.categoryId == categoryId }
            for p in toDelete {
                cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: p.id, operation: .delete)
            }
        case .onlyThisMonth:
            let candidates = provisions
                .enumerated()
                .filter { $0.element.categoryId == categoryId && $0.element.yearMonthKey <= targetKey }
                .sorted { a, b in
                    if a.element.yearMonthKey == b.element.yearMonthKey {
                        return a.element.createdAt < b.element.createdAt
                    }
                    return a.element.yearMonthKey < b.element.yearMonthKey
                }
            if let latest = candidates.last {
                let idx = latest.offset
                if provisions[idx].repeatForFutureMonths {
                    var excluded = provisions[idx].excludedYearMonthKeys ?? []
                    excluded.insert(targetKey)
                    provisions[idx].excludedYearMonthKeys = excluded
                    provisions[idx].monthlyOverrides?.removeValue(forKey: targetKey)
                    let prov = provisions[idx]
                    cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: prov.id, operation: .upsert, entity: prov)
                } else if provisions[idx].yearMonthKey == targetKey {
                    let deletedId = provisions[idx].id
                    provisions.remove(at: idx)
                    cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: deletedId, operation: .delete)
                }
            }
        case .fromThisMonthOnward:
            let removedProvs = provisions.filter { $0.categoryId == categoryId && $0.yearMonthKey > targetKey }
            provisions.removeAll { $0.categoryId == categoryId && $0.yearMonthKey > targetKey }
            for removed in removedProvs {
                cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: removed.id, operation: .delete)
            }
            for idx in provisions.indices where provisions[idx].categoryId == categoryId {
                var changed = false
                if var overrides = provisions[idx].monthlyOverrides {
                    let filtered = overrides.filter { $0.key < targetKey }
                    if filtered != overrides {
                        provisions[idx].monthlyOverrides = filtered.isEmpty ? nil : filtered
                        changed = true
                    }
                }
                if var excluded = provisions[idx].excludedYearMonthKeys {
                    let filtered = excluded.filter { $0 < targetKey }
                    if filtered != excluded {
                        provisions[idx].excludedYearMonthKeys = filtered.isEmpty ? nil : filtered
                        changed = true
                    }
                }
                if changed {
                    let prov = provisions[idx]
                    cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: prov.id, operation: .upsert, entity: prov)
                }
            }

            let hasPriorRecurring = provisions.contains {
                $0.categoryId == categoryId &&
                $0.yearMonthKey < targetKey &&
                $0.repeatForFutureMonths &&
                $0.estimatedAmount > 0
            }

            if let exactIdx = provisions.firstIndex(where: {
                $0.categoryId == categoryId && $0.year == year && $0.month == month
            }) {
                if hasPriorRecurring {
                    provisions[exactIdx].estimatedAmount = 0
                    provisions[exactIdx].repeatForFutureMonths = true
                    let prov = provisions[exactIdx]
                    cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: prov.id, operation: .upsert, entity: prov)
                } else {
                    let deletedId = provisions[exactIdx].id
                    provisions.remove(at: exactIdx)
                    cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: deletedId, operation: .delete)
                }
            } else if hasPriorRecurring {
                let stopper = CategoryProvision(
                    categoryId: categoryId,
                    year: year,
                    month: month,
                    estimatedAmount: 0,
                    repeatForFutureMonths: true
                )
                provisions.append(stopper)
                cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: stopper.id, operation: .upsert, entity: stopper)
            }
        }

        saveToDisk()
    }

    public func createCategoryQuotaRule(
        categoryId: UUID,
        name: String,
        iconSymbol: String = "shippingbox.fill",
        year: Int,
        month: Int,
        plannedQuantity: Int,
        estimatedUnitPrice: Double,
        repeatForFutureMonths: Bool = true,
        quotaType: QuotaType = .expense,
        linkedInvestmentId: UUID? = nil
    ) {
        let quota = CategoryQuotaRule(
            categoryId: categoryId,
            name: name,
            iconSymbol: iconSymbol,
            year: year,
            month: month,
            plannedQuantity: plannedQuantity,
            estimatedUnitPrice: estimatedUnitPrice,
            repeatForFutureMonths: repeatForFutureMonths,
            quotaType: quotaType,
            linkedInvestmentId: linkedInvestmentId
        )
        categoryQuotas.append(quota)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: quota.id, operation: .upsert, entity: quota)
    }

    public func updateCategoryQuotaRule(_ quota: CategoryQuotaRule) {
        if let idx = categoryQuotas.firstIndex(where: { $0.id == quota.id }) {
            categoryQuotas[idx] = quota
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: quota.id, operation: .upsert, entity: quota)
        }
    }

    public func deleteCategoryQuotaRule(_ quotaId: UUID) {
        categoryQuotas.removeAll { $0.id == quotaId }
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: quotaId, operation: .delete)
    }

    public func categoryQuotaEnvelopes(for monthReference: Date) -> [CategoryQuotaEnvelope] {
        let year = calendar.component(.year, from: monthReference)
        let month = calendar.component(.month, from: monthReference)
        let ymKey = year * 100 + month

        // Group quotas by seriesId to guarantee exactly one active envelope per quota series
        let grouped = Dictionary(grouping: categoryQuotas, by: { $0.seriesId })
        var result: [CategoryQuotaEnvelope] = []

        for (_, seriesRules) in grouped {
            var activeRule: CategoryQuotaRule? = nil
            var isInherited = false

            // 1. Exact match for this month
            if let exact = seriesRules.first(where: { $0.yearMonthKey == ymKey }) {
                if !(exact.excludedYearMonthKeys?.contains(ymKey) ?? false) {
                    activeRule = exact
                    isInherited = false
                }
            } else {
                // 2. Most recent rule from an earlier month that repeats for future months
                let applicable = seriesRules
                    .filter { rule in
                        rule.yearMonthKey < ymKey &&
                        rule.repeatForFutureMonths &&
                        !(rule.excludedYearMonthKeys?.contains(ymKey) ?? false)
                    }
                    .max(by: { $0.yearMonthKey < $1.yearMonthKey })

                if let rule = applicable {
                    activeRule = rule
                    isInherited = true
                }
            }

            guard let rule = activeRule else { continue }

            let override = rule.monthlyOverrides?[ymKey]
            let planned = override?.plannedQuantity ?? rule.plannedQuantity
            let unitPrice = override?.estimatedUnitPrice ?? rule.estimatedUnitPrice
            guard planned > 0 && unitPrice > 0 else { continue }
            let ruleName = override?.name ?? rule.name

            let linkedTxs = transactionsForMonth(monthReference).filter { tx in
                if tx.linkedQuotaId == rule.id || tx.linkedQuotaId == rule.seriesId {
                    return true
                }
                if rule.quotaType == .investment, let linkedInvId = rule.linkedInvestmentId {
                    return tx.linkedInvestmentId == linkedInvId && tx.transactionOrigin == .investmentDeposit
                }
                return false
            }
            let consumed = linkedTxs.reduce(0) { $0 + ($1.linkedQuotaUnits ?? 1) }
            let realized = linkedTxs.reduce(0.0) { $0 + $1.amount }

            let env = CategoryQuotaEnvelope(
                rule: rule,
                name: ruleName,
                iconSymbol: rule.iconSymbol,
                plannedQuantity: planned,
                consumedUnits: consumed,
                estimatedUnitPrice: unitPrice,
                realizedExpense: realized,
                repeatForFutureMonths: rule.repeatForFutureMonths,
                isInheritedFromPreviousMonth: isInherited,
                isLocalMonthOverride: override != nil
            )
            result.append(env)
        }
        return result.sorted { $0.name < $1.name }
    }

    public func totalQuotasRemaining(for monthReference: Date, referenceNow: Date? = nil) -> Double {
        if isMonthPriorToCurrent(monthReference, referenceNow: referenceNow) {
            return 0.0
        }
        return categoryQuotaEnvelopes(for: monthReference).reduce(0.0) { $0 + $1.remainingProvision }
    }

    public func totalRemainingProvision(for monthReference: Date, referenceNow: Date? = nil) -> Double {
        if isMonthPriorToCurrent(monthReference, referenceNow: referenceNow) {
            return 0.0
        }
        return totalCategoryProvisionsRemaining(for: monthReference, referenceNow: referenceNow) + totalQuotasRemaining(for: monthReference, referenceNow: referenceNow)
    }

    public func accumulatedRemainingProvisions(
        throughMonth monthReference: Date,
        referenceNow: Date? = nil
    ) -> Double {
        let now = referenceNow ?? effectiveCurrentDate
        let currentMonthStart = startOfMonth(for: now)
        let targetMonthStart = startOfMonth(for: monthReference)

        if targetMonthStart < currentMonthStart {
            return 0.0
        }

        var total = 0.0
        var cursor = currentMonthStart
        while cursor <= targetMonthStart {
            total += totalRemainingProvision(for: cursor, referenceNow: now)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: cursor) else {
                break
            }
            cursor = nextMonth
        }
        return total
    }

    /// Exclui uma Cota de Item Específico respeitando o escopo temporal:
    /// - `.onlyThisMonth`: remove do mês corrente; continua nos meses anteriores e reaparece nos futuros.
    /// - `.fromThisMonthOnward`: encerra a cota daquele mês em diante, preservando o histórico dos meses anteriores.
    /// - `.allOccurrences`: remove o registro e interrompe a recorrência definitivamente para frente e para trás.
    public func deleteCategoryQuota(
        seriesId: UUID,
        for monthReference: Date,
        scope: ProvisionDeleteScope
    ) {
        let year = calendar.component(.year, from: monthReference)
        let month = calendar.component(.month, from: monthReference)
        let targetKey = year * 100 + month

        switch scope {
        case .allOccurrences:
            let toDelete = categoryQuotas.filter { $0.seriesId == seriesId }
            categoryQuotas.removeAll { $0.seriesId == seriesId }
            for r in toDelete {
                cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: r.id, operation: .delete)
            }
        case .onlyThisMonth:
            let candidates = categoryQuotas
                .enumerated()
                .filter { $0.element.seriesId == seriesId && $0.element.yearMonthKey <= targetKey }
                .sorted { a, b in
                    if a.element.yearMonthKey == b.element.yearMonthKey {
                        return a.element.createdAt < b.element.createdAt
                    }
                    return a.element.yearMonthKey < b.element.yearMonthKey
                }
            if let latest = candidates.last {
                let idx = latest.offset
                if categoryQuotas[idx].repeatForFutureMonths {
                    var excluded = categoryQuotas[idx].excludedYearMonthKeys ?? []
                    excluded.insert(targetKey)
                    categoryQuotas[idx].excludedYearMonthKeys = excluded
                    categoryQuotas[idx].monthlyOverrides?.removeValue(forKey: targetKey)
                    let rule = categoryQuotas[idx]
                    cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: rule.id, operation: .upsert, entity: rule)
                } else if categoryQuotas[idx].yearMonthKey == targetKey {
                    let deletedId = categoryQuotas[idx].id
                    categoryQuotas.remove(at: idx)
                    cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: deletedId, operation: .delete)
                }
            }
        case .fromThisMonthOnward:
            let removedRules = categoryQuotas.filter { $0.seriesId == seriesId && $0.yearMonthKey > targetKey }
            categoryQuotas.removeAll { $0.seriesId == seriesId && $0.yearMonthKey > targetKey }
            for removed in removedRules {
                cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: removed.id, operation: .delete)
            }
            for idx in categoryQuotas.indices where categoryQuotas[idx].seriesId == seriesId {
                var changed = false
                if let overrides = categoryQuotas[idx].monthlyOverrides {
                    let filtered = overrides.filter { $0.key < targetKey }
                    if filtered != overrides {
                        categoryQuotas[idx].monthlyOverrides = filtered.isEmpty ? nil : filtered
                        changed = true
                    }
                }
                if let excluded = categoryQuotas[idx].excludedYearMonthKeys {
                    let filtered = excluded.filter { $0 < targetKey }
                    if filtered != excluded {
                        categoryQuotas[idx].excludedYearMonthKeys = filtered.isEmpty ? nil : filtered
                        changed = true
                    }
                }
                if changed {
                    let rule = categoryQuotas[idx]
                    cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: rule.id, operation: .upsert, entity: rule)
                }
            }

            let hasPriorRecurring = categoryQuotas.contains {
                $0.seriesId == seriesId &&
                $0.yearMonthKey < targetKey &&
                $0.repeatForFutureMonths &&
                $0.plannedQuantity > 0 &&
                $0.estimatedUnitPrice > 0
            }

            if let exactIdx = categoryQuotas.firstIndex(where: {
                $0.seriesId == seriesId && $0.year == year && $0.month == month
            }) {
                if hasPriorRecurring {
                    categoryQuotas[exactIdx].plannedQuantity = 0
                    categoryQuotas[exactIdx].estimatedUnitPrice = 0
                    categoryQuotas[exactIdx].repeatForFutureMonths = true
                    let rule = categoryQuotas[exactIdx]
                    cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: rule.id, operation: .upsert, entity: rule)
                } else {
                    let deletedId = categoryQuotas[exactIdx].id
                    categoryQuotas.remove(at: exactIdx)
                    cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: deletedId, operation: .delete)
                }
            } else if hasPriorRecurring {
                let template = categoryQuotas.first(where: { $0.seriesId == seriesId })
                let stopper = CategoryQuotaRule(
                    seriesId: seriesId,
                    categoryId: template?.categoryId ?? UUID(),
                    name: template?.name ?? "Cota Encerrada",
                    iconSymbol: template?.iconSymbol ?? "xmark.circle",
                    year: year,
                    month: month,
                    plannedQuantity: 0,
                    estimatedUnitPrice: 0,
                    repeatForFutureMonths: true,
                    quotaType: template?.quotaType ?? .expense,
                    linkedInvestmentId: template?.linkedInvestmentId
                )
                categoryQuotas.append(stopper)
                cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: stopper.id, operation: .upsert, entity: stopper)
            }
        }

        saveToDisk()
    }

    /// Cria ou atualiza uma Cota de Item Específico com suporte a escopo temporal e sincronização
    @discardableResult
    public func saveCategoryQuota(
        seriesId: UUID? = nil,
        categoryId: UUID,
        name: String,
        iconSymbol: String? = nil,
        plannedQuantity: Int,
        estimatedUnitPrice: Double,
        for monthReference: Date,
        repeatForFutureMonths: Bool,
        editScope: ProvisionEditScope = .thisAndFutureMonths,
        quotaType: QuotaType = .expense,
        linkedInvestmentId: UUID? = nil
    ) -> CategoryQuotaRule {
        let year = calendar.component(.year, from: monthReference)
        let month = calendar.component(.month, from: monthReference)
        let targetKey = year * 100 + month
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanQty = max(1, plannedQuantity)
        let cleanPrice = max(0.0, estimatedUnitPrice)
        let resolvedIcon: String = {
            if let iconSymbol = iconSymbol, !iconSymbol.isEmpty { return iconSymbol }
            if quotaType == .investment, let invId = linkedInvestmentId, let inv = investments.first(where: { $0.id == invId }) {
                return inv.iconSymbol
            }
            return "shippingbox.fill"
        }()

        if let existingSeriesId = seriesId,
           categoryQuotas.contains(where: { $0.seriesId == existingSeriesId }) {
            if editScope == .onlyThisMonth {
                let candidates = categoryQuotas
                    .enumerated()
                    .filter { $0.element.seriesId == existingSeriesId && $0.element.yearMonthKey <= targetKey }
                    .sorted { a, b in
                        if a.element.yearMonthKey == b.element.yearMonthKey {
                            return a.element.createdAt < b.element.createdAt
                        }
                        return a.element.yearMonthKey < b.element.yearMonthKey
                    }

                if let latest = candidates.last {
                    let idx = latest.offset
                    if categoryQuotas[idx].yearMonthKey == targetKey && !categoryQuotas[idx].repeatForFutureMonths {
                        categoryQuotas[idx].name = cleanName
                        categoryQuotas[idx].iconSymbol = resolvedIcon
                        categoryQuotas[idx].plannedQuantity = cleanQty
                        categoryQuotas[idx].estimatedUnitPrice = cleanPrice
                        categoryQuotas[idx].quotaType = quotaType
                        categoryQuotas[idx].linkedInvestmentId = linkedInvestmentId
                    } else {
                        var overrides = categoryQuotas[idx].monthlyOverrides ?? [:]
                        overrides[targetKey] = CategoryQuotaMonthlyOverride(
                            name: cleanName,
                            plannedQuantity: cleanQty,
                            estimatedUnitPrice: cleanPrice
                        )
                        categoryQuotas[idx].monthlyOverrides = overrides
                        categoryQuotas[idx].excludedYearMonthKeys?.remove(targetKey)
                    }
                    saveToDisk()
                    let rule = categoryQuotas[idx]
                    cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: rule.id, operation: .upsert, entity: rule)
                    return rule
                }
            }

            // Escopo: .thisAndFutureMonths
            let removedRules = categoryQuotas.filter { $0.seriesId == existingSeriesId && $0.yearMonthKey > targetKey }
            categoryQuotas.removeAll { $0.seriesId == existingSeriesId && $0.yearMonthKey > targetKey }
            for removed in removedRules {
                cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: removed.id, operation: .delete)
            }
            for idx in categoryQuotas.indices where categoryQuotas[idx].seriesId == existingSeriesId {
                var changed = false
                if let overrides = categoryQuotas[idx].monthlyOverrides {
                    let filtered = overrides.filter { $0.key < targetKey }
                    if filtered != overrides {
                        categoryQuotas[idx].monthlyOverrides = filtered.isEmpty ? nil : filtered
                        changed = true
                    }
                }
                if let excluded = categoryQuotas[idx].excludedYearMonthKeys {
                    let filtered = excluded.filter { $0 < targetKey }
                    if filtered != excluded {
                        categoryQuotas[idx].excludedYearMonthKeys = filtered.isEmpty ? nil : filtered
                        changed = true
                    }
                }
                if changed {
                    let rule = categoryQuotas[idx]
                    cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: rule.id, operation: .upsert, entity: rule)
                }
            }

            if let exactIdx = categoryQuotas.firstIndex(where: {
                $0.seriesId == existingSeriesId && $0.year == year && $0.month == month
            }) {
                categoryQuotas[exactIdx].name = cleanName
                categoryQuotas[exactIdx].iconSymbol = resolvedIcon
                categoryQuotas[exactIdx].plannedQuantity = cleanQty
                categoryQuotas[exactIdx].estimatedUnitPrice = cleanPrice
                categoryQuotas[exactIdx].repeatForFutureMonths = repeatForFutureMonths
                categoryQuotas[exactIdx].quotaType = quotaType
                categoryQuotas[exactIdx].linkedInvestmentId = linkedInvestmentId
                saveToDisk()
                let rule = categoryQuotas[exactIdx]
                cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: rule.id, operation: .upsert, entity: rule)
                return rule
            } else {
                let updatedFutureRule = CategoryQuotaRule(
                    seriesId: existingSeriesId,
                    categoryId: categoryId,
                    name: cleanName,
                    iconSymbol: resolvedIcon,
                    year: year,
                    month: month,
                    plannedQuantity: cleanQty,
                    estimatedUnitPrice: cleanPrice,
                    repeatForFutureMonths: repeatForFutureMonths,
                    quotaType: quotaType,
                    linkedInvestmentId: linkedInvestmentId
                )
                categoryQuotas.append(updatedFutureRule)
                saveToDisk()
                cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: updatedFutureRule.id, operation: .upsert, entity: updatedFutureRule)
                return updatedFutureRule
            }
        }

        let newRule = CategoryQuotaRule(
            seriesId: seriesId,
            categoryId: categoryId,
            name: cleanName,
            iconSymbol: resolvedIcon,
            year: year,
            month: month,
            plannedQuantity: cleanQty,
            estimatedUnitPrice: cleanPrice,
            repeatForFutureMonths: repeatForFutureMonths,
            quotaType: quotaType,
            linkedInvestmentId: linkedInvestmentId
        )
        categoryQuotas.append(newRule)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: newRule.id, operation: .upsert, entity: newRule)
        return newRule
    }

    public func calculateQuotaEnvelopes(for month: Date) -> [CategoryQuotaEnvelope] {
        categoryQuotaEnvelopes(for: month)
    }

    public func allQuotaEnvelopes(for monthReference: Date) -> [CategoryQuotaEnvelope] {
        categoryQuotaEnvelopes(for: monthReference)
    }

    public func totalEstimatedProvision(for monthReference: Date) -> Double {
        let quotasEstimated = categoryQuotaEnvelopes(for: monthReference).reduce(0.0) { $0 + $1.totalEstimatedAmount }
        let categoriesEstimated = provisionEnvelopes(for: monthReference).reduce(0.0) { $0 + $1.estimatedAmount }
        return quotasEstimated + categoriesEstimated
    }

    public func ensureRecurringTransactionsMaterialized(upTo targetDate: Date) {
        let recurringTxs = transactions.filter { $0.recurrenceMode == .recurring && $0.seriesGroupId != nil }
        guard !recurringTxs.isEmpty else { return }

        let grouped = Dictionary(grouping: recurringTxs, by: { $0.seriesGroupId! })
        var didAppend = false

        for (groupId, items) in grouped {
            guard !items.contains(where: { $0.isCanceledRecurringSeries == true }) else { continue }
            guard let lastTx = items.max(by: { $0.date < $1.date }) else { continue }
            let freq = lastTx.recurrenceFrequency ?? .monthly
            var currentLastDate = lastTx.date
            var currentIndex = (lastTx.installmentIndex ?? items.count)

            while currentLastDate < targetDate {
                let nextDate = freq.nextDate(from: currentLastDate, occurrenceIndex: 1, calendar: calendar)
                if nextDate <= currentLastDate { break }
                currentIndex += 1
                let newTx = FinancialTransaction(
                    name: lastTx.name,
                    details: lastTx.details,
                    amount: lastTx.amount,
                    date: nextDate,
                    type: lastTx.type,
                    isPaid: false,
                    categoryId: lastTx.categoryId,
                    accountId: lastTx.accountId,
                    attachmentPath: lastTx.attachmentPath,
                    attachmentName: lastTx.attachmentName,
                    ignoreInConsolidated: lastTx.ignoreInConsolidated,
                    recurrenceMode: .recurring,
                    recurrenceFrequency: freq,
                    isCanceledRecurringSeries: false,
                    seriesGroupId: groupId,
                    installmentIndex: currentIndex,
                    installmentTotal: nil
                )
                transactions.append(newTx)
                currentLastDate = nextDate
                didAppend = true
            }
        }

        if didAppend {
            sortTransactions()
            saveToDisk()
        }
    }

    public func createQuota(
        categoryId: UUID,
        name: String,
        iconSymbol: String = "shippingbox.fill",
        year: Int,
        month: Int,
        quantity: Int,
        unitPrice: Double,
        repeatForFuture: Bool = true,
        quotaType: QuotaType = .expense,
        linkedInvestmentId: UUID? = nil
    ) {
        createCategoryQuotaRule(
            categoryId: categoryId,
            name: name,
            iconSymbol: iconSymbol,
            year: year,
            month: month,
            plannedQuantity: quantity,
            estimatedUnitPrice: unitPrice,
            repeatForFutureMonths: repeatForFuture,
            quotaType: quotaType,
            linkedInvestmentId: linkedInvestmentId
        )
    }

    public func redeemQuotaUnits(
        quotaId: UUID,
        units: Int,
        accountId: UUID,
        date: Date = Date(),
        unitPriceOverride: Double? = nil
    ) {
        guard let rule = categoryQuotas.first(where: { $0.id == quotaId || $0.seriesId == quotaId }) else { return }
        let effectivePrice = max(0.0, unitPriceOverride ?? rule.estimatedUnitPrice)
        let totalAmount = Double(units) * effectivePrice
        let isInvestment = rule.quotaType == .investment
        let catId: UUID = {
            if isInvestment {
                return investmentDepositCategoryId()
            }
            return rule.categoryId
        }()
        let txOrigin: TransactionOrigin = isInvestment ? .investmentDeposit : .quotaAllocation
        let txTitle = isInvestment ? "Aporte: \(rule.name)" : "\(rule.name) (\(units) un.)"
        let txDetails = isInvestment ? "Aporte via planejamento de investimento" : "Baixa de cota"

        let tx = createTransaction(
            name: txTitle,
            details: txDetails,
            amount: totalAmount,
            date: date,
            type: .expense,
            isPaid: true,
            categoryId: catId,
            accountId: accountId,
            linkedInvestmentId: isInvestment ? rule.linkedInvestmentId : nil,
            linkedQuotaId: rule.seriesId,
            linkedQuotaUnits: units,
            linkedQuotaYearMonthKey: rule.yearMonthKey,
            transactionOrigin: txOrigin,
            linkedEntityID: isInvestment ? rule.linkedInvestmentId : nil
        )

        if isInvestment, let invId = rule.linkedInvestmentId, let idx = investments.firstIndex(where: { $0.id == invId }) {
            investments[idx].balance += totalAmount
            let mov = InvestmentMovement(
                type: .deposit,
                amount: totalAmount,
                date: date,
                sourceAccountId: accountId,
                investmentAccountId: investments[idx].investmentAccountId,
                notes: txDetails,
                generatedTransactionId: tx.id
            )
            investments[idx].movements.insert(mov, at: 0)
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: invId, operation: .upsert, entity: investments[idx])
        }
    }

    public func calculateProvisionEnvelopes(for month: Date) -> [CategoryProvisionEnvelope] {
        provisionEnvelopes(for: month)
    }

    public func setProvision(
        categoryId: UUID,
        year: Int,
        month: Int,
        amount: Double,
        repeatForFuture: Bool = true
    ) {
        if let idx = provisions.firstIndex(where: { $0.categoryId == categoryId && $0.year == year && $0.month == month }) {
            provisions[idx].estimatedAmount = amount
            provisions[idx].repeatForFutureMonths = repeatForFuture
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: provisions[idx].id, operation: .upsert, entity: provisions[idx])
        } else {
            createProvision(
                categoryId: categoryId,
                year: year,
                month: month,
                estimatedAmount: amount,
                repeatForFutureMonths: repeatForFuture
            )
        }
    }

    // MARK: - Balances, Monthly & Annual Aggregations

    public func transactions(for date: Date) -> [FinancialTransaction] {
        transactionsForMonth(date)
    }

    public func transactionsForMonth(_ monthReference: Date) -> [FinancialTransaction] {
        ensureTransactionIndexesBuilt()
        let comps = calendar.dateComponents([.year, .month], from: monthReference)
        guard let y = comps.year, let m = comps.month else { return [] }
        let ymKey = y * 100 + m
        return cachedTransactionsByYM?[ymKey] ?? []
    }

    public func isInMonth(_ date: Date, monthReference: Date) -> Bool {
        calendar.isDate(date, equalTo: monthReference, toGranularity: .month) &&
        calendar.isDate(date, equalTo: monthReference, toGranularity: .year)
    }

    public func isInYear(_ date: Date, yearReference: Date) -> Bool {
        calendar.isDate(date, equalTo: yearReference, toGranularity: .year)
    }

    public func endOfMonth(for date: Date) -> Date {
        var comps = calendar.dateComponents([.year, .month], from: date)
        comps.month = (comps.month ?? 1) + 1
        comps.day = 0
        comps.hour = 23
        comps.minute = 59
        comps.second = 59
        return calendar.date(from: comps) ?? date
    }

    public func endOfYear(for date: Date) -> Date {
        var comps = calendar.dateComponents([.year], from: date)
        comps.month = 12
        comps.day = 31
        comps.hour = 23
        comps.minute = 59
        comps.second = 59
        return calendar.date(from: comps) ?? date
    }

    public func changeMonth(by offset: Int) {
        if let next = calendar.date(byAdding: .month, value: offset, to: selectedMonth) {
            selectedMonth = next
            ensureRecurringTransactionsMaterialized(upTo: endOfMonth(for: next))
        }
    }

    public func changeYear(by offset: Int) {
        if let next = calendar.date(byAdding: .year, value: offset, to: selectedMonth) {
            selectedMonth = next
            ensureRecurringTransactionsMaterialized(upTo: endOfYear(for: next))
        }
    }

    public func startOfMonth(for date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    public func isMonthPriorToCurrent(_ date: Date, referenceNow: Date? = nil) -> Bool {
        let now = referenceNow ?? effectiveCurrentDate
        let curComps = calendar.dateComponents([.year, .month], from: now)
        let curKey = (curComps.year ?? 0) * 100 + (curComps.month ?? 0)
        let dComps = calendar.dateComponents([.year, .month], from: date)
        let dKey = (dComps.year ?? 0) * 100 + (dComps.month ?? 0)
        return dKey < curKey
    }

    public func monthlyIncome(for month: Date) -> Double {
        transactionsForMonth(month)
            .filter { $0.type == .income && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
    }

    public func monthlyExpense(for month: Date) -> Double {
        transactionsForMonth(month)
            .filter { $0.type == .expense && !$0.ignoreInConsolidated && !$0.isCreditCardInvoicePayment }
            .reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
    }

    public func monthlyPaidExpense(for month: Date) -> Double {
        transactionsForMonth(month)
            .filter { $0.type == .expense && ($0.isPaid || $0.isCreditCardExpense) && !$0.ignoreInConsolidated && !$0.isCreditCardInvoicePayment }
            .reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
    }

    public func monthlyPendingExpenses(for month: Date) -> Double {
        transactionsForMonth(month)
            .filter { $0.type == .expense && !$0.isPaid && !$0.isCreditCardExpense && !$0.ignoreInConsolidated && !$0.isCreditCardInvoicePayment }
            .reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
    }

    public func monthlyPendingExpense(for month: Date) -> Double {
        monthlyPendingExpenses(for: month)
    }

    public func monthlyReceivedIncome(for month: Date) -> Double {
        transactionsForMonth(month)
            .filter { $0.type == .income && $0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
    }

    public func monthlyPendingIncome(for month: Date) -> Double {
        transactionsForMonth(month)
            .filter { $0.type == .income && !$0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
    }

    public func monthlyNetBalance(for month: Date) -> Double {
        monthlyIncome(for: month) - monthlyExpense(for: month)
    }

    public func transactionsForYear(_ yearReference: Date) -> [FinancialTransaction] {
        ensureTransactionIndexesBuilt()
        let y = calendar.component(.year, from: yearReference)
        return (cachedTransactionsByYear?[y] ?? []).sorted { a, b in
            if a.date == b.date { return a.createdAt > b.createdAt }
            return a.date > b.date
        }
    }

    public func annualIncome(for yearReference: Date) -> Double {
        transactionsForYear(yearReference)
            .filter { $0.type == .income && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
    }

    public func annualExpense(for yearReference: Date) -> Double {
        transactionsForYear(yearReference)
            .filter { $0.type == .expense && !$0.ignoreInConsolidated && !$0.isCreditCardInvoicePayment }
            .reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
    }

    public func annualPaidExpense(for yearReference: Date) -> Double {
        transactionsForYear(yearReference)
            .filter { $0.type == .expense && ($0.isPaid || $0.isCreditCardExpense) && !$0.ignoreInConsolidated && !$0.isCreditCardInvoicePayment }
            .reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
    }

    public func annualPendingExpense(for yearReference: Date) -> Double {
        transactionsForYear(yearReference)
            .filter { $0.type == .expense && !$0.isPaid && !$0.isCreditCardExpense && !$0.ignoreInConsolidated && !$0.isCreditCardInvoicePayment }
            .reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
    }

    public func annualReceivedIncome(for yearReference: Date) -> Double {
        transactionsForYear(yearReference)
            .filter { $0.type == .income && $0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
    }

    public func annualPendingIncome(for yearReference: Date) -> Double {
        transactionsForYear(yearReference)
            .filter { $0.type == .income && !$0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
    }

    public func annualNetBalance(for yearReference: Date) -> Double {
        annualIncome(for: yearReference) - annualExpense(for: yearReference)
    }

    public func financialHealthScore(for month: Date) -> Int {
        let income = monthlyIncome(for: month)
        let expense = monthlyExpense(for: month)
        guard income > 0 else {
            return expense > 0 ? 30 : 60
        }
        let savingsRatio = (income - expense) / income
        if savingsRatio >= 0.3 { return 95 }
        if savingsRatio >= 0.2 { return 85 }
        if savingsRatio >= 0.1 { return 75 }
        if savingsRatio >= 0.0 { return 65 }
        if savingsRatio >= -0.15 { return 45 }
        return 25
    }

    public func currentBalance(forAccount accountId: UUID, upTo dateLimit: Date? = nil) -> Double {
        guard let acc = account(for: accountId) else { return 0.0 }
        let limit = dateLimit.map { endOfMonth(for: $0) }
        let delta = transactions
            .filter { tx in
                guard tx.accountId == accountId else { return false }
                guard !tx.ignoreInConsolidated else { return false }
                guard !tx.isCreditCardExpense else { return false }
                if let limit {
                    return tx.date <= limit && (tx.isPaid || tx.date <= limit)
                } else {
                    return tx.isPaid
                }
            }
            .reduce(0.0) { $0 + $1.signedAmount }
        return acc.initialBalance + delta
    }

    public func accumulatedConsolidatedBalance(throughMonth monthReference: Date, includeProjectedUnpaid: Bool = true) -> Double {
        let cutoff = endOfMonth(for: monthReference)
        let initialAccountsSum = accounts.reduce(0.0) { $0 + $1.initialBalance }
        let transactionsDelta = transactions
            .filter { tx in
                guard !tx.ignoreInConsolidated else { return false }
                guard !tx.isCreditCardExpense else { return false }
                guard tx.date <= cutoff else { return false }
                return includeProjectedUnpaid ? true : tx.isPaid
            }
            .reduce(0.0) { $0 + effectiveSignedTransactionAmount(for: $1) }

        let consolidatedInvestmentsSum = investments
            .filter(\.showInConsolidated)
            .reduce(0.0) { $0 + $1.balance }

        let remainingProvisions = includeProjectedUnpaid ? accumulatedRemainingProvisions(throughMonth: monthReference) : 0.0

        return initialAccountsSum + transactionsDelta + consolidatedInvestmentsSum - remainingProvisions
    }

    public func accumulatedConsolidatedBalanceThroughYear(_ yearReference: Date, includeProjectedUnpaid: Bool = true) -> Double {
        let cutoff = endOfYear(for: yearReference)
        return accumulatedConsolidatedBalance(throughMonth: cutoff, includeProjectedUnpaid: includeProjectedUnpaid)
    }

    public var totalCheckingBalanceNow: Double {
        accounts.reduce(0.0) { $0 + currentBalance(forAccount: $1.id) }
    }

    public var totalInvestmentsBalance: Double {
        investments.reduce(0.0) { $0 + $1.balance }
    }

    public var consolidatedInvestmentsBalance: Double {
        investments.filter(\.showInConsolidated).reduce(0.0) { $0 + $1.balance }
    }

    public var totalConsolidatedPatrimonyNow: Double {
        totalCheckingBalanceNow + consolidatedInvestmentsBalance
    }

    public func categoryBreakdown(for monthReference: Date, type: TransactionType) -> [CategorySpendSummary] {
        let monthTxs = transactionsForMonth(monthReference)
            .filter { $0.type == type && !$0.ignoreInConsolidated && !$0.isCreditCardInvoicePayment }
        let grandTotal = monthTxs.reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
        guard grandTotal > 0 else { return [] }

        var grouped: [UUID: (sum: Double, count: Int)] = [:]
        for tx in monthTxs {
            let effAmt = effectiveTransactionAmount(for: tx)
            guard effAmt > 0.001 else { continue }
            let current = grouped[tx.categoryId] ?? (0.0, 0)
            grouped[tx.categoryId] = (current.sum + effAmt, current.count + 1)
        }

        var result: [CategorySpendSummary] = []
        for (catId, info) in grouped {
            let cat = category(for: catId) ?? CategoryItem(
                id: catId,
                name: "Outros",
                type: type,
                iconSymbol: "tag.fill",
                colorHex: "#64748B"
            )
            result.append(
                CategorySpendSummary(
                    category: cat,
                    total: info.sum,
                    percentage: (info.sum / grandTotal) * 100.0,
                    count: info.count
                )
            )
        }
        return result.sorted { $0.total > $1.total }
    }

    public func annualCategoryBreakdown(for yearReference: Date, type: TransactionType) -> [CategorySpendSummary] {
        let yearTxs = transactionsForYear(yearReference)
            .filter { $0.type == type && !$0.ignoreInConsolidated && !$0.isCreditCardInvoicePayment }
        let grandTotal = yearTxs.reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
        guard grandTotal > 0 else { return [] }

        var grouped: [UUID: (sum: Double, count: Int)] = [:]
        for tx in yearTxs {
            let effAmt = effectiveTransactionAmount(for: tx)
            guard effAmt > 0.001 else { continue }
            let current = grouped[tx.categoryId] ?? (0.0, 0)
            grouped[tx.categoryId] = (current.sum + effAmt, current.count + 1)
        }

        var result: [CategorySpendSummary] = []
        for (catId, info) in grouped {
            let cat = category(for: catId) ?? CategoryItem(
                id: catId,
                name: "Outros",
                type: type,
                iconSymbol: "tag.fill",
                colorHex: "#64748B"
            )
            result.append(
                CategorySpendSummary(
                    category: cat,
                    total: info.sum,
                    percentage: (info.sum / grandTotal) * 100.0,
                    count: info.count
                )
            )
        }
        return result.sorted { $0.total > $1.total }
    }

    public func cashFlowSeries(around centerMonth: Date, monthsBack: Int = 3, monthsForward: Int = 4) -> [MonthlyCashFlowPoint] {
        var points: [MonthlyCashFlowPoint] = []
        for offset in (-monthsBack)...monthsForward {
            if let mDate = calendar.date(byAdding: .month, value: offset, to: centerMonth) {
                let inc = monthlyIncome(for: mDate)
                let exp = monthlyExpense(for: mDate)
                let acc = accumulatedConsolidatedBalance(throughMonth: mDate, includeProjectedUnpaid: true)
                let remProv = isMonthPriorToCurrent(mDate) ? 0.0 : totalRemainingProvision(for: mDate)
                let isPast = isMonthPriorToCurrent(mDate)
                points.append(
                    MonthlyCashFlowPoint(
                        monthDate: mDate,
                        label: AppFormatters.shortMonthYearFormatter.string(from: mDate).capitalized,
                        income: inc,
                        expense: exp,
                        net: inc - exp,
                        accumulatedBalance: acc,
                        remainingProvisions: remProv,
                        isPastMonth: isPast
                    )
                )
            }
        }
        return points
    }

    public func annualCashFlowSeries(for yearReference: Date) -> [MonthlyCashFlowPoint] {
        let year = calendar.component(.year, from: yearReference)
        var points: [MonthlyCashFlowPoint] = []
        for month in 1...12 {
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 15
            if let mDate = calendar.date(from: comps) {
                let inc = monthlyIncome(for: mDate)
                let exp = monthlyExpense(for: mDate)
                let acc = accumulatedConsolidatedBalance(throughMonth: mDate, includeProjectedUnpaid: true)
                let remProv = isMonthPriorToCurrent(mDate) ? 0.0 : totalRemainingProvision(for: mDate)
                let isPast = isMonthPriorToCurrent(mDate)
                points.append(
                    MonthlyCashFlowPoint(
                        monthDate: mDate,
                        label: AppFormatters.shortMonthYearFormatter.string(from: mDate).capitalized,
                        income: inc,
                        expense: exp,
                        net: inc - exp,
                        accumulatedBalance: acc,
                        remainingProvisions: remProv,
                        isPastMonth: isPast
                    )
                )
            }
        }
        return points
    }

    public func buildComprehensiveDebtSummary(referenceDate: Date = Date(), isAnnual: Bool = false) -> ComprehensiveDebtSummary {
        let currentPeriodUnpaid = transactions.filter { tx in
            tx.type == .expense &&
            !tx.isPaid &&
            !tx.ignoreInConsolidated &&
            !tx.isCreditCardExpense &&
            (isAnnual ? isInYear(tx.date, yearReference: referenceDate) : isInMonth(tx.date, monthReference: referenceDate))
        }

        let endOfCurrentPeriod = isAnnual ? endOfYear(for: referenceDate) : endOfMonth(for: referenceDate)
        let futureRegularUnpaid = transactions.filter { tx in
            tx.type == .expense &&
            !tx.isPaid &&
            !tx.ignoreInConsolidated &&
            !tx.isCreditCardExpense &&
            tx.date > endOfCurrentPeriod &&
            tx.linkedContractId == nil
        }

        let openDebts = activeDebts
        let openLoans = activeContracts(for: .loan)
        let openFinancings = activeContracts(for: .financing)

        let currentMonthUnpaidSum = currentPeriodUnpaid.reduce(0.0) { $0 + $1.amount }
        let futureRegularSum = futureRegularUnpaid.reduce(0.0) { $0 + $1.amount }
        let debtsSum = openDebts.reduce(0.0) { $0 + $1.originalAmount }

        let loansNominalSum = openLoans.reduce(0.0) { $0 + remainingNominalAmount(for: $1, asOf: endOfCurrentPeriod) }
        let loansProjectedSum = openLoans.reduce(0.0) { $0 + projectedPayoffAmount(for: $1, asOf: endOfCurrentPeriod) }
        let loansPaidTotal = openLoans.reduce(0.0) { $0 + amortizedAmountInPeriod(for: $1, referenceDate: referenceDate, isAnnual: isAnnual) }
        let loansRealAmortizationTotal = openLoans.reduce(0.0) { $0 + realAmortizationAmountInPeriod(for: $1, referenceDate: referenceDate, isAnnual: isAnnual) }

        let financingsNominalSum = openFinancings.reduce(0.0) { $0 + remainingNominalAmount(for: $1, asOf: endOfCurrentPeriod) }
        let financingsProjectedSum = openFinancings.reduce(0.0) { $0 + projectedPayoffAmount(for: $1, asOf: endOfCurrentPeriod) }
        let financingsPaidTotal = openFinancings.reduce(0.0) { $0 + amortizedAmountInPeriod(for: $1, referenceDate: referenceDate, isAnnual: isAnnual) }
        let financingsRealAmortizationTotal = openFinancings.reduce(0.0) { $0 + realAmortizationAmountInPeriod(for: $1, referenceDate: referenceDate, isAnnual: isAnnual) }

        var items: [DebtLineItem] = []

        let periodExpenseSectionTitle = isAnnual ? "Despesas do Ano" : "Despesas do Mês"
        for tx in currentPeriodUnpaid {
            items.append(
                DebtLineItem(
                    id: tx.id,
                    title: tx.name,
                    subtitle: "Despesa pendente (\(AppFormatters.shortDate(tx.date)))",
                    section: periodExpenseSectionTitle,
                    nominalAmount: tx.amount,
                    projectedPayoffAmount: tx.amount,
                    iconSymbol: "calendar.badge.exclamationmark",
                    colorHex: "#F59E0B"
                )
            )
        }

        for tx in futureRegularUnpaid {
            items.append(
                DebtLineItem(
                    id: tx.id,
                    title: tx.name,
                    subtitle: "Despesa futura para \(AppFormatters.shortDate(tx.date))",
                    section: periodExpenseSectionTitle,
                    nominalAmount: tx.amount,
                    projectedPayoffAmount: tx.amount,
                    iconSymbol: "clock.arrow.circlepath",
                    colorHex: "#3B82F6"
                )
            )
        }

        for debt in openDebts {
            let dateInfo = debt.contractedDate.map { "Contraída em \(AppFormatters.shortDate($0))" } ?? "Dívida em aberto"
            items.append(
                DebtLineItem(
                    id: debt.id,
                    title: debt.name,
                    subtitle: dateInfo,
                    section: "Dívidas (Serasa / Acordos)",
                    nominalAmount: debt.originalAmount,
                    projectedPayoffAmount: debt.originalAmount,
                    iconSymbol: debt.iconSymbol,
                    colorHex: debt.colorHex
                )
            )
        }

        for loan in openLoans {
            let remCount = remainingInstallmentsCount(for: loan, asOf: endOfCurrentPeriod)
            let nom = remainingNominalAmount(for: loan, asOf: endOfCurrentPeriod)
            let proj = projectedPayoffAmount(for: loan, asOf: endOfCurrentPeriod)
            let paid = amortizedAmountInPeriod(for: loan, referenceDate: referenceDate, isAnnual: isAnnual)
            let paidStr = paid > 0 ? " • Pagamentos: \(AppFormatters.currency(paid))" : ""
            items.append(
                DebtLineItem(
                    id: loan.id,
                    title: "\(loan.name) (\(loan.subtypeDisplayName))",
                    subtitle: "\(remCount)x restantes de \(AppFormatters.currency(loan.installmentAmount))\(paidStr) • Juros \(String(format: "%.2f", loan.monthlyInterestRate))% a.m.",
                    section: "Empréstimos",
                    nominalAmount: nom,
                    projectedPayoffAmount: proj,
                    iconSymbol: loan.iconSymbol,
                    colorHex: "#D97706"
                )
            )
        }

        for fin in openFinancings {
            let remCount = remainingInstallmentsCount(for: fin, asOf: endOfCurrentPeriod)
            let nom = remainingNominalAmount(for: fin, asOf: endOfCurrentPeriod)
            let proj = projectedPayoffAmount(for: fin, asOf: endOfCurrentPeriod)
            let paid = amortizedAmountInPeriod(for: fin, referenceDate: referenceDate, isAnnual: isAnnual)
            let paidStr = paid > 0 ? " • Pagamentos: \(AppFormatters.currency(paid))" : ""
            items.append(
                DebtLineItem(
                    id: fin.id,
                    title: "\(fin.name) (\(fin.subtypeDisplayName))",
                    subtitle: "\(remCount)x restantes de \(AppFormatters.currency(fin.installmentAmount))\(paidStr) • Saldo Devedor: \(AppFormatters.currency(proj))",
                    section: "Financiamentos",
                    nominalAmount: nom,
                    projectedPayoffAmount: proj,
                    iconSymbol: fin.iconSymbol,
                    colorHex: "#8B5CF6"
                )
            )
        }

        let debtStockNominal = debtsSum + loansNominalSum + financingsNominalSum
        let debtStockProjected = debtsSum + loansProjectedSum + financingsProjectedSum

        return ComprehensiveDebtSummary(
            currentMonthUnpaidTransactions: currentPeriodUnpaid,
            futureUnpaidRegularTransactions: futureRegularUnpaid,
            activeDebts: openDebts,
            activeLoans: openLoans,
            activeFinancings: openFinancings,
            currentMonthUnpaidTotal: currentMonthUnpaidSum,
            futureRegularExpensesTotal: futureRegularSum,
            unpaidDebtsTotal: debtsSum,
            loansRemainingNominalTotal: loansNominalSum,
            loansProjectedPayoffTotal: loansProjectedSum,
            loansAmortizedInPeriodTotal: loansPaidTotal,
            financingsRemainingNominalTotal: financingsNominalSum,
            financingsProjectedPayoffTotal: financingsProjectedSum,
            financingsAmortizedInPeriodTotal: financingsPaidTotal,
            loansPaidInPeriodTotal: loansPaidTotal,
            loansRealAmortizationInPeriodTotal: loansRealAmortizationTotal,
            financingsPaidInPeriodTotal: financingsPaidTotal,
            financingsRealAmortizationInPeriodTotal: financingsRealAmortizationTotal,
            grandTotalNominal: debtStockNominal,
            grandTotalWithPayoffProjection: debtStockProjected,
            itemizedLines: items
        )
    }

    public func periodInstallmentsTotal(for kind: CreditContractKind, referenceDate: Date, isAnnual: Bool) -> Double {
        let active = activeContracts(for: kind)
        guard !active.isEmpty else { return 0.0 }
        let ids = Set(active.map(\.id))
        if isAnnual {
            let txs = transactionsForYear(referenceDate).filter {
                $0.type == .expense &&
                $0.linkedContractId != nil &&
                ids.contains($0.linkedContractId!)
            }.reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
            if txs > 0 { return txs }
            return active.reduce(0.0) { $0 + ($1.installmentAmount * 12.0) }
        } else {
            let txs = transactionsForMonth(referenceDate).filter {
                $0.type == .expense &&
                $0.linkedContractId != nil &&
                ids.contains($0.linkedContractId!)
            }.reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
            if txs > 0 { return txs }
            return active.reduce(0.0) { $0 + $1.installmentAmount }
        }
    }

    public func monthEndBalanceCardTitle(for month: Date) -> String {
        let isPast = isMonthPriorToCurrent(month)
        if isPast {
            return "Resultado Consolidado"
        }
        let monthStr = AppFormatters.shortMonthYearFormatter.string(from: month).capitalized
        return "Saldo Previsto para Fim de \(monthStr)"
    }

    public func deductionSubtitleForProjectedBalance(periodMode: DashboardPeriodMode, selectedMonth: Date) -> String {
        let isPast = isMonthPriorToCurrent(selectedMonth)
        if isPast {
            return "Saldo histórico consolidado"
        }
        let pending = periodMode == .annual ? annualPendingExpense(for: selectedMonth) : monthlyPendingExpenses(for: selectedMonth)
        let prov = totalRemainingProvision(for: selectedMonth)
        if pending > 0 && prov > 0 {
            return "Deduzidos \(AppFormatters.currency(pending)) em pendentes e \(AppFormatters.currency(prov)) em tetos/cotas"
        } else if pending > 0 {
            return "Deduzidos \(AppFormatters.currency(pending)) em compromissos pendentes"
        } else if prov > 0 {
            return "Deduzidos \(AppFormatters.currency(prov)) em tetos/cotas restantes"
        }
        return "Nenhuma dedução pendente projetada"
    }

    public func deductionBreakdownTooltipForProjectedBalance(periodMode: DashboardPeriodMode, selectedMonth: Date) -> String {
        let pending = periodMode == .annual ? annualPendingExpense(for: selectedMonth) : monthlyPendingExpenses(for: selectedMonth)
        let prov = totalRemainingProvision(for: selectedMonth)
        return "Pendentes: \(AppFormatters.currency(pending)) • Tetos e Cotas Restantes: \(AppFormatters.currency(prov))"
    }

    // MARK: - Centralized Unified Financial KPI Engine

    /// Constrói e retorna o sumário analítico financeiro unificado (KPIs) para o período e granularidade especificados.
    /// Esta é a ÚNICA FONTE DE VERDADE para os cards analíticos das telas da aplicação:
    /// Dashboard, Extrato/Transações, Despesas e Receitas.
    public func buildUnifiedFinancialKPISummary(
        referenceDate: Date,
        isAnnual: Bool,
        referenceNow: Date? = nil
    ) -> UnifiedFinancialKPISummary {
        let now = referenceNow ?? effectiveCurrentDate
        let nowYear = calendar.component(.year, from: now)
        let nowMonth = calendar.component(.month, from: now)
        let refYear = calendar.component(.year, from: referenceDate)
        let refMonth = calendar.component(.month, from: referenceDate)

        // 1. Identificação estrita do contexto temporal (6 modalidades)
        let temporalContext: FinancialTemporalContext = {
            if isAnnual {
                if refYear < nowYear { return .pastYear }
                if refYear == nowYear { return .currentYear }
                return .futureYear
            } else {
                if refYear < nowYear || (refYear == nowYear && refMonth < nowMonth) {
                    return .pastMonth
                } else if refYear == nowYear && refMonth == nowMonth {
                    return .currentMonth
                } else {
                    return .futureMonth
                }
            }
        }()

        let isClosed = temporalContext.isClosed

        // 2. Extração de transações do período
        let rawPeriodTxs = isAnnual ? transactionsForYear(referenceDate) : transactionsForMonth(referenceDate)
        // Filtra apenas transações ativas consolidadas (ignora transferências internas e canceladas)
        let periodTxs = rawPeriodTxs.filter { tx in
            !tx.ignoreInConsolidated &&
            tx.transactionOrigin != .internalTransfer &&
            tx.isCanceledRecurringSeries != true
        }

        let incomeTxs = periodTxs.filter { $0.type == .income }
        let expenseTxs = periodTxs.filter { $0.type == .expense && !$0.isCreditCardInvoicePayment }

        // 3. Receitas: Recebidas, Pendentes (no prazo vs em atraso), Extraordinárias vs Habituais
        let receivedIncome = incomeTxs.filter(\.isPaid).reduce(0.0) { $0 + $1.amount }
        let pendingIncomeTxs = incomeTxs.filter { !$0.isPaid }
        let pendingIncome = pendingIncomeTxs.reduce(0.0) { $0 + $1.amount }

        let todayStart = calendar.startOfDay(for: now)
        let pendingIncomeOverdue = pendingIncomeTxs.filter { calendar.startOfDay(for: $0.date) < todayStart }.reduce(0.0) { $0 + $1.amount }
        let pendingIncomeOnTime = pendingIncomeTxs.filter { calendar.startOfDay(for: $0.date) >= todayStart }.reduce(0.0) { $0 + $1.amount }

        let unrecordedExpectedIncome = 0.0

        let projectedIncome: Double = {
            if isClosed {
                return receivedIncome
            } else if temporalContext == .currentYear {
                var sum = 0.0
                for m in 1...12 {
                    if let mDate = calendar.date(from: DateComponents(year: refYear, month: m, day: 1)) {
                        if m < nowMonth {
                            sum += monthlyReceivedIncome(for: mDate)
                        } else {
                            sum += monthlyIncome(for: mDate)
                        }
                    }
                }
                return sum + unrecordedExpectedIncome
            } else {
                return receivedIncome + pendingIncome + unrecordedExpectedIncome
            }
        }()

        let habitualIncome = incomeTxs.filter { !$0.isExtraordinaryIncome && (isClosed ? $0.isPaid : true) }.reduce(0.0) { $0 + $1.amount }
        let extraordinaryIncome = incomeTxs.filter { $0.isExtraordinaryIncome && (isClosed ? $0.isPaid : true) }.reduce(0.0) { $0 + $1.amount }

        var incomeByCategory: [UUID: Double] = [:]
        for tx in incomeTxs where (isClosed ? tx.isPaid : true) {
            incomeByCategory[tx.categoryId, default: 0.0] += tx.amount
        }
        let topCategoryEntry = incomeByCategory.max(by: { $0.value < $1.value })
        let topIncomeSourceName = topCategoryEntry.flatMap { category(for: $0.key)?.name }
        let topIncomeSourceAmount = topCategoryEntry?.value ?? 0.0
        let effectiveIncomeForRatio = isClosed ? receivedIncome : (receivedIncome + pendingIncome)
        let topIncomeSourcePercentage = effectiveIncomeForRatio > 0 ? (topIncomeSourceAmount / effectiveIncomeForRatio) * 100.0 : 0.0

        // 4. Despesas (Competência): Pagas (inclui cartão realizado), Pendentes (no prazo vs vencidas em atraso), Fixas vs Variáveis
        let paidExpense = expenseTxs.filter { $0.isPaid || $0.isCreditCardExpense }.reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
        let pendingExpenseTxs = expenseTxs.filter { !$0.isPaid && !$0.isCreditCardExpense }
        let pendingExpense = pendingExpenseTxs.reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }

        let overdueExpenses = pendingExpenseTxs.filter { calendar.startOfDay(for: $0.date) < todayStart }.reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
        let onTimePendingExpenses = pendingExpenseTxs.filter { calendar.startOfDay(for: $0.date) >= todayStart }.reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }

        let recordedExpense: Double = {
            if isClosed {
                return paidExpense
            } else if temporalContext == .currentYear {
                var sum = 0.0
                for m in 1...12 {
                    if let mDate = calendar.date(from: DateComponents(year: refYear, month: m, day: 1)) {
                        if m < nowMonth {
                            sum += monthlyPaidExpense(for: mDate)
                        } else {
                            sum += monthlyExpense(for: mDate)
                        }
                    }
                }
                return sum
            } else {
                return paidExpense + pendingExpense
            }
        }()

        let fixedExpenses = expenseTxs.filter { $0.isFixedExpense && (isClosed ? ($0.isPaid || $0.isCreditCardExpense) : true) }.reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
        let variableExpenses = expenseTxs.filter { $0.isVariableExpense && (isClosed ? ($0.isPaid || $0.isCreditCardExpense) : true) }.reduce(0.0) { $0 + effectiveTransactionAmount(for: $1) }
        let totalClassifiedExp = fixedExpenses + variableExpenses
        let fixedExpensesPercentage = totalClassifiedExp > 0 ? (fixedExpenses / totalClassifiedExp) * 100.0 : 0.0
        let variableExpensesPercentage = totalClassifiedExp > 0 ? (variableExpenses / totalClassifiedExp) * 100.0 : 0.0

        // 5. Orçamentos e Cotas Restantes & Excedentes
        let categoryCeilingsRemaining: Double
        let specificQuotasRemaining: Double
        let remainingBudgetsAndQuotas: Double
        let totalBudgetsOverrun: Double

        if isClosed {
            categoryCeilingsRemaining = 0.0
            specificQuotasRemaining = 0.0
            remainingBudgetsAndQuotas = 0.0
            totalBudgetsOverrun = provisionEnvelopes(for: referenceDate).reduce(0.0) { $0 + $1.exceededAmount }
        } else if isAnnual {
            if temporalContext == .currentYear {
                var catRem = 0.0
                var quotRem = 0.0
                var overrun = 0.0
                for m in nowMonth...12 {
                    if let mDate = calendar.date(from: DateComponents(year: refYear, month: m, day: 1)) {
                        catRem += totalCategoryProvisionsRemaining(for: mDate, referenceNow: now)
                        quotRem += totalQuotasRemaining(for: mDate)
                        overrun += provisionEnvelopes(for: mDate).reduce(0.0) { $0 + $1.exceededAmount }
                    }
                }
                categoryCeilingsRemaining = catRem
                specificQuotasRemaining = quotRem
                remainingBudgetsAndQuotas = catRem + quotRem
                totalBudgetsOverrun = overrun
            } else {
                var catRem = 0.0
                var quotRem = 0.0
                var overrun = 0.0
                for m in 1...12 {
                    if let mDate = calendar.date(from: DateComponents(year: refYear, month: m, day: 1)) {
                        catRem += totalCategoryProvisionsRemaining(for: mDate, referenceNow: now)
                        quotRem += totalQuotasRemaining(for: mDate)
                        overrun += provisionEnvelopes(for: mDate).reduce(0.0) { $0 + $1.exceededAmount }
                    }
                }
                categoryCeilingsRemaining = catRem
                specificQuotasRemaining = quotRem
                remainingBudgetsAndQuotas = catRem + quotRem
                totalBudgetsOverrun = overrun
            }
        } else {
            categoryCeilingsRemaining = totalCategoryProvisionsRemaining(for: referenceDate, referenceNow: now)
            specificQuotasRemaining = totalQuotasRemaining(for: referenceDate)
            remainingBudgetsAndQuotas = totalRemainingProvision(for: referenceDate, referenceNow: now)
            totalBudgetsOverrun = provisionEnvelopes(for: referenceDate).reduce(0.0) { $0 + $1.exceededAmount }
        }

        let hasBudgetOverrun = totalBudgetsOverrun > 0.001

        // 6. Gastos Planejados e Sobra Após Planejamento
        let totalPlannedExpenses = recordedExpense + remainingBudgetsAndQuotas
        let surplusAfterPlanning = projectedIncome - totalPlannedExpenses
        let operationalNetBalance = projectedIncome - recordedExpense

        // 7. Saldo Bancário em Contas e Saldo se Utilizar Todo o Orçamento
        let currentAccountBalanceNow = totalCheckingBalanceNow

        let cutoffDate: Date = isAnnual ? endOfYear(for: referenceDate) : endOfMonth(for: referenceDate)
        let initialAccountsSum = accounts.reduce(0.0) { $0 + $1.initialBalance }
        let transactionsDelta = transactions
            .filter { tx in
                guard !tx.ignoreInConsolidated else { return false }
                guard !tx.isCreditCardExpense else { return false }
                guard tx.date <= cutoffDate else { return false }
                return isClosed ? tx.isPaid : true
            }
            .reduce(0.0) { $0 + effectiveSignedTransactionAmount(for: $1) }
        let consolidatedInvestmentsSum = investments
            .filter(\.showInConsolidated)
            .reduce(0.0) { $0 + $1.balance }

        let projectedAccountBalance = initialAccountsSum + transactionsDelta + consolidatedInvestmentsSum
        let balanceIfAllBudgetsConsumed = isClosed
            ? projectedAccountBalance
            : (projectedAccountBalance - (isAnnual ? remainingBudgetsAndQuotas : accumulatedRemainingProvisions(throughMonth: referenceDate, referenceNow: now)))

        let projectedAccountBalanceTitle: String = {
            if isAnnual {
                return isClosed
                    ? "Resultado Consolidado"
                    : "Saldo Previsto para 31/12/\(AppFormatters.yearString(referenceDate))"
            } else {
                return isClosed
                    ? "Saldo Final Realizado"
                    : monthEndBalanceCardTitle(for: referenceDate)
            }
        }()

        // 8. Estatísticas Operacionais da Tela de Transações
        let consolidatedEntries: Double = isClosed ? receivedIncome : (receivedIncome + pendingIncome)
        let consolidatedExits: Double = isClosed ? paidExpense : (paidExpense + pendingExpense)
        let transactionsNetBalance = consolidatedEntries - consolidatedExits
        let totalPendingVolume = pendingIncome + pendingExpense
        let paidTransactionsCount = periodTxs.filter(\.isPaid).count
        let pendingTransactionsCount = periodTxs.filter { !$0.isPaid }.count
        let validTransactionsCount = periodTxs.count

        return UnifiedFinancialKPISummary(
            referenceDate: referenceDate,
            referenceNow: now,
            isAnnual: isAnnual,
            temporalContext: temporalContext,
            receivedIncome: receivedIncome,
            pendingIncome: pendingIncome,
            pendingIncomeOverdue: pendingIncomeOverdue,
            pendingIncomeOnTime: pendingIncomeOnTime,
            unrecordedExpectedIncome: unrecordedExpectedIncome,
            projectedIncome: projectedIncome,
            habitualIncome: habitualIncome,
            extraordinaryIncome: extraordinaryIncome,
            topIncomeSourceName: topIncomeSourceName,
            topIncomeSourceAmount: topIncomeSourceAmount,
            topIncomeSourcePercentage: topIncomeSourcePercentage,
            paidExpense: paidExpense,
            pendingExpense: pendingExpense,
            recordedExpense: recordedExpense,
            overdueExpenses: overdueExpenses,
            onTimePendingExpenses: onTimePendingExpenses,
            fixedExpenses: fixedExpenses,
            fixedExpensesPercentage: fixedExpensesPercentage,
            variableExpenses: variableExpenses,
            variableExpensesPercentage: variableExpensesPercentage,
            categoryCeilingsRemaining: categoryCeilingsRemaining,
            specificQuotasRemaining: specificQuotasRemaining,
            remainingBudgetsAndQuotas: remainingBudgetsAndQuotas,
            totalBudgetsOverrun: totalBudgetsOverrun,
            hasBudgetOverrun: hasBudgetOverrun,
            totalPlannedExpenses: totalPlannedExpenses,
            surplusAfterPlanning: surplusAfterPlanning,
            operationalNetBalance: operationalNetBalance,
            currentAccountBalanceNow: currentAccountBalanceNow,
            projectedAccountBalance: projectedAccountBalance,
            balanceIfAllBudgetsConsumed: balanceIfAllBudgetsConsumed,
            projectedAccountBalanceTitle: projectedAccountBalanceTitle,
            consolidatedEntries: consolidatedEntries,
            consolidatedExits: consolidatedExits,
            transactionsNetBalance: transactionsNetBalance,
            totalPendingVolume: totalPendingVolume,
            paidTransactionsCount: paidTransactionsCount,
            pendingTransactionsCount: pendingTransactionsCount,
            validTransactionsCount: validTransactionsCount
        )
    }

    // MARK: - Reset All Data

    public func resetAllData() {
        transactions.removeAll()
        accounts.removeAll()
        creditCards.removeAll()
        creditCardInvoices.removeAll()
        categories.removeAll()
        investments.removeAll()
        debts.removeAll()
        contracts.removeAll()
        amortizationPlans.removeAll()
        provisions.removeAll()
        categoryQuotas.removeAll()
        invalidateDerivedCaches()
        saveToDisk()
        cloudSyncService?.resetSyncState()
    }

    // MARK: - Análise Cronológica Intramês (Vale de Caixa)

    public func buildIntraMonthCashFlowAnalysis(for monthReference: Date) -> IntraMonthCashFlowAnalysis {
        let comps = calendar.dateComponents([.year, .month], from: monthReference)
        let ymKey = (comps.year ?? 2026) * 100 + (comps.month ?? 1)
        if let cached = cachedIntraMonthAnalysisByYM[ymKey] {
            return cached
        }

        let isClosed = isMonthPriorToCurrent(monthReference, referenceNow: effectiveCurrentDate)
        let result = IntraMonthCashFlowEngine.analyze(
            monthReference: monthReference,
            accounts: accounts,
            investments: investments,
            transactions: transactions,
            isClosedMonth: isClosed,
            calendar: calendar,
            isVisible: { [weak self] tx in
                self?.isTransactionVisibleInCurrentScenario(tx) ?? true
            },
            effectiveSignedAmount: { [weak self] tx in
                self?.effectiveSignedTransactionAmount(for: tx) ?? tx.signedAmount
            }
        )
        cachedIntraMonthAnalysisByYM[ymKey] = result
        return result
    }
}

public enum IntraMonthCashFlowEngine {
    public static func analyze(
        monthReference: Date,
        accounts: [BankAccount],
        investments: [InvestmentItem],
        transactions: [FinancialTransaction],
        isClosedMonth: Bool,
        calendar: Calendar = .current,
        isVisible: (FinancialTransaction) -> Bool,
        effectiveSignedAmount: (FinancialTransaction) -> Double
    ) -> IntraMonthCashFlowAnalysis {
        let monthComps = calendar.dateComponents([.year, .month], from: monthReference)
        let year = monthComps.year ?? calendar.component(.year, from: Date())
        let month = monthComps.month ?? calendar.component(.month, from: Date())

        let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1, hour: 0, minute: 0, second: 0))
            ?? calendar.startOfDay(for: monthReference)
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? (1..<31)
        let daysInMonth = dayRange.count
        let monthEnd: Date = {
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) {
                return calendar.date(byAdding: .second, value: -1, to: nextMonth) ?? nextMonth
            }
            return monthReference
        }()

        let baseOpening = accounts.reduce(0.0) { $0 + $1.initialBalance }
            + investments.filter(\.showInConsolidated).reduce(0.0) { $0 + $1.balance }

        var priorDelta = 0.0
        var monthTxs: [FinancialTransaction] = []
        monthTxs.reserveCapacity(64)

        for tx in transactions {
            guard !tx.ignoreInConsolidated else { continue }
            guard !tx.isCreditCardExpense else { continue }
            guard isVisible(tx) else { continue }
            if isClosedMonth && !tx.isPaid { continue }

            if tx.date < monthStart {
                priorDelta += effectiveSignedAmount(tx)
            } else if tx.date <= monthEnd {
                monthTxs.append(tx)
            }
        }

        let openingBalance = baseOpening + priorDelta

        let sortedMonthTxs = monthTxs.sorted { a, b in
            let dayA = calendar.component(.day, from: a.date)
            let dayB = calendar.component(.day, from: b.date)
            if dayA != dayB { return dayA < dayB }
            if a.type != b.type { return a.type == .income }
            if a.date != b.date { return a.date < b.date }
            if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }

        var txsByDay: [Int: [FinancialTransaction]] = [:]
        for tx in sortedMonthTxs {
            let day = calendar.component(.day, from: tx.date)
            txsByDay[day, default: []].append(tx)
        }

        var runningBalance = openingBalance
        var minimumBalance = openingBalance
        var minimumBalanceDate: Date? = openingBalance < -0.005 ? monthStart : nil
        var minimumBalanceDay: Int? = openingBalance < -0.005 ? 1 : nil

        var cutoffTransactionId: UUID? = nil
        var recoveryTransactionId: UUID? = nil
        var deficitZoneTransactionIds = Set<UUID>()
        var runningBalanceByTxId: [UUID: Double] = [:]

        var riskStartDay: Int? = openingBalance < -0.005 ? 1 : nil
        var riskEndDay: Int? = nil
        var currentlyInDeficit = openingBalance < -0.005

        var dailyPoints: [DailyCashFlowPoint] = []
        dailyPoints.reserveCapacity(daysInMonth)

        for day in 1...daysInMonth {
            let dayDate = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? monthStart
            let dayOpening = runningBalance
            var dayIncome = 0.0
            var dayExpense = 0.0

            let dayItems = txsByDay[day] ?? []
            for tx in dayItems {
                let signed = effectiveSignedAmount(tx)
                if signed >= 0 {
                    dayIncome += signed
                } else {
                    dayExpense += abs(signed)
                }

                let wasInDeficit = runningBalance < -0.005
                runningBalance += signed
                runningBalanceByTxId[tx.id] = runningBalance

                if runningBalance < minimumBalance {
                    minimumBalance = runningBalance
                    minimumBalanceDate = dayDate
                    minimumBalanceDay = day
                }

                let isNowInDeficit = runningBalance < -0.005

                if !wasInDeficit && isNowInDeficit {
                    if cutoffTransactionId == nil {
                        cutoffTransactionId = tx.id
                    }
                    if riskStartDay == nil {
                        riskStartDay = day
                    }
                    currentlyInDeficit = true
                    deficitZoneTransactionIds.insert(tx.id)
                } else if wasInDeficit && isNowInDeficit {
                    currentlyInDeficit = true
                    deficitZoneTransactionIds.insert(tx.id)
                } else if wasInDeficit && !isNowInDeficit {
                    if cutoffTransactionId != nil && recoveryTransactionId == nil {
                        recoveryTransactionId = tx.id
                    }
                    currentlyInDeficit = false
                    riskEndDay = max(riskEndDay ?? day, day)
                }
            }

            if currentlyInDeficit || runningBalance < -0.005 {
                if riskStartDay == nil {
                    riskStartDay = day
                }
                riskEndDay = day
            }

            dailyPoints.append(
                DailyCashFlowPoint(
                    day: day,
                    date: dayDate,
                    openingBalance: dayOpening,
                    dayIncome: dayIncome,
                    dayExpense: dayExpense,
                    closingBalance: runningBalance
                )
            )
        }

        let closingBalance = runningBalance
        let hasDeficit = minimumBalance < -0.005 || dailyPoints.contains { $0.closingBalance < -0.005 }
        let isTemporaryTrough = hasDeficit && closingBalance >= -0.005

        return IntraMonthCashFlowAnalysis(
            monthStart: monthStart,
            monthEnd: monthEnd,
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            minimumBalance: minimumBalance,
            minimumBalanceDate: minimumBalanceDate,
            minimumBalanceDay: minimumBalanceDay,
            hasIntraMonthDeficit: hasDeficit,
            isTemporaryTrough: isTemporaryTrough,
            riskStartDay: hasDeficit ? riskStartDay : nil,
            riskEndDay: hasDeficit ? riskEndDay : nil,
            cutoffTransactionId: cutoffTransactionId,
            recoveryTransactionId: recoveryTransactionId,
            deficitZoneTransactionIds: deficitZoneTransactionIds,
            runningBalanceByTransactionId: runningBalanceByTxId,
            dailyPoints: dailyPoints
        )
    }
}
