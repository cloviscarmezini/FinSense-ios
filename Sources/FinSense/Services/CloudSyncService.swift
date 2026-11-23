// Sources/FinSense/Services/CloudSyncService.swift
import Foundation
import Combine
import Network
import SwiftUI
import UIKit

@MainActor
public final class CloudSyncService: ObservableObject {
    @Published public var syncStatus: SyncStatus = .disabled
    @Published public var isSyncing: Bool = false
    @Published public var pendingMutationsCount: Int = 0
    @Published public var lastSyncDate: Date? = nil

    @AppStorage("cloud_sync_enabled") public var isEnabled: Bool = false {
        didSet {
            evaluateInitialStatus()
        }
    }
    @AppStorage("cloud_sync_base_url") public var baseURLString: String = AppConfiguration.shared.apiBaseURL
    @AppStorage("cloud_sync_client_id") public var clientId: String = UUID().uuidString
    @AppStorage("cloud_sync_last_revision") public var lastServerRevision: Int = 0
    @AppStorage("cloud_sync_last_user_id") public var lastSyncedUserId: String = ""
    @AppStorage("cloud_sync_initial_seeded") private var hasSeededInitialData: Bool = false

    public var canSync: Bool {
        isEnabled && (authService?.isAuthenticated ?? false)
    }

    private var outboxQueue: [LocalSyncMutation] = []
    private let outboxFileURL: URL
    private let outboxPersistenceQueue = DispatchQueue(label: "br.com.finsense.ios.outboxPersistence", qos: .utility)
    private static let payloadEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private static let isoFormatter = ISO8601DateFormatter()
    private var debounceTimer: AnyCancellable? = nil
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable: Bool = true
    private var authCancellable: AnyCancellable? = nil

    public weak var store: FinancialDataStore?
    public weak var authService: AuthService? {
        didSet {
            guard authService !== oldValue else { return }
            authCancellable?.cancel()
            authCancellable = authService?.$isAuthenticated
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isAuth in
                    guard let self else { return }
                    self.handleAuthChange(isAuth: isAuth)
                }
            evaluateInitialStatus()
        }
    }

    private func handleAuthChange(isAuth: Bool) {
        if isAuth {
            let currentUserId = authService?.currentUser?.id.uuidString ?? ""
            if !currentUserId.isEmpty && currentUserId != lastSyncedUserId {
                lastSyncedUserId = currentUserId
                lastServerRevision = 0
                outboxQueue.removeAll()
                saveOutboxQueue()
            }
            evaluateInitialStatus()
        } else {
            lastSyncedUserId = ""
            evaluateInitialStatus()
        }
    }

    public func resetSyncState() {
        lastServerRevision = 0
        lastSyncDate = nil
        outboxQueue.removeAll()
        saveOutboxQueue()
        pendingMutationsCount = 0
        evaluateInitialStatus()
    }

    public func resetCloudData(targets: [String]? = nil) async throws {
        let token = authService?.accessToken ?? BackendAPIClient.shared.bearerToken
        try await BackendAPIClient.shared.resetCloudData(baseURL: baseURLString, targets: targets, token: token)
        await MainActor.run {
            self.resetSyncState()
        }
    }

    private func enqueueMutation(_ mutation: LocalSyncMutation) {
        if let existingIndex = outboxQueue.firstIndex(where: { $0.entityName == mutation.entityName && $0.entityId == mutation.entityId }) {
            outboxQueue[existingIndex] = mutation
        } else {
            outboxQueue.append(mutation)
        }
    }

    public init(store: FinancialDataStore? = nil, authService: AuthService? = nil) {
        self.store = store
        self.authService = authService
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.outboxFileURL = docs.appendingPathComponent("sync_outbox_queue.json")
        
        if let envBaseURL = ProcessInfo.processInfo.environment["API_BASE_URL"], !envBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.baseURLString = envBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        loadOutboxQueue()
        startNetworkMonitoring()
        evaluateInitialStatus()
    }

    public func evaluateInitialStatus() {
        if !isEnabled || !(authService?.isAuthenticated ?? false) {
            syncStatus = .disabled
        } else if !outboxQueue.isEmpty {
            syncStatus = .outOfSync(pendingCount: outboxQueue.count, reason: "Alterações pendentes")
        } else if let last = lastSyncDate {
            syncStatus = .synced(lastSync: last)
        } else {
            syncStatus = .synced(lastSync: Date())
        }
    }

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                self.isNetworkAvailable = (path.status == .satisfied)
                let isAuth = self.authService?.isAuthenticated ?? false
                if !self.isNetworkAvailable && self.isEnabled && isAuth {
                    self.syncStatus = .outOfSync(
                        pendingCount: self.outboxQueue.count,
                        reason: "Sem conexão com a internet"
                    )
                }
            }
        }
        let queue = DispatchQueue(label: "br.com.finsense.ios.syncNetworkMonitor")
        networkMonitor.start(queue: queue)
    }

    /// Mantido apenas por compatibilidade; a sincronização agora é estritamente manual
    /// (via Configurações ou pull-to-refresh no início do Dashboard).
    public func syncOnAppEntry() {
        evaluateInitialStatus()
    }

    public func recordLocalMutation<T: Codable>(
        entityName: String,
        entityId: UUID,
        operation: SyncOperation,
        entity: T? = nil
    ) {
        guard isEnabled else { return }

        let payloadJSON: String? = {
            guard let entity, operation != .delete else { return nil }
            guard let data = try? Self.payloadEncoder.encode(entity),
                  let str = String(data: data, encoding: .utf8) else { return nil }
            return str
        }()

        let mutation = LocalSyncMutation(
            entityName: entityName,
            entityId: entityId,
            operation: operation,
            updatedAt: Date(),
            payloadJSON: payloadJSON
        )

        enqueueMutation(mutation)
        saveOutboxQueue()
        pendingMutationsCount = outboxQueue.count
        syncStatus = .outOfSync(pendingCount: outboxQueue.count, reason: "Alterações pendentes")
    }

    public func recordLocalMutation(
        entityName: String,
        entityId: UUID,
        operation: SyncOperation
    ) {
        recordLocalMutation(entityName: entityName, entityId: entityId, operation: operation, entity: Optional<String>.none)
    }

    public func scheduleSync(delaySeconds: Double) {
        // Sincronização automática desativada: apenas manual pelas Configurações ou pull-to-refresh no Dashboard.
    }

    public func performSync() {
        Task {
            await performManualSync()
        }
    }

    public func performManualSync() async {
        let isAuth = authService?.isAuthenticated ?? false
        guard isEnabled, isAuth else {
            syncStatus = .disabled
            return
        }
        guard isNetworkAvailable else {
            syncStatus = .outOfSync(pendingCount: outboxQueue.count, reason: "Sem internet")
            return
        }
        guard !isSyncing else { return }

        isSyncing = true
        syncStatus = .syncing
        await executeSyncPushPull()
        isSyncing = false
    }

    private func executeSyncPushPull(hasRetriedAuth: Bool = false) async {
        guard let store else { return }

        var remainingBatches = 20
        while remainingBatches > 0 {
            remainingBatches -= 1

            let isLocalEmpty = store.transactions.isEmpty && store.accounts.isEmpty && store.categories.isEmpty && store.contracts.isEmpty && store.investments.isEmpty && store.debts.isEmpty
            let effectiveSinceRevision: Int64 = isLocalEmpty ? 0 : Int64(lastServerRevision)

            let batchToSend = Array(outboxQueue.prefix(250))
            let payload = SyncPushPullRequest(
                clientId: clientId,
                sinceRevision: effectiveSinceRevision,
                mutations: batchToSend.map { mut in
                    SyncMutationDTO(
                        mutationId: mut.id,
                        entityName: mut.entityName,
                        entityId: mut.entityId,
                        operation: mut.operation.rawValue,
                        updatedAt: Self.isoFormatter.string(from: mut.updatedAt),
                        payload: mut.payloadJSON.flatMap { try? JSONDecoder().decode([String: AnyCodableValue].self, from: Data($0.utf8)) }
                    )
                }
            )

            // Garante token renovado antes da sincronização
            let currentToken = await authService?.ensureFreshToken(baseURL: baseURLString) ?? authService?.accessToken

            do {
                let response = try await BackendAPIClient.shared.pushPull(
                    baseURL: baseURLString,
                    requestPayload: payload,
                    token: currentToken
                )

                let ackIds = response.acknowledgedMutationIds
                let processedSet: Set<UUID> = Set(ackIds)
                let previousOutboxCount = outboxQueue.count
                outboxQueue.removeAll { (item: LocalSyncMutation) in processedSet.contains(item.id) }
                saveOutboxQueue()
                pendingMutationsCount = outboxQueue.count

                if let deltas = response.deltas {
                    applyDeltasToStore(deltas, tombstones: response.tombstones ?? [], into: store)
                }
                if let changes = response.serverChanges, !changes.isEmpty {
                    applyServerChanges(changes, into: store)
                }

                let serverIsEmpty = response.latestRevision == 0 && (response.serverChanges?.isEmpty ?? true) && (response.deltas?.isEmpty ?? true)
                let hasLocalData = !store.transactions.isEmpty || !store.accounts.isEmpty || !store.categories.isEmpty || !store.contracts.isEmpty || !store.investments.isEmpty || !store.debts.isEmpty || !store.provisions.isEmpty || !store.categoryQuotas.isEmpty

                if serverIsEmpty && hasLocalData && outboxQueue.isEmpty && lastServerRevision == 0 && !hasSeededInitialData {
                    print("⚡️ [FinSense-iOS] Servidor vazio detectado com dados locais: realizando auto-seed de envio inicial...")
                    hasSeededInitialData = true
                    enqueueAllLocalData()
                }

                lastServerRevision = Int(response.latestRevision)
                let now = Date()
                lastSyncDate = now

                if outboxQueue.isEmpty {
                    syncStatus = .synced(lastSync: now)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    break
                } else if outboxQueue.count < previousOutboxCount {
                    // Houve redução na fila: continua para descarregar o lote seguinte dentro desta sync manual
                    continue
                } else {
                    syncStatus = .outOfSync(pendingCount: outboxQueue.count, reason: "Alterações pendentes")
                    break
                }
            } catch let err as URLError where err.code == .userAuthenticationRequired {
                if !hasRetriedAuth, let auth = authService, await auth.renewTokens(baseURL: baseURLString) {
                    print("⚡️ [CloudSyncService] Token renovado após 401. Tentando novamente...")
                    await executeSyncPushPull(hasRetriedAuth: true)
                    return
                } else {
                    syncStatus = .authError(message: "Sessão expirada. Faça login novamente.")
                    break
                }
            } catch {
                syncStatus = .outOfSync(pendingCount: outboxQueue.count, reason: "Servidor indisponível")
                break
            }
        }
    }

    public func enqueueAllLocalData() {
        guard let store else { return }

        let accounts = store.accounts
        let creditCards = store.creditCards
        let creditCardInvoices = store.creditCardInvoices
        let categories = store.categories
        let contracts = store.contracts
        let plans = store.amortizationPlans
        let investments = store.investments
        let debts = store.debts
        let provisions = store.provisions
        let quotas = store.categoryQuotas
        let transactions = store.transactions

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        var allMutations: [LocalSyncMutation] = []

        func addItems<T: Codable>(items: [T], entityName: String, idKeyPath: KeyPath<T, UUID>) {
            for item in items {
                let entityId = item[keyPath: idKeyPath]
                let payloadJSON: String? = {
                    guard let data = try? encoder.encode(item) else { return nil }
                    return String(data: data, encoding: .utf8)
                }()
                let mutation = LocalSyncMutation(
                    entityName: entityName,
                    entityId: entityId,
                    operation: .upsert,
                    updatedAt: Date(),
                    payloadJSON: payloadJSON
                )
                allMutations.append(mutation)
            }
        }

        // Enqueue in strict dependency order:
        addItems(items: accounts, entityName: "bank_accounts", idKeyPath: \.id)
        addItems(items: creditCards, entityName: "credit_cards", idKeyPath: \.id)
        addItems(items: creditCardInvoices, entityName: "credit_card_invoices", idKeyPath: \.id)
        addItems(items: categories, entityName: "categories", idKeyPath: \.id)
        addItems(items: contracts, entityName: "credit_contracts", idKeyPath: \.id)
        addItems(items: plans, entityName: "amortization_plans", idKeyPath: \.id)
        addItems(items: investments, entityName: "investment_items", idKeyPath: \.id)
        addItems(items: debts, entityName: "debt_items", idKeyPath: \.id)
        addItems(items: provisions, entityName: "category_provisions", idKeyPath: \.id)
        addItems(items: quotas, entityName: "category_quota_rules", idKeyPath: \.id)
        addItems(items: transactions, entityName: "financial_transactions", idKeyPath: \.id)

        for mutation in allMutations {
            enqueueMutation(mutation)
        }
        saveOutboxQueue()
        pendingMutationsCount = outboxQueue.count
    }

    private func applyServerChanges(_ changes: [SyncMutationDTO], into store: FinancialDataStore) {
        let decoder = BackendAPIClient.makeFlexibleDateDecoder()

        for change in changes {
            let changeDate: Date = {
                let f = ISO8601DateFormatter()
                if let d = f.date(from: change.updatedAt) { return d }
                return Date.distantPast
            }()

            // LWW: If local outbox has a pending mutation for this entity that is newer, retain local state
            if let pending = outboxQueue.first(where: { $0.entityId == change.entityId }) {
                if pending.updatedAt >= changeDate {
                    continue
                }
            }

            if change.operation == "DELETE" {
                switch change.entityName {
                case "financial_transactions": store.transactions.removeAll { $0.id == change.entityId }
                case "bank_accounts": store.accounts.removeAll { $0.id == change.entityId }
                case "credit_cards": store.creditCards.removeAll { $0.id == change.entityId }
                case "credit_card_invoices": store.creditCardInvoices.removeAll { $0.id == change.entityId }
                case "categories": store.categories.removeAll { $0.id == change.entityId }
                case "investment_items": store.investments.removeAll { $0.id == change.entityId }
                case "debt_items": store.debts.removeAll { $0.id == change.entityId }
                case "credit_contracts": store.contracts.removeAll { $0.id == change.entityId }
                case "amortization_plans": store.amortizationPlans.removeAll { $0.id == change.entityId }
                case "category_provisions": store.provisions.removeAll { $0.id == change.entityId }
                case "category_quota_rules": store.categoryQuotas.removeAll { $0.id == change.entityId }
                default: break
                }
            } else if let dataMap = change.data ?? change.payload,
                      let rawData = try? JSONEncoder().encode(dataMap) {
                switch change.entityName {
                case "financial_transactions":
                    if let item = try? decoder.decode(FinancialTransaction.self, from: rawData) {
                        if let idx = store.transactions.firstIndex(where: { $0.id == item.id }) { store.transactions[idx] = item }
                        else { store.transactions.append(item) }
                    }
                case "bank_accounts":
                    if let item = try? decoder.decode(BankAccount.self, from: rawData) {
                        if let idx = store.accounts.firstIndex(where: { $0.id == item.id }) { store.accounts[idx] = item }
                        else { store.accounts.append(item) }
                    }
                case "credit_cards":
                    if let item = try? decoder.decode(CreditCard.self, from: rawData) {
                        if let idx = store.creditCards.firstIndex(where: { $0.id == item.id }) { store.creditCards[idx] = item }
                        else { store.creditCards.append(item) }
                    }
                case "credit_card_invoices":
                    if let item = try? decoder.decode(CreditCardInvoice.self, from: rawData) {
                        if let idx = store.creditCardInvoices.firstIndex(where: { $0.id == item.id }) { store.creditCardInvoices[idx] = item }
                        else { store.creditCardInvoices.append(item) }
                    }
                case "categories":
                    if let item = try? decoder.decode(CategoryItem.self, from: rawData) {
                        if let idx = store.categories.firstIndex(where: { $0.id == item.id }) { store.categories[idx] = item }
                        else { store.categories.append(item) }
                    }
                case "investment_items":
                    if let item = try? decoder.decode(InvestmentItem.self, from: rawData) {
                        if let idx = store.investments.firstIndex(where: { $0.id == item.id }) { store.investments[idx] = item }
                        else { store.investments.append(item) }
                    }
                case "debt_items":
                    if let item = try? decoder.decode(DebtItem.self, from: rawData) {
                        if let idx = store.debts.firstIndex(where: { $0.id == item.id }) { store.debts[idx] = item }
                        else { store.debts.append(item) }
                    }
                case "credit_contracts":
                    if let item = try? decoder.decode(CreditContract.self, from: rawData) {
                        if let idx = store.contracts.firstIndex(where: { $0.id == item.id }) { store.contracts[idx] = item }
                        else { store.contracts.append(item) }
                    }
                case "amortization_plans":
                    if let item = try? decoder.decode(AmortizationPlan.self, from: rawData) {
                        if let idx = store.amortizationPlans.firstIndex(where: { $0.id == item.id }) { store.amortizationPlans[idx] = item }
                        else { store.amortizationPlans.append(item) }
                        store.syncPlannedAmortizationTransactions(for: item.contractId, saveAfter: false)
                    }
                case "category_provisions":
                    if let item = try? decoder.decode(CategoryProvision.self, from: rawData) {
                        if let idx = store.provisions.firstIndex(where: { $0.id == item.id }) { store.provisions[idx] = item }
                        else { store.provisions.append(item) }
                    }
                case "category_quota_rules":
                    if let item = try? decoder.decode(CategoryQuotaRule.self, from: rawData) {
                        if let idx = store.categoryQuotas.firstIndex(where: { $0.id == item.id }) { store.categoryQuotas[idx] = item }
                        else { store.categoryQuotas.append(item) }
                    }
                default: break
                }
            }
        }
        store.saveToDisk()
        store.objectWillChange.send()
    }

    private func applyDeltasToStore(
        _ deltas: SyncDeltasContainerDTO,
        tombstones: [SyncTombstoneDTO],
        into store: FinancialDataStore
    ) {
        for tomb in tombstones {
            let tombDate = ISO8601DateFormatter().date(from: tomb.deletedAt) ?? Date.distantPast
            if let pending = outboxQueue.first(where: { $0.entityId == tomb.entityId }) {
                if pending.updatedAt >= tombDate && pending.operation != .delete {
                    continue
                }
            }

            switch tomb.entityName {
            case "financial_transactions": store.transactions.removeAll { $0.id == tomb.entityId }
            case "bank_accounts": store.accounts.removeAll { $0.id == tomb.entityId }
            case "credit_cards": store.creditCards.removeAll { $0.id == tomb.entityId }
            case "credit_card_invoices": store.creditCardInvoices.removeAll { $0.id == tomb.entityId }
            case "categories": store.categories.removeAll { $0.id == tomb.entityId }
            case "investment_items": store.investments.removeAll { $0.id == tomb.entityId }
            case "debt_items": store.debts.removeAll { $0.id == tomb.entityId }
            case "credit_contracts": store.contracts.removeAll { $0.id == tomb.entityId }
            case "amortization_plans": store.amortizationPlans.removeAll { $0.id == tomb.entityId }
            case "category_provisions": store.provisions.removeAll { $0.id == tomb.entityId }
            case "category_quota_rules": store.categoryQuotas.removeAll { $0.id == tomb.entityId }
            default: break
            }
        }

        if let txs = deltas.financialTransactions {
            for item in txs {
                if outboxQueue.contains(where: { $0.entityId == item.id }) { continue }
                if let idx = store.transactions.firstIndex(where: { $0.id == item.id }) {
                    store.transactions[idx] = item
                } else {
                    store.transactions.append(item)
                }
            }
        }
        if let accs = deltas.bankAccounts {
            for item in accs {
                if outboxQueue.contains(where: { $0.entityId == item.id }) { continue }
                if let idx = store.accounts.firstIndex(where: { $0.id == item.id }) {
                    store.accounts[idx] = item
                } else {
                    store.accounts.append(item)
                }
            }
        }
        if let cards = deltas.creditCards {
            for item in cards {
                if outboxQueue.contains(where: { $0.entityId == item.id }) { continue }
                if let idx = store.creditCards.firstIndex(where: { $0.id == item.id }) {
                    store.creditCards[idx] = item
                } else {
                    store.creditCards.append(item)
                }
            }
        }
        if let invoices = deltas.creditCardInvoices {
            for item in invoices {
                if outboxQueue.contains(where: { $0.entityId == item.id }) { continue }
                if let idx = store.creditCardInvoices.firstIndex(where: { $0.id == item.id }) {
                    store.creditCardInvoices[idx] = item
                } else {
                    store.creditCardInvoices.append(item)
                }
            }
        }
        if let cats = deltas.categories {
            for item in cats {
                if outboxQueue.contains(where: { $0.entityId == item.id }) { continue }
                if let idx = store.categories.firstIndex(where: { $0.id == item.id }) {
                    store.categories[idx] = item
                } else {
                    store.categories.append(item)
                }
            }
        }
        if let invs = deltas.investmentItems {
            for item in invs {
                if outboxQueue.contains(where: { $0.entityId == item.id }) { continue }
                if let idx = store.investments.firstIndex(where: { $0.id == item.id }) {
                    store.investments[idx] = item
                } else {
                    store.investments.append(item)
                }
            }
        }
        if let debts = deltas.debtItems {
            for item in debts {
                if outboxQueue.contains(where: { $0.entityId == item.id }) { continue }
                if let idx = store.debts.firstIndex(where: { $0.id == item.id }) {
                    store.debts[idx] = item
                } else {
                    store.debts.append(item)
                }
            }
        }
        if let contracts = deltas.creditContracts {
            for item in contracts {
                if outboxQueue.contains(where: { $0.entityId == item.id }) { continue }
                if let idx = store.contracts.firstIndex(where: { $0.id == item.id }) {
                    store.contracts[idx] = item
                } else {
                    store.contracts.append(item)
                }
            }
        }
        if let plans = deltas.amortizationPlans {
            for item in plans {
                if outboxQueue.contains(where: { $0.entityId == item.id }) { continue }
                if let idx = store.amortizationPlans.firstIndex(where: { $0.id == item.id }) {
                    store.amortizationPlans[idx] = item
                } else {
                    store.amortizationPlans.append(item)
                }
                store.syncPlannedAmortizationTransactions(for: item.contractId, saveAfter: false)
            }
        }
        if let provisions = deltas.categoryProvisions {
            for item in provisions {
                if outboxQueue.contains(where: { $0.entityId == item.id }) { continue }
                if let idx = store.provisions.firstIndex(where: { $0.id == item.id }) {
                    store.provisions[idx] = item
                } else {
                    store.provisions.append(item)
                }
            }
        }
        if let quotas = deltas.categoryQuotaRules {
            for item in quotas {
                if outboxQueue.contains(where: { $0.entityId == item.id }) { continue }
                if let idx = store.categoryQuotas.firstIndex(where: { $0.id == item.id }) {
                    store.categoryQuotas[idx] = item
                } else {
                    store.categoryQuotas.append(item)
                }
            }
        }

        store.saveToDisk()
        store.objectWillChange.send()
    }

    private func saveOutboxQueue() {
        let snapshot = outboxQueue
        let targetURL = outboxFileURL
        outboxPersistenceQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: targetURL, options: .atomic)
        }
    }

    private func loadOutboxQueue() {
        guard let data = try? Data(contentsOf: outboxFileURL),
              let decoded = try? JSONDecoder().decode([LocalSyncMutation].self, from: data) else {
            self.outboxQueue = []
            return
        }
        self.outboxQueue = decoded
        self.pendingMutationsCount = decoded.count
    }

    public func queueEntireDatabaseForUpload(store: FinancialDataStore) {
        for acc in store.accounts {
            recordLocalMutation(entityName: "bank_accounts", entityId: acc.id, operation: .upsert, entity: acc)
        }
        for cat in store.categories {
            recordLocalMutation(entityName: "categories", entityId: cat.id, operation: .upsert, entity: cat)
        }
        for tx in store.transactions {
            recordLocalMutation(entityName: "financial_transactions", entityId: tx.id, operation: .upsert, entity: tx)
        }
        for inv in store.investments {
            recordLocalMutation(entityName: "investment_items", entityId: inv.id, operation: .upsert, entity: inv)
        }
        for debt in store.debts {
            recordLocalMutation(entityName: "debt_items", entityId: debt.id, operation: .upsert, entity: debt)
        }
        for contract in store.contracts {
            recordLocalMutation(entityName: "credit_contracts", entityId: contract.id, operation: .upsert, entity: contract)
        }
        for plan in store.amortizationPlans {
            recordLocalMutation(entityName: "amortization_plans", entityId: plan.id, operation: .upsert, entity: plan)
        }
        for prov in store.provisions {
            recordLocalMutation(entityName: "category_provisions", entityId: prov.id, operation: .upsert, entity: prov)
        }
        for quota in store.categoryQuotas {
            recordLocalMutation(entityName: "category_quota_rules", entityId: quota.id, operation: .upsert, entity: quota)
        }
    }
}
