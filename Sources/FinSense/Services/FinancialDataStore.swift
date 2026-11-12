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
    public var categories: [CategoryItem]
    public var transactions: [FinancialTransaction]
    public var investments: [InvestmentItem]
    public var debts: [DebtItem]
    public var contracts: [CreditContract]
    public var provisions: [CategoryProvision]?
    public var categoryQuotas: [CategoryQuotaRule]?

    public init(
        schemaVersion: Int? = 3,
        accounts: [BankAccount] = [],
        categories: [CategoryItem] = [],
        transactions: [FinancialTransaction] = [],
        investments: [InvestmentItem] = [],
        debts: [DebtItem] = [],
        contracts: [CreditContract] = [],
        provisions: [CategoryProvision]? = [],
        categoryQuotas: [CategoryQuotaRule]? = []
    ) {
        self.schemaVersion = schemaVersion
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
        self.investments = investments
        self.debts = debts
        self.contracts = contracts
        self.provisions = provisions
        self.categoryQuotas = categoryQuotas
    }
}

@MainActor
public final class FinancialDataStore: ObservableObject {
    @Published public var accounts: [BankAccount] = []
    @Published public var categories: [CategoryItem] = []
    @Published public var transactions: [FinancialTransaction] = []
    @Published public var investments: [InvestmentItem] = []
    @Published public var debts: [DebtItem] = []
    @Published public var contracts: [CreditContract] = []
    @Published public var provisions: [CategoryProvision] = []
    @Published public var categoryQuotas: [CategoryQuotaRule] = []

    @Published public var selectedMonth: Date = Date() {
        didSet {
            ensureRecurringTransactionsMaterialized(upTo: endOfYear(for: selectedMonth))
        }
    }
    @Published public var dashboardPeriodMode: DashboardPeriodMode = .monthly
    @Published public var isHideBalancesEnabled: Bool = false

    public weak var cloudSyncService: CloudSyncService?

    public let databaseFileURL: URL
    public let attachmentsDirectoryURL: URL

    public var effectiveCurrentDate: Date { Date() }

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
            self.categories = decoded.categories.isEmpty ? DefaultCategoriesCatalog.buildInitialCategories() : decoded.categories
            self.transactions = decoded.transactions
            self.investments = decoded.investments
            self.debts = decoded.debts
            self.contracts = decoded.contracts
            self.provisions = decoded.provisions ?? []
            self.categoryQuotas = decoded.categoryQuotas ?? []
            ensureRecurringTransactionsMaterialized(upTo: endOfYear(for: selectedMonth))
        } else {
            self.categories = DefaultCategoriesCatalog.buildInitialCategories()
            self.accounts = []
            self.transactions = []
            self.investments = []
            self.debts = []
            self.contracts = []
            self.provisions = []
            self.categoryQuotas = []
            saveToDisk()
        }
    }

    public func saveToDisk() {
        let snapshot = FinancialDatabaseSnapshot(
            schemaVersion: 3,
            accounts: accounts,
            categories: categories,
            transactions: transactions,
            investments: investments,
            debts: debts,
            contracts: contracts,
            provisions: provisions,
            categoryQuotas: categoryQuotas
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: databaseFileURL, options: .atomic)
        }
    }

    public func save() {
        saveToDisk()
    }

    // MARK: - Helpers de Categoria e Conta

    public func account(for id: UUID?) -> BankAccount? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }
    }

    public func category(for id: UUID?) -> CategoryItem? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    public func fallbackCategoryId(for type: TransactionType, matchingSubstring: String = "") -> UUID {
        if !matchingSubstring.isEmpty,
           let match = categories.first(where: { $0.type == type && $0.name.localizedCaseInsensitiveContains(matchingSubstring) }) {
            return match.id
        }
        return categories.first(where: { $0.type == type })?.id ?? categories.first?.id ?? UUID()
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
        installmentIndex: Int? = nil,
        installmentTotal: Int? = nil,
        seriesGroupId: UUID? = nil,
        linkedContractId: UUID? = nil,
        linkedInvestmentId: UUID? = nil,
        linkedDebtId: UUID? = nil,
        linkedQuotaId: UUID? = nil,
        transactionOrigin: TransactionOrigin? = nil,
        linkedEntityID: UUID? = nil
    ) -> FinancialTransaction {
        let effectiveAccountId: UUID = accounts.contains(where: { $0.id == accountId })
            ? accountId
            : (accounts.first?.id ?? accountId)

        let effectiveCategoryId: UUID = categories.contains(where: { $0.id == categoryId })
            ? categoryId
            : (categories.first(where: { $0.type == type })?.id ?? categories.first?.id ?? categoryId)

        let tx = FinancialTransaction(
            name: name,
            details: details,
            amount: amount,
            date: date,
            type: type,
            isPaid: isPaid,
            categoryId: effectiveCategoryId,
            accountId: effectiveAccountId,
            recurrenceMode: recurrenceMode,
            seriesGroupId: seriesGroupId,
            installmentIndex: installmentIndex,
            installmentTotal: installmentTotal,
            linkedContractId: linkedContractId,
            linkedInvestmentId: linkedInvestmentId,
            linkedDebtId: linkedDebtId,
            linkedQuotaId: linkedQuotaId,
            transactionOrigin: transactionOrigin,
            linkedEntityID: linkedEntityID
        )
        transactions.append(tx)
        sortTransactions()
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: tx.id, operation: .upsert, entity: tx)
        return tx
    }

    public func updateTransaction(_ tx: FinancialTransaction) {
        var validated = tx
        if !accounts.contains(where: { $0.id == validated.accountId }), let fallbackAcc = accounts.first {
            validated.accountId = fallbackAcc.id
        }
        if !categories.contains(where: { $0.id == validated.categoryId }), let fallbackCat = categories.first(where: { $0.type == validated.type }) ?? categories.first {
            validated.categoryId = fallbackCat.id
        }

        if let idx = transactions.firstIndex(where: { $0.id == validated.id }) {
            transactions[idx] = validated
            sortTransactions()
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: validated.id, operation: .upsert, entity: validated)
        }
    }

    public func toggleTransactionPaid(transactionId: UUID) {
        if let idx = transactions.firstIndex(where: { $0.id == transactionId }) {
            transactions[idx].isPaid.toggle()
            let updated = transactions[idx]
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: updated.id, operation: .upsert, entity: updated)
        }
    }

    public func deleteTransaction(_ transactionId: UUID) {
        guard let targetTx = transactions.first(where: { $0.id == transactionId }) else { return }
        revertLinkedEntities(for: targetTx)
        transactions.removeAll { $0.id == transactionId }
        sortTransactions()
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
                investments[idx].balance = max(0.0, investments[idx].balance - tx.amount)
                investments[idx].movements.removeAll { $0.generatedTransactionId == tx.id }
                cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: invId, operation: .upsert, entity: investments[idx])
            }

        case .investmentRedemption:
            if let invId = entityId ?? tx.linkedInvestmentId,
               let idx = investments.firstIndex(where: { $0.id == invId }) {
                investments[idx].balance += tx.amount
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

        let catId: UUID = {
            if movementType == .deposit {
                return fallbackCategoryId(for: .expense, matchingSubstring: "Aportes")
            } else {
                return fallbackCategoryId(for: .income, matchingSubstring: "Resgate")
            }
        }()

        let tx = createTransaction(
            name: "\(movementType.title): \(investments[idx].name)",
            details: notes,
            amount: cleanAmount,
            date: date,
            type: movementType == .deposit ? .expense : .income,
            isPaid: true,
            categoryId: catId,
            accountId: sourceAccountId,
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
        if movementType == .deposit {
            investments[idx].balance += cleanAmount
        } else {
            investments[idx].balance = max(0, investments[idx].balance - cleanAmount)
        }

        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: investments[idx].id, operation: .upsert, entity: investments[idx])
    }

    public var totalInvestedAmount: Double {
        totalInvestmentsBalance
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
        while cursorDate < todayStart && elapsed < totalInstallments {
            elapsed += 1
            cursorDate = calendar.date(byAdding: .month, value: 1, to: cursorDate) ?? cursorDate
        }

        return (min(elapsed, totalInstallments), cursorDate)
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
        baseInstallmentAmount: Double? = nil
    ) -> CreditContract {
        let creditCategoryId = categoryId ?? fallbackCategoryId(for: .expense, matchingSubstring: "Empréstimos")

        let computedSchedule = computePastInstallmentsAndFirstFutureDate(
            startDate: startDate,
            billingDay: billingDay,
            totalInstallments: totalInstallments,
            referenceDate: referenceDate
        )
        let pastCount = min(max(overridePastInstallmentsCount ?? computedSchedule.pastInstallmentsCount, 0), totalInstallments)
        let firstFutureDate = overrideFirstFutureBillingDate ?? computedSchedule.firstFutureBillingDate

        let initialLoanBalance: Double? = {
            if let explicit = outstandingBalance { return explicit }
            guard kind == .loan else { return nil }
            if pastCount > 0 {
                let remaining = max(totalInstallments - pastCount, 0)
                return LoanModel.calculatePresentValue(installment: installmentAmount, monthlyRate: monthlyInterestRate, remaining: remaining)
            }
            return totalContractedAmount
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
            installmentAmount: installmentAmount,
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
            baseInstallmentAmount: baseInstallmentAmount
        )
        contracts.append(contract)

        let remainingToCreate = max(totalInstallments - pastCount, 0)
        for offset in 0..<remainingToCreate {
            let installmentNumber = pastCount + offset + 1
            let dueDate = calendar.date(byAdding: .month, value: offset, to: firstFutureDate) ?? firstFutureDate
            let tx = FinancialTransaction(
                name: "\(name) - Parcela \(installmentNumber)/\(totalInstallments)",
                details: "\(contract.kind.title) (\(contract.subtypeDisplayName)) • Juros \(String(format: "%.2f", monthlyInterestRate))% a.m.",
                amount: installmentAmount,
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
                linkedEntityID: contract.id
            )
            transactions.append(tx)
        }

        sortTransactions()
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contract.id, operation: .upsert, entity: contract)
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
        transactions.removeAll { $0.linkedContractId == contractId || $0.seriesGroupId == contractId }
        contracts.removeAll { $0.id == contractId }
        saveToDisk()
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

            let monthlyRate = contract.monthlyInterestRate
            let pmt = contract.installmentAmount

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
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contract.id, operation: .upsert, entity: contract)
        cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: settleTx.id, operation: .upsert, entity: settleTx)
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
            let realized = transactionsForMonth(monthReference)
                .filter { $0.categoryId == catId && $0.type == .expense && $0.linkedQuotaId == nil }
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
            provisions.removeAll { $0.categoryId == categoryId }
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
                } else if provisions[idx].yearMonthKey == targetKey {
                    provisions.remove(at: idx)
                }
            }
        case .fromThisMonthOnward:
            provisions.removeAll { $0.categoryId == categoryId && $0.yearMonthKey > targetKey }
            for idx in provisions.indices where provisions[idx].categoryId == categoryId {
                if var overrides = provisions[idx].monthlyOverrides {
                    overrides = overrides.filter { $0.key < targetKey }
                    provisions[idx].monthlyOverrides = overrides.isEmpty ? nil : overrides
                }
                if var excluded = provisions[idx].excludedYearMonthKeys {
                    excluded = excluded.filter { $0 < targetKey }
                    provisions[idx].excludedYearMonthKeys = excluded.isEmpty ? nil : excluded
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
                } else {
                    provisions.remove(at: exactIdx)
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
            }
        }

        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: categoryId, operation: .delete)
    }

    public func createCategoryQuotaRule(
        categoryId: UUID,
        name: String,
        iconSymbol: String = "shippingbox.fill",
        year: Int,
        month: Int,
        plannedQuantity: Int,
        estimatedUnitPrice: Double,
        repeatForFutureMonths: Bool = true
    ) {
        let quota = CategoryQuotaRule(
            categoryId: categoryId,
            name: name,
            iconSymbol: iconSymbol,
            year: year,
            month: month,
            plannedQuantity: plannedQuantity,
            estimatedUnitPrice: estimatedUnitPrice,
            repeatForFutureMonths: repeatForFutureMonths
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
            let ruleName = override?.name ?? rule.name

            let linkedTxs = transactionsForMonth(monthReference).filter { $0.linkedQuotaId == rule.id || $0.linkedQuotaId == rule.seriesId }
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
            categoryQuotas.removeAll { $0.seriesId == seriesId }
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
                } else if categoryQuotas[idx].yearMonthKey == targetKey {
                    categoryQuotas.remove(at: idx)
                }
            }
        case .fromThisMonthOnward:
            categoryQuotas.removeAll { $0.seriesId == seriesId && $0.yearMonthKey > targetKey }
            for idx in categoryQuotas.indices where categoryQuotas[idx].seriesId == seriesId {
                if var overrides = categoryQuotas[idx].monthlyOverrides {
                    overrides = overrides.filter { $0.key < targetKey }
                    categoryQuotas[idx].monthlyOverrides = overrides.isEmpty ? nil : overrides
                }
                if var excluded = categoryQuotas[idx].excludedYearMonthKeys {
                    excluded = excluded.filter { $0 < targetKey }
                    categoryQuotas[idx].excludedYearMonthKeys = excluded.isEmpty ? nil : excluded
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
                } else {
                    categoryQuotas.remove(at: exactIdx)
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
                    repeatForFutureMonths: true
                )
                categoryQuotas.append(stopper)
            }
        }

        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: seriesId, operation: .delete)
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
        year: Int,
        month: Int,
        quantity: Int,
        unitPrice: Double,
        repeatForFuture: Bool = true
    ) {
        createCategoryQuotaRule(
            categoryId: categoryId,
            name: name,
            year: year,
            month: month,
            plannedQuantity: quantity,
            estimatedUnitPrice: unitPrice,
            repeatForFutureMonths: repeatForFuture
        )
    }

    public func redeemQuotaUnits(
        quotaId: UUID,
        units: Int,
        accountId: UUID,
        date: Date = Date()
    ) {
        guard let rule = categoryQuotas.first(where: { $0.id == quotaId || $0.seriesId == quotaId }) else { return }
        let totalAmount = Double(units) * rule.estimatedUnitPrice
        createTransaction(
            name: "\(rule.name) (\(units) un.)",
            details: "Baixa de cota",
            amount: totalAmount,
            date: date,
            type: .expense,
            isPaid: true,
            categoryId: rule.categoryId,
            accountId: accountId,
            linkedQuotaId: rule.id,
            transactionOrigin: .quotaAllocation
        )
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
        transactions.filter { isInMonth($0.date, monthReference: monthReference) }
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
            .reduce(0.0) { $0 + $1.amount }
    }

    public func monthlyExpense(for month: Date) -> Double {
        transactionsForMonth(month)
            .filter { $0.type == .expense && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func monthlyPaidExpense(for month: Date) -> Double {
        transactionsForMonth(month)
            .filter { $0.type == .expense && $0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func monthlyPendingExpenses(for month: Date) -> Double {
        transactionsForMonth(month)
            .filter { $0.type == .expense && !$0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func monthlyPendingExpense(for month: Date) -> Double {
        monthlyPendingExpenses(for: month)
    }

    public func monthlyReceivedIncome(for month: Date) -> Double {
        transactionsForMonth(month)
            .filter { $0.type == .income && $0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func monthlyPendingIncome(for month: Date) -> Double {
        transactionsForMonth(month)
            .filter { $0.type == .income && !$0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func monthlyNetBalance(for month: Date) -> Double {
        monthlyIncome(for: month) - monthlyExpense(for: month)
    }

    public func transactionsForYear(_ yearReference: Date) -> [FinancialTransaction] {
        transactions
            .filter { isInYear($0.date, yearReference: yearReference) }
            .sorted { a, b in
                if a.date == b.date { return a.createdAt > b.createdAt }
                return a.date > b.date
            }
    }

    public func annualIncome(for yearReference: Date) -> Double {
        transactions.filter { isInYear($0.date, yearReference: yearReference) && $0.type == .income && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func annualExpense(for yearReference: Date) -> Double {
        transactions.filter { isInYear($0.date, yearReference: yearReference) && $0.type == .expense && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func annualPaidExpense(for yearReference: Date) -> Double {
        transactions.filter { isInYear($0.date, yearReference: yearReference) && $0.type == .expense && $0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func annualPendingExpense(for yearReference: Date) -> Double {
        transactions.filter { isInYear($0.date, yearReference: yearReference) && $0.type == .expense && !$0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func annualReceivedIncome(for yearReference: Date) -> Double {
        transactions.filter { isInYear($0.date, yearReference: yearReference) && $0.type == .income && $0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func annualPendingIncome(for yearReference: Date) -> Double {
        transactions.filter { isInYear($0.date, yearReference: yearReference) && $0.type == .income && !$0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
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
                guard tx.date <= cutoff else { return false }
                return includeProjectedUnpaid ? true : tx.isPaid
            }
            .reduce(0.0) { $0 + $1.signedAmount }

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
            .filter { $0.type == type && !$0.ignoreInConsolidated }
        let grandTotal = monthTxs.reduce(0.0) { $0 + $1.amount }
        guard grandTotal > 0 else { return [] }

        var grouped: [UUID: (sum: Double, count: Int)] = [:]
        for tx in monthTxs {
            let current = grouped[tx.categoryId] ?? (0.0, 0)
            grouped[tx.categoryId] = (current.sum + tx.amount, current.count + 1)
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
        let yearTxs = transactions
            .filter { isInYear($0.date, yearReference: yearReference) && $0.type == type && !$0.ignoreInConsolidated }
        let grandTotal = yearTxs.reduce(0.0) { $0 + $1.amount }
        guard grandTotal > 0 else { return [] }

        var grouped: [UUID: (sum: Double, count: Int)] = [:]
        for tx in yearTxs {
            let current = grouped[tx.categoryId] ?? (0.0, 0)
            grouped[tx.categoryId] = (current.sum + tx.amount, current.count + 1)
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
            (isAnnual ? isInYear(tx.date, yearReference: referenceDate) : isInMonth(tx.date, monthReference: referenceDate))
        }

        let endOfCurrentPeriod = isAnnual ? endOfYear(for: referenceDate) : endOfMonth(for: referenceDate)
        let futureRegularUnpaid = transactions.filter { tx in
            tx.type == .expense &&
            !tx.isPaid &&
            !tx.ignoreInConsolidated &&
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
            let txs = transactions.filter {
                isInYear($0.date, yearReference: referenceDate) &&
                $0.type == .expense &&
                $0.linkedContractId != nil &&
                ids.contains($0.linkedContractId!)
            }.reduce(0.0) { $0 + $1.amount }
            if txs > 0 { return txs }
            return active.reduce(0.0) { $0 + ($1.installmentAmount * 12.0) }
        } else {
            let txs = transactionsForMonth(referenceDate).filter {
                $0.type == .expense &&
                $0.linkedContractId != nil &&
                ids.contains($0.linkedContractId!)
            }.reduce(0.0) { $0 + $1.amount }
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
        let expenseTxs = periodTxs.filter { $0.type == .expense }

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

        // 4. Despesas: Pagas, Pendentes, Fixas vs Variáveis
        let paidExpense = expenseTxs.filter(\.isPaid).reduce(0.0) { $0 + $1.amount }
        let pendingExpenseTxs = expenseTxs.filter { !$0.isPaid }
        let pendingExpense = pendingExpenseTxs.reduce(0.0) { $0 + $1.amount }

        let overdueExpenses = pendingExpenseTxs.filter { calendar.startOfDay(for: $0.date) < todayStart }.reduce(0.0) { $0 + $1.amount }
        let onTimePendingExpenses = pendingExpenseTxs.filter { calendar.startOfDay(for: $0.date) >= todayStart }.reduce(0.0) { $0 + $1.amount }

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

        let fixedExpenses = expenseTxs.filter { $0.isFixedExpense && (isClosed ? $0.isPaid : true) }.reduce(0.0) { $0 + $1.amount }
        let variableExpenses = expenseTxs.filter { $0.isVariableExpense && (isClosed ? $0.isPaid : true) }.reduce(0.0) { $0 + $1.amount }
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
                guard tx.date <= cutoffDate else { return false }
                return isClosed ? tx.isPaid : true
            }
            .reduce(0.0) { $0 + $1.signedAmount }
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
        categories.removeAll()
        investments.removeAll()
        debts.removeAll()
        contracts.removeAll()
        provisions.removeAll()
        categoryQuotas.removeAll()
        saveToDisk()
        cloudSyncService?.resetSyncState()
    }
}
