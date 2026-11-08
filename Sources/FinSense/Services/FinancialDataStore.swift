// Sources/FinSense/Services/FinancialDataStore.swift
import Foundation
import SwiftUI
import Combine

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
    public var chatHistory: [ChatMessage]

    public init(
        schemaVersion: Int? = 2,
        accounts: [BankAccount] = [],
        categories: [CategoryItem] = [],
        transactions: [FinancialTransaction] = [],
        investments: [InvestmentItem] = [],
        debts: [DebtItem] = [],
        contracts: [CreditContract] = [],
        provisions: [CategoryProvision]? = [],
        categoryQuotas: [CategoryQuotaRule]? = [],
        chatHistory: [ChatMessage] = []
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
        self.chatHistory = chatHistory
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
    @Published public var chatHistory: [ChatMessage] = []

    @Published public var selectedMonth: Date = Date()
    @Published public var isHideBalancesEnabled: Bool = false

    public weak var cloudSyncService: CloudSyncService?

    public let databaseFileURL: URL
    public let attachmentsDirectoryURL: URL

    private let calendar: Calendar = {
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
            self.chatHistory = decoded.chatHistory
        } else {
            // Inicialização limpa com catálogo padrão
            self.categories = DefaultCategoriesCatalog.buildInitialCategories()
            self.accounts = []
            self.transactions = []
            self.investments = []
            self.debts = []
            self.contracts = []
            self.provisions = []
            self.categoryQuotas = []
            self.chatHistory = [
                ChatMessage(
                    role: .assistant,
                    content: "Olá! Sou o FinSense AI. Estou pronto para analisar suas finanças, orçamentos, projeções de amortização e estratégias de quitação."
                )
            ]
            saveToDisk()
        }
    }

    public func saveToDisk() {
        let snapshot = FinancialDatabaseSnapshot(
            schemaVersion: 2,
            accounts: accounts,
            categories: categories,
            transactions: transactions,
            investments: investments,
            debts: debts,
            contracts: contracts,
            provisions: provisions,
            categoryQuotas: categoryQuotas,
            chatHistory: chatHistory
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: databaseFileURL, options: .atomic)
        }
    }

    public func save() {
        saveToDisk()
    }

    // MARK: - Métricas e Diagnósticos Financeiros

    public func accountBalance(for accountId: UUID) -> Double {
        guard let account = accounts.first(where: { $0.id == accountId }) else { return 0.0 }
        let txs = transactions.filter { $0.accountId == accountId && $0.isPaid }
        let txSum = txs.reduce(0.0) { $0 + $1.signedAmount }
        return account.initialBalance + txSum
    }

    public var totalCurrentBalance: Double {
        accounts.reduce(0.0) { $0 + accountBalance(for: $1.id) }
    }

    public var totalDebtAmount: Double {
        debts.filter { !$0.isPaid }.reduce(0.0) { $0 + ($1.negotiatedAmount ?? $1.originalAmount) }
    }

    public var totalInvestedAmount: Double {
        investments.reduce(0.0) { $0 + $1.balance }
    }

    public func transactions(for date: Date) -> [FinancialTransaction] {
        let comp = calendar.dateComponents([.year, .month], from: date)
        return transactions.filter {
            let txComp = calendar.dateComponents([.year, .month], from: $0.date)
            return txComp.year == comp.year && txComp.month == comp.month
        }
    }

    public func monthlyIncome(for date: Date) -> Double {
        transactions(for: date)
            .filter { $0.type == .income && $0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func monthlyExpense(for date: Date) -> Double {
        transactions(for: date)
            .filter { $0.type == .expense && $0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func monthlyPendingExpenses(for date: Date) -> Double {
        transactions(for: date)
            .filter { $0.type == .expense && !$0.isPaid && !$0.ignoreInConsolidated }
            .reduce(0.0) { $0 + $1.amount }
    }

    public func monthlyNetBalance(for date: Date) -> Double {
        monthlyIncome(for: date) - monthlyExpense(for: date)
    }

    public func financialHealthScore(for date: Date) -> Int {
        let income = monthlyIncome(for: date)
        let expense = monthlyExpense(for: date)
        guard income > 0 else { return expense > 0 ? 30 : 50 }

        let savingsRatio = (income - expense) / income
        if savingsRatio >= 0.3 {
            return min(100, Int(75 + (savingsRatio - 0.3) * 50))
        } else if savingsRatio >= 0.1 {
            return Int(60 + (savingsRatio - 0.1) * 75)
        } else if savingsRatio >= 0.0 {
            return Int(50 + savingsRatio * 100)
        } else {
            let deficit = abs(savingsRatio)
            return max(10, Int(50 - deficit * 50))
        }
    }

    // MARK: - CRUD: Contas

    public func createAccount(
        name: String,
        bankPresetId: String? = nil,
        iconSymbol: String = "building.columns.fill",
        colorHex: String = "#EC7000",
        initialBalance: Double = 0.0,
        agency: String = "",
        accountNumber: String = ""
    ) {
        let account = BankAccount(
            name: name,
            bankPresetId: bankPresetId,
            iconSymbol: iconSymbol,
            colorHex: colorHex,
            initialBalance: initialBalance,
            agency: agency,
            accountNumber: accountNumber
        )
        accounts.append(account)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "bank_accounts", entityId: account.id, operation: .upsert, entity: account)
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
        cloudSyncService?.recordLocalMutation(entityName: "bank_accounts", entityId: accountId, operation: .delete, entity: Optional<BankAccount>.none)
    }

    // MARK: - CRUD: Categorias

    public func createCategory(
        name: String,
        type: TransactionType,
        iconSymbol: String = "tag.fill",
        colorHex: String = "#3B82F6",
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
        provisions.removeAll { $0.categoryId == categoryId }
        categoryQuotas.removeAll { $0.categoryId == categoryId }
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "categories", entityId: categoryId, operation: .delete, entity: Optional<CategoryItem>.none)
    }

    // MARK: - CRUD: Transações

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
        seriesGroupId: UUID? = nil
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
            installmentTotal: installmentTotal
        )
        transactions.append(tx)
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
        transactions.removeAll { $0.id == transactionId }
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: transactionId, operation: .delete, entity: Optional<FinancialTransaction>.none)
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
        cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: investmentId, operation: .delete, entity: Optional<InvestmentItem>.none)
    }

    public func recordInvestmentMovement(
        investmentId: UUID,
        type: InvestmentMovementType,
        amount: Double,
        sourceAccountId: UUID,
        date: Date = Date(),
        notes: String = ""
    ) {
        guard let idx = investments.firstIndex(where: { $0.id == investmentId }) else { return }

        // Cria transação bancária correspondente
        let catId: UUID = {
            if type == .deposit {
                return categories.first(where: { $0.name.contains("Aporte") || $0.name.contains("Investimento") })?.id ?? categories.first!.id
            } else {
                return categories.first(where: { $0.name.contains("Resgate") })?.id ?? categories.first!.id
            }
        }()

        let tx = createTransaction(
            name: "\(type.title): \(investments[idx].name)",
            details: notes,
            amount: amount,
            date: date,
            type: type == .deposit ? .expense : .income,
            isPaid: true,
            categoryId: catId,
            accountId: sourceAccountId
        )

        let mov = InvestmentMovement(
            type: type,
            amount: amount,
            date: date,
            sourceAccountId: sourceAccountId,
            investmentAccountId: investments[idx].investmentAccountId,
            notes: notes,
            generatedTransactionId: tx.id
        )

        investments[idx].movements.append(mov)
        if type == .deposit {
            investments[idx].balance += amount
        } else {
            investments[idx].balance = max(0, investments[idx].balance - amount)
        }

        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "investment_items", entityId: investments[idx].id, operation: .upsert, entity: investments[idx])
    }

    // MARK: - CRUD: Dívidas

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
        cloudSyncService?.recordLocalMutation(entityName: "debt_items", entityId: debtId, operation: .delete, entity: Optional<DebtItem>.none)
    }

    public func markDebtPaid(debtId: UUID, negotiatedAmount: Double, paidFromAccountId: UUID) {
        guard let idx = debts.firstIndex(where: { $0.id == debtId }) else { return }

        let catId = categories.first(where: { $0.name.contains("Dívida") || $0.name.contains("Quitação") })?.id ?? categories.first!.id
        let tx = createTransaction(
            name: "Quitação de Dívida: \(debts[idx].name)",
            details: "Acordo liquidado",
            amount: negotiatedAmount,
            date: Date(),
            type: .expense,
            isPaid: true,
            categoryId: catId,
            accountId: paidFromAccountId
        )

        debts[idx].isPaid = true
        debts[idx].negotiatedAmount = negotiatedAmount
        debts[idx].paidDate = Date()
        debts[idx].paidFromAccountId = paidFromAccountId
        debts[idx].paymentTransactionId = tx.id

        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "debt_items", entityId: debts[idx].id, operation: .upsert, entity: debts[idx])
    }

    // MARK: - CRUD: Financiamentos e Empréstimos

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
        let contract = CreditContract(
            kind: kind,
            name: name,
            loanSubtype: loanSubtype,
            financingSubtype: financingSubtype,
            amortizationSystem: amortizationSystem,
            totalContractedAmount: totalContractedAmount,
            outstandingBalance: totalContractedAmount,
            installmentAmount: installmentAmount,
            billingDay: billingDay,
            totalInstallments: totalInstallments,
            monthlyInterestRate: monthlyInterestRate,
            startDate: Date(),
            accountId: accountId,
            categoryId: categoryId
        )
        contracts.append(contract)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contract.id, operation: .upsert, entity: contract)
    }

    public func updateContract(_ contract: CreditContract) {
        if let idx = contracts.firstIndex(where: { $0.id == contract.id }) {
            contracts[idx] = contract
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contract.id, operation: .upsert, entity: contract)
        }
    }

    public func deleteContract(_ contractId: UUID) {
        contracts.removeAll { $0.id == contractId }
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contractId, operation: .delete, entity: Optional<CreditContract>.none)
    }

    public func recordAmortization(
        contractId: UUID,
        amount: Double,
        mode: AmortizationRecalculationMode,
        paidFromAccountId: UUID,
        notes: String = ""
    ) {
        guard let idx = contracts.firstIndex(where: { $0.id == contractId }) else { return }

        let contract = contracts[idx]
        let currentBalance = contract.outstandingBalance ?? contract.totalContractedAmount
        let newBalance = max(0, currentBalance - amount)

        let tx = createTransaction(
            name: "Amortização Extraordinária: \(contract.name)",
            details: "\(mode.rawValue) • \(notes)",
            amount: amount,
            date: Date(),
            type: .expense,
            isPaid: true,
            categoryId: contract.categoryId,
            accountId: paidFromAccountId
        )

        var newInstallmentAmount = contract.installmentAmount
        var newRemainingInstallments = max(0, contract.totalInstallments - contract.pastInstallmentsElapsedAtCreation)

        if mode == .reduceTerm {
            // Estima redução de parcelas mantendo valor da parcela
            let monthlyRate = (contract.monthlyInterestRate / 100.0)
            if monthlyRate > 0 && newInstallmentAmount > 0 {
                let estimatedRemainingMonths = log(newInstallmentAmount / (newInstallmentAmount - newBalance * monthlyRate)) / log(1.0 + monthlyRate)
                if !estimatedRemainingMonths.isNaN && estimatedRemainingMonths > 0 {
                    newRemainingInstallments = max(1, Int(estimatedRemainingMonths.rounded(.up)))
                }
            }
        } else {
            // Estima redução do valor da parcela mantendo prazo
            let monthlyRate = (contract.monthlyInterestRate / 100.0)
            let n = Double(max(1, newRemainingInstallments))
            if monthlyRate > 0 {
                newInstallmentAmount = (newBalance * monthlyRate * pow(1.0 + monthlyRate, n)) / (pow(1.0 + monthlyRate, n) - 1.0)
            } else {
                newInstallmentAmount = newBalance / n
            }
        }

        let record = AmortizationRecord(
            amountPaid: amount,
            mode: mode,
            previousInstallmentAmount: contract.installmentAmount,
            newInstallmentAmount: newInstallmentAmount,
            previousRemainingInstallments: max(0, contract.totalInstallments - contract.pastInstallmentsElapsedAtCreation),
            newRemainingInstallments: newRemainingInstallments,
            accountId: paidFromAccountId,
            transactionId: tx.id,
            notes: notes
        )

        contracts[idx].outstandingBalance = newBalance
        contracts[idx].extraAmortizedTotal += amount
        contracts[idx].installmentAmount = newInstallmentAmount
        contracts[idx].amortizationHistory.append(record)

        if newBalance <= 0.01 {
            contracts[idx].isSettled = true
            contracts[idx].settledDate = Date()
            contracts[idx].settledAmount = amount
        }

        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "credit_contracts", entityId: contracts[idx].id, operation: .upsert, entity: contracts[idx])
    }

    // MARK: - CRUD: Provisões e Cotas

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
            let prov = CategoryProvision(
                categoryId: categoryId,
                year: year,
                month: month,
                estimatedAmount: amount,
                repeatForFutureMonths: repeatForFuture
            )
            provisions.append(prov)
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: prov.id, operation: .upsert, entity: prov)
        }
    }

    public func deleteProvision(_ provisionId: UUID) {
        provisions.removeAll { $0.id == provisionId }
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "category_provisions", entityId: provisionId, operation: .delete, entity: Optional<CategoryProvision>.none)
    }

    public func createQuota(
        categoryId: UUID,
        name: String,
        iconSymbol: String = "shippingbox.fill",
        year: Int,
        month: Int,
        quantity: Int,
        unitPrice: Double,
        repeatForFuture: Bool = true
    ) {
        let quota = CategoryQuotaRule(
            categoryId: categoryId,
            name: name,
            iconSymbol: iconSymbol,
            year: year,
            month: month,
            plannedQuantity: quantity,
            estimatedUnitPrice: unitPrice,
            repeatForFutureMonths: repeatForFuture
        )
        categoryQuotas.append(quota)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: quota.id, operation: .upsert, entity: quota)
    }

    public func updateQuota(_ quota: CategoryQuotaRule) {
        if let idx = categoryQuotas.firstIndex(where: { $0.id == quota.id }) {
            categoryQuotas[idx] = quota
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: quota.id, operation: .upsert, entity: quota)
        }
    }

    public func deleteQuota(_ quotaId: UUID) {
        categoryQuotas.removeAll { $0.id == quotaId }
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "category_quota_rules", entityId: quotaId, operation: .delete, entity: Optional<CategoryQuotaRule>.none)
    }

    public func redeemQuotaUnits(
        quotaId: UUID,
        units: Int,
        accountId: UUID,
        date: Date = Date(),
        unitPrice: Double? = nil
    ) {
        guard let quota = categoryQuotas.first(where: { $0.id == quotaId }) else { return }
        let effectiveUnitPrice = unitPrice ?? quota.estimatedUnitPrice
        let totalAmount = Double(units) * effectiveUnitPrice
        let yearMonthKey = calendar.component(.year, from: date) * 100 + calendar.component(.month, from: date)

        let tx = createTransaction(
            name: "Baixa de Cota: \(quota.name) (\(units)x)",
            details: "Cota resgatada no valor de R$ \(effectiveUnitPrice) un.",
            amount: totalAmount,
            date: date,
            type: .expense,
            isPaid: true,
            categoryId: quota.categoryId,
            accountId: accountId
        )

        if let idx = transactions.firstIndex(where: { $0.id == tx.id }) {
            transactions[idx].linkedQuotaId = quota.id
            transactions[idx].linkedQuotaUnits = units
            transactions[idx].linkedQuotaYearMonthKey = yearMonthKey
            saveToDisk()
            cloudSyncService?.recordLocalMutation(entityName: "financial_transactions", entityId: transactions[idx].id, operation: .upsert, entity: transactions[idx])
        }
    }

    public func calculateQuotaEnvelopes(for date: Date) -> [CategoryQuotaEnvelope] {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let targetKey = year * 100 + month

        var result: [CategoryQuotaEnvelope] = []
        for rule in categoryQuotas {
            let isCurrentOrPast = (rule.year < year) || (rule.year == year && rule.month <= month)
            guard (rule.year == year && rule.month == month) || (rule.repeatForFutureMonths && isCurrentOrPast) else { continue }

            let override = rule.monthlyOverrides?[targetKey]
            let plannedQty = override?.plannedQuantity ?? rule.plannedQuantity
            let unitPrice = override?.estimatedUnitPrice ?? rule.estimatedUnitPrice
            let quotaName = override?.name ?? rule.name

            // Unidades consumidas no mês
            let consumed = transactions.filter {
                $0.linkedQuotaId == rule.id && $0.linkedQuotaYearMonthKey == targetKey
            }.reduce(0) { $0 + ($1.linkedQuotaUnits ?? 1) }

            let realized = transactions.filter {
                $0.linkedQuotaId == rule.id && $0.linkedQuotaYearMonthKey == targetKey
            }.reduce(0.0) { $0 + $1.amount }

            let env = CategoryQuotaEnvelope(
                rule: rule,
                name: quotaName,
                iconSymbol: rule.iconSymbol,
                plannedQuantity: plannedQty,
                consumedUnits: consumed,
                estimatedUnitPrice: unitPrice,
                realizedExpense: realized,
                repeatForFutureMonths: rule.repeatForFutureMonths,
                isInheritedFromPreviousMonth: (rule.year != year || rule.month != month),
                isLocalMonthOverride: override != nil
            )
            result.append(env)
        }
        return result
    }

    public func calculateProvisionEnvelopes(for date: Date) -> [CategoryProvisionEnvelope] {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let targetKey = year * 100 + month

        var result: [CategoryProvisionEnvelope] = []
        for category in categories.filter({ $0.type == .expense }) {
            let matchProv = provisions.first(where: {
                $0.categoryId == category.id &&
                (($0.year == year && $0.month == month) || ($0.repeatForFutureMonths && (($0.year < year) || ($0.year == year && $0.month <= month))))
            })

            let prov = matchProv ?? CategoryProvision(categoryId: category.id, year: year, month: month, estimatedAmount: 0.0, repeatForFutureMonths: true)
            let overrideAmount = prov.monthlyOverrides?[targetKey]
            let estimated = overrideAmount ?? prov.estimatedAmount

            // Gasto real do mês desconsiderando cotas
            let monthTxs = transactions(for: date).filter {
                $0.categoryId == category.id && $0.type == .expense && $0.isPaid && $0.linkedQuotaId == nil
            }
            let realized = monthTxs.reduce(0.0) { $0 + $1.amount }

            let env = CategoryProvisionEnvelope(
                category: category,
                provision: prov,
                isInheritedFromPreviousMonth: (prov.year != year || prov.month != month),
                estimatedAmount: estimated,
                realizedExpense: realized,
                isFreeBudgetLocalOverride: overrideAmount != nil
            )
            result.append(env)
        }
        return result
    }

    // MARK: - Chat History

    public func addChatMessage(role: ChatMessageRole, content: String, modelUsed: String? = nil) {
        let msg = ChatMessage(role: role, content: content, modelUsed: modelUsed)
        chatHistory.append(msg)
        saveToDisk()
        cloudSyncService?.recordLocalMutation(entityName: "chat_messages", entityId: msg.id, operation: .upsert, entity: msg)
    }

    public func clearChatHistory() {
        chatHistory.removeAll()
        saveToDisk()
    }

    public func resetAllData() {
        transactions.removeAll()
        accounts.removeAll()
        categories.removeAll()
        investments.removeAll()
        debts.removeAll()
        contracts.removeAll()
        provisions.removeAll()
        categoryQuotas.removeAll()
        save()
        cloudSyncService?.resetSyncState()
    }
}
